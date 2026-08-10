"""A sign-in that is half finished, kept somewhere that outlives the process.

The pending OTP used to be a module-level Python dict. On one machine with one
worker that looks fine — and it is, right up until the process restarts. A
deploy, a crash, an out-of-memory kill, a host migration: any of them silently
empties the dict, and every member who has the SMS in their hand but has not
typed it yet is told **"Invalid or expired verification ID"**.

That message is the worst part. It is indistinguishable from typing the wrong
code, so nobody reports a server problem — they assume they fumbled it, request
another code, and hit the same wall. During a period of frequent deploys this
reads exactly like "login is down and we don't know why".

A row in the database costs one insert and one delete per sign-in, survives
every restart, and would let a second instance serve verify traffic if the app
ever grows past one machine. The code itself is never stored: only an HMAC of
it, so a leaked table hands over nothing usable inside the ten minutes it lives.
"""
from sqlalchemy import Column, DateTime, Integer, String

from app.core.database import Base
from app.models.base import GUID, TimestampMixin


class PendingOtp(Base, TimestampMixin):
    __tablename__ = "pending_otps"

    # The opaque handle we gave the app ("v_ab12cd34ef56"). The app sends it
    # back with the typed code, and it is the only way into this row.
    verification_id = Column(String(40), primary_key=True)

    phone_number = Column(String(20), nullable=False, index=True)
    organization_id = Column(GUID(), nullable=False)

    # NULL when Twilio Verify holds the code on its own side — then this row
    # exists only to remember which phone and org the handle belongs to.
    # Otherwise: HMAC-SHA256 of the code, never the code.
    code_hash = Column(String(64), nullable=True)

    expires_at = Column(DateTime(timezone=True), nullable=False)

    # Wrong guesses so far. At the limit the row is deleted outright, so a
    # six-digit code can never be ground down inside its lifetime.
    attempts = Column(Integer, nullable=False, default=0)
