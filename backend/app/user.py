from fastapi import APIRouter, Depends, HTTPException, Header
from pydantic import BaseModel
from .auth_integration import get_current_user
from .models import User, Playlist, PlaylistSong, Song, Like
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from sqlalchemy.orm import selectinload
from typing import List, Optional
from .db import get_db
from .schemas import UpdateProfileRequest, ChangePasswordRequest, UpdateSettingsRequest, FeedbackRequest
from .password_utils import hash_password, verify_password
from .cache_decorator import cache_user_profile, get_cached_user_profile, invalidate_user_cache
from .redis_client import store_token_blacklist, delete_all_user_sessions, create_session, publish_notification

router = APIRouter(prefix="/user", tags=["user"])

class PlaylistCreate(BaseModel):
    name: str
    is_public: bool = False

class PlaylistUpdate(BaseModel):
    name: Optional[str] = None
    is_public: Optional[bool] = None

class PlaylistAddSong(BaseModel):
    song_id: int

class UpgradeRequest(BaseModel):
    role: str  # 'listen', 'rep', 'influencer'
    kyc_verified: bool = False

@router.get("/me")
async def me(current_user: User = Depends(get_current_user)):
    """Get current user profile with caching."""
    user_id = str(current_user.id)
    
    # Try cache first
    cached_profile = await get_cached_user_profile(user_id)
    if cached_profile:
        return cached_profile
    
    # Build profile data
    profile_data = {
        "id": user_id,
        "contact": current_user.contact,
        "email": current_user.email,
        "full_name": current_user.full_name,
        "date_of_birth": current_user.date_of_birth.isoformat() if current_user.date_of_birth else None,
        "channel_name": current_user.channel_name,
        "banner_url": current_user.banner_url,
        "photo_url": current_user.photo_url,
        "is_artist": current_user.is_artist,
        "is_upgraded": current_user.is_upgraded,
        "user_role": current_user.user_role,
        "kyc_verified": current_user.kyc_verified,
        "referral_code": current_user.referral_code,
        "notification_settings": current_user.notification_settings or {},
        "privacy_settings": current_user.privacy_settings or {},
        "language": current_user.language or "en",
        "location": current_user.location,
    }
    
    # Cache for 30 minutes
    await cache_user_profile(user_id, profile_data, expiry_seconds=1800)
    return profile_data

