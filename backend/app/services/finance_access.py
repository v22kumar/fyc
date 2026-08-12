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

# Full control: create campaigns, appoint treasurers, edit and verify anything.
MANAGING_ROLES = ("ADMIN", "SUPER_ADMIN")

# Executives run the club's events, and the club decided they confirm its money
# too. They can create and run campaigns and verify contributions; only ADMIN
# and above can archive a campaign or overrule a verified record.
VERIFYING_ROLES = ("EXECUTIVE_MEMBER", "ADMIN", "SUPER_ADMIN")


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
        """True when this caller may only see contributions they recorded.

        An appointed treasurer sees their own collection in full and the
        campaign's totals — not other treasurers' contributor names and phone
        numbers. The club already decided that contact details are attributed
        rather than freely browsable, and a contributor list is a list of who
        has money.
        """
        return not self.can_view_all


def resolve(db: Session, campaign: FinanceCampaign, user: User) -> Access:
    """What this user may do to this campaign."""
    role = (user.role or "").upper()
    appointed = _is_appointed(db, campaign.id, user.id)

    manages = role in MANAGING_ROLES or role == "EXECUTIVE_MEMBER"
    verifies = role in VERIFYING_ROLES

    return Access(
        campaign=campaign,
        user=user,
        can_manage=manages,
        can_archive=role in MANAGING_ROLES,
        # An executive can record without being appointed — they run the event.
        # Anybody else needs the appointment, which is the whole point of it.
        can_record=manages or appointed,
        can_verify=verifies,
        can_view_all=manages or verifies,
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
    if role in VERIFYING_ROLES:
        return q
    return (q.join(FinanceCampaignAssignment,
                   FinanceCampaignAssignment.campaign_id == FinanceCampaign.id)
             .filter(FinanceCampaignAssignment.user_id == user.id,
                     FinanceCampaignAssignment.revoked_at.is_(None)))


def can_touch_contribution(access: Access, contribution) -> bool:
    """May this caller edit this specific row?

    A treasurer owns what they recorded, and only while it is still a claim.
    Once an executive has verified it, it is the club's record and changing it
    is an executive's decision — logged, like every other change to it.
    """
    if access.can_verify:
        return True
    if not access.can_record:
        return False
    same_person = str(contribution.recorded_by_user_id or "") == str(access.user.id)
    return same_person and contribution.status == "RECORDED"
