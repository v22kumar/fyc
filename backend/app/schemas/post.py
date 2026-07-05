from datetime import datetime
from typing import List, Optional
from uuid import UUID

from pydantic import BaseModel, Field


class PostCreate(BaseModel):
    content: str = ""
    image_urls: List[str] = Field(default_factory=list)
    category: Optional[str] = None
    location: Optional[str] = None
    # When true (and the post has an image), also publish to the org's
    # Instagram feed. Honoured only for managers/admins and only when
    # Instagram credentials are configured; otherwise silently ignored.
    share_to_instagram: bool = False
    idempotency_key: Optional[str] = None


class PostReportIn(BaseModel):
    """Optional body for POST /posts/{id}/report."""
    reason: Optional[str] = Field(default=None, max_length=300)


class PostAuthor(BaseModel):
    id: UUID
    name: str
    avatar_url: Optional[str] = None
    role: Optional[str] = None       # "Admin" / "Manager" / "Member" / "Citizen"
    verified: bool = False           # official/admin accounts get a check


class PostOut(BaseModel):
    id: UUID
    author: PostAuthor
    content: str
    image_urls: List[str]
    category: Optional[str] = None
    source: str = "thread"           # "thread" or "instagram"
    location: Optional[str] = None
    created_at: datetime
    like_count: int
    comment_count: int
    repost_count: int = 0
    liked_by_me: bool
    reposted_by_me: bool = False


class CommentCreate(BaseModel):
    content: str
    idempotency_key: Optional[str] = None


class CommentOut(BaseModel):
    id: UUID
    author_name: str
    content: str
    created_at: datetime
