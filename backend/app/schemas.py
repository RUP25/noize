from pydantic import BaseModel, validator, Field
from typing import Optional, List
from datetime import datetime, date
import re

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
    title: str = Field(..., min_length=1, max_length=200, description="Song title (1-200 characters)")
    album: Optional[str] = Field(None, max_length=200, description="Album name (max 200 characters)")
    r2_key: str
    content_type: Optional[str]
    duration: Optional[int] = Field(None, ge=0, description="Duration in seconds (must be >= 0)")
    cover_photo_url: Optional[str] = None
    lyrics: Optional[str] = Field(None, max_length=10000, description="Song lyrics (max 10000 characters)")
    genre: Optional[str] = Field(None, max_length=80, description="Genre tag for discovery (e.g. Pop, Electronic)")

    @validator('title')
    def validate_title(cls, v):
        """Validate song title format."""
        if not v or not v.strip():
            raise ValueError('Title cannot be empty or whitespace only')
        # Remove leading/trailing whitespace
        v = v.strip()
        # Check for valid characters (allow letters, numbers, spaces, and common punctuation)
        if len(v) < 1:
            raise ValueError('Title must be at least 1 character')
        if len(v) > 200:
            raise ValueError('Title must be at most 200 characters')
        return v

    @validator('album')
    def validate_album(cls, v):
        """Validate album name format."""
        if v is None:
            return v
        v = v.strip() if isinstance(v, str) else v
        if not v:
            return None
        if len(v) > 200:
            raise ValueError('Album name must be at most 200 characters')
        return v.strip()

    @validator('r2_key')
    def validate_r2_key(cls, v):
        """Validate R2 key format."""
        if not v or not v.strip():
            raise ValueError('R2 key cannot be empty')
        if not v.startswith('uploads/'):
            raise ValueError('R2 key must start with "uploads/"')
        return v.strip()

class SongUpdate(BaseModel):
    title: Optional[str] = Field(None, min_length=1, max_length=200, description="Song title (1-200 characters)")
    album: Optional[str] = Field(None, max_length=200, description="Album name (max 200 characters)")
    cover_photo_url: Optional[str] = None
    lyrics: Optional[str] = Field(None, max_length=10000, description="Song lyrics (max 10000 characters)")
    genre: Optional[str] = Field(None, max_length=80, description="Genre tag for discovery")

    @validator('title')
    def validate_title(cls, v):
        """Validate song title format."""
        if v is None:
            return v
        if not v or not v.strip():
            raise ValueError('Title cannot be empty or whitespace only')
        v = v.strip()
        if len(v) < 1:
            raise ValueError('Title must be at least 1 character')
        if len(v) > 200:
            raise ValueError('Title must be at most 200 characters')
        return v

    @validator('album')
    def validate_album(cls, v):
        """Validate album name format."""
        if v is None:
            return v
        v = v.strip() if isinstance(v, str) else v
        if not v:
            return None
        if len(v) > 200:
            raise ValueError('Album name must be at most 200 characters')
        return v.strip()

class SongOut(BaseModel):
    id: int
    title: str
    album: Optional[str]
    r2_key: str
    content_type: Optional[str]
    duration: Optional[int]
    cover_photo_url: Optional[str]
    lyrics: Optional[str] = None
    genre: Optional[str] = None
    created_at: datetime
    artist: UserOut
    moderation_status: Optional[str] = None
    like_count: int = 0
    dislike_count: int = 0

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
    cover_photo_url: Optional[str] = None

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
    experience_preferences: Optional[dict] = None

class FeedbackRequest(BaseModel):
    feedback: str
    email: Optional[str] = None


