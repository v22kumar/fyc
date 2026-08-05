"""The questions we drip-feed members, and the rules that keep it civil.

The catalogue lives in code rather than the database on purpose: these are UI
strings, they need translating, and reordering them should not need a
migration. The client renders them from its own string registry using the ids
here, so adding a language is still one file.

Ordering is deliberate. Blood group comes first because the blood-donation
screen is useless without it — GPS ranking and compatible-group matching mean
nothing if nobody's group is known.
"""
from dataclasses import dataclass, field
from typing import List, Optional


@dataclass(frozen=True)
class ProfileQuestion:
    """One question, answerable in a single tap."""

    id: str
    # Registry id the client resolves to the member's language.
    prompt_id: str
    # Fixed choices. Free text is a form; a form is what we are avoiding.
    options: List[str] = field(default_factory=list)
    # Column on UserProfile to write through to, when the answer is something
    # the rest of the app already reads. Without this the answer would sit in
    # a table nothing queries.
    profile_field: Optional[str] = None
    # Lower runs first.
    priority: int = 100


BLOOD_GROUPS = ["A+", "A-", "B+", "B-", "AB+", "AB-", "O+", "O-"]

CATALOGUE: List[ProfileQuestion] = [
    # First, because everything in the blood feature depends on it.
    ProfileQuestion(
        id="blood_group",
        prompt_id="q_blood_group",
        options=BLOOD_GROUPS + ["dont_know"],
        profile_field="blood_group",
        priority=1,
    ),
    ProfileQuestion(
        id="gender",
        prompt_id="q_gender",
        options=["male", "female", "other", "prefer_not_to_say"],
        profile_field="gender",
        priority=10,
    ),
    # No profile column yet — the answer is kept for the club's own picture of
    # its membership, and a column can follow once there is something to do
    # with it.
    ProfileQuestion(
        id="education",
        prompt_id="q_education",
        options=["school", "diploma", "graduate", "postgraduate", "other"],
        priority=20,
    ),
    ProfileQuestion(
        id="volunteer_interest",
        prompt_id="q_volunteer_interest",
        options=["events", "sports", "blood_drives", "teaching", "not_now"],
        priority=30,
    ),
]

BY_ID = {q.id: q for q in CATALOGUE}

# How long to leave a member alone after they answer or dismiss anything. The
# point of this feature is that it never feels like a form; asking daily would
# undo that on its own.
QUIET_DAYS_AFTER_RESPONSE = 2

# A dismissed question goes to the back rather than away — but not back within
# a fortnight, or dismissing would mean nothing.
QUIET_DAYS_AFTER_DISMISS = 14

# If a member neither answers nor dismisses, stop repeating the same card
# every session.
QUIET_DAYS_AFTER_SHOWN = 1

# After this many dismissals, take the hint.
MAX_DISMISSALS = 3
