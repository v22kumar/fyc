import logging
import re
import uuid
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException, Request, Response, status, Query
from sqlalchemy import func, desc
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session, joinedload

from app.core.database import get_db
from app.core.etag import etag_not_modified, set_etag
from app.models.post import Post, PostLike, PostRepost, PostReport
from app.models.core_services import Comment
from app.models.user import User, UserBlock
from app.schemas.post import (
    PostCreate,
    PostOut,
    PostAuthor,
    CommentCreate,
    CommentOut,
    PostReportIn,
)
from app.dependencies import get_current_user, get_current_user_optional, RoleChecker
from app.middleware.tenant import require_tenant_id
from app.core.config import settings

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/posts", tags=["Posts"])

require_admin = RoleChecker(["ADMIN", "SUPER_ADMIN"])


def _name(u: Optional[User]) -> str:
    if not u:
        return "FYC Member"
    p = getattr(u, "profile", None)
    if p:
        return p.full_name_en or p.full_name_ta or "FYC Member"
    return "FYC Member"


_ROLE_LABEL = {
    "SUPER_ADMIN": "Admin",
    "ADMIN": "Admin",
    "EXECUTIVE_MEMBER": "Manager",
    "CLUB_MEMBER": "Member",
    "VOLUNTEER": "Volunteer",
}


def _author(u: Optional[User], author_id) -> PostAuthor:
    p = getattr(u, "profile", None) if u else None
    role = getattr(u, "role", None) if u else None
    return PostAuthor(
        id=author_id,
        name=_name(u),
        avatar_url=getattr(p, "profile_image_url", None) if p else None,
        role=_ROLE_LABEL.get(role, "Member"),
        verified=role in ("ADMIN", "SUPER_ADMIN") if role else False,
    )


def _serialize(
    db: Session,
    post: Post,
    current_user_id,
    *,
    counts: Optional[dict] = None,
    liked_ids: Optional[set] = None,
    reposted_ids: Optional[set] = None,
) -> PostOut:
    """Build a PostOut. Single-post callers pass nothing and each count is a
    small query; the feed passes precomputed `counts` (post_id -> (likes,
    comments, reposts)) and `liked_ids`/`reposted_ids` sets so a whole page is
    served in a handful of queries instead of ~7 per post (the old N+1)."""
    if counts is not None:
        like_count, comment_count, repost_count = counts.get(post.id, (0, 0, 0))
    else:
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
        repost_count = (
            db.query(func.count(PostRepost.id))
            .filter(PostRepost.post_id == post.id)
            .scalar()
            or 0
        )
    liked = False
    reposted = False
    if liked_ids is not None or reposted_ids is not None:
        liked = post.id in liked_ids if liked_ids is not None else False
        reposted = post.id in reposted_ids if reposted_ids is not None else False
    elif current_user_id:
        liked = (
            db.query(PostLike.id)
            .filter(
                PostLike.post_id == post.id,
                PostLike.user_id == current_user_id,
            )
            .first()
            is not None
        )
        reposted = (
            db.query(PostRepost.id)
            .filter(
                PostRepost.post_id == post.id,
                PostRepost.user_id == current_user_id,
            )
            .first()
            is not None
        )
    return PostOut(
        id=post.id,
        author=_author(post.author, post.author_id),
        content=post.content or "",
        image_urls=post.image_urls or [],
        category=post.category,
        source=post.source or "thread",
        location=post.location,
        created_at=post.created_at,
        like_count=like_count,
        comment_count=comment_count,
        repost_count=repost_count,
        liked_by_me=liked,
        reposted_by_me=reposted,
    )


