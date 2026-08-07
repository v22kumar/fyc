"""Build the letter a member sends.

The skeleton is code. A model fills two slots.

Asking a model to write the whole letter gives a different letter every time,
a bill for each one, and — the part that matters — no letter at all when the
quota runs out or the call fails. Here the shape is fixed and written once, and
the model is asked for exactly two things: a subject line, and a few sentences
of formal description. If it cannot answer, the member's own words go in and
the letter still sends. Plainer, not broken.

The letter is the member's. It does not carry the club's name, because in
Lane A the club did not write it and did not send it.
"""
from __future__ import annotations

from dataclasses import dataclass
from datetime import date
from typing import Optional

#: Anything above this and a mail client starts truncating, or the intent URI
#: breaks. The description is trimmed rather than the address block, which is
#: the part an officer needs.
MAX_BODY_CHARS = 4000


def maps_link(latitude, longitude) -> Optional[str]:
    """A link that opens the pin.

    "GPS 8.1833, 77.4119" means nothing to an engineer reading mail on a phone.
    """
    if latitude is None or longitude is None:
        return None
    return f"https://www.google.com/maps/search/?api=1&query={latitude},{longitude}"


@dataclass(frozen=True)
class Recipient:
    designation: str
    office: str
    email: Optional[str] = None

    @property
    def line(self) -> str:
        return f"{self.designation}, {self.office}" if self.office else self.designation


@dataclass(frozen=True)
class CallRecord:
    """A call the member made and told us about.

    This is the most valuable line in the letter and it costs one tap. An
    Executive Engineer reading "I spoke to the Assistant Engineer on 5 August,
    who said it would be seen to; there has been no action since" is being told
    the ladder has already been climbed.
    """

    office: str
    on: date
    outcome: str  # REACHED / NO_ANSWER / PROMISED


def _calls_paragraph(calls: list[CallRecord]) -> str:
    if not calls:
        return ""
    lines = []
    for c in calls:
        when = c.on.strftime("%-d %B %Y") if hasattr(c.on, "strftime") else str(c.on)
        if c.outcome == "PROMISED":
            lines.append(f"I spoke to the {c.office} on {when}, who said it would "
                         "be attended to.")
        elif c.outcome == "REACHED":
            lines.append(f"I spoke to the {c.office} on {when}.")
        else:
            lines.append(f"I tried to reach the {c.office} on {when} without an "
                         "answer.")
    lines.append("There has been no action since.")
    return "\n".join(lines)


def build_letter(
    *,
    recipient: Recipient,
    subject: str,
    body: str,
    reporter_name: str,
    reporter_phone: Optional[str] = None,
    reporter_address: Optional[str] = None,
    place_name: Optional[str] = None,
    latitude=None,
    longitude=None,
    photo_url: Optional[str] = None,
    reference: Optional[str] = None,
    reported_on: Optional[date] = None,
    calls: Optional[list[CallRecord]] = None,
) -> tuple[str, str]:
    """Return (subject, body) ready to hand to a mail client."""
    parts: list[str] = [f"To: {recipient.line}", "", "Sir / Madam,", ""]

    trimmed = (body or "").strip()
    if len(trimmed) > MAX_BODY_CHARS:
        trimmed = trimmed[:MAX_BODY_CHARS].rstrip() + "…"
    parts.append(trimmed)

    called = _calls_paragraph(calls or [])
    if called:
        parts += ["", called]

    parts.append("")
    if place_name:
        parts.append(f"Location:  {place_name}")
    link = maps_link(latitude, longitude)
    if link:
        parts.append(f"{'           ' if place_name else 'Location:  '}{link}")
    if reported_on:
        parts.append(f"Reported:  {reported_on.isoformat()}")
    if photo_url:
        parts.append(f"Photo:     {photo_url}")
    if reference:
        parts.append(f"Reference: {reference}")

    parts += ["", reporter_name]
    if reporter_phone:
        parts.append(reporter_phone)
    if reporter_address:
        parts.append(reporter_address)

    return subject.strip(), "\n".join(parts)
