from datetime import datetime, timezone
from typing import List
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.dependencies import get_current_user, RoleChecker
from app.middleware.tenant import require_tenant_id
from app.models.instagram_post import InstagramPost, InstagramPostStatus
from app.models.user import User
from app.schemas.instagram import InstagramPostCreate, InstagramPostOut
from app.services import instagram as instagram_service

router = APIRouter(prefix="/instagram", tags=["Instagram"])

require_admin = RoleChecker(["ADMIN", "SUPER_ADMIN"])

# Roles that may publish directly without manual approval
_TRUSTED_ROLES = {"CLUB_MEMBER", "EXECUTIVE_MEMBER", "ADMIN", "SUPER_ADMIN"}


# ---------------------------------------------------------------------------
# POST /instagram/post
# ---------------------------------------------------------------------------

@router.post(
    "/post",
    response_model=InstagramPostOut,
    status_code=status.HTTP_201_CREATED,
)
def create_instagram_post(
    payload: InstagramPostCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
    tenant_id: UUID = Depends(require_tenant_id),
):
    """
    Submit a post for the org's Instagram feed.

    - Trusted roles (CLUB_MEMBER and above) → publish immediately if Instagram
      is configured; create PUBLISHED record.
    - Lower-privilege roles (PUBLIC_CITIZEN, VOLUNTEER) → create PENDING_REVIEW
      record; an admin must approve before it goes live.
    - If Instagram is not configured, a record is still created (PENDING_REVIEW
      or APPROVED depending on role) and a notice is returned in the response.
    """
    is_trusted = current_user.role in _TRUSTED_ROLES
    configured = instagram_service.is_configured()

    post = InstagramPost(
        organization_id=current_user.organization_id,
        created_by_user_id=current_user.id,
        image_url=payload.image_url,
        caption=payload.caption,
        status=InstagramPostStatus.PENDING_REVIEW,
    )

    message: str | None = None

    if is_trusted:
        if configured:
            try:
                media_id = instagram_service.publish_photo(
                    payload.image_url, payload.caption
                )
                post.status = InstagramPostStatus.PUBLISHED
                post.instagram_media_id = media_id
            except Exception as exc:
                raise HTTPException(
                    status_code=status.HTTP_502_BAD_GATEWAY,
                    detail=f"Instagram publish failed: {exc}",
                )
        else:
            # Trusted user but no credentials yet — queue as approved
            post.status = InstagramPostStatus.APPROVED
            message = "Instagram not configured yet, post queued"
    else:
        # Untrusted role — always goes to review queue
        post.status = InstagramPostStatus.PENDING_REVIEW

    db.add(post)
    db.commit()
    db.refresh(post)

    # FastAPI will serialise `post` via InstagramPostOut; attach the message
    # as a custom header so callers can surface it without breaking the schema.
    from fastapi.responses import JSONResponse
    from app.schemas.instagram import InstagramPostOut as Schema

    response_data = Schema.model_validate(post).model_dump(mode="json")
    if message:
        response_data["message"] = message

    return response_data


# ---------------------------------------------------------------------------
# GET /instagram/posts  (ADMIN / SUPER_ADMIN only)
# ---------------------------------------------------------------------------

@router.get(
    "/posts",
    response_model=List[InstagramPostOut],
)
def list_instagram_posts(
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin),
    tenant_id: UUID = Depends(require_tenant_id),
):
    """
    List all Instagram posts for the current organisation, newest first.
    Accessible to ADMIN and SUPER_ADMIN only.
    """
    posts = (
        db.query(InstagramPost)
        .filter(InstagramPost.organization_id == tenant_id)
        .order_by(InstagramPost.created_at.desc())
        .all()
    )
    return posts


# ---------------------------------------------------------------------------
# POST /instagram/posts/{post_id}/approve  (ADMIN / SUPER_ADMIN only)
# ---------------------------------------------------------------------------

@router.post(
    "/posts/{post_id}/approve",
    response_model=InstagramPostOut,
)
def approve_instagram_post(
    post_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin),
    tenant_id: UUID = Depends(require_tenant_id),
):
    """
    Approve a PENDING_REVIEW post and publish it to Instagram.
    If Instagram is not configured, sets status to APPROVED (not PUBLISHED)
    and returns a notice.
    """
    post = db.query(InstagramPost).filter(
        InstagramPost.id == post_id,
        InstagramPost.organization_id == tenant_id,
    ).first()

    if not post:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Instagram post not found.",
        )

    if post.status not in (
        InstagramPostStatus.PENDING_REVIEW,
        InstagramPostStatus.APPROVED,
    ):
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"Cannot approve a post with status '{post.status}'.",
        )

    post.reviewed_by_user_id = current_user.id
    post.reviewed_at = datetime.now(timezone.utc)

    message: str | None = None

    if instagram_service.is_configured():
        try:
            media_id = instagram_service.publish_photo(post.image_url, post.caption)
            post.status = InstagramPostStatus.PUBLISHED
            post.instagram_media_id = media_id
        except Exception as exc:
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail=f"Instagram publish failed: {exc}",
            )
    else:
        post.status = InstagramPostStatus.APPROVED
        message = "Instagram not configured yet, post marked as approved"

    db.commit()
    db.refresh(post)

    from app.schemas.instagram import InstagramPostOut as Schema

    response_data = Schema.model_validate(post).model_dump(mode="json")
    if message:
        response_data["message"] = message

    return response_data


# ---------------------------------------------------------------------------
# POST /instagram/posts/{post_id}/reject  (ADMIN / SUPER_ADMIN only)
# ---------------------------------------------------------------------------

@router.post(
    "/posts/{post_id}/reject",
    response_model=InstagramPostOut,
)
def reject_instagram_post(
    post_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin),
    tenant_id: UUID = Depends(require_tenant_id),
):
    """
    Reject a PENDING_REVIEW post.  Sets status to REJECTED.
    """
    post = db.query(InstagramPost).filter(
        InstagramPost.id == post_id,
        InstagramPost.organization_id == tenant_id,
    ).first()

    if not post:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Instagram post not found.",
        )

    if post.status == InstagramPostStatus.PUBLISHED:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Cannot reject an already published post.",
        )

    post.status = InstagramPostStatus.REJECTED
    post.reviewed_by_user_id = current_user.id
    post.reviewed_at = datetime.now(timezone.utc)

    db.commit()
    db.refresh(post)
    return post
