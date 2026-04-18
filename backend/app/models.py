import uuid
from sqlalchemy import (
    Column,
    String,
    Text,
    Boolean,
    ForeignKey,
    DateTime,
    Date,
    func,
    Integer,
    Float,
    Time,
)
from sqlalchemy.dialects.postgresql import UUID, JSON
from sqlalchemy.orm import relationship
from .db import Base


# --------------------------
# USERS
# --------------------------
class User(Base):
    __tablename__ = "users"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4, index=True)
    contact = Column(String, unique=True, index=True, nullable=False)
    email = Column(String, unique=True, index=True, nullable=True)
    password_hash = Column(String, nullable=True)
    is_artist = Column(Boolean, default=False)
    # NOIZE Artist (free): upload, profile, basic stats. Artist+ (paid): merch, events, tipping, campaigns.
    artist_plus = Column(Boolean, default=False)
    artist_plus_monthly_paise = Column(Integer, nullable=True)
    channel_name = Column(String, unique=True, index=True, nullable=True)
    banner_url = Column(String, nullable=True)
    photo_url = Column(String, nullable=True)
    is_upgraded = Column(Boolean, default=False)
    # guest | listen | rep (listener engagement) | influencer | artist (NOIZE Artist free / Artist+ paid) | ngo
    user_role = Column(String, default='guest')
    kyc_verified = Column(Boolean, default=False)
    is_admin = Column(Boolean, default=False)
    is_suspended = Column(Boolean, default=False)
    referral_code = Column(String, unique=True, nullable=True)
    # Listener profile fields (used for non-artist users too)
    full_name = Column(String, nullable=True)
    date_of_birth = Column(Date, nullable=True)
    # Settings stored as JSON
    notification_settings = Column(JSON, nullable=True, default=dict)
    privacy_settings = Column(JSON, nullable=True, default=dict)
    language = Column(String, nullable=True, default='en')
    location = Column(String, nullable=True)
    experience_preferences = Column(JSON, nullable=True, default=dict)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    # Relationships
    songs = relationship("Song", back_populates="artist", cascade="all, delete-orphan")
    followers = relationship("Follow", back_populates="artist", foreign_keys="Follow.artist_id")
    likes = relationship("Like", back_populates="user", foreign_keys="Like.user_id")
    dislikes = relationship("Dislike", back_populates="user", foreign_keys="Dislike.user_id")
    playlists = relationship("Playlist", back_populates="user")
    listen_events = relationship("ListenEvent", back_populates="user", cascade="all, delete-orphan")
    merchandise = relationship("Merchandise", back_populates="artist", cascade="all, delete-orphan")
    events = relationship("Event", back_populates="artist", cascade="all, delete-orphan")


# --------------------------
# SONGS
# --------------------------
class Song(Base):
    __tablename__ = "songs"

    id = Column(Integer, primary_key=True, index=True)
    title = Column(String, nullable=False)
    album = Column(String, nullable=True)
    r2_key = Column(String, nullable=False, index=True)
    content_type = Column(String, nullable=True)
    duration = Column(Integer, nullable=True)
    cover_photo_url = Column(String, nullable=True)
    lyrics = Column(Text, nullable=True)  # Song lyrics text
    genre = Column(String, nullable=True, index=True)
    artist_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"))
    moderation_status = Column(String, nullable=True)  # pending, approved, rejected, flagged
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    # Relationships
    artist = relationship("User", back_populates="songs")
    likes = relationship("Like", back_populates="song", cascade="all, delete-orphan")
    dislikes = relationship("Dislike", back_populates="song", cascade="all, delete-orphan")


# --------------------------
# FOLLOWS
# --------------------------
class Follow(Base):
    __tablename__ = "follows"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"))
    artist_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"))
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    artist = relationship("User", foreign_keys=[artist_id], back_populates="followers")


# --------------------------
# LIKES
# --------------------------
class Like(Base):
    __tablename__ = "likes"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"))
    song_id = Column(Integer, ForeignKey("songs.id", ondelete="CASCADE"))
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    user = relationship("User", back_populates="likes")
    song = relationship("Song", back_populates="likes")


# --------------------------
# DISLIKES (explicit negative feedback for recommendations)
# --------------------------
class Dislike(Base):
    __tablename__ = "dislikes"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"))
    song_id = Column(Integer, ForeignKey("songs.id", ondelete="CASCADE"))
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    user = relationship("User", back_populates="dislikes")
    song = relationship("Song", back_populates="dislikes")


# --------------------------
# LISTEN EVENTS (implicit feedback for recommendations / trending)
# --------------------------
class ListenEvent(Base):
    __tablename__ = "listen_events"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    song_id = Column(Integer, ForeignKey("songs.id", ondelete="CASCADE"), nullable=False, index=True)
    listen_ms = Column(Integer, nullable=True)
    played_at = Column(DateTime(timezone=True), server_default=func.now(), index=True)

    user = relationship("User", back_populates="listen_events")
    song = relationship("Song")


# --------------------------
# PLAYLISTS
# --------------------------
class Playlist(Base):
    __tablename__ = "playlists"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4, index=True)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"))
    name = Column(String, default="My Playlist")
    is_public = Column(Boolean, default=False)
    cover_photo_url = Column(String, nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    user = relationship("User", back_populates="playlists")
    songs = relationship("PlaylistSong", back_populates="playlist", cascade="all, delete-orphan")


# --------------------------
# PLAYLIST_SONGS (many-to-many)
# --------------------------
class PlaylistSong(Base):
    __tablename__ = "playlist_songs"

    id = Column(Integer, primary_key=True, index=True)
    playlist_id = Column(UUID(as_uuid=True), ForeignKey("playlists.id", ondelete="CASCADE"))
    song_id = Column(Integer, ForeignKey("songs.id", ondelete="CASCADE"))
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    playlist = relationship("Playlist", back_populates="songs")
    song = relationship("Song")


# --------------------------
# MERCHANDISE
# --------------------------
class Merchandise(Base):
    __tablename__ = "merchandise"

    id = Column(Integer, primary_key=True, index=True)
    title = Column(String, nullable=False)
    description = Column(String, nullable=True)
    price = Column(Float, nullable=False)
    image_url = Column(String, nullable=True)
    purchase_link = Column(String, nullable=True)
    category = Column(String, nullable=True)  # Apparel, Accessories, Music, Other
    stock = Column(Integer, nullable=True)
    artist_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"))
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    # Relationships
    artist = relationship("User", back_populates="merchandise")


# --------------------------
# EVENTS
# --------------------------
class Event(Base):
    __tablename__ = "events"

    id = Column(Integer, primary_key=True, index=True)
    title = Column(String, nullable=False)
    description = Column(String, nullable=True)
    date = Column(Date, nullable=False)
    time = Column(Time, nullable=False)
    location = Column(String, nullable=False)
    ticket_price = Column(Float, nullable=True)
    ticket_link = Column(String, nullable=True)
    artist_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"))
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    # Relationships
    artist = relationship("User", back_populates="events")
