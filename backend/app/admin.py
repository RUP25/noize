# backend/app/admin.py
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, and_, or_
from sqlalchemy.orm import selectinload
from typing import List, Optional
from datetime import datetime, timedelta
from .db import get_db
from .models import User, Song, Playlist, Like, Follow
from .auth_integration import get_current_user
from .schemas import UserOut, SongOut
from pydantic import BaseModel

router = APIRouter(prefix="/admin", tags=["admin"])


# ==================== Pydantic Schemas ====================

class AdminStats(BaseModel):
    total_users: int
    total_artists: int
    total_songs: int
    total_playlists: int
    pending_songs: int
    active_users_30d: int
    new_users_7d: int


class ContentModerationAction(BaseModel):
    song_id: int
    action: str  # "approve", "reject", "flag"
    reason: Optional[str] = None


class UserManagementAction(BaseModel):
    user_id: str
    action: str  # "suspend", "activate", "delete", "promote_to_admin"
    reason: Optional[str] = None


class FeatureToggle(BaseModel):
    feature_name: str
    enabled: bool


# ==================== Admin Auth Helper ====================

async def get_admin_user(current_user: User = Depends(get_current_user)) -> User:
    """Verify that the current user is an admin."""
    if not current_user.is_admin:
        raise HTTPException(status_code=403, detail="Admin access required")
    return current_user


# ==================== Dashboard & Stats ====================

@router.get("/stats", response_model=AdminStats)
async def get_admin_stats(
    db: AsyncSession = Depends(get_db),
    admin: User = Depends(get_admin_user)
):
    """Get overall platform statistics."""
    # Total users
    total_users_result = await db.execute(select(func.count(User.id)))
    total_users = total_users_result.scalar() or 0
    
    # Total artists
    artists_result = await db.execute(select(func.count(User.id)).where(User.is_artist == True))
    total_artists = artists_result.scalar() or 0
    
    # Total songs
    songs_result = await db.execute(select(func.count(Song.id)))
    total_songs = songs_result.scalar() or 0
    
    # Total playlists
    playlists_result = await db.execute(select(func.count(Playlist.id)))
    total_playlists = playlists_result.scalar() or 0
    
    # Pending songs (songs without moderation_status or status='pending')
    pending_result = await db.execute(
        select(func.count(Song.id)).where(
            or_(
                Song.moderation_status == None,
                Song.moderation_status == 'pending'
            )
        )
    )
    pending_songs = pending_result.scalar() or 0
    
    # Active users in last 30 days
    thirty_days_ago = datetime.utcnow() - timedelta(days=30)
    active_users_result = await db.execute(
        select(func.count(func.distinct(Like.user_id)))
        .where(Like.created_at >= thirty_days_ago)
    )
    active_users_30d = active_users_result.scalar() or 0
    
    # New users in last 7 days
    seven_days_ago = datetime.utcnow() - timedelta(days=7)
    new_users_result = await db.execute(
        select(func.count(User.id)).where(User.created_at >= seven_days_ago)
    )
    new_users_7d = new_users_result.scalar() or 0
    
    return AdminStats(
        total_users=total_users,
        total_artists=total_artists,
        total_songs=total_songs,
        total_playlists=total_playlists,
        pending_songs=pending_songs,
        active_users_30d=active_users_30d,
        new_users_7d=new_users_7d,
    )


# ==================== Content Moderation ====================

@router.get("/content/songs/pending")
async def get_pending_songs(
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=100),
    search: Optional[str] = Query(None),
    db: AsyncSession = Depends(get_db),
    admin: User = Depends(get_admin_user)
):
    """Get list of songs pending moderation."""
    query = select(Song).options(selectinload(Song.artist))
    
    # Base filter for pending songs
    status_filter = or_(
        Song.moderation_status == None,
        Song.moderation_status == 'pending'
    )
    
    if search:
        # Join User table for search
        query = query.join(User, Song.artist_id == User.id)
        # Combine status filter with search filter
        query = query.where(
            and_(
                status_filter,
                or_(
                    Song.title.ilike(f"%{search}%"),
                    Song.album.ilike(f"%{search}%"),
                    User.channel_name.ilike(f"%{search}%"),
                )
            )
        )
    else:
        query = query.where(status_filter)
    
    result = await db.execute(
        query.order_by(Song.created_at.desc()).offset(skip).limit(limit)
    )
    songs = result.scalars().all()
    return [{
        "id": song.id,
        "title": song.title,
        "album": song.album,
        "artist": song.artist.channel_name if song.artist else "Unknown",
        "artist_id": str(song.artist_id),
        "cover_photo_url": song.cover_photo_url,
        "created_at": song.created_at.isoformat() if song.created_at else None,
        "moderation_status": song.moderation_status,
    } for song in songs]