# --------------------------
# MERCHANDISE SCHEMAS
# --------------------------
class MerchandiseCreate(BaseModel):
    title: str = Field(..., min_length=1, max_length=200, description="Item title (1-200 characters)")
    description: Optional[str] = Field(None, max_length=1000, description="Item description (max 1000 characters)")
    price: float = Field(..., ge=0, description="Price (must be >= 0)")
    image_url: Optional[str] = None
    purchase_link: Optional[str] = None
    category: Optional[str] = Field(None, max_length=50, description="Category (max 50 characters)")
    stock: Optional[int] = Field(None, ge=0, description="Stock quantity (must be >= 0)")

    @validator('title')
    def validate_title(cls, v):
        """Validate merchandise title format."""
        if not v or not v.strip():
            raise ValueError('Title cannot be empty or whitespace only')
        v = v.strip()
        if len(v) < 1:
            raise ValueError('Title must be at least 1 character')
        if len(v) > 200:
            raise ValueError('Title must be at most 200 characters')
        return v

    @validator('description')
    def validate_description(cls, v):
        """Validate description format."""
        if v is None:
            return v
        v = v.strip() if isinstance(v, str) else v
        if not v:
            return None
        if len(v) > 1000:
            raise ValueError('Description must be at most 1000 characters')
        return v.strip()

    @validator('price')
    def validate_price(cls, v):
        """Validate price."""
        if v < 0:
            raise ValueError('Price must be >= 0')
        if v > 1000000:  # Reasonable upper limit
            raise ValueError('Price must be <= 1,000,000')
        return round(v, 2)  # Round to 2 decimal places

    @validator('purchase_link')
    def validate_purchase_link(cls, v):
        """Validate purchase link URL format."""
        if v is None or not v.strip():
            return None
        v = v.strip()
        # Basic URL validation
        url_pattern = re.compile(
            r'^https?://'  # http:// or https://
            r'(?:(?:[A-Z0-9](?:[A-Z0-9-]{0,61}[A-Z0-9])?\.)+[A-Z]{2,6}\.?|'  # domain...
            r'localhost|'  # localhost...
            r'\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})'  # ...or ip
            r'(?::\d+)?'  # optional port
            r'(?:/?|[/?]\S+)$', re.IGNORECASE)
        if not url_pattern.match(v):
            raise ValueError('Purchase link must be a valid URL starting with http:// or https://')
        return v

    @validator('category')
    def validate_category(cls, v):
        """Validate category format."""
        if v is None:
            return v
        v = v.strip() if isinstance(v, str) else v
        if not v:
            return None
        if len(v) > 50:
            raise ValueError('Category must be at most 50 characters')
        return v.strip()

    @validator('stock')
    def validate_stock(cls, v):
        """Validate stock quantity."""
        if v is None:
            return v
        if v < 0:
            raise ValueError('Stock quantity must be >= 0')
        return v


class MerchandiseUpdate(BaseModel):
    title: Optional[str] = Field(None, min_length=1, max_length=200, description="Item title (1-200 characters)")
    description: Optional[str] = Field(None, max_length=1000, description="Item description (max 1000 characters)")
    price: Optional[float] = Field(None, ge=0, description="Price (must be >= 0)")
    image_url: Optional[str] = None
    purchase_link: Optional[str] = None
    category: Optional[str] = Field(None, max_length=50, description="Category (max 50 characters)")
    stock: Optional[int] = Field(None, ge=0, description="Stock quantity (must be >= 0)")

    @validator('title')
    def validate_title(cls, v):
        """Validate merchandise title format."""
        if v is None:
            return v
        if not v or not v.strip():
            raise ValueError('Title cannot be empty or whitespace only')
        v = v.strip()
        if len(v) < 1:
            raise ValueError('Title must be at least 1 character')
        if len(v) > 200:
            raise ValueError('Title must be at most 200 characters')
        return v

    @validator('description')
    def validate_description(cls, v):
        """Validate description format."""
        if v is None:
            return v
        v = v.strip() if isinstance(v, str) else v
        if not v:
            return None
        if len(v) > 1000:
            raise ValueError('Description must be at most 1000 characters')
        return v.strip()

    @validator('price')
    def validate_price(cls, v):
        """Validate price."""
        if v is None:
            return v
        if v < 0:
            raise ValueError('Price must be >= 0')
        if v > 1000000:
            raise ValueError('Price must be <= 1,000,000')
        return round(v, 2)

    @validator('purchase_link')
    def validate_purchase_link(cls, v):
        """Validate purchase link URL format."""
        if v is None or not v.strip():
            return None
        v = v.strip()
        url_pattern = re.compile(
            r'^https?://'
            r'(?:(?:[A-Z0-9](?:[A-Z0-9-]{0,61}[A-Z0-9])?\.)+[A-Z]{2,6}\.?|'
            r'localhost|'
            r'\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})'
            r'(?::\d+)?'
            r'(?:/?|[/?]\S+)$', re.IGNORECASE)
        if not url_pattern.match(v):
            raise ValueError('Purchase link must be a valid URL starting with http:// or https://')
        return v

    @validator('category')
    def validate_category(cls, v):
        """Validate category format."""
        if v is None:
            return v
        v = v.strip() if isinstance(v, str) else v
        if not v:
            return None
        if len(v) > 50:
            raise ValueError('Category must be at most 50 characters')
        return v.strip()

    @validator('stock')
    def validate_stock(cls, v):
        """Validate stock quantity."""
        if v is None:
            return v
        if v < 0:
            raise ValueError('Stock quantity must be >= 0')
        return v


