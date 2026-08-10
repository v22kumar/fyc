from datetime import datetime
from typing import Optional

from pydantic import BaseModel


class NewsItemResponse(BaseModel):
    """A single Tamil news headline sourced from Google News RSS."""

    title: str
    source: str
    link: str
    published_at: Optional[datetime] = None
    # The publisher's own picture for this article, when one could be found.
    # Optional on purpose: a headline without a picture is still news, and the
    # app draws a generated tile rather than a hole.
    image_url: Optional[str] = None
