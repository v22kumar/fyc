"""The numbers, derived from the rows every time.

There is no running-total column anywhere in this module, and that is the point.
The club already made this call once, for cricket standings and net run rate:
derive from the fixtures, never store the answer beside them. A stored total is
a second source of truth, it goes wrong quietly, and here the thing that goes
quietly wrong is how much money the club thinks it has.

A campaign is hundreds of rows, not millions. Grouping happens in SQL — not
because it is slow otherwise, but because pulling every contribution into
Python to add it up is how an endpoint that is fine in August becomes the
slowest thing in the app in three years.
"""
from __future__ import annotations

from sqlalchemy import case, distinct, func
from sqlalchemy.orm import Session

from app.models.finance import COUNTED_STATUSES, Contribution
from app.models.user import User, UserProfile


def _counted(q):
    """Rejected and cancelled money is not money."""
    return q.filter(Contribution.status.in_(COUNTED_STATUSES))


def summary(db: Session, campaign) -> dict:
    """The nine numbers an admin opens the app to see.

    `target_amount_paise` is nullable and stays that way here. A club that has
    not set a target yet is a normal state — reporting it as zero would make
    the dashboard claim 100% collected on the first rupee, and 0% remaining
    when nothing has been raised.
    """
    row = _counted(db.query(
        func.coalesce(func.sum(Contribution.amount_paise), 0),
        func.count(Contribution.id),
        func.count(distinct(Contribution.contributor_key)),
        func.coalesce(func.sum(case(
            (Contribution.status == "VERIFIED", Contribution.amount_paise), else_=0)), 0),
        func.coalesce(func.sum(case(
            (Contribution.status == "RECORDED", Contribution.amount_paise), else_=0)), 0),
        func.coalesce(func.sum(case((Contribution.self_verified.is_(True), 1), else_=0)), 0),
    ).filter(Contribution.campaign_id == campaign.id)).one()

    collected, payments, contributors, verified, pending, self_verified = row

    withdrawn = db.query(
        func.coalesce(func.sum(Contribution.amount_paise), 0),
        func.count(Contribution.id),
    ).filter(
        Contribution.campaign_id == campaign.id,
        Contribution.status.in_(("REJECTED", "CANCELLED")),
    ).one()

    target = campaign.target_amount_paise
    out = {
        "campaign_id": str(campaign.id),
        "currency": campaign.currency or "INR",
        "target_paise": target,
        "collected_paise": int(collected),
        "verified_paise": int(verified),
        "pending_paise": int(pending),
        "withdrawn_paise": int(withdrawn[0]),
        "withdrawn_count": int(withdrawn[1]),
        "contributors": int(contributors),
        "payments": int(payments),
        "average_paise": int(collected // payments) if payments else 0,
        "self_verified_count": int(self_verified),
        # Null, not zero, when there is no target. The app shows a plain total
        # instead of a progress bar, which is the honest rendering of "nobody
        # has decided how much we need yet".
        "remaining_paise": max(0, target - int(collected)) if target else None,
        "collection_percent": (
            round(int(collected) * 100 / target, 1) if target else None
        ),
        "suggested_amount_paise": campaign.suggested_amount_paise,
        "active_treasurers": _active_treasurers(db, campaign.id),
    }
    return out


def _active_treasurers(db: Session, campaign_id) -> int:
    from app.models.finance import FinanceCampaignAssignment
    return db.query(func.count(FinanceCampaignAssignment.id)).filter(
        FinanceCampaignAssignment.campaign_id == campaign_id,
        FinanceCampaignAssignment.revoked_at.is_(None),
    ).scalar() or 0


def by_treasurer(db: Session, campaign) -> list[dict]:
    """Who collected how much. Ordered by amount, because that is the question."""
    rows = _counted(
        db.query(
            Contribution.recorded_by_user_id,
            func.count(Contribution.id),
            func.count(distinct(Contribution.contributor_key)),
            func.coalesce(func.sum(Contribution.amount_paise), 0),
            func.coalesce(func.sum(case(
                (Contribution.status == "VERIFIED", Contribution.amount_paise),
                else_=0)), 0),
        ).filter(Contribution.campaign_id == campaign.id)
    ).group_by(Contribution.recorded_by_user_id).all()

    names = _names_for(db, [r[0] for r in rows if r[0]])
    out = [{
        "user_id": str(uid) if uid else None,
        "name": names.get(str(uid), "Unknown"),
        "payments": int(payments),
        "contributors": int(contributors),
        "amount_paise": int(total),
        "verified_paise": int(verified),
    } for uid, payments, contributors, total, verified in rows]
    out.sort(key=lambda r: r["amount_paise"], reverse=True)
    return out


def by_method(db: Session, campaign) -> list[dict]:
    rows = _counted(
        db.query(
            Contribution.method,
            func.count(Contribution.id),
            func.coalesce(func.sum(Contribution.amount_paise), 0),
        ).filter(Contribution.campaign_id == campaign.id)
    ).group_by(Contribution.method).all()
    out = [{"method": m, "payments": int(n), "amount_paise": int(total)}
           for m, n, total in rows]
    out.sort(key=lambda r: r["amount_paise"], reverse=True)
    return out


def by_day(db: Session, campaign) -> list[dict]:
    """Daily collection, oldest first — the shape of the push, not a ranking."""
    rows = _counted(
        db.query(
            Contribution.paid_on,
            func.count(Contribution.id),
            func.coalesce(func.sum(Contribution.amount_paise), 0),
        ).filter(Contribution.campaign_id == campaign.id)
    ).group_by(Contribution.paid_on).all()
    out = [{"day": d.isoformat() if d else None,
            "payments": int(n),
            "amount_paise": int(total)} for d, n, total in rows if d]
    out.sort(key=lambda r: r["day"])
    return out


def my_summary(db: Session, campaign, user) -> dict:
    """The four numbers a treasurer needs, and nothing else.

    A treasurer collecting money in a hall does not need the campaign's method
    breakdown. They need to know what they have taken and what is still
    unconfirmed.
    """
    row = _counted(db.query(
        func.coalesce(func.sum(Contribution.amount_paise), 0),
        func.count(Contribution.id),
        func.count(distinct(Contribution.contributor_key)),
        func.coalesce(func.sum(case(
            (Contribution.status == "VERIFIED", Contribution.amount_paise), else_=0)), 0),
        func.coalesce(func.sum(case(
            (Contribution.status == "RECORDED", Contribution.amount_paise), else_=0)), 0),
    ).filter(
        Contribution.campaign_id == campaign.id,
        Contribution.recorded_by_user_id == user.id,
    )).one()
    total, payments, contributors, verified, pending = row
    return {
        "campaign_id": str(campaign.id),
        "recorded_paise": int(total),
        "verified_paise": int(verified),
        "pending_paise": int(pending),
        "contributors": int(contributors),
        "payments": int(payments),
    }


def _names_for(db: Session, user_ids) -> dict:
    if not user_ids:
        return {}
    rows = (db.query(User.id, UserProfile.full_name_en, User.phone_number)
              .outerjoin(UserProfile, UserProfile.user_id == User.id)
              .filter(User.id.in_(user_ids)).all())
    return {str(uid): (name or phone or "Unknown") for uid, name, phone in rows}