class MerchandiseOut(BaseModel):
    id: int
    title: str
    description: Optional[str]
    price: float
    image_url: Optional[str]
    purchase_link: Optional[str]
    category: Optional[str]
    stock: Optional[int]
    artist_id: str
    created_at: datetime

    class Config:
        orm_mode = True
    
    @validator('artist_id', pre=True)
    def convert_uuid_to_str(cls, v):
        """Convert UUID to string if needed."""
        if v is not None:
            return str(v)
        return v


# --------------------------
# EVENT SCHEMAS
# --------------------------
class EventCreate(BaseModel):
    title: str = Field(..., min_length=1, max_length=200, description="Event title (1-200 characters)")
    description: Optional[str] = Field(None, max_length=1000, description="Event description (max 1000 characters)")
    date: date
    time: str = Field(..., description="Event time in HH:MM format")
    location: str = Field(..., min_length=1, max_length=200, description="Event location (1-200 characters)")
    ticket_price: Optional[float] = Field(None, ge=0, description="Ticket price (must be >= 0)")
    ticket_link: Optional[str] = Field(None, max_length=2000, description="Ticket purchase URL")

    @validator('title')
    def validate_title(cls, v):
        """Validate event title format."""
        if not v or not v.strip():
            raise ValueError('Title cannot be empty or whitespace only')
        v = v.strip()
        if len(v) < 1:
            raise ValueError('Title must be at least 1 character')
        if len(v) > 200:
            raise ValueError('Title must be at most 200 characters')
        return v

    @validator('description')
    def validate_description(cls, v):
        """Validate description format."""
        if v is None:
            return v
        v = v.strip() if isinstance(v, str) else v
        if not v:
            return None
        if len(v) > 1000:
            raise ValueError('Description must be at most 1000 characters')
        return v.strip()

    @validator('time')
    def validate_time(cls, v):
        """Validate time format (HH:MM)."""
        if not v or not v.strip():
            raise ValueError('Time cannot be empty')
        v = v.strip()
        # Validate HH:MM format
        time_pattern = re.compile(r'^([0-1]?[0-9]|2[0-3]):[0-5][0-9]$')
        if not time_pattern.match(v):
            raise ValueError('Time must be in HH:MM format (24-hour, e.g., 14:30)')
        return v

    @validator('location')
    def validate_location(cls, v):
        """Validate location format."""
        if not v or not v.strip():
            raise ValueError('Location cannot be empty or whitespace only')
        v = v.strip()
        if len(v) < 1:
            raise ValueError('Location must be at least 1 character')
        if len(v) > 200:
            raise ValueError('Location must be at most 200 characters')
        return v

    @validator('date')
    def validate_date(cls, v):
        """Validate event date (must not be in the past for new events)."""
        from datetime import date as date_class
        # Allow past dates for now (might want to change this later)
        # if v < date_class.today():
        #     raise ValueError('Event date cannot be in the past')
        return v

    @validator('ticket_price')
    def validate_ticket_price(cls, v):
        """Validate ticket price."""
        if v is None:
            return v
        if v < 0:
            raise ValueError('Ticket price must be >= 0')
        if v > 10000:  # Reasonable upper limit
            raise ValueError('Ticket price must be <= 10,000')
        return round(v, 2)  # Round to 2 decimal places


