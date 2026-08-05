import uuid

from sqlalchemy import Column, String, DateTime, Integer, ForeignKey, Index

from app.core.database import Base
from app.models.base import GUID, TimestampMixin, TenantModelMixin


class ProfilePromptState(Base, TimestampMixin, TenantModelMixin):
    """What we have already asked one member, and how they responded.

    Registration deliberately stays short — a long signup form loses people,
    and the club would rather have a member with a thin profile than no member.
    The cost is that the fields the app actually needs (blood group first) are
    empty for almost everyone.

    So we ask afterwards: one question at a time, days apart, always dismissable.
    This table is what makes that possible — it remembers what was asked, what
    was answered, and what was pushed away, so nobody is asked the same thing
    twice and nobody is asked twice in one week.
    """

    __tablename__ = "profile_prompt_states"
    __table_args__ = (
        # "What should I ask this member next" is the only read there is.
        Index("ix_profile_prompt_user_question", "user_id", "question_id"),
    )

    id = Column(GUID(), primary_key=True, default=uuid.uuid4)
    user_id = Column(GUID(), ForeignKey("users.id", ondelete="CASCADE"),
                     nullable=False, index=True)

    # Id from the question catalogue in app/services/profile_questions.py.
    # A string, not a foreign key: the catalogue is code, so it can be
    # translated and reordered without a migration.
    question_id = Column(String(64), nullable=False)

    # Set once the member answers. A question with an answer is never asked
    # again.
    answered_at = Column(DateTime(timezone=True), nullable=True)

    # What they said, kept even when the answer is also written through to a
    # real profile column — so a later correction to the profile does not erase
    # the fact that they told us.
    answer = Column(String(200), nullable=True)

    # Dismissing is free. The question goes to the back of the queue rather
    # than away forever, but it stops being offered for a good while.
    dismissed_at = Column(DateTime(timezone=True), nullable=True)
    dismiss_count = Column(Integer, nullable=False, default=0)

    # Last time this particular question was put in front of them, so a member
    # who never responds either way is not shown the same card every day.
    last_shown_at = Column(DateTime(timezone=True), nullable=True)
