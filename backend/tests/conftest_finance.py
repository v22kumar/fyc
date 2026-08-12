"""Shared setup for the finance tests: a club, its people, and a collection.

Deliberately built through real HTTP calls where the endpoint exists, and
through the database only for the things the finance module does not own
(creating users, granting roles). The authorization tests in particular have to
go over the wire: this repository has already lost days to a bug that every
test missed because the tests mocked the layer the bug lived in.
"""
import uuid

from app.core.security import create_access_token, get_password_hash
from app.models.finance import FinanceCampaign, FinanceCampaignAssignment
from app.models.tenant import Organization
from app.models.user import User, UserProfile


def make_org(db, slug=None):
    org = Organization(id=uuid.uuid4(), slug=slug or f"f-{uuid.uuid4().hex[:6]}",
                       name_ta="அ", name_en="Friends Youth Club")
    db.add(org)
    db.commit()
    return org


def make_user(db, org, role="CLUB_MEMBER", name="Member", phone=None):
    u = User(
        organization_id=org.id,
        phone_number=phone or f"+9198{uuid.uuid4().int % 100000000:08d}",
        password_hash=get_password_hash("x"),
        role=role,
        is_verified=True,
    )
    db.add(u)
    db.flush()
    db.add(UserProfile(user_id=u.id, full_name_en=name, full_name_ta=name))
    db.commit()
    db.refresh(u)
    return u


def auth(user):
    """Headers a real request carries.

    `X-Organization-ID` is not optional: TenantMiddleware binds it and
    `get_current_user` refuses any token whose organisation does not match it.
    Omitting it makes every request 403 — which quietly turns an authorization
    test into a test that the header is missing, and it passes.
    """
    token = create_access_token(subject=user.id, role=user.role,
                                organization_id=str(user.organization_id))
    return {
        "Authorization": f"Bearer {token}",
        "X-Organization-ID": str(user.organization_id),
    }


def make_campaign(db, org, creator, **kwargs):
    fields = dict(
        organization_id=org.id,
        title_en="FYC Anniversary Celebration 2026",
        title_ta="எஃப்ஒய்சி ஆண்டு விழா 2026",
        purpose="ANNIVERSARY",
        suggested_amount_paise=350000,
        status="ACTIVE",
        created_by_user_id=creator.id,
    )
    fields.update(kwargs)
    campaign = FinanceCampaign(**fields)
    db.add(campaign)
    db.commit()
    db.refresh(campaign)
    return campaign


def appoint(db, campaign, user, by=None):
    a = FinanceCampaignAssignment(
        campaign_id=campaign.id, user_id=user.id, capacity="TREASURER",
        assigned_by_user_id=(by.id if by else None))
    db.add(a)
    db.commit()
    return a


def record(client, campaign, headers, **kwargs):
    """POST a contribution with sensible defaults for everything unstated."""
    body = {"contributor_name": "Ravi", "amount": 1000, "method": "CASH"}
    body.update(kwargs)
    return client.post(f"/api/v1/finance/campaigns/{campaign.id}/contributions",
                       json=body, headers=headers)
