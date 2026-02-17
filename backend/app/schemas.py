from pydantic import BaseModel, validator
from typing import Optional, List
from datetime import datetime, date

class UserOut(BaseModel):
    id: str
    contact: str
    email: Optional[str]
    is_artist: bool
    channel_name: Optional[str]
    banner_url: Optional[str]
    photo_url: Optional[str]
    is_upgraded: bool
    created_at: datetime

    class Config:
        orm_mode = True
    
    @validator('id', pre=True)
    def convert_uuid_to_str(cls, v):
        """Convert UUID to string if needed."""
        if v is not None:
            return str(v)
        return v

class SongCreate(BaseModel):
    title: str
    album: Optional[str]
    r2_key: str
    content_type: Optional[str]
    duration: Optional[int]
    cover_photo_url: Optional[str] = None

class SongOut(BaseModel):
    id: int
    title: str
    album: Optional[str]
    r2_key: str
    content_type: Optional[str]
    duration: Optional[int]
    cover_photo_url: Optional[str]
    created_at: datetime
    artist: UserOut
    moderation_status: Optional[str] = None

    class Config:
        orm_mode = True

class CreateChannelRequest(BaseModel):
    channel_name: str
    banner_url: Optional[str] = None
    photo_url: Optional[str] = None

class PlaylistCreate(BaseModel):
    name: str
    is_public: bool = False

class PlaylistUpdate(BaseModel):
    name: Optional[str] = None
    is_public: Optional[bool] = None

class EmailPasswordLogin(BaseModel):
    email: str
    password: str

class EmailPasswordSignup(BaseModel):
    email: str
    password: str
    contact: str  # Phone number still required

class UpdateProfileRequest(BaseModel):
    channel_name: Optional[str] = None
    banner_url: Optional[str] = None
    photo_url: Optional[str] = None
    full_name: Optional[str] = None
    date_of_birth: Optional[date] = None

class ChangePasswordRequest(BaseModel):
    current_password: str
    new_password: str

class NotificationSettings(BaseModel):
    push_notifications: bool = True
    email_notifications: bool = False
    new_follower: bool = True
    new_like: bool = True
    new_comment: bool = True
    new_message: bool = True
    weekly_digest: bool = False

class PrivacySettings(BaseModel):
    public_profile: bool = True
    show_email: bool = False
    show_phone: bool = False
    allow_messages: bool = True
    show_playlists: bool = True
    show_likes: bool = True

class UpdateSettingsRequest(BaseModel):
    notification_settings: Optional[dict] = None
    privacy_settings: Optional[dict] = None
    language: Optional[str] = None
    location: Optional[str] = None

class FeedbackRequest(BaseModel):
    feedback: str
    email: Optional[str] = None