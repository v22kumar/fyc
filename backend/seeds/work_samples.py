"""A handful of example listings, so the index is not empty on day one.

The cold-start research is blunt: somebody who opens a category and finds
nothing concludes the whole app is empty and does not come back. A directory
has to look like a directory before anybody will add themselves to it.

**But these are not real people, and the app never pretends they are.**

India reserves no fictional telephone range — any ten-digit number invented
here could belong to somebody who would then be rung by strangers about
carpentry. So every sample carries an unusable number, is flagged in the
database, is shown with a "Sample" mark, and the Call button refuses to dial
it. An index that looked populated by quietly putting a stranger's phone in
front of members would be worse than an empty one.

They are removed by `remove(db, org_id)` — worth doing once real listings
outnumber them, because the honest version of this feature has no samples in
it at all.
"""
from __future__ import annotations

import uuid
from typing import Optional
from uuid import UUID

from sqlalchemy.orm import Session

from app.models.work import Listing, ListingKind

#: Never dialled — the app blocks it — but written as something a person can
#: see is not a phone number.
SAMPLE_PHONE = "0000000000"

_NOTE = ("Sample listing added by FYC to show how this works. "
         "This is not a real person — add your own to replace it.")

# name, kind, category, about, area, hours
SAMPLES = [
    ("Murugan A.", "PERSON", "CARPENTRY",
     "Doors, window frames, interlock brick work", "Vadasery", None),
    ("Selvam Furniture", "BUSINESS", "CARPENTRY",
     "Custom furniture and repairs", "Putheri", "9am – 8pm"),
    ("Anitha R.", "PERSON", "TUITION",
     "Maths and science, classes 6 to 10", "Nagercoil town", None),
    ("Bala Mobile Care", "BUSINESS", "MOBILE_REPAIR",
     "Screen replacement, battery, water damage", "Vadasery", "10am – 9pm"),
    ("Suresh K.", "PERSON", "ELECTRICAL",
     "House wiring, fan and light fitting", "Ozhuginasery", None),
    ("Jeyaraj M.", "PERSON", "PLUMBING",
     "Taps, pipe leaks, bathroom fitting", "Chettikulam", None),
    ("Kumar Painting Works", "BUSINESS", "PAINTING",
     "Interior and exterior, whitewash", "Putheri", "8am – 6pm"),
    ("Ravi S.", "PERSON", "BIKE_REPAIR",
     "All two-wheelers, servicing and puncture", "Vadasery", None),
    ("Lakshmi Tailors", "BUSINESS", "TAILORING",
     "Blouse, salwar, alterations", "Nagercoil town", "9am – 7pm"),
    ("Prakash D.", "PERSON", "PHOTOGRAPHY",
     "Weddings, functions, school events", "Nagercoil town", None),
    ("Vetri Catering", "BUSINESS", "CATERING",
     "Functions from 50 to 500 people", "Ozhuginasery", None),
    ("Arun P.", "PERSON", "SOFTWARE",
     "Websites and small business software", "Nagercoil town", None),
    ("Mani V.", "PERSON", "DAILY_LABOUR",
     "Building work, loading, garden clearing", "Chettikulam", None),
    ("Shanthi Beauty Parlour", "BUSINESS", "BEAUTY",
     "Bridal, threading, hair", "Vadasery", "10am – 8pm"),
]


def seed(db: Session, organization_id: UUID, owner_user_id: UUID) -> int:
    """Add the samples that are not there yet. Idempotent by name."""
    existing = {
        n for (n,) in db.query(Listing.display_name).filter(
            Listing.organization_id == organization_id,
            Listing.is_sample.is_(True),
        )
    }
    made = 0
    for name, kind, category, about, area, hours in SAMPLES:
        if name in existing:
            continue
        db.add(Listing(
            id=uuid.uuid4(),
            organization_id=organization_id,
            owner_user_id=owner_user_id,
            kind=(ListingKind.BUSINESS.value if kind == "BUSINESS"
                  else ListingKind.PERSON.value),
            display_name=name,
            category=category,
            about=f"{about}\n\n{_NOTE}",
            area=area,
            phone=SAMPLE_PHONE,
            hours=hours,
            is_sample=True,
        ))
        made += 1
    if made:
        db.flush()
    return made


def remove(db: Session, organization_id: UUID) -> int:
    """Take the samples out.

    Worth running once real listings outnumber them: the honest version of
    this feature has no samples in it at all.
    """
    rows = db.query(Listing).filter(
        Listing.organization_id == organization_id,
        Listing.is_sample.is_(True),
    ).all()
    for r in rows:
        db.delete(r)
    if rows:
        db.flush()
    return len(rows)
