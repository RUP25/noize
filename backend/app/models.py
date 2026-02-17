import uuid
from sqlalchemy import (
    Column,
    String,
    Boolean,
    ForeignKey,
    DateTime,
    Date,
    func,
    Integer,
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
    channel_name = Column(String, unique=True, index=True, nullable=True)
    banner_url = Column(String, nullable=True)
    photo_url = Column(String, nullable=True)
    is_upgraded = Column(Boolean, default=False)
    user_role = Column(String, default='guest')  # guest, listen, rep, influencer, artist, ngo
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
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    # Relationships
    songs = relationship("Song", back_populates="artist", cascade="all, delete-orphan")
    followers = relationship("Follow", back_populates="artist", foreign_keys="Follow.artist_id")
    likes = relationship("Like", back_populates="user", foreign_keys="Like.user_id")
    playlists = relationship("Playlist", back_populates="user")


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
    artist_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"))
    moderation_status = Column(String, nullable=True)  # pending, approved, rejected, flagged
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    # Relationships
    artist = relationship("User", back_populates="songs")
    likes = relationship("Like", back_populates="song", cascade="all, delete-orphan")


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
# PLAYLISTS
# --------------------------
class Playlist(Base):
    __tablename__ = "playlists"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4, index=True)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"))
    name = Column(String, default="My Playlist")
    is_public = Column(Boolean, default=False)
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
