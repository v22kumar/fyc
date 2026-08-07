"""What may happen to a complaint, and in what order.

The model carries a comment that explains how this got lost:

    # Removed VALID_TRANSITIONS to allow flexible community updates

The flexibility that was wanted is real — a reviewer needs to be able to reject
late, a volunteer needs to be able to record a resolution. But it belongs in
*who may act*, not in *which states exist*. With the table gone, any status could
become any other: a `RESOLVED` complaint could silently return to `NEW`, and a
report could reach an officer without anyone at the club having read it.

So the table comes back, and the permission question is answered separately.

## The seven states, and what each one means

The enum is unchanged on purpose — it is a native Postgres type, and adding
values to one at boot is a migration this project has no mechanism for. The
seven that exist are enough; they were simply never given meanings.

    NEW           reported, nobody at the club has looked yet
    ASSIGNED      a reviewer approved it — real, complete, worth an officer's
                  time — and it is ready to be sent
    UNDER_REVIEW  sent, and the first office is sitting on it
    ESCALATED     sent again, higher up the ladder
    RESOLVED      fixed, ideally with a photo of the fixed thing
    CLOSED        finished without a fix: the ladder ran out, or it stopped
                  mattering. A real outcome, and visible rather than hidden
    REJECTED      the club declined to send it, with a reason the reporter reads

`ASSIGNED` is the gate. Nothing reaches a government office without passing
through it, because the club's name is on every letter.
"""
from __future__ import annotations

from typing import Iterable

from app.models.issue import IssueStatus as S

#: What each state may become. Everything absent is forbidden.
#:
#: Read the rows as sentences: a NEW report can be approved, rejected outright,
#: or resolved on the spot when a member simply fixes the thing themselves —
#: which happens, and refusing to record it would be absurd.
TRANSITIONS: dict[S, set[S]] = {
    S.NEW: {S.ASSIGNED, S.REJECTED, S.RESOLVED, S.CLOSED},
    S.ASSIGNED: {S.UNDER_REVIEW, S.REJECTED, S.RESOLVED, S.CLOSED},
    # Escalation is the ordinary path out of UNDER_REVIEW, and it can loop:
    # ESCALATED → ESCALATED is a complaint climbing rung by rung.
    S.UNDER_REVIEW: {S.ESCALATED, S.RESOLVED, S.CLOSED, S.REJECTED},
    S.ESCALATED: {S.ESCALATED, S.RESOLVED, S.CLOSED, S.REJECTED},
    # Terminal, with one door left open: a fix that did not hold is a real
    # event, and reopening it to the club's queue is better than a second
    # complaint that loses the whole history.
    S.RESOLVED: {S.ASSIGNED, S.CLOSED},
    S.CLOSED: {S.ASSIGNED},
    S.REJECTED: {S.ASSIGNED},
}

#: States where the complaint is waiting on the club, not on an officer. These
#: are what the reviewer queue is for.
OURS: frozenset = frozenset({S.NEW, S.ASSIGNED})

#: States where a letter is out and somebody else owes an answer.
THEIRS: frozenset = frozenset({S.UNDER_REVIEW, S.ESCALATED})

#: Nothing further will happen on its own.
FINISHED: frozenset = frozenset({S.RESOLVED, S.CLOSED, S.REJECTED})


class IllegalTransition(ValueError):
    """Raised instead of silently writing a state that makes no sense."""

    def __init__(self, current: S, requested: S):
        self.current, self.requested = current, requested
        allowed = ", ".join(sorted(s.value for s in TRANSITIONS.get(current, set())))
        super().__init__(
            f"a complaint that is {current.value} cannot become {requested.value}"
            + (f" (allowed: {allowed})" if allowed else " (it is finished)")
        )


def can(current: S, requested: S) -> bool:
    """Is this move legal at all?

    Staying put is always legal — re-saving a complaint without changing its
    status should not be an error.
    """
    if current == requested:
        return True
    return requested in TRANSITIONS.get(current, set())


def check(current: S, requested: S) -> None:
    """Raise unless the move is legal."""
    if not can(current, requested):
        raise IllegalTransition(current, requested)


def next_states(current: S) -> Iterable[S]:
    """What a reviewer may do from here — for building a UI that offers only
    the buttons that will work."""
    return sorted(TRANSITIONS.get(current, set()), key=lambda s: s.value)
