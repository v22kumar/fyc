"""Shapes crossing the wire, and the validation that never trusts the app.

Amounts arrive as rupees, because that is what a treasurer types, and are
converted to whole paise the moment they land — once, here, rather than in
every endpoint that touches them. Amounts leave as paise *and* as a formatted
string, so the app never has to reimplement Indian digit grouping and can never
disagree with the server about what ₹1,00,000 looks like.
"""
from __future__ import annotations

from datetime import date, datetime
from typing import List, Optional
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, field_validator

from app.core.money import (format_paise, rupees_to_paise,
                            validate_contribution_paise)
from app.models.finance import CAMPAIGN_STATUSES, PAYMENT_METHODS


def _paise_from_rupees(value):
    if value is None:
        return None
    try:
        return rupees_to_paise(value)
    except ValueError as e:
        raise ValueError(str(e))


# ── Campaigns ───────────────────────────────────────────────────────────────

class CampaignCreate(BaseModel):
    title_en: str = Field(..., min_length=2, max_length=200)
    title_ta: Optional[str] = Field(None, max_length=200)
    description: Optional[str] = None
    purpose: Optional[str] = Field("OTHER", max_length=30)

    # Rupees in, paise stored. Both optional: a club that has not decided its
    # target yet is a normal state, and the admin can set or change it later.
    target_amount: Optional[float] = None
    suggested_amount: Optional[float] = None

    starts_on: Optional[date] = None
    ends_on: Optional[date] = None
    status: Optional[str] = "ACTIVE"

    # Attach to an event that already exists…
    event_id: Optional[UUID] = None
    # …or mint one from this campaign. The anniversary needs an Event and does
    # not have one; making the admin create it separately, in another screen,
    # and then come back to link it is three chances to end up with a campaign
    # attached to nothing.
    create_event: bool = False

    @field_validator("status")
    @classmethod
    def _known_status(cls, v):
        if v and v.upper() not in CAMPAIGN_STATUSES:
            raise ValueError(f"Status must be one of {', '.join(CAMPAIGN_STATUSES)}")
        return v.upper() if v else v

    @field_validator("target_amount", "suggested_amount")
    @classmethod
    def _non_negative(cls, v):
        if v is not None and v < 0:
            raise ValueError("Amount cannot be negative.")
        return v


class CampaignUpdate(BaseModel):
    title_en: Optional[str] = Field(None, min_length=2, max_length=200)
    title_ta: Optional[str] = Field(None, max_length=200)
    description: Optional[str] = None
    purpose: Optional[str] = Field(None, max_length=30)
    target_amount: Optional[float] = None
    suggested_amount: Optional[float] = None
    starts_on: Optional[date] = None
    ends_on: Optional[date] = None
    status: Optional[str] = None
    event_id: Optional[UUID] = None
    # Distinguishes "leave the target alone" from "there is no target any
    # more". Without it, an admin can set a target and never remove it.
    clear_target: bool = False

    @field_validator("status")
    @classmethod
    def _known_status(cls, v):
        if v and v.upper() not in CAMPAIGN_STATUSES:
            raise ValueError(f"Status must be one of {', '.join(CAMPAIGN_STATUSES)}")
        return v.upper() if v else v


class CampaignOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    event_id: Optional[UUID] = None
    title_en: str
    title_ta: str
    description: Optional[str] = None
    purpose: Optional[str] = None
    target_amount_paise: Optional[int] = None
    target_display: Optional[str] = None
    suggested_amount_paise: Optional[int] = None
    suggested_display: Optional[str] = None
    currency: str = "INR"
    starts_on: Optional[date] = None
    ends_on: Optional[date] = None
    status: str
    created_at: Optional[datetime] = None
    # What *this* caller may do, so the app never has to infer it from a role
    # string and never shows a button that will 403.
    can_manage: bool = False
    can_record: bool = False
    can_verify: bool = False
    can_view_all: bool = False


# ── Assignments ─────────────────────────────────────────────────────────────

class AssignmentCreate(BaseModel):
    user_id: UUID
    capacity: Optional[str] = "TREASURER"


class AssignmentOut(BaseModel):
    id: UUID
    user_id: UUID
    name: str
    phone_number: Optional[str] = None
    capacity: str
    assigned_at: Optional[datetime] = None
    # Denormalised so the "5 treasurers active" card and the per-person row
    # come from one request instead of one per treasurer.
    recorded_paise: int = 0
    payments: int = 0


# ── Contributions ───────────────────────────────────────────────────────────