class EventUpdate(BaseModel):
    title: Optional[str] = Field(None, min_length=1, max_length=200, description="Event title (1-200 characters)")
    description: Optional[str] = Field(None, max_length=1000, description="Event description (max 1000 characters)")
    date: Optional[date] = None
    time: Optional[str] = Field(None, description="Event time in HH:MM format")
    location: Optional[str] = Field(None, min_length=1, max_length=200, description="Event location (1-200 characters)")
    ticket_price: Optional[float] = Field(None, ge=0, description="Ticket price (must be >= 0)")
    ticket_link: Optional[str] = Field(None, max_length=2000, description="Ticket purchase URL")

    @validator('title')
    def validate_title(cls, v):
        """Validate event title format."""
        if v is None:
            return v
        if not v or not v.strip():
            raise ValueError('Title cannot be empty or whitespace only')
        v = v.strip()
        if len(v) < 1:
            raise ValueError('Title must be at least 1 character')
        if len(v) > 200:
            raise ValueError('Title must be at most 200 characters')
        return v

    @validator('description')
    def validate_description(cls, v):
        """Validate description format."""
        if v is None:
            return v
        v = v.strip() if isinstance(v, str) else v
        if not v:
            return None
        if len(v) > 1000:
            raise ValueError('Description must be at most 1000 characters')
        return v.strip()

    @validator('time')
    def validate_time(cls, v):
        """Validate time format (HH:MM)."""
        if v is None:
            return v
        if not v or not v.strip():
            raise ValueError('Time cannot be empty')
        v = v.strip()
        time_pattern = re.compile(r'^([0-1]?[0-9]|2[0-3]):[0-5][0-9]$')
        if not time_pattern.match(v):
            raise ValueError('Time must be in HH:MM format (24-hour, e.g., 14:30)')
        return v

    @validator('location')
    def validate_location(cls, v):
        """Validate location format."""
        if v is None:
            return v
        if not v or not v.strip():
            raise ValueError('Location cannot be empty or whitespace only')
        v = v.strip()
        if len(v) < 1:
            raise ValueError('Location must be at least 1 character')
        if len(v) > 200:
            raise ValueError('Location must be at most 200 characters')
        return v

    @validator('ticket_price')
    def validate_ticket_price(cls, v):
        """Validate ticket price."""
        if v is None:
            return v
        if v < 0:
            raise ValueError('Ticket price must be >= 0')
        if v > 10000:
            raise ValueError('Ticket price must be <= 10,000')
        return round(v, 2)


class EventOut(BaseModel):
    id: int
    title: str
    description: Optional[str]
    date: date
    time: str  # Will be converted from Time to string
    location: str
    ticket_price: Optional[float]
    ticket_link: Optional[str] = None
    artist_id: str
    created_at: datetime

    class Config:
        orm_mode = True
    
    @validator('artist_id', pre=True)
    def convert_uuid_to_str(cls, v):
        """Convert UUID to string if needed."""
        if v is not None:
            return str(v)
        return v
    
    @validator('time', pre=True)
    def convert_time_to_str(cls, v):
        """Convert Time object to string if needed."""
        if v is not None:
            if isinstance(v, str):
                return v
            # If it's a time object, convert to string
            return str(v)
        return v