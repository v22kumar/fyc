"""Recording a payment: who it was from, and whether we have it already.

Two problems live here, and they are not the same problem.

**Identity.** A contribution should link to a member when there is one, and
still work when there is not. The repository already solved this shape once —
`EventRegistration` carries a nullable `user_id` beside a plain name and mobile
number — so this reuses it rather than introducing a fourth table of people
that would need its own de-duplication, merge tooling and privacy rules. What a
separate table would have bought is one thing: the ability to count distinct
contributors and to look up one person's history. A derived key buys that too.

**Repetition.** Three different things all look like "the same payment twice",
they have different causes, and treating them identically is why duplicate
protection usually ends up either useless or infuriating:

  1. the request arrived twice — a double tap, a retry, an offline entry
     replayed after it already landed. Not a duplicate at all. The client id
     absorbs it and nobody is told anything.
  2. the same transaction reference recorded twice. A UTR is unique in the real
     world; two of them is always an error, so it is refused outright.
  3. the same person, same amount, minutes apart. Might be a mistake, might be
     two people who both gave ₹500 in cash. Only a human knows, so ask.
"""
from __future__ import annotations

import re
from datetime import datetime, timedelta, timezone
from typing import Optional

from sqlalchemy.orm import Session

from app.models.audit import AuditLog
from app.models.finance import Contribution

# How close in time two identical-looking entries have to be before we suspect
# the treasurer's thumb rather than two generous neighbours.
DUPLICATE_WINDOW = timedelta(minutes=10)

_NON_DIGITS = re.compile(r"\D+")
_SPACES = re.compile(r"\s+")


def normalise_phone(phone: Optional[str]) -> Optional[str]:
    """Last ten digits, or None.

    +91 94879 84964, 09487984964 and 9487984964 are one person. Country code
    and spacing are how the number was typed, not who it belongs to.
    """
    if not phone:
        return None
    digits = _NON_DIGITS.sub("", phone)
    return digits[-10:] if len(digits) >= 10 else (digits or None)


def contributor_key(user_id, phone: Optional[str], name: str) -> str:
    """A stable handle for one giver, in descending order of confidence.

    A selected member is certain. A phone number is nearly certain. A bare name
    is a guess — two Ravis in one village collapse into one key — but it is the
    honest limit of what was collected, and it is better than counting every
    row as a separate person.
    """
    if user_id:
        return f"u:{user_id}"
    tel = normalise_phone(phone)
    if tel:
        return f"p:{tel}"
    return f"n:{_SPACES.sub(' ', (name or '').strip()).casefold()[:70]}"


def normalise_reference(reference: Optional[str]) -> Optional[str]:
    """utr123456 and 'UTR 123456' are the same reference."""
    if not reference:
        return None
    cleaned = _SPACES.sub("", reference).upper()
    return cleaned or None


# ── The three layers ────────────────────────────────────────────────────────

def find_by_client_id(db: Session, campaign_id, recorder_id,
                      client_id: Optional[str]) -> Optional[Contribution]:
    """Layer 1. The row this exact request already created, if it did."""
    if not client_id:
        return None
    return db.query(Contribution).filter(
        Contribution.campaign_id == campaign_id,
        Contribution.recorded_by_user_id == recorder_id,
        Contribution.client_contribution_id == client_id,
    ).first()


def find_by_reference(db: Session, campaign_id,
                      reference: Optional[str]) -> Optional[Contribution]:
    """Layer 2. A live contribution already carrying this reference.

    Cancelled and rejected rows are skipped: a reference entered in error and
    withdrawn must not block the correct entry that replaces it.
    """
    ref = normalise_reference(reference)
    if not ref:
        return None
    return db.query(Contribution).filter(
        Contribution.campaign_id == campaign_id,
        Contribution.reference_no == ref,
        Contribution.status.notin_(("CANCELLED", "REJECTED")),
    ).first()


def find_similar(db: Session, campaign_id, key: str, amount_paise: int,
                 *, now: Optional[datetime] = None,
                 recorder_id=None) -> list[Contribution]:
    """Layer 3. Same giver, same amount, in the last few minutes.

    Returned rather than refused. Two neighbours can each hand over ₹500 a
    minute apart, and a system that will not let a treasurer record the second
    one is a system they stop using.

    `recorder_id` narrows the search to one person's entries. It is passed for
    a caller who may only see their own rows, because the answer carries the
    matching contributor's name and who recorded it — and telling somebody
    "this looks like a repeat" is not a reason to show them a row they are
    otherwise not allowed to read.
    """
    now = now or datetime.now(timezone.utc)
    since = now - DUPLICATE_WINDOW
    q = db.query(Contribution).filter(
        Contribution.campaign_id == campaign_id,
        Contribution.contributor_key == key,
        Contribution.amount_paise == amount_paise,
        Contribution.status.notin_(("CANCELLED", "REJECTED")),
        Contribution.created_at >= since,
    )
    if recorder_id is not None:
        q = q.filter(Contribution.recorded_by_user_id == recorder_id)
    return q.order_by(Contribution.created_at.desc()).limit(5).all()


# ── Audit ───────────────────────────────────────────────────────────────────

def record_audit(db: Session, *, user, action: str, contribution_id,
                 old: Optional[dict] = None, new: Optional[dict] = None,
                 table: str = "contributions") -> None:
    """Write to the audit log the club already has.

    A second, finance-specific audit table would be one more thing to keep
    correct and would carry no truth `AuditLog` does not already carry: who,
    when, against which row, from what, to what. Reusing it also means finance
    changes appear in the same place admins already look.
    """
    db.add(AuditLog(
        organization_id=user.organization_id,
        user_id=user.id,
        action_type=action,
        target_table=table,
        target_id=contribution_id,
        old_values=old,
        new_values=new,
    ))


def snapshot(c: Contribution) -> dict:
    """The fields worth remembering the previous value of."""
    return {
        "amount_paise": c.amount_paise,
        "method": c.method,
        "reference_no": c.reference_no,
        "paid_on": c.paid_on.isoformat() if c.paid_on else None,
        "status": c.status,
        "contributor_name": c.contributor_name,
        "contributor_phone": c.contributor_phone,
        "notes": c.notes,
    }
