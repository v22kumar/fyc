from datetime import datetime
from typing import List, Optional
from uuid import UUID

from pydantic import BaseModel, Field


class PostCreate(BaseModel):
    content: str = ""
    image_urls: List[str] = Field(default_factory=list)
    # When true (and the post has an image), also publish to the org's
    # Instagram feed. Honoured only for managers/admins and only when
    # Instagram credentials are configured; otherwise silently ignored.
    share_to_instagram: bool = False


class PostAuthor(BaseModel):
    id: UUID
    name: str
    avatar_url: Optional[str] = None


class PostOut(BaseModel):
    id: UUID
    author: PostAuthor
    content: str
    image_urls: List[str]
    created_at: datetime
    like_count: int
    comment_count: int
    liked_by_me: bool


class CommentCreate(BaseModel):
    content: str


class CommentOut(BaseModel):
    id: UUID
    author_name: str
    content: str
    created_at: datetime