@router.get("/content/songs/all")
async def get_all_songs(
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=100),
    status: Optional[str] = Query(None),
    search: Optional[str] = Query(None),
    db: AsyncSession = Depends(get_db),
    admin: User = Depends(get_admin_user)
):
    """Get all songs with optional status filter and search."""
    from .models import Like
    
    # Use selectinload to eagerly load both artist and likes relationships
    query = select(Song).options(selectinload(Song.artist), selectinload(Song.likes))
    
    conditions = []
    
    if status:
        conditions.append(Song.moderation_status == status)
    
    if search:
        # Join User table for search
        query = query.join(User, Song.artist_id == User.id)
        conditions.append(
            or_(
                Song.title.ilike(f"%{search}%"),
                Song.album.ilike(f"%{search}%"),
                User.channel_name.ilike(f"%{search}%"),
            )
        )
    
    if conditions:
        query = query.where(and_(*conditions))
    
    result = await db.execute(
        query.order_by(Song.created_at.desc()).offset(skip).limit(limit)
    )
    songs = result.scalars().all()
    return [{
        "id": song.id,
        "title": song.title,
        "album": song.album,
        "artist": song.artist.channel_name if song.artist else "Unknown",
        "artist_id": str(song.artist_id),
        "cover_photo_url": song.cover_photo_url,
        "created_at": song.created_at.isoformat() if song.created_at else None,
        "moderation_status": song.moderation_status,
        "like_count": len(song.likes) if song.likes else 0,
    } for song in songs]


@router.post("/content/songs/moderate")
async def moderate_song(
    action: ContentModerationAction,
    db: AsyncSession = Depends(get_db),
    admin: User = Depends(get_admin_user)
):
    """Approve, reject, flag (suspend), or suspend a song."""
    # Load song with artist relationship for cache invalidation
    result = await db.execute(
        select(Song)
        .where(Song.id == action.song_id)
        .options(selectinload(Song.artist))
    )
    song = result.scalars().first()
    
    if not song:
        raise HTTPException(status_code=404, detail="Song not found")
    
    # Store artist channel name before modifying song
    artist_channel_name = song.artist.channel_name if song.artist else None
    
    if action.action == "approve":
        song.moderation_status = "approved"
    elif action.action == "reject":
        song.moderation_status = "rejected"
        # Optionally store rejection reason in a separate table
    elif action.action == "flag" or action.action == "suspend":
        song.moderation_status = "flagged"
    else:
        raise HTTPException(status_code=400, detail=f"Invalid action: {action.action}. Valid actions are: approve, reject, flag, suspend")
    
    await db.commit()
    await db.refresh(song)
    
    # Invalidate cache for this artist's channel after commit
    from .cache_decorator import invalidate_artist_cache
    if artist_channel_name:
        await invalidate_artist_cache(artist_channel_name)
    
    return {"ok": True, "song_id": song.id, "status": song.moderation_status}


@router.delete("/content/songs/{song_id}")
async def delete_song(
    song_id: int,
    db: AsyncSession = Depends(get_db),
    admin: User = Depends(get_admin_user)
):
    """Delete a song permanently."""
    result = await db.execute(select(Song).where(Song.id == song_id).options(selectinload(Song.artist)))
    song = result.scalars().first()
    
    if not song:
        raise HTTPException(status_code=404, detail="Song not found")
    
    # Store artist channel name before deletion for cache invalidation
    artist_channel_name = song.artist.channel_name if song.artist else None
    
    # Delete the song (cascade will handle related records like likes, playlist_songs)
    await db.delete(song)
    await db.commit()
    
    # Invalidate cache for this artist's channel
    from .cache_decorator import invalidate_artist_cache
    if artist_channel_name:
        await invalidate_artist_cache(artist_channel_name)
    
    return {"ok": True, "song_id": song_id, "deleted": True}


# ==================== User Management ====================

