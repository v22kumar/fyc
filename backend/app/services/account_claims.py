"""Who owns a phone number, and who has merely typed one.

The club identifies members by phone number — `uq_org_phone` makes it the key.
That is right, and it is exactly why letting somebody register with a number
they have not proven is dangerous: the row would own the number, and the real
owner signing in by OTP would land in a stranger's account. Account takeover by
registration, needing nothing but a keyboard.

So an unverified identifier is a **claim**, not ownership:

* a claim reserves nothing — anyone may register the same number, and none of
  them are the member until one of them answers a code on it;
* **proof beats a claim, always.** When somebody verifies a number by OTP, any
  unverified claim on it is released to them. The impostor keeps their account,
  their password and their name; they simply stop holding a number that was
  never theirs.

That last rule is what makes deferred verification safe here. Without it, the
first person to type a number wins — which is the opposite of what a village
club needs, where the number *is* the person.
"""
from __future__ import annotations

from datetime import datetime, timezone
from uuid import UUID

from sqlalchemy.orm import Session

from app.models.user import User


def owner_of_phone(db: Session, organization_id: UUID, phone: str) -> User | None:
    """The member who has *proven* this number, if anyone has."""
    return (
        db.query(User)
        .filter(
            User.organization_id == organization_id,
            User.phone_number == phone,
            User.phone_verified_at.isnot(None),
        )
        .first()
    )


def claimants_of_phone(db: Session, organization_id: UUID, phone: str) -> list[User]:
    """Accounts holding this number without having proven it."""
    return (
        db.query(User)
        .filter(
            User.organization_id == organization_id,
            User.phone_number == phone,
            User.phone_verified_at.is_(None),
        )
        .all()
    )


def release_claims(db: Session, organization_id: UUID, phone: str,
                   keep: User) -> int:
    """Take a number away from everyone who never proved it.

    Called the moment somebody answers a code on it. The claimants keep their
    accounts and their passwords — they lose only a number that was never
    theirs, and they can still sign in by email.

    Returns how many claims were released, because a number being contested is
    worth knowing about.
    """
    released = 0
    for claimant in claimants_of_phone(db, organization_id, phone):
        if claimant.id == keep.id:
            continue
        claimant.phone_number = None
        released += 1
    return released


def mark_phone_verified(db: Session, user: User) -> int:
    """Record proof, and settle the number in the same breath.

    One function rather than two, because a verification that stamps the date
    and leaves a rival claim in place has created exactly the ambiguity the
    stamp was meant to end.
    """
    user.phone_verified_at = datetime.now(timezone.utc)
    user.is_verified = True
    released = 0
    if user.phone_number:
        released = release_claims(db, user.organization_id, user.phone_number, user)
    return released
