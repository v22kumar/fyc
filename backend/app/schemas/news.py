from datetime import datetime
from typing import Optional

from pydantic import BaseModel


class NewsItemResponse(BaseModel):
    """A single Tamil news headline sourced from Google News RSS."""

    title: str
    source: str
    link: str
    published_at: Optional[datetime] = None
