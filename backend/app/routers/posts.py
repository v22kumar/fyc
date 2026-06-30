import uuid
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy import func, desc
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.models.post import Post, PostLike
from app.models.core_services import Comment
from app.models.user import User
from app.schemas.post import (
    PostCreate,
    PostOut,
    PostAuthor,
    CommentCreate,
    CommentOut,
)
from app.dependencies import get_current_user, get_current_user_optional, RoleChecker
from app.middleware.tenant import require_tenant_id

router = APIRouter(prefix="/posts", tags=["Posts"])

require_admin = RoleChecker(["ADMIN", "SUPER_ADMIN"])


def _name(u: Optional[User]) -> str:
    if not u:
        return "FYC Member"
    p = getattr(u, "profile", None)
    if p:
        return p.full_name_en or p.full_name_ta or "FYC Member"
    return "FYC Member"


def _author(u: Optional[User], author_id) -> PostAuthor:
    p = getattr(u, "profile", None) if u else None
    return PostAuthor(
        id=author_id,
        name=_name(u),
        avatar_url=getattr(p, "profile_image_url", None) if p else None,
    )


def _serialize(db: Session, post: Post, current_user_id) -> PostOut:
    like_count = (
        db.query(func.count(PostLike.id))
        .filter(PostLike.post_id == post.id)
        .scalar()
        or 0
    )
    comment_count = (
        db.query(func.count(Comment.id))
        .filter(Comment.entity_type == "post", Comment.entity_id == post.id)
        .scalar()
        or 0
    )
    liked = False
    if current_user_id:
        liked = (
            db.query(PostLike.id)
            .filter(
                PostLike.post_id == post.id,
                PostLike.user_id == current_user_id,
            )
            .first()
            is not None
        )
    return PostOut(
        id=post.id,
        author=_author(post.author, post.author_id),
        content=post.content or "",
        image_urls=post.image_urls or [],
        created_at=post.created_at,
        like_count=like_count,
        comment_count=comment_count,
        liked_by_me=liked,
    )


@router.get("", response_model=List[PostOut])
def list_posts(
    scope: str = Query("all", pattern="^(all|mine)$"),
    limit: int = Query(20, ge=1, le=50),
    offset: int = Query(0, ge=0),
    db: Session = Depends(get_db),
    tenant_id: uuid.UUID = Depends(require_tenant_id),
    current_user: Optional[User] = Depends(get_current_user_optional),
):
    """Community feed (newest first). scope=mine returns only my posts."""
    q = db.query(Post).filter(Post.organization_id == tenant_id)
    if scope == "mine":
        if not current_user:
            return []
        q = q.filter(Post.author_id == current_user.id)
    posts = q.order_by(desc(Post.created_at)).offset(offset).limit(limit).all()
    cid = current_user.id if current_user else None
    return [_serialize(db, p, cid) for p in posts]


@router.post("", response_model=PostOut, status_code=status.HTTP_201_CREATED)
def create_post(
    payload: PostCreate,
    db: Session = Depends(get_db),
    tenant_id: uuid.UUID = Depends(require_tenant_id),
    current_user: User = Depends(get_current_user),
):
    content = (payload.content or "").strip()
    images = [u for u in (payload.image_urls or []) if u]
    if not content and not images:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="A post needs some text or at least one image.",
        )
    post = Post(
        id=uuid.uuid4(),
        organization_id=tenant_id,
        author_id=current_user.id,
        content=content,
        image_urls=images,
    )
    db.add(post)
    db.commit()
    db.refresh(post)
    return _serialize(db, post, current_user.id)


@router.delete("/{post_id}")
def delete_post(
    post_id: uuid.UUID,
    db: Session = Depends(get_db),
    tenant_id: uuid.UUID = Depends(require_tenant_id),
    current_user: User = Depends(get_current_user),
):
    post = (
        db.query(Post)
        .filter(Post.id == post_id, Post.organization_id == tenant_id)
        .first()
    )
    if not post:
        raise HTTPException(status_code=404, detail="Post not found")
    if post.author_id != current_user.id and current_user.role not in (
        "ADMIN",
        "SUPER_ADMIN",
    ):
        raise HTTPException(status_code=403, detail="Not allowed")
    db.delete(post)
    db.commit()
    return {"deleted": True}


@router.post("/{post_id}/like")
def toggle_like(
    post_id: uuid.UUID,
    db: Session = Depends(get_db),
    tenant_id: uuid.UUID = Depends(require_tenant_id),
    current_user: User = Depends(get_current_user),
):
    post = (
        db.query(Post)
        .filter(Post.id == post_id, Post.organization_id == tenant_id)
        .first()
    )
    if not post:
        raise HTTPException(status_code=404, detail="Post not found")
    existing = (
        db.query(PostLike)
        .filter(PostLike.post_id == post_id, PostLike.user_id == current_user.id)
        .first()
    )
    if existing:
        db.delete(existing)
        db.commit()
        liked = False
    else:
        db.add(
            PostLike(
                id=uuid.uuid4(),
                organization_id=tenant_id,
                post_id=post_id,
                user_id=current_user.id,
            )
        )
        db.commit()
        liked = True
    count = (
        db.query(func.count(PostLike.id))
        .filter(PostLike.post_id == post_id)
        .scalar()
        or 0
    )
    return {"liked": liked, "like_count": count}


@router.get("/{post_id}/comments", response_model=List[CommentOut])
def list_comments(
    post_id: uuid.UUID,
    db: Session = Depends(get_db),
    tenant_id: uuid.UUID = Depends(require_tenant_id),
):
    rows = (
        db.query(Comment)
        .filter(
            Comment.entity_type == "post",
            Comment.entity_id == post_id,
            Comment.organization_id == tenant_id,
        )
        .order_by(Comment.created_at.asc())
        .all()
    )
    return [
        CommentOut(
            id=c.id,
            author_name=_name(c.author),
            content=c.content,
            created_at=c.created_at,
        )
        for c in rows
    ]


@router.post(
    "/{post_id}/comments",
    response_model=CommentOut,
    status_code=status.HTTP_201_CREATED,
)
def add_comment(
    post_id: uuid.UUID,
    payload: CommentCreate,
    db: Session = Depends(get_db),
    tenant_id: uuid.UUID = Depends(require_tenant_id),
    current_user: User = Depends(get_current_user),
):
    content = (payload.content or "").strip()
    if not content:
        raise HTTPException(status_code=400, detail="Comment can't be empty")
    post = (
        db.query(Post)
        .filter(Post.id == post_id, Post.organization_id == tenant_id)
        .first()
    )
    if not post:
        raise HTTPException(status_code=404, detail="Post not found")
    c = Comment(
        id=uuid.uuid4(),
        organization_id=tenant_id,
        author_id=current_user.id,
        entity_type="post",
        entity_id=post_id,
        content=content,
    )
    db.add(c)
    db.commit()
    db.refresh(c)
    return CommentOut(
        id=c.id,
        author_name=_name(current_user),
        content=c.content,
        created_at=c.created_at,
    )
