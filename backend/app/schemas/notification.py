from pydantic import BaseModel
from typing import Optional, Dict, Any, List
from uuid import UUID
from datetime import datetime

class NotificationBase(BaseModel):
    title_en: str
    title_ta: str
    body_en: str
    body_ta: str
    notification_type: str
    data: Optional[Dict[str, Any]] = None

class NotificationCreate(NotificationBase):
    user_id: UUID

class NotificationResponse(NotificationBase):
    id: UUID
    user_id: UUID
    is_read: bool
    created_at: datetime
    
    class Config:
        from_attributes = True

class NotificationPreferenceBase(BaseModel):
    push_enabled: bool = True
    whatsapp_enabled: bool = True
    sms_enabled: bool = False
    email_enabled: bool = True
    news_enabled: bool = True
    sports_enabled: bool = True
    community_enabled: bool = True
    events_enabled: bool = True

class NotificationPreferenceUpdate(NotificationPreferenceBase):
    pass

class NotificationPreferenceResponse(NotificationPreferenceBase):
    id: UUID
    user_id: UUID

    class Config:
        from_attributes = True

class BroadcastRequest(BaseModel):
    title_en: str
    title_ta: str
    body_en: str
    body_ta: str
    notification_type: str
    data: Optional[Dict[str, Any]] = None
    target_roles: Optional[List[str]] = None