@router.get("", response_model=List[PostOut])
def list_posts(
    request: Request,
    response: Response,
    scope: str = Query("all", pattern="^(all|mine)$"),
    feed: str = Query("recent", pattern="^(recent|popular|following)$"),
    category: Optional[str] = Query(None),
    source: Optional[str] = Query(None, description="Filter by source: thread | instagram"),
    limit: int = Query(20, ge=1, le=50),
    offset: int = Query(0, ge=0),
    db: Session = Depends(get_db),
    tenant_id: uuid.UUID = Depends(require_tenant_id),
    current_user: Optional[User] = Depends(get_current_user_optional),
):
    """Community feed. feed=recent (default, newest first), popular (most liked),
    following (official/admin voices). category filters by post category.
    scope=mine returns only my posts."""
    # is_hidden was added after posts already existed; rows backfilled by the
    # startup schema-reconcile can be NULL. Treat NULL as "not hidden" so
    # pre-existing posts don't silently vanish from the feed — only rows
    # explicitly flagged True are excluded.
    # Eager-load author + profile so the feed doesn't lazy-load them per row.
    q = (
        db.query(Post)
        .options(joinedload(Post.author).joinedload(User.profile))
        .filter(Post.organization_id == tenant_id, Post.is_hidden.isnot(True))
    )
    if scope == "mine":
        if not current_user:
            return []
        q = q.filter(Post.author_id == current_user.id)
    elif current_user:
        # Exclude posts from blocked users in the main feed
        blocked_subq = db.query(UserBlock.blocked_id).filter(
            UserBlock.blocker_id == current_user.id,
            UserBlock.organization_id == tenant_id
        )
        q = q.filter(~Post.author_id.in_(blocked_subq))

    if category and category.lower() != "all":
        q = q.filter(func.lower(Post.category) == category.lower())
    if source and source.lower() != "all":
        q = q.filter(func.lower(Post.source) == source.lower())
    if feed == "following":
        # No follow graph yet → show the club's official voice (admin authors).
        q = q.join(User, User.id == Post.author_id).filter(
            User.role.in_(["ADMIN", "SUPER_ADMIN", "EXECUTIVE_MEMBER"])
        )

    if feed == "popular":
        like_sub = (
            db.query(PostLike.post_id, func.count(PostLike.id).label("lc"))
            .group_by(PostLike.post_id)
            .subquery()
        )
        q = q.outerjoin(like_sub, like_sub.c.post_id == Post.id).order_by(
            desc(func.coalesce(like_sub.c.lc, 0)), desc(Post.created_at)
        )
    else:
        q = q.order_by(desc(Post.created_at))

    posts = q.offset(offset).limit(limit).all()
    cid = current_user.id if current_user else None

    # Batch the counts + my-liked/reposted lookups for the whole page: a few
    # grouped queries instead of ~7 per post (was the feed's biggest hotspot).
    post_ids = [p.id for p in posts]
    counts: dict = {}
    liked_ids: set = set()
    reposted_ids: set = set()
    if post_ids:
        like_rows = (
            db.query(PostLike.post_id, func.count(PostLike.id))
            .filter(PostLike.post_id.in_(post_ids))
            .group_by(PostLike.post_id)
            .all()
        )
        repost_rows = (
            db.query(PostRepost.post_id, func.count(PostRepost.id))
            .filter(PostRepost.post_id.in_(post_ids))
            .group_by(PostRepost.post_id)
            .all()
        )
        comment_rows = (
            db.query(Comment.entity_id, func.count(Comment.id))
            .filter(Comment.entity_type == "post", Comment.entity_id.in_(post_ids))
            .group_by(Comment.entity_id)
            .all()
        )
        likes_map = {pid: c for pid, c in like_rows}
        reposts_map = {pid: c for pid, c in repost_rows}
        comments_map = {pid: c for pid, c in comment_rows}
        counts = {
            pid: (likes_map.get(pid, 0), comments_map.get(pid, 0), reposts_map.get(pid, 0))
            for pid in post_ids
        }
        if cid:
            liked_ids = {
                pid for (pid,) in db.query(PostLike.post_id)
                .filter(PostLike.user_id == cid, PostLike.post_id.in_(post_ids))
                .all()
            }
            reposted_ids = {
                pid for (pid,) in db.query(PostRepost.post_id)
                .filter(PostRepost.user_id == cid, PostRepost.post_id.in_(post_ids))
                .all()
            }
    result = [
        _serialize(db, p, cid, counts=counts, liked_ids=liked_ids, reposted_ids=reposted_ids)
        for p in posts
    ]

    cached = etag_not_modified(request, result)
    if cached is not None:
        return cached
    set_etag(response, result)
    return result


