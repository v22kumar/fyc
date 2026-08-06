import hashlib
import json
from datetime import datetime, timezone
from typing import List, Optional
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Request, Response, status
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.dependencies import get_current_user
from app.middleware.tenant import require_tenant_id
from app.models.profile_attribute import ProfileAttribute
from app.models.profile_prompt import ProfilePromptState
from app.models.user import User, UserProfile
from app.services import profile_questions as pq

router = APIRouter(prefix="/profile-prompts", tags=["Profile"])


class QuestionOut(BaseModel):
    id: str
    prompt_id: str
    options: List[str]


class CatalogueOut(BaseModel):
    """Everything the app needs to run the drip on its own."""

    questions: List[QuestionOut]
    # Ids this member has already answered, or that we already know from the
    # profile. Without this a reinstall would start asking from scratch and
    # re-ask things the club was told months ago.
    answered: List[str]
    # The cadence, published rather than hardcoded in the app, so it can be
    # tuned without shipping a new build.
    quiet_days_after_response: int
    quiet_days_after_dismiss: int
    quiet_days_after_shown: int
    max_dismissals: int


class AnswerIn(BaseModel):
    question_id: str
    answer: str = Field(min_length=1, max_length=200)


def _now() -> datetime:
    return datetime.now(timezone.utc)


def _state(db: Session, tenant_id: UUID, user_id: UUID,
           question_id: str) -> ProfilePromptState:
    row = (
        db.query(ProfilePromptState)
        .filter(
            ProfilePromptState.user_id == user_id,
            ProfilePromptState.question_id == question_id,
        )
        .first()
    )
    if not row:
        row = ProfilePromptState(
            organization_id=tenant_id, user_id=user_id, question_id=question_id
        )
        db.add(row)
    return row


@router.get("/catalogue", response_model=CatalogueOut)
def catalogue(
    request: Request,
    response: Response,
    db: Session = Depends(get_db),
    tenant_id: UUID = Depends(require_tenant_id),
    current_user: User = Depends(get_current_user),
):
    """The questions, and what this member has already told us.

    The server used to be asked on every app open *which* question to show. The
    answer was almost always "none", so that was a round trip per launch to be
    told to do nothing — and an unnecessary one, because whether to ask is a
    pure function of state the app can hold itself.

    So the server publishes and the app decides. This response is small, changes
    rarely, and carries an ETag, so in the steady state it costs a 304.
    """
    answered: set[str] = set()

    for row in (
        db.query(ProfilePromptState)
        .filter(
            ProfilePromptState.user_id == current_user.id,
            ProfilePromptState.answered_at.isnot(None),
        )
        .all()
    ):
        answered.add(row.question_id)

    for row in (
        db.query(ProfileAttribute)
        .filter(ProfileAttribute.user_id == current_user.id)
        .all()
    ):
        answered.add(row.key)

    # Known from somewhere else entirely — registration, an admin edit. Asking
    # for it would look like we had not been paying attention.
    profile = (
        db.query(UserProfile).filter(UserProfile.user_id == current_user.id).first()
    )
    if profile is not None:
        for q in pq.CATALOGUE:
            if q.profile_field and getattr(profile, q.profile_field, None):
                answered.add(q.id)

    body = CatalogueOut(
        questions=[
            QuestionOut(id=q.id, prompt_id=q.prompt_id, options=q.options)
            for q in sorted(pq.CATALOGUE, key=lambda x: x.priority)
        ],
        answered=sorted(answered),
        quiet_days_after_response=pq.QUIET_DAYS_AFTER_RESPONSE,
        quiet_days_after_dismiss=pq.QUIET_DAYS_AFTER_DISMISS,
        quiet_days_after_shown=pq.QUIET_DAYS_AFTER_SHOWN,
        max_dismissals=pq.MAX_DISMISSALS,
    )

    # Per member, because `answered` is per member. A shared ETag would serve
    # one member's answers to another.
    etag = '"%s"' % hashlib.sha256(
        json.dumps(body.model_dump(), sort_keys=True).encode()
    ).hexdigest()[:32]
    if request.headers.get("if-none-match") == etag:
        response.status_code = status.HTTP_304_NOT_MODIFIED
        return body
    response.headers["ETag"] = etag
    response.headers["Cache-Control"] = "private, max-age=0, must-revalidate"
    return body


@router.post("/answer", status_code=status.HTTP_204_NO_CONTENT)
def answer(
    payload: AnswerIn,
    db: Session = Depends(get_db),
    tenant_id: UUID = Depends(require_tenant_id),
    current_user: User = Depends(get_current_user),
):
    """Record an answer.

    It lands in two places on purpose: `profile_attributes`, which is what the
    club has learned and is expandable without migrations; and, when the field
    has earned a column, on the profile itself, where features can query it.
    """
    q = pq.BY_ID.get(payload.question_id)
    if not q:
        raise HTTPException(status_code=404, detail="Unknown question")
    if q.options and payload.answer not in q.options:
        raise HTTPException(status_code=400, detail="Answer is not one of the options")

    now = _now()

    row = _state(db, tenant_id, current_user.id, q.id)
    row.answered_at = now
    row.answer = payload.answer

    attr = (
        db.query(ProfileAttribute)
        .filter(
            ProfileAttribute.user_id == current_user.id,
            ProfileAttribute.key == q.id,
        )
        .first()
    )
    if attr:
        attr.value = payload.answer
        attr.answered_at = now
    else:
        db.add(ProfileAttribute(
            organization_id=tenant_id, user_id=current_user.id,
            key=q.id, value=payload.answer, answered_at=now,
        ))

    # "I don't know my blood group" is a real and useful answer — it stops us
    # asking again — but it is not a blood group, so it must not be written to
    # the profile as though it were, or a donor search would match on it.
    if q.profile_field and payload.answer != "dont_know":
        profile = (
            db.query(UserProfile)
            .filter(UserProfile.user_id == current_user.id)
            .first()
        )
        if profile is not None:
            setattr(profile, q.profile_field, payload.answer)

    db.commit()


@router.post("/dismiss", status_code=status.HTTP_204_NO_CONTENT)
def dismiss(
    payload: AnswerIn,
    db: Session = Depends(get_db),
    tenant_id: UUID = Depends(require_tenant_id),
    current_user: User = Depends(get_current_user),
):
    """Push a question to the back.

    The app already knows not to re-ask for a fortnight — it holds that state
    itself. This is recorded server-side anyway so a reinstall does not forget
    that someone pushed a question away three times.
    """
    if payload.question_id not in pq.BY_ID:
        raise HTTPException(status_code=404, detail="Unknown question")
    row = _state(db, tenant_id, current_user.id, payload.question_id)
    row.dismissed_at = _now()
    row.dismiss_count = (row.dismiss_count or 0) + 1
    db.commit()
