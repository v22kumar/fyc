"""Two accounts for one person, folded into one.

A member can end up with two rows without doing anything wrong: an account
created by email with a password (how officers were set up), and an account
created later by signing in with a phone number. They are the same human, but
to the database they are strangers — and because a phone number is unique per
club, OTP sign-in can only ever land in the phone one. The officer signs in and
finds themselves an ordinary member.

Merging means moving everything the second account owns onto the first, taking
its phone number with it, and deleting it. What "everything" means is not a
list somebody typed out: **74 columns across 58 tables** point at a user today,
and any hand-written list would be wrong the day after the next table is added.
So the columns are discovered from the schema itself.

Two things make this safe enough to run on real data:

* **Dry run.** The real merge executes inside a savepoint and rolls back, so the
  report you read is what actually happened, not a prediction of it.
* **Collisions are resolved, not crashed into.** Some tables allow one row per
  user — a profile, a membership card, notification preferences — and some carry
  a uniqueness rule like "one registration per event per member". Where both
  accounts have a row, the surviving account keeps its own and the duplicate is
  deleted, counted, and reported rather than aborting the merge.
"""
from __future__ import annotations

import logging
from typing import Any

from sqlalchemy import select, update
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.core.database import Base
from app.models.user import User, UserProfile

logger = logging.getLogger(__name__)

# Strongest wins. A merge must never quietly demote somebody, and must never
# promote them either — the result is whichever role the two accounts already
# had, at its highest.
_ROLE_RANK = [
    "PUBLIC_CITIZEN", "VOLUNTEER", "CLUB_MEMBER",
    "EXECUTIVE_MEMBER", "ADMIN", "SUPER_ADMIN",
]

# Set by the owner, not copied from the other account: identity columns are
# handled explicitly below, and bookkeeping is not worth carrying over.
_PROFILE_SKIP = {"id", "user_id", "created_at", "updated_at", "deleted_at"}


def _user_fk_columns() -> list[tuple[Any, Any]]:
    """Every (table, column) in the schema that points at users.id."""
    found = []
    for table in Base.metadata.tables.values():
        for column in table.columns:
            for fk in column.foreign_keys:
                if fk.column.table.name == "users":
                    found.append((table, column))
    return found


def _is_blank(value: Any) -> bool:
    return value is None or (isinstance(value, str) and not value.strip())


def _move_rows(db: Session, table, column, merged_id, keep_id) -> tuple[int, int]:
    """Repoint one column, returning (moved, dropped_as_duplicate).

    Tried as a single statement first, because that is the normal case and it
    is one round trip. A uniqueness rule the merge would violate — "one profile
    per user", "one registration per event per member" — sends it down the slow
    path, where each row is retried alone and a genuine duplicate is deleted
    rather than aborting everything behind it.
    """
    pk = list(table.primary_key.columns)
    try:
        with db.begin_nested():
            result = db.execute(
                update(table).where(column == merged_id).values({column.name: keep_id})
            )
        return result.rowcount or 0, 0
    except IntegrityError:
        pass

    if not pk:
        # No primary key to address rows individually. Dropping them is the only
        # remaining option, and it is reported as such.
        with db.begin_nested():
            dropped = db.execute(table.delete().where(column == merged_id))
        return 0, dropped.rowcount or 0

    rows = db.execute(select(*pk).where(column == merged_id)).all()
    moved = dropped = 0
    for row in rows:
        where = [c == v for c, v in zip(pk, row)]
        try:
            with db.begin_nested():
                db.execute(update(table).where(*where).values({column.name: keep_id}))
            moved += 1
        except IntegrityError:
            with db.begin_nested():
                db.execute(table.delete().where(*where))
            dropped += 1
    return moved, dropped


def _absorb_profile(db: Session, keep: User, merged: User) -> list[str]:
    """Fill blanks on the surviving profile from the one being retired.

    This is usually where the real information is. An officer's email account
    was created by an administrator and carries little more than a name; the
    phone account was created by the member themselves and is where the date of
    birth, blood group, area and anniversary actually live. Only blanks are
    filled — an existing answer is never overwritten.
    """
    keep_profile = db.query(UserProfile).filter(UserProfile.user_id == keep.id).first()
    merged_profile = db.query(UserProfile).filter(UserProfile.user_id == merged.id).first()
    if merged_profile is None:
        return []
    if keep_profile is None:
        # Nothing to merge into — the row simply changes hands.
        merged_profile.user_id = keep.id
        return ["(whole profile moved)"]

    filled = []
    for column in UserProfile.__table__.columns:
        name = column.name
        if name in _PROFILE_SKIP:
            continue
        incoming = getattr(merged_profile, name, None)
        if _is_blank(getattr(keep_profile, name, None)) and not _is_blank(incoming):
            setattr(keep_profile, name, incoming)
            filled.append(name)
    return filled


def merge_accounts(db: Session, keep: User, merged: User,
                   dry_run: bool = True) -> dict:
    """Fold `merged` into `keep`. Returns a report of everything that moved.

    On a dry run every statement below really executes and is then rolled back,
    so the numbers are observed rather than estimated — including the duplicate
    collisions, which are the part nobody can predict by reading the schema.
    """
    if keep.id == merged.id:
        raise ValueError("an account cannot be merged into itself")
    if keep.organization_id != merged.organization_id:
        raise ValueError("accounts belong to different clubs")

    report: dict[str, Any] = {
        "keep_user_id": str(keep.id),
        "merged_user_id": str(merged.id),
        "dry_run": dry_run,
        "moved": {},
        "duplicates_dropped": {},
        "profile_fields_filled": [],
        "phone_number_moved": None,
        "email_moved": None,
        "role_before": keep.role,
        "role_after": keep.role,
    }

    outer = db.begin_nested()
    try:
        report["profile_fields_filled"] = _absorb_profile(db, keep, merged)

        # The number is what identifies a member, and it is unique per club, so
        # it has to leave the old row before it can arrive at the new one.
        if merged.phone_number and not keep.phone_number:
            moving = merged.phone_number
            merged.phone_number = None
            db.flush()
            keep.phone_number = moving
            report["phone_number_moved"] = moving
        elif merged.phone_number:
            # The surviving account already has a number. Keep it; the other is
            # released so the row can be deleted without holding the constraint.
            merged.phone_number = None
            report["phone_number_moved"] = "kept existing"

        if merged.email and not keep.email:
            keep.email = merged.email
            merged.email = None
            report["email_moved"] = keep.email

        # Whichever of the two was stronger. Never weaker, never stronger.
        ranks = [r for r in (keep.role, merged.role) if r in _ROLE_RANK]
        if ranks:
            keep.role = max(ranks, key=_ROLE_RANK.index)
        report["role_after"] = keep.role
        if merged.is_verified:
            keep.is_verified = True
        db.flush()

        for table, column in _user_fk_columns():
            if table.name == "users":
                continue
            moved, dropped = _move_rows(db, table, column, merged.id, keep.id)
            key = f"{table.name}.{column.name}"
            if moved:
                report["moved"][key] = moved
            if dropped:
                report["duplicates_dropped"][key] = dropped

        # A merge can leave somebody blocking themselves, which is nonsense the
        # schema is happy to store.
        blocks = Base.metadata.tables.get("user_blocks")
        if blocks is not None:
            db.execute(blocks.delete().where(
                blocks.c.blocker_id == keep.id, blocks.c.blocked_id == keep.id))

        db.delete(merged)
        db.flush()
        report["merged_account_deleted"] = True
    except Exception:
        outer.rollback()
        raise

    if dry_run:
        outer.rollback()
    else:
        outer.commit()
        db.commit()
    return report