@router.get("/users")
async def get_users(
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=100),
    role: Optional[str] = Query(None),
    search: Optional[str] = Query(None),
    db: AsyncSession = Depends(get_db),
    admin: User = Depends(get_admin_user)
):
    """Get list of users with optional filters."""
    query = select(User)
    
    if role:
        query = query.where(User.user_role == role)
    
    if search:
        query = query.where(
            or_(
                User.email.ilike(f"%{search}%"),
                User.contact.ilike(f"%{search}%"),
                User.channel_name.ilike(f"%{search}%"),
                User.full_name.ilike(f"%{search}%"),
            )
        )
    
    result = await db.execute(
        query.order_by(User.created_at.desc()).offset(skip).limit(limit)
    )
    users = result.scalars().all()
    
    return [{
        "id": str(user.id),
        "contact": user.contact,
        "email": user.email,
        "channel_name": user.channel_name,
        "full_name": user.full_name,
        "is_artist": user.is_artist,
        "is_upgraded": user.is_upgraded,
        "user_role": user.user_role,
        "kyc_verified": user.kyc_verified,
        "is_suspended": user.is_suspended if hasattr(user, 'is_suspended') else False,
        "created_at": user.created_at.isoformat() if user.created_at else None,
    } for user in users]


@router.post("/users/manage")
async def manage_user(
    action: UserManagementAction,
    db: AsyncSession = Depends(get_db),
    admin: User = Depends(get_admin_user)
):
    """Suspend, activate, delete, or promote a user."""
    result = await db.execute(select(User).where(User.id == action.user_id))
    user = result.scalars().first()
    
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    if action.action == "suspend":
        if not hasattr(user, 'is_suspended'):
            # Add column if it doesn't exist (migration needed)
            raise HTTPException(status_code=500, detail="Suspension feature not available")
        user.is_suspended = True
    elif action.action == "activate":
        if hasattr(user, 'is_suspended'):
            user.is_suspended = False
    elif action.action == "delete":
        # Soft delete or hard delete based on your needs
        await db.delete(user)
    elif action.action == "promote_to_admin":
        user.is_admin = True
    else:
        raise HTTPException(status_code=400, detail="Invalid action")
    
    await db.commit()
    
    return {"ok": True, "user_id": str(user.id), "action": action.action}


# ==================== Feature Toggles ====================

@router.get("/features")
async def get_feature_toggles(
    db: AsyncSession = Depends(get_db),
    admin: User = Depends(get_admin_user)
):
    """Get current feature toggle settings."""
    # In a real system, these would be stored in a database table
    # For now, return default feature flags
    return {
        "new_user_registration": True,
        "song_uploads": True,
        "playlist_sharing": True,
        "donation_features": True,
        "rep_program": True,
        "kyc_verification": True,
    }


@router.post("/features/toggle")
async def toggle_feature(
    toggle: FeatureToggle,
    db: AsyncSession = Depends(get_db),
    admin: User = Depends(get_admin_user)
):
    """Toggle a feature on/off."""
    # In a real system, store this in a database table
    # For now, just return success
    return {"ok": True, "feature": toggle.feature_name, "enabled": toggle.enabled}


# ==================== Analytics ====================

@router.get("/analytics/upload-trends")
async def get_upload_trends(
    days: int = Query(30, ge=1, le=365),
    db: AsyncSession = Depends(get_db),
    admin: User = Depends(get_admin_user)
):
    """Get song upload trends over time."""
    cutoff_date = datetime.utcnow() - timedelta(days=days)
    
    result = await db.execute(
        select(
            func.date(Song.created_at).label('date'),
            func.count(Song.id).label('count')
        )
        .where(Song.created_at >= cutoff_date)
        .group_by(func.date(Song.created_at))
        .order_by(func.date(Song.created_at))
    )
    
    trends = result.all()
    return [{"date": str(row.date), "count": row.count} for row in trends]


@router.get("/analytics/user-growth")
async def get_user_growth(
    days: int = Query(30, ge=1, le=365),
    db: AsyncSession = Depends(get_db),
    admin: User = Depends(get_admin_user)
):
    """Get user growth trends over time."""
    cutoff_date = datetime.utcnow() - timedelta(days=days)
    
    result = await db.execute(
        select(
            func.date(User.created_at).label('date'),
            func.count(User.id).label('count')
        )
        .where(User.created_at >= cutoff_date)
        .group_by(func.date(User.created_at))
        .order_by(func.date(User.created_at))
    )
    
    growth = result.all()
    return [{"date": str(row.date), "count": row.count} for row in growth]