@router.get("/hashtags", response_model=List[str])
def recent_hashtags(
    limit: int = Query(8, ge=1, le=20),
    db: Session = Depends(get_db),
    tenant_id: uuid.UUID = Depends(require_tenant_id),
):
    """Most-used hashtags across recent posts, for the create-post suggestions."""
    recent = (
        db.query(Post.content)
        .filter(Post.organization_id == tenant_id)
        .order_by(desc(Post.created_at))
        .limit(100)
        .all()
    )
    counts: dict = {}
    for (content,) in recent:
        for word in re.findall(r"#(\w+)", content or ""):
            key = word.lower()
            counts[key] = counts.get(key, 0) + 1
    ordered = sorted(counts.items(), key=lambda kv: kv[1], reverse=True)
    tags = [f"#{w}" for w, _ in ordered[:limit]]
    if not tags:
        tags = ["#FYC", "#Community", "#Teamwork", "#GreenFYC", "#Event", "#Cricket"]
    return tags


@router.post("", response_model=PostOut, status_code=status.HTTP_201_CREATED)
async def create_post(
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
    if payload.idempotency_key:
        existing = (
            db.query(Post)
            .filter(
                Post.author_id == current_user.id,
                Post.idempotency_key == payload.idempotency_key,
                Post.organization_id == tenant_id,
            )
            .first()
        )
        if existing:
            return _serialize(db, existing, current_user.id)
    post = Post(
        id=uuid.uuid4(),
        organization_id=tenant_id,
        author_id=current_user.id,
        content=content,
        image_urls=images,
        category=(payload.category or None),
        location=(payload.location.strip() if payload.location else None),
        source="thread",
        idempotency_key=payload.idempotency_key,
    )
    db.add(post)
    try:
        db.commit()
    except IntegrityError:
        # A concurrent retry with the same idempotency_key won the race and the
        # unique index fired. Return the row that landed instead of erroring.
        db.rollback()
        if payload.idempotency_key:
            dup = (
                db.query(Post)
                .filter(
                    Post.author_id == current_user.id,
                    Post.idempotency_key == payload.idempotency_key,
                    Post.organization_id == tenant_id,
                )
                .first()
            )
            if dup:
                return _serialize(db, dup, current_user.id)
        raise
    db.refresh(post)

    # Optional cross-post to the org's Instagram feed. Gated to managers/admins
    # (official voice), requires an image, and only runs when IG is configured.
    # Best-effort: a failed cross-post must never fail the community post.
    if (
        payload.share_to_instagram
        and images
        and current_user.role in ("EXECUTIVE_MEMBER", "ADMIN", "SUPER_ADMIN")
    ):
        try:
            from app.services import instagram as instagram_service

            if instagram_service.is_configured():
                image_url = images[0]
                if not image_url.startswith("http"):
                    # Instagram needs a public absolute URL.
                    base = settings.PUBLIC_BASE_URL.rstrip("/") if getattr(settings, "PUBLIC_BASE_URL", "") else ""
                    image_url = f"{base}{image_url}" if base else image_url
                if image_url.startswith("http"):
                    await instagram_service.publish_photo(image_url, content[:2200])
                    post.source = "instagram"
                    db.commit()
                    db.refresh(post)
        except Exception as e:  # pragma: no cover - best-effort
            logger.warning(f"Instagram cross-post failed (non-fatal): {e}")

    return _serialize(db, post, current_user.id)


@router.post("/{post_id}/repost")
def toggle_repost(
    post_id: uuid.UUID,
    db: Session = Depends(get_db),
    tenant_id: uuid.UUID = Depends(require_tenant_id),
    current_user: User = Depends(get_current_user),
):
    """Toggle a repost (like a retweet). Returns the new count + my state."""
    post = (
        db.query(Post)
        .filter(Post.id == post_id, Post.organization_id == tenant_id)
        .first()
    )
    if not post:
        raise HTTPException(status_code=404, detail="Post not found")
    existing = (
        db.query(PostRepost)
        .filter(PostRepost.post_id == post_id, PostRepost.user_id == current_user.id)
        .first()
    )
    if existing:
        db.delete(existing)
        reposted = False
    else:
        db.add(PostRepost(
            id=uuid.uuid4(),
            organization_id=tenant_id,
            post_id=post_id,
            user_id=current_user.id,
        ))
        reposted = True
    db.commit()
    count = (
        db.query(func.count(PostRepost.id))
        .filter(PostRepost.post_id == post_id)
        .scalar()
        or 0
    )
    return {"reposted": reposted, "repost_count": count}


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


@router.post("/{post_id}/report")
def report_post(
    post_id: uuid.UUID,
    payload: Optional[PostReportIn] = None,
    db: Session = Depends(get_db),
    tenant_id: uuid.UUID = Depends(require_tenant_id),
    current_user: User = Depends(get_current_user),
):
    """Flag a post for admin review and persist the report.

    Idempotent: a second report from the same user updates the reason rather
    than creating a duplicate row, so admins get one entry per flagged post.
    """
    post = (
        db.query(Post)
        .filter(Post.id == post_id, Post.organization_id == tenant_id)
        .first()
    )
    if not post:
        raise HTTPException(status_code=404, detail="Post not found")

    reason = payload.reason if payload else None

    existing = (
        db.query(PostReport)
        .filter(
            PostReport.post_id == post_id,
            PostReport.reporter_id == current_user.id,
            PostReport.organization_id == tenant_id,
        )
        .first()
    )
    if existing:
        if reason:
            existing.reason = reason
            db.commit()
        return {"status": "reported"}

    report = PostReport(
        id=uuid.uuid4(),
        organization_id=tenant_id,
        post_id=post_id,
        reporter_id=current_user.id,
        reason=reason,
    )
    db.add(report)
    try:
        db.commit()
    except IntegrityError:
        # Only swallow the error if it's the expected duplicate-report race
        # (the unique constraint fired). Re-check after rollback and re-raise
        # anything else so a genuine DB failure isn't masked as success.
        db.rollback()
        dup = (
            db.query(PostReport)
            .filter(
                PostReport.post_id == post_id,
                PostReport.reporter_id == current_user.id,
                PostReport.organization_id == tenant_id,
            )
            .first()
        )
        if dup is None:
            raise
    return {"status": "reported"}


@router.post("/{post_id}/hide")
def hide_post(
    post_id: uuid.UUID,
    db: Session = Depends(get_db),
    tenant_id: uuid.UUID = Depends(require_tenant_id),
    current_user: User = Depends(require_admin),
):
    """Admins can hide a post from the feed."""
    post = (
        db.query(Post)
        .filter(Post.id == post_id, Post.organization_id == tenant_id)
        .first()
    )
    if not post:
        raise HTTPException(status_code=404, detail="Post not found")
    post.is_hidden = True
    db.commit()
    return {"status": "hidden"}


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
        
    if payload.idempotency_key:
        existing = (
            db.query(Comment)
            .filter(
                Comment.author_id == current_user.id,
                Comment.idempotency_key == payload.idempotency_key,
                Comment.organization_id == tenant_id,
                Comment.entity_id == post_id,
            )
            .first()
        )
        if existing:
            return CommentOut(
                id=existing.id,
                author_name=_name(current_user),
                content=existing.content,
                created_at=existing.created_at,
            )
    c = Comment(
        id=uuid.uuid4(),
        organization_id=tenant_id,
        author_id=current_user.id,
        entity_type="post",
        entity_id=post_id,
        content=content,
        idempotency_key=payload.idempotency_key,
    )
    db.add(c)
    try:
        db.commit()
    except IntegrityError:
        # Concurrent retry with the same idempotency_key — return the row that won.
        db.rollback()
        if payload.idempotency_key:
            dup = (
                db.query(Comment)
                .filter(
                    Comment.author_id == current_user.id,
                    Comment.idempotency_key == payload.idempotency_key,
                    Comment.organization_id == tenant_id,
                    Comment.entity_id == post_id,
                )
                .first()
            )
            if dup:
                return CommentOut(
                    id=dup.id,
                    author_name=_name(current_user),
                    content=dup.content,
                    created_at=dup.created_at,
                )
        raise
    db.refresh(c)
    return CommentOut(
        id=c.id,
        author_name=_name(current_user),
        content=c.content,
        created_at=c.created_at,
    )
