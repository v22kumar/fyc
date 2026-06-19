import httpx
from app.core.config import settings

GRAPH_API = "https://graph.facebook.com/v19.0"


def is_configured() -> bool:
    """Return True when both INSTAGRAM_ACCOUNT_ID and INSTAGRAM_ACCESS_TOKEN are set."""
    return bool(settings.INSTAGRAM_ACCOUNT_ID and settings.INSTAGRAM_ACCESS_TOKEN)


def publish_photo(image_url: str, caption: str) -> str:
    """
    Publish a photo to the org's Instagram feed.
    Returns the Instagram media ID.
    Raises RuntimeError if not configured or if the API returns an error.
    """
    if not is_configured():
        raise RuntimeError(
            "Instagram is not configured. "
            "Set INSTAGRAM_ACCOUNT_ID and INSTAGRAM_ACCESS_TOKEN."
        )

    account_id = settings.INSTAGRAM_ACCOUNT_ID
    token = settings.INSTAGRAM_ACCESS_TOKEN

    # Step 1: create container
    r1 = httpx.post(
        f"{GRAPH_API}/{account_id}/media",
        params={"image_url": image_url, "caption": caption, "access_token": token},
        timeout=15,
    )
    r1.raise_for_status()
    container_id = r1.json()["id"]

    # Step 2: publish
    r2 = httpx.post(
        f"{GRAPH_API}/{account_id}/media_publish",
        params={"creation_id": container_id, "access_token": token},
        timeout=15,
    )
    r2.raise_for_status()
    return r2.json()["id"]
