from datetime import datetime, timedelta, timezone
from typing import List, Optional
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.dependencies import get_current_user
from app.middleware.tenant import require_tenant_id
from app.models.profile_prompt import ProfilePromptState
from app.models.user import User, UserProfile
from app.services import profile_questions as pq

router = APIRouter(prefix="/profile-prompts", tags=["Profile"])


class QuestionOut(BaseModel):
    id: str
    prompt_id: str
    options: List[str]


class AnswerIn(BaseModel):
    question_id: str
    answer: str = Field(min_length=1, max_length=200)


def _now() -> datetime:
    return datetime.now(timezone.utc)


def _aware(dt: Optional[datetime]) -> Optional[datetime]:
    """SQLite hands back naive datetimes; comparing them to an aware `now`
    raises. Treat a naive value as UTC, which is what we stored."""
    if dt is None:
        return None
    return dt if dt.tzinfo else dt.replace(tzinfo=timezone.utc)


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


@router.get("/next", response_model=Optional[QuestionOut])
def next_question(
    db: Session = Depends(get_db),
    tenant_id: UUID = Depends(require_tenant_id),
    current_user: User = Depends(get_current_user),
):
    """The one question to ask this member right now, or nothing at all.

    Nothing at all is the common and correct answer. A member who answered
    yesterday should see no card today — the whole idea rests on this never
    feeling like a form.
    """
    now = _now()
    states = {
        s.question_id: s
        for s in db.query(ProfilePromptState)
        .filter(ProfilePromptState.user_id == current_user.id)
        .all()
    }

    # One response, of any kind, buys quiet across every question — not just
    # the one they responded to.
    for s in states.values():
        last = max(
            [d for d in (_aware(s.answered_at), _aware(s.dismissed_at)) if d],
            default=None,
        )
        if last and now - last < timedelta(days=pq.QUIET_DAYS_AFTER_RESPONSE):
            return None

    # And having been *shown* anything recently buys quiet too. Without this,
    # ignoring the blood-group card simply produced the next question instead —
    # which is two questions in one sitting, and exactly the drip turning back
    # into the form we set out to avoid.
    for s in states.values():
        shown = _aware(s.last_shown_at)
        if shown and now - shown < timedelta(days=pq.QUIET_DAYS_AFTER_SHOWN):
            return None

    profile = (
        db.query(UserProfile).filter(UserProfile.user_id == current_user.id).first()
    )

    for q in sorted(pq.CATALOGUE, key=lambda x: x.priority):
        s = states.get(q.id)
        if s and s.answered_at:
            continue
        # Already known from somewhere else (registration, an admin edit) —
        # asking would look like we had not been paying attention.
        if q.profile_field and profile is not None:
            existing = getattr(profile, q.profile_field, None)
            if existing:
                continue
        if s:
            if s.dismiss_count >= pq.MAX_DISMISSALS:
                continue
            dismissed = _aware(s.dismissed_at)
            if dismissed and now - dismissed < timedelta(days=pq.QUIET_DAYS_AFTER_DISMISS):
                continue

        row = _state(db, tenant_id, current_user.id, q.id)
        row.last_shown_at = now
        db.commit()
        return QuestionOut(id=q.id, prompt_id=q.prompt_id, options=q.options)

    return None


@router.post("/answer", status_code=status.HTTP_204_NO_CONTENT)
def answer(
    payload: AnswerIn,
    db: Session = Depends(get_db),
    tenant_id: UUID = Depends(require_tenant_id),
    current_user: User = Depends(get_current_user),
):
    """Record an answer, and write it through to the profile where there is a
    column for it — otherwise the answer would sit in a table nothing reads."""
    q = pq.BY_ID.get(payload.question_id)
    if not q:
        raise HTTPException(status_code=404, detail="Unknown question")
    if q.options and payload.answer not in q.options:
        raise HTTPException(status_code=400, detail="Answer is not one of the options")

    row = _state(db, tenant_id, current_user.id, q.id)
    row.answered_at = _now()
    row.answer = payload.answer

    # "I don't know my blood group" is a real and useful answer — it stops us
    # asking again — but it is not a blood group, so it must not be written to
    # the profile as though it were.
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
    """Push a question to the back. Free, and it must stay free — a dismissal
    that costs something turns the card into a demand."""
    if payload.question_id not in pq.BY_ID:
        raise HTTPException(status_code=404, detail="Unknown question")
    row = _state(db, tenant_id, current_user.id, payload.question_id)
    row.dismissed_at = _now()
    row.dismiss_count = (row.dismiss_count or 0) + 1
    db.commit()
