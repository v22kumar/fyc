"""
Client error reporting.

The club has no way to test on a phone, so the next best thing is to hear about
failures the moment a member hits one. Reports land here rather than in a
third-party service: no extra account, no new secret, and the data stays with
the club.

Reporting is deliberately forgiving — an error report that itself fails, or is
malformed, must never make a bad situation worse for the person using the app.
"""
import hashlib
import logging
import uuid
from datetime import datetime, timedelta, timezone
from typing import List, Optional

from fastapi import APIRouter, Depends, Request
from pydantic import BaseModel, Field
from slowapi import Limiter
from slowapi.util import get_remote_address
from sqlalchemy import func
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.dependencies import RoleChecker, get_current_user_optional
from app.middleware.tenant import require_tenant_id
from app.models.client_error import ClientError
from app.models.user import User

logger = logging.getLogger(__name__)
limiter = Limiter(key_func=get_remote_address)
router = APIRouter(prefix="/diagnostics", tags=["diagnostics"])

require_admin = RoleChecker(["EXECUTIVE_MEMBER", "ADMIN", "SUPER_ADMIN"])

# A stack trace is useful for a few frames and noise after that; a message
# longer than this is a payload, not an error.
MAX_MESSAGE = 2000
MAX_STACK = 6000
MAX_BATCH = 20


class ClientErrorIn(BaseModel):
    message: str = Field(..., max_length=MAX_MESSAGE * 2)
    stack: Optional[str] = Field(None, max_length=MAX_STACK * 2)
    platform: str = "unknown"
    app_version: Optional[str] = Field(None, max_length=40)
    context: Optional[str] = Field(None, max_length=200)


class ClientErrorBatch(BaseModel):
    errors: List[ClientErrorIn] = Field(default_factory=list)


class ClientErrorOut(BaseModel):
    id: uuid.UUID
    platform: str
    app_version: Optional[str]
    context: Optional[str]
    message: str
    stack: Optional[str]
    occurrences: int
    created_at: datetime


def _fingerprint(platform: str, message: str, stack: Optional[str]) -> str:
    """Group identical failures so fifty phones crashing the same way is one row.

    Uses the platform, the head of the message, and the first stack frame —
    enough to separate distinct bugs without splitting one bug across every
    slightly different line number.
    """
    first_frame = ""
    if stack:
        for line in stack.splitlines():
            line = line.strip()
            if line:
                first_frame = line[:200]
                break
    raw = f"{platform}|{message[:200]}|{first_frame}"
    return hashlib.sha256(raw.encode("utf-8", "replace")).hexdigest()[:32]


@router.post("/errors", status_code=202)
@limiter.limit("60/minute")
def report_errors(
    request: Request,
    payload: ClientErrorBatch,
    db: Session = Depends(get_db),
    tenant_id: uuid.UUID = Depends(require_tenant_id),
    current_user: Optional[User] = Depends(get_current_user_optional),
):
    """Accept a batch of client errors.

    Authentication is OPTIONAL on purpose: a crash during sign-in is exactly the
    kind we most want to hear about, and requiring a token would hide it.

    Always returns 202. A reporting endpoint that can fail loudly would turn one
    bug in the app into two.
    """
    accepted = 0
    try:
        for item in payload.errors[:MAX_BATCH]:
            message = (item.message or "").strip()[:MAX_MESSAGE]
            if not message:
                continue
            stack = (item.stack or "").strip()[:MAX_STACK] or None
            platform = (item.platform or "unknown").strip()[:20]
            fp = _fingerprint(platform, message, stack)

            # Fold repeats of the same failure into one row with a count, so a
            # crash loop cannot bury everything else.
            existing = (
                db.query(ClientError)
                .filter(
                    ClientError.organization_id == tenant_id,
                    ClientError.fingerprint == fp,
                    ClientError.created_at
                    >= datetime.now(timezone.utc) - timedelta(days=7),
                )
                .first()
            )
            if existing:
                existing.occurrences = (existing.occurrences or 1) + 1
            else:
                db.add(ClientError(
                    id=uuid.uuid4(),
                    organization_id=tenant_id,
                    user_id=current_user.id if current_user else None,
                    platform=platform,
                    app_version=(item.app_version or None),
                    context=(item.context or None),
                    message=message,
                    stack=stack,
                    fingerprint=fp,
                    occurrences=1,
                ))
            accepted += 1
        db.commit()
    except Exception as e:  # noqa: BLE001
        db.rollback()
        logger.warning(f"[diagnostics] could not store client errors: {e}")
    return {"accepted": accepted}


@router.get("/errors", response_model=List[ClientErrorOut])
def list_errors(
    limit: int = 50,
    platform: Optional[str] = None,
    db: Session = Depends(get_db),
    tenant_id: uuid.UUID = Depends(require_tenant_id),
    _: User = Depends(require_admin),
):
    """Recent client errors, most frequent first — what an organizer looks at."""
    q = db.query(ClientError).filter(ClientError.organization_id == tenant_id)
    if platform:
        q = q.filter(ClientError.platform == platform)
    rows = (
        q.order_by(ClientError.created_at.desc())
        .limit(max(1, min(limit, 200)))
        .all()
    )
    return [
        ClientErrorOut(
            id=r.id,
            platform=r.platform,
            app_version=r.app_version,
            context=r.context,
            message=r.message,
            stack=r.stack,
            occurrences=r.occurrences or 1,
            created_at=r.created_at,
        )
        for r in rows
    ]


@router.get("/errors/summary")
def error_summary(
    db: Session = Depends(get_db),
    tenant_id: uuid.UUID = Depends(require_tenant_id),
    _: User = Depends(require_admin),
):
    """One-glance health: how many distinct failures, and on what."""
    since = datetime.now(timezone.utc) - timedelta(days=7)
    rows = (
        db.query(
            ClientError.platform,
            func.count(ClientError.id),
            func.sum(ClientError.occurrences),
        )
        .filter(
            ClientError.organization_id == tenant_id,
            ClientError.created_at >= since,
        )
        .group_by(ClientError.platform)
        .all()
    )
    return {
        "since": since.isoformat(),
        "platforms": [
            {"platform": p, "distinct": int(d or 0), "total": int(t or 0)}
            for p, d, t in rows
        ],
    }