class ContributionCreate(BaseModel):
    # Either a member…
    contributor_user_id: Optional[UUID] = None
    # …or a name, which is also what gets stored when a member *is* picked, so
    # the ledger still reads correctly if that account is ever removed.
    contributor_name: Optional[str] = Field(None, max_length=150)
    contributor_phone: Optional[str] = Field(None, max_length=20)

    amount: float
    method: str = "CASH"
    reference_no: Optional[str] = Field(None, max_length=60)
    paid_on: Optional[date] = None
    notes: Optional[str] = None

    # Generated on the phone before the network is involved. Two requests
    # carrying the same one are the same payment, whatever happened in between.
    client_contribution_id: Optional[str] = Field(None, max_length=64)

    # Set only after the app has shown the member the possible repeat and they
    # said it is a different payment. Never sent on a first attempt.
    confirm_duplicate: bool = False

    @field_validator("method")
    @classmethod
    def _known_method(cls, v):
        if (v or "").upper() not in PAYMENT_METHODS:
            raise ValueError(f"Method must be one of {', '.join(PAYMENT_METHODS)}")
        return v.upper()

    @field_validator("amount")
    @classmethod
    def _real_amount(cls, v):
        validate_contribution_paise(rupees_to_paise(v))
        return v


class ContributionUpdate(BaseModel):
    contributor_name: Optional[str] = Field(None, max_length=150)
    contributor_phone: Optional[str] = Field(None, max_length=20)
    amount: Optional[float] = None
    method: Optional[str] = None
    reference_no: Optional[str] = Field(None, max_length=60)
    paid_on: Optional[date] = None
    notes: Optional[str] = None

    @field_validator("method")
    @classmethod
    def _known_method(cls, v):
        if v and v.upper() not in PAYMENT_METHODS:
            raise ValueError(f"Method must be one of {', '.join(PAYMENT_METHODS)}")
        return v.upper() if v else v

    @field_validator("amount")
    @classmethod
    def _real_amount(cls, v):
        if v is not None:
            validate_contribution_paise(rupees_to_paise(v))
        return v


class Resolution(BaseModel):
    """Rejecting or cancelling. The reason is not optional.

    A withdrawn payment that does not say why is a hole in the total that
    nobody can explain six months later, which is the situation an audit trail
    exists to prevent.
    """
    reason: str = Field(..., min_length=3, max_length=300)


class ContributionOut(BaseModel):
    id: UUID
    campaign_id: UUID
    contributor_user_id: Optional[UUID] = None
    contributor_name: str
    contributor_phone: Optional[str] = None
    amount_paise: int
    amount_display: str
    currency: str = "INR"
    method: str
    reference_no: Optional[str] = None
    paid_on: Optional[date] = None
    status: str
    recorded_by_user_id: Optional[UUID] = None
    recorded_by_name: Optional[str] = None
    verified_by_user_id: Optional[UUID] = None
    verified_by_name: Optional[str] = None
    verified_at: Optional[datetime] = None
    self_verified: bool = False
    resolution_reason: Optional[str] = None
    notes: Optional[str] = None
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None


class DuplicateCandidate(BaseModel):
    """One earlier row that looks like the one being recorded."""
    id: UUID
    contributor_name: str
    amount_display: str
    method: str
    reference_no: Optional[str] = None
    recorded_by_name: Optional[str] = None
    created_at: Optional[datetime] = None


class DuplicateWarning(BaseModel):
    """What comes back with a 409 so the app can ask instead of guessing."""
    detail: str
    kind: str  # "reference" (refused) | "similar" (confirmable)
    can_confirm: bool
    candidates: List[DuplicateCandidate] = []


def contribution_out(c, names: dict | None = None) -> ContributionOut:
    names = names or {}
    return ContributionOut(
        id=c.id,
        campaign_id=c.campaign_id,
        contributor_user_id=c.contributor_user_id,
        contributor_name=c.contributor_name,
        contributor_phone=c.contributor_phone,
        amount_paise=c.amount_paise,
        amount_display=format_paise(c.amount_paise),
        currency=c.currency or "INR",
        method=c.method,
        reference_no=c.reference_no,
        paid_on=c.paid_on,
        status=c.status,
        recorded_by_user_id=c.recorded_by_user_id,
        recorded_by_name=names.get(str(c.recorded_by_user_id)),
        verified_by_user_id=c.verified_by_user_id,
        verified_by_name=names.get(str(c.verified_by_user_id)),
        verified_at=c.verified_at,
        self_verified=bool(c.self_verified),
        resolution_reason=c.resolution_reason,
        notes=c.notes,
        created_at=c.created_at,
        updated_at=c.updated_at,
    )


def campaign_out(campaign, access=None) -> CampaignOut:
    out = CampaignOut.model_validate(campaign)
    out.target_display = (format_paise(campaign.target_amount_paise)
                          if campaign.target_amount_paise else None)
    out.suggested_display = (format_paise(campaign.suggested_amount_paise)
                             if campaign.suggested_amount_paise else None)
    if access is not None:
        out.can_manage = access.can_manage
        out.can_record = access.can_record
        out.can_verify = access.can_verify
        out.can_view_all = access.can_view_all
    return out
