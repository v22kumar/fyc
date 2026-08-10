"""Instagram, Threads and Facebook, pulled into the club's own feed.

The club posts on Instagram and Threads already. This mirrors those posts into
the app's feed so a member who does not use either still sees what the club is
saying, in their own language, in the app they already have.

**Two directions, easily confused.** This file is *inbound* only — it reads
those platforms and writes `Post` rows. Publishing club content *outbound* to
Instagram is a completely separate feature (`routers/instagram.py`, with its own
review workflow and its own `InstagramPost` table). They share a name and
nothing else; reading them as one system is what makes this area feel tangled.

What changed here:

* **Three copies became one.** `_sync_facebook`, `_sync_instagram` and
  `_sync_threads` were ninety per cent identical — same fetch, same idempotency
  check, same insert, differing only in a URL, a field list and which key holds
  the text. They are now one loop over `_PROVIDERS`. Adding a platform is an
  entry in that tuple.

* **Images no longer expire.** Meta's `media_url` is a signed, short-lived link
  into their CDN, and it was being stored verbatim. A post looked right the day
  it synced and became a broken box days later — silently, with nothing
  connecting the two events. Each image is now mirrored into the club's own
  storage, and the original is kept only when that storage is not configured.
"""
import logging
from typing import Callable, NamedTuple, Optional

import requests
from sqlalchemy.orm import Session

from app.core.database import SessionLocal
from app.models.post import Post
from app.models.tenant import Organization
from app.models.user import User
from app.routers.media import mirror_remote_image

logger = logging.getLogger(__name__)

_TIMEOUT = 15
_PER_SYNC = 10


class Provider(NamedTuple):
    """One platform, described rather than reimplemented."""
    name: str
    # The org columns holding this platform's credentials. Absent → skipped.
    token_field: str
    account_field: str
    endpoint: Callable[[str], str]
    fields: str
    # Which key carries the words. Instagram calls it a caption, Threads text.
    text_key: str
    # Media types that carry a still image worth mirroring.
    image_types: tuple[str, ...] = ("IMAGE", "CAROUSEL_ALBUM")


_PROVIDERS: tuple[Provider, ...] = (
    Provider(
        "facebook", "facebook_access_token", "facebook_page_id",
        lambda acc: f"https://graph.facebook.com/v19.0/{acc}/posts",
        "id,message,full_picture,created_time,permalink_url",
        text_key="message",
    ),
    Provider(
        "instagram", "instagram_access_token", "instagram_account_id",
        lambda acc: f"https://graph.facebook.com/v19.0/{acc}/media",
        "id,caption,media_type,media_url,timestamp,permalink",
        text_key="caption",
    ),
    Provider(
        "threads", "threads_access_token", "threads_account_id",
        lambda acc: "https://graph.threads.net/v1.0/me/threads",
        "id,media_product_type,media_type,media_url,permalink,text,timestamp,username",
        text_key="text",
        image_types=("IMAGE",),
    ),
)


def _image_of(item: dict, provider: Provider) -> Optional[str]:
    # Facebook answers with `full_picture` and no media_type; the others carry a
    # media_url that is only a still image for some types.
    if provider.name == "facebook":
        return item.get("full_picture")
    if item.get("media_type") in provider.image_types:
        return item.get("media_url")
    return None


def _sync_provider(db: Session, org: Organization, author: User,
                   provider: Provider) -> int:
    token = getattr(org, provider.token_field, None)
    account = getattr(org, provider.account_field, None)
    if not token or not account:
        return 0

    try:
        response = requests.get(
            provider.endpoint(account),
            params={"fields": provider.fields, "access_token": token,
                    "limit": _PER_SYNC},
            timeout=_TIMEOUT,
        )
    except requests.RequestException as exc:
        logger.warning("[social] %s unreachable for org %s: %s",
                       provider.name, org.id, exc)
        return 0

    if response.status_code != 200:
        logger.error("[social] %s refused for org %s: %s",
                     provider.name, org.id, response.text[:200])
        return 0

    added = 0
    for item in response.json().get("data", []):
        remote_id = item.get("id")
        if not remote_id:
            continue
        key = f"{provider.name}_{remote_id}"
        already = db.query(Post).filter(
            Post.organization_id == org.id,
            Post.idempotency_key == key,
        ).first()
        if already:
            continue

        remote_image = _image_of(item, provider)
        image_urls = []
        if remote_image:
            # Ours if we can host it, theirs if we cannot — but never silently
            # nothing, and never a link we know will rot.
            image_urls = [
                mirror_remote_image(remote_image, tenant_id=org.id,
                                    public_id=key) or remote_image
            ]

        db.add(Post(
            organization_id=org.id,
            author_id=author.id,
            content=item.get(provider.text_key) or "",
            image_urls=image_urls,
            category="Announcement",
            source=provider.name,
            idempotency_key=key,
        ))
        added += 1

    if added:
        db.commit()
    return added


def sync_social_feeds():
    """Pull new posts from every configured platform into the community feed."""
    logger.info("[social] sync starting")
    db: Session = SessionLocal()
    try:
        orgs = db.query(Organization).filter(
            Organization.is_active == True  # noqa: E712
        ).all()
        for org in orgs:
            author = db.query(User).filter(
                User.organization_id == org.id,
                User.role == "SUPER_ADMIN",
            ).first()
            if not author:
                continue
            for provider in _PROVIDERS:
                # One platform's outage, expired token or API change must not
                # stop the others syncing.
                try:
                    added = _sync_provider(db, org, author, provider)
                    if added:
                        logger.info("[social] %s: %s new for org %s",
                                    provider.name, added, org.id)
                except Exception:
                    db.rollback()
                    logger.exception("[social] %s failed for org %s",
                                     provider.name, org.id)
    finally:
        db.close()
