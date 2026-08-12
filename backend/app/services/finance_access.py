"""Who may do what to a campaign, decided once.

Cricket answers the equivalent question with the same four-line comparison
copy-pasted at four call sites. It works, and it is exactly the shape that goes
wrong: the fifth one, written in a hurry, is the one that forgets. Money is not
where that should be discovered.

So every finance endpoint resolves an `Access` and reads it. There is one
sentence in this codebase that decides whether somebody may record a payment,
and it is below.

The club's decisions, encoded:

  * **Executives verify.** EXECUTIVE_MEMBER and above turn a claim into the
    club's record. That is a role, not an appointment — being appointed to
    collect for the anniversary does not make somebody a verifier.
  * **Treasurer is an appointment.** One capacity, scoped to one campaign,
    revocable. Whoever is appointed may record; nothing else follows from it.
  * **Everybody else is a 403**, including signed-in members. Finance is not
    part of the public or member surface.
"""
from __future__ import annotations

from dataclasses import dataclass
from typing import Optional

from sqlalchemy.orm import Session

from app.models.finance import FinanceCampaign, FinanceCampaignAssignment
from app.models.user import User

# Run the collection: create campaigns, appoint treasurers, see everything.
MANAGING_ROLES = ("ADMIN", "SUPER_ADMIN")
ORGANISING_ROLES = ("EXECUTIVE_MEMBER", "ADMIN", "SUPER_ADMIN")

# Verification belongs to the treasurer, because the treasurer holds the money.
#
# This is the club's rule and it is the right way round. An executive who hands
# over ₹5,000 has made a *claim*; it becomes the club's record when the person
# who physically receives and keeps the cash says it arrived. So an appointed
# treasurer's own entry is verified the moment they write it — they are not
# confirming somebody else's word, they are the authority — and everybody
# else's entry waits for them.
#
# ADMIN and SUPER_ADMIN keep the power as a break-glass, because a club whose
# treasurer is unreachable must not be a club whose money can never be
# confirmed. Those verifications are audited as an override and counted on the
# dashboard, so using it is visible rather than silent.
OVERRIDE_ROLES = ("ADMIN", "SUPER_ADMIN")


@dataclass(frozen=True)
class Access:
    """Everything a caller may do to one campaign."""

    campaign: FinanceCampaign
    user: User

    can_manage: bool = False      # edit the campaign, appoint/revoke treasurers
    can_archive: bool = False     # admin only — the irreversible-looking one
    can_record: bool = False      # add contributions
    can_verify: bool = False      # verify / reject / cancel
    can_view_all: bool = False    # see every contribution, not only their own
    is_appointed: bool = False    # holds a live assignment to this campaign

    @property
    def scope_is_own(self) -> bool:
        """True when this caller may only see their own rows, plus their queue.

        A treasurer sees the money they took and the entries waiting on their
        confirmation — not other treasurers' contributor names and numbers. The
        club already decided contact details are attributed rather than freely
        browsable, and a contributor list is a list of who has money.
        """
        return not self.can_view_all


def resolve(db: Session, campaign: FinanceCampaign, user: User) -> Access:
    """What this user may do to this campaign."""
    role = (user.role or "").upper()
    appointed = _is_appointed(db, campaign.id, user.id)

    organises = role in ORGANISING_ROLES

    return Access(
        campaign=campaign,
        user=user,
        can_manage=organises,
        can_archive=role in MANAGING_ROLES,
        # An executive can record without being appointed — they run the event.
        # Anybody else needs the appointment, which is the whole point of it.
        can_record=organises or appointed,
        can_verify=appointed or role in OVERRIDE_ROLES,
        # Seeing every contributor's name and number is a separate question
        # from confirming money, and it stays with the people who run the club.
        # A treasurer sees their own rows plus whatever is waiting on them.
        can_view_all=organises,
        is_appointed=appointed,
    )


def _is_appointed(db: Session, campaign_id, user_id) -> bool:
    return db.query(FinanceCampaignAssignment.id).filter(
        FinanceCampaignAssignment.campaign_id == campaign_id,
        FinanceCampaignAssignment.user_id == user_id,
        FinanceCampaignAssignment.revoked_at.is_(None),
    ).first() is not None


def load_campaign(db: Session, campaign_id, user: User) -> Optional[FinanceCampaign]:
    """The campaign, if it belongs to this caller's club.

    Gated on organization_id here rather than at each call site, so a campaign
    id from another club looks exactly like an id that does not exist — which
    is what it should look like.
    """
    return db.query(FinanceCampaign).filter(
        FinanceCampaign.id == campaign_id,
        FinanceCampaign.organization_id == user.organization_id,
        FinanceCampaign.deleted_at.is_(None),
    ).first()


def visible_campaigns(db: Session, user: User):
    """The campaigns this caller may see at all.

    An executive sees the club's campaigns. Anybody else sees only what they
    have been appointed to — an empty list is the correct answer for a member
    who has not been given a job, not an error.
    """
    q = db.query(FinanceCampaign).filter(
        FinanceCampaign.organization_id == user.organization_id,
        FinanceCampaign.deleted_at.is_(None),
    )
    role = (user.role or "").upper()
    if role in ORGANISING_ROLES:
        return q
    # distinct(), because nothing at the database level stops two live
    # assignment rows for one person on one campaign — two taps on "Add" that
    # race, and the join returns the campaign twice.
    return (q.join(FinanceCampaignAssignment,
                   FinanceCampaignAssignment.campaign_id == FinanceCampaign.id)
             .filter(FinanceCampaignAssignment.user_id == user.id,
                     FinanceCampaignAssignment.revoked_at.is_(None))
             .distinct())


def can_touch_contribution(access: Access, contribution) -> bool:
    """May this caller edit this specific row?

    An appointed treasurer owns what they recorded, verified or not. They are
    the authority on money they physically received, so "you can no longer
    correct this" would be the system overruling the person who counted it —
    and a treasurer who cannot fix their own typo will keep a second list on
    paper, which is worse than the typo.

    Everybody else may edit only their own entry, and only while it is still a
    claim. Once a treasurer has confirmed it, changing it needs the authority
    that confirmed it. Either way the previous values go to the audit log.
    """
    same_person = str(contribution.recorded_by_user_id or "") == str(access.user.id)
    if access.is_appointed and same_person:
        return True
    if access.can_verify:
        return True
    if not access.can_record:
        return False
    return same_person and contribution.status == "RECORDED"