@router.put("/profile")
async def update_profile(
    req: UpdateProfileRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Update user profile (channel name, banner, photo)."""
    if req.channel_name is not None:
        # Check if channel name is already taken by another user
        if req.channel_name != current_user.channel_name:
            result = await db.execute(select(User).where(User.channel_name == req.channel_name))
            if result.scalars().first():
                raise HTTPException(status_code=400, detail="Channel name already taken")
            current_user.channel_name = req.channel_name
    
    if req.banner_url is not None:
        current_user.banner_url = req.banner_url
    
    if req.photo_url is not None:
        current_user.photo_url = req.photo_url

    if getattr(req, "full_name", None) is not None:
        current_user.full_name = req.full_name

    if getattr(req, "date_of_birth", None) is not None:
        current_user.date_of_birth = req.date_of_birth
    
    db.add(current_user)
    await db.commit()
    await db.refresh(current_user)
    
    # Invalidate cache after update
    await invalidate_user_cache(str(current_user.id))
    
    return {
        "id": str(current_user.id),
        "channel_name": current_user.channel_name,
        "banner_url": current_user.banner_url,
        "photo_url": current_user.photo_url,
        "full_name": current_user.full_name,
        "date_of_birth": current_user.date_of_birth.isoformat() if current_user.date_of_birth else None,
    }

@router.post("/change-password")
async def change_password(
    req: ChangePasswordRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Change user password."""
    if not current_user.password_hash:
        raise HTTPException(status_code=400, detail="Password not set. Please set a password first.")
    
    if not verify_password(req.current_password, current_user.password_hash):
        raise HTTPException(status_code=401, detail="Current password is incorrect")
    
    if len(req.new_password) < 6:
        raise HTTPException(status_code=400, detail="New password must be at least 6 characters")
    
    current_user.password_hash = hash_password(req.new_password)
    db.add(current_user)
    await db.commit()
    
    # Invalidate all user sessions on password change
    await delete_all_user_sessions(str(current_user.id))
    await invalidate_user_cache(str(current_user.id))
    
    # Notify user of password change
    await publish_notification(
        f"notifications:user:{current_user.id}",
        {
            "type": "password_changed",
            "message": "Your password has been changed successfully",
            "timestamp": str(current_user.created_at)
        }
    )
    
    return {"ok": True, "message": "Password changed successfully"}

@router.get("/settings")
async def get_settings(current_user: User = Depends(get_current_user)):
    """Get user settings."""
    return {
        "notification_settings": current_user.notification_settings or {
            "push_notifications": True,
            "email_notifications": False,
            "new_follower": True,
            "new_like": True,
            "new_comment": True,
            "new_message": True,
            "weekly_digest": False,
        },
        "privacy_settings": current_user.privacy_settings or {
            "public_profile": True,
            "show_email": False,
            "show_phone": False,
            "allow_messages": True,
            "show_playlists": True,
            "show_likes": True,
        },
        "language": current_user.language or "en",
        "location": current_user.location or "",
    }

@router.put("/settings")
async def update_settings(
    req: UpdateSettingsRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Update user settings."""
    if req.notification_settings is not None:
        if current_user.notification_settings is None:
            current_user.notification_settings = {}
        current_user.notification_settings.update(req.notification_settings)
    
    if req.privacy_settings is not None:
        if current_user.privacy_settings is None:
            current_user.privacy_settings = {}
        current_user.privacy_settings.update(req.privacy_settings)
    
    if req.language is not None:
        current_user.language = req.language
    
    if req.location is not None:
        current_user.location = req.location
    
    db.add(current_user)
    await db.commit()
    await db.refresh(current_user)
    
    return {
        "notification_settings": current_user.notification_settings or {},
        "privacy_settings": current_user.privacy_settings or {},
        "language": current_user.language or "en",
        "location": current_user.location or "",
    }

@router.post("/feedback")
async def submit_feedback(
    req: FeedbackRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Submit user feedback."""
    # In a real app, you would save this to a feedback table or send via email
    # For now, we'll just log it and return success
    print(f"\n{'='*60}")
    print(f"📝 Feedback from user {current_user.contact} ({current_user.email or 'no email'}):")
    print(f"{req.feedback}")
    print(f"{'='*60}\n")
    
    # TODO: Save to database or send via email service
    return {"ok": True, "message": "Thank you for your feedback!"}

@router.post("/logout")
async def logout(
    authorization: str = Header(None),
    current_user: User = Depends(get_current_user)
):
    """Logout user and blacklist token."""
    if not authorization:
        raise HTTPException(status_code=401, detail="Missing authorization header")
    
    parts = authorization.split()
    if len(parts) != 2 or parts[0].lower() != "bearer":
        raise HTTPException(status_code=401, detail="Invalid auth scheme")
    
    token = parts[1]
    
    # Blacklist token (24 hour expiry)
    await store_token_blacklist(token, expiry_seconds=86400)
    
    # Delete session
    await delete_all_user_sessions(str(current_user.id))
    
    # Invalidate cache
    await invalidate_user_cache(str(current_user.id))
    
    return {"ok": True, "message": "Logged out successfully"}


@router.delete("/account")
async def delete_account(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Delete user account and all associated data."""
    user_id = str(current_user.id)
    
    # Cascade deletes will handle related records (songs, playlists, etc.)
    from sqlalchemy import delete
    await db.execute(delete(User).where(User.id == current_user.id))
    await db.commit()
    
    # Clean up Redis data
    await delete_all_user_sessions(user_id)
    await invalidate_user_cache(user_id)
    
    return {"ok": True, "message": "Account deleted successfully"}

@router.get("/likes")
async def get_likes(current_user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    """Get all liked song IDs for the current user"""
    q = await db.execute(select(Like).where(Like.user_id == current_user.id))
    likes = q.scalars().all()
    return {"liked_songs": [like.song_id for like in likes]}

@router.get("/likes/songs")
async def get_liked_songs(current_user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    """Get all liked songs with full details for the current user"""
    from sqlalchemy import or_
    q = await db.execute(
        select(Like)
        .where(Like.user_id == current_user.id)
        .options(selectinload(Like.song).selectinload(Song.artist))
    )
    likes = q.scalars().all()
    result = []
    for like in likes:
        song = like.song
        # Filter out rejected songs, but include flagged (suspended) songs
        if song.moderation_status == 'rejected':
            continue  # Skip rejected songs
        result.append({
            "id": song.id,
            "title": song.title,
            "album": song.album,
            "r2_key": song.r2_key,
            "artist": song.artist.channel_name if song.artist else None,
            "moderation_status": song.moderation_status,
            "cover_photo_url": song.cover_photo_url,
        })
    return result

@router.post("/upgrade")
async def upgrade(req: UpgradeRequest, current_user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    """Upgrade user to specified role (listen, rep, influencer)"""
    # Generate referral code if upgrading to REP
    import secrets
    import string
    
    if current_user.user_role in ['listen', 'rep', 'influencer'] and current_user.user_role != 'guest':
        return {"ok": False, "msg": f"Already upgraded to {current_user.user_role}"}
    
    current_user.is_upgraded = True
    current_user.user_role = req.role
    current_user.kyc_verified = req.kyc_verified
    
    # Generate unique referral code for REP users
    if req.role == 'rep' and current_user.referral_code is None:
        while True:
            code = ''.join(secrets.choice(string.ascii_uppercase + string.digits) for _ in range(8))
            # Check if code exists
            q = await db.execute(select(User).where(User.referral_code == code))
            if q.scalars().first() is None:
                current_user.referral_code = code
                break
    
    db.add(current_user)
    await db.commit()
    await db.refresh(current_user)
    
    return {
        "ok": True, 
        "is_upgraded": True,
        "user_role": current_user.user_role,
        "referral_code": current_user.referral_code,
    }

# Playlist endpoints
@router.get("/playlists")
async def get_playlists(current_user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    """Get all playlists for the current user"""
    q = await db.execute(
        select(Playlist)
        .where(Playlist.user_id == current_user.id)
        .options(selectinload(Playlist.songs).selectinload(PlaylistSong.song).selectinload(Song.artist))
    )
    playlists = q.scalars().all()
    result = []
    for p in playlists:
        songs_data = []
        for ps in p.songs:
            # Filter out rejected songs, but include flagged (suspended) songs
            if ps.song.moderation_status == 'rejected':
                continue  # Skip rejected songs
            songs_data.append({
                "id": ps.song.id,
                "title": ps.song.title,
                "album": ps.song.album,
                "artist": ps.song.artist.channel_name if ps.song.artist else None,
                "r2_key": ps.song.r2_key,
                "moderation_status": ps.song.moderation_status,
                "cover_photo_url": ps.song.cover_photo_url,
            })
        result.append({
            "id": str(p.id),
            "name": p.name,
            "song_count": len(songs_data),
            "songs": songs_data,
            "is_public": p.is_public,
        })
    return result

@router.get("/playlists/public")
async def get_public_playlists(db: AsyncSession = Depends(get_db)):
    """Get all public playlists"""
    q = await db.execute(
        select(Playlist)
        .where(Playlist.is_public == True)
        .options(selectinload(Playlist.user), selectinload(Playlist.songs).selectinload(PlaylistSong.song).selectinload(Song.artist))
    )
    playlists = q.scalars().all()
    result = []
    for p in playlists:
        songs_data = []
        for ps in p.songs:
            # Filter out rejected songs, but include flagged (suspended) songs
            if ps.song.moderation_status == 'rejected':
                continue  # Skip rejected songs
            songs_data.append({
                "id": ps.song.id,
                "title": ps.song.title,
                "album": ps.song.album,
                "artist": ps.song.artist.channel_name if ps.song.artist else None,
                "r2_key": ps.song.r2_key,
                "moderation_status": ps.song.moderation_status,
                "cover_photo_url": ps.song.cover_photo_url,
            })
        result.append({
            "id": str(p.id),
            "name": p.name,
            "creator": p.user.contact if p.user else "Unknown",
            "song_count": len(songs_data),
            "songs": songs_data,
        })
    return result

@router.post("/playlist/create")
async def create_playlist(req: PlaylistCreate, current_user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    """Create a new playlist"""
    # Only upgraded users can create public playlists
    if req.is_public and not current_user.is_upgraded:
        raise HTTPException(status_code=403, detail="Upgrade required to create public playlists")
    
    p = Playlist(user_id=current_user.id, name=req.name, is_public=req.is_public if current_user.is_upgraded else False)
    db.add(p)
    await db.commit()
    await db.refresh(p)
    return {"ok": True, "playlist_id": str(p.id), "name": p.name, "is_public": p.is_public}

@router.post("/playlist/{playlist_id}/add")
async def add_to_playlist(playlist_id: str, req: PlaylistAddSong, current_user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    """Add a song to a playlist"""
    q = await db.execute(select(Playlist).where(Playlist.id == playlist_id, Playlist.user_id == current_user.id))
    playlist = q.scalars().first()
    if not playlist:
        raise HTTPException(status_code=404, detail="Playlist not found")
    
    # Check if song exists
    q2 = await db.execute(select(Song).where(Song.id == req.song_id))
    song = q2.scalars().first()
    if not song:
        raise HTTPException(status_code=404, detail="Song not found")
    
    # Check if already in playlist
    q3 = await db.execute(select(PlaylistSong).where(PlaylistSong.playlist_id == playlist_id, PlaylistSong.song_id == req.song_id))
    exists = q3.scalars().first()
    if exists:
        return {"ok": True, "added": False, "msg": "Already in playlist"}
    
    ps = PlaylistSong(playlist_id=playlist_id, song_id=req.song_id)
    db.add(ps)
    await db.commit()
    return {"ok": True, "added": True}

@router.get("/playlist/{playlist_id}")
async def get_playlist(playlist_id: str, current_user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    """Get a single playlist by ID"""
    q = await db.execute(
        select(Playlist)
        .where(Playlist.id == playlist_id)
        .options(selectinload(Playlist.songs).selectinload(PlaylistSong.song).selectinload(Song.artist))
    )
    playlist = q.scalars().first()
    if not playlist:
        raise HTTPException(status_code=404, detail="Playlist not found")
    
    # Check if user has access (owner or public)
    if playlist.user_id != current_user.id and not playlist.is_public:
        raise HTTPException(status_code=403, detail="Access denied")
    
    songs_data = []
    for ps in playlist.songs:
        # Filter out rejected songs, but include flagged (suspended) songs
        if ps.song.moderation_status == 'rejected':
            continue  # Skip rejected songs
        songs_data.append({
            "id": ps.song.id,
            "title": ps.song.title,
            "album": ps.song.album,
            "artist": ps.song.artist.channel_name if ps.song.artist else None,
            "r2_key": ps.song.r2_key,
            "cover_photo_url": ps.song.cover_photo_url,
            "duration": ps.song.duration,
            "moderation_status": ps.song.moderation_status,
        })
    
    return {
        "id": str(playlist.id),
        "name": playlist.name,
        "song_count": len(songs_data),
        "songs": songs_data,
        "is_public": playlist.is_public,
        "created_at": playlist.created_at.isoformat(),
        "is_owner": playlist.user_id == current_user.id,
    }

@router.put("/playlist/{playlist_id}")
async def update_playlist(playlist_id: str, req: PlaylistUpdate, current_user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    """Update a playlist (name and/or is_public)"""
    q = await db.execute(select(Playlist).where(Playlist.id == playlist_id, Playlist.user_id == current_user.id))
    playlist = q.scalars().first()
    if not playlist:
        raise HTTPException(status_code=404, detail="Playlist not found")
    
    # Only upgraded users can make playlists public
    if req.is_public is not None and req.is_public and not current_user.is_upgraded:
        raise HTTPException(status_code=403, detail="Upgrade required to make playlists public")
    
    # Update fields if provided
    if req.name is not None:
        playlist.name = req.name
    if req.is_public is not None:
        playlist.is_public = req.is_public if current_user.is_upgraded else False
    
    await db.commit()
    await db.refresh(playlist)
    
    return {
        "ok": True,
        "playlist_id": str(playlist.id),
        "name": playlist.name,
        "is_public": playlist.is_public,
    }

@router.delete("/playlist/{playlist_id}")
async def delete_playlist(playlist_id: str, current_user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    """Delete a playlist"""
    q = await db.execute(select(Playlist).where(Playlist.id == playlist_id, Playlist.user_id == current_user.id))
    playlist = q.scalars().first()
    if not playlist:
        raise HTTPException(status_code=404, detail="Playlist not found")
    
    # Cascade delete will handle PlaylistSong records
    from sqlalchemy import delete
    await db.execute(delete(Playlist).where(Playlist.id == playlist_id))
    await db.commit()
    
    return {"ok": True, "deleted": True, "playlist_id": playlist_id}

@router.delete("/playlist/{playlist_id}/song/{song_id}")
async def remove_from_playlist(playlist_id: str, song_id: int, current_user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    """Remove a song from a playlist"""
    q = await db.execute(select(Playlist).where(Playlist.id == playlist_id, Playlist.user_id == current_user.id))
    playlist = q.scalars().first()
    if not playlist:
        raise HTTPException(status_code=404, detail="Playlist not found")
    
    from sqlalchemy import delete
    await db.execute(delete(PlaylistSong).where(PlaylistSong.playlist_id == playlist_id, PlaylistSong.song_id == song_id))
    await db.commit()
    return {"ok": True, "removed": True}
