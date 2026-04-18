from fastapi import APIRouter, Depends, HTTPException, Query, Header
from pydantic import BaseModel
from .auth_integration import get_current_user
from .models import User, Playlist, PlaylistSong, Song, Like, Follow
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from sqlalchemy.orm import selectinload
from typing import List, Optional
from .db import get_db
from .schemas import UpdateProfileRequest, ChangePasswordRequest, UpdateSettingsRequest, FeedbackRequest
from .password_utils import hash_password, verify_password
from .cache_decorator import cache_user_profile, get_cached_user_profile, invalidate_user_cache
from .redis_client import store_token_blacklist, delete_all_user_sessions, create_session, publish_notification
from .config import is_demo_payment_enabled

router = APIRouter(prefix="/user", tags=["user"])

class PlaylistCreate(BaseModel):
    name: str
    is_public: bool = False

class PlaylistUpdate(BaseModel):
    name: Optional[str] = None
    is_public: Optional[bool] = None
    cover_photo_url: Optional[str] = None

class PlaylistAddSong(BaseModel):
    song_id: int

class UpgradeRequest(BaseModel):
    role: str  # 'listen', 'rep', 'influencer' (Creator in product UI)
    kyc_verified: bool = False


class ArtistPlusUpgradeRequest(BaseModel):
    """NOIZE Artist+ — paid tier for channel owners (₹299 or ₹599 / month)."""
    tier: str = "standard"  # "standard" (₹299) | "pro" (₹599)
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
        "artist_plus": getattr(current_user, "artist_plus", False),
        "artist_plus_monthly_paise": getattr(current_user, "artist_plus_monthly_paise", None),
        "is_upgraded": current_user.is_upgraded,
        "user_role": current_user.user_role,
        "kyc_verified": current_user.kyc_verified,
        "referral_code": current_user.referral_code,
        "notification_settings": current_user.notification_settings or {},
        "privacy_settings": current_user.privacy_settings or {},
        "language": current_user.language or "en",
        "location": current_user.location,
        "experience_preferences": getattr(current_user, "experience_preferences", None) or {},
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
        "experience_preferences": getattr(current_user, "experience_preferences", None) or {},
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

    if req.experience_preferences is not None:
        if current_user.experience_preferences is None:
            current_user.experience_preferences = {}
        if isinstance(req.experience_preferences, dict):
            current_user.experience_preferences.update(req.experience_preferences)
        await invalidate_user_cache(str(current_user.id))
        try:
            from .redis_client import cache_delete_matching

            await cache_delete_matching(f"rec:v2:fy:{current_user.id}:")
            await cache_delete_matching(f"rec:v2:mood:{current_user.id}:")
            await cache_delete_matching("charts:v1:")
        except Exception as e:
            print(f"experience prefs cache bust failed: {e}")
    
    db.add(current_user)
    await db.commit()
    await db.refresh(current_user)
    
    return {
        "notification_settings": current_user.notification_settings or {},
        "privacy_settings": current_user.privacy_settings or {},
        "language": current_user.language or "en",
        "location": current_user.location or "",
        "experience_preferences": getattr(current_user, "experience_preferences", None) or {},
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


@router.get("/following")
async def get_following(current_user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    """Get followed artists for the current user (for 'Recently followed' UI)."""
    q = await db.execute(
        select(Follow)
        .where(Follow.user_id == current_user.id)
        .options(selectinload(Follow.artist))
        .order_by(Follow.created_at.desc())
        .limit(50)
    )
    follows = q.scalars().all()
    out = []
    for f in follows:
        a = f.artist
        if not a:
            continue
        out.append(
            {
                "id": str(a.id),
                "channel_name": a.channel_name,
                "photo_url": a.photo_url,
                "banner_url": a.banner_url,
                "is_artist": a.is_artist,
            }
        )
    return out

@router.post("/upgrade")
async def upgrade(req: UpgradeRequest, current_user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    """
    Upgrade user to specified role (listen, rep, influencer / Creator).

    **NOIZE Listen** (`role=listen`) is the core paid tier (see `/config/subscription-tiers`):
    ad-free, unlimited skips, offline access, full catalog — subscription revenue participates in
    stream-based distribution to rights holders (prototype: role flag + listen telemetry).

    **NOIZE REP** (`role=rep`) is the engagement tier after Listen: referrals, task earning, token caps,
    reward-pool-based earnings — see `/config/subscription-tiers` for limits and metadata.

    MVP: when `DEMO_PAYMENT_ENABLED` is true (default), the app uses simulated checkout; no payment processor.
    """
    import secrets
    import string

    if not is_demo_payment_enabled():
        raise HTTPException(
            status_code=403,
            detail="Demo billing is disabled. Subscription upgrades are not available until billing is configured.",
        )

    if current_user.user_role == req.role:
        return {"ok": False, "msg": f"Already on {req.role}"}

    # Vertical progression (Listen → REP is the main path after core subscription).
    _allowed_paths = {
        ("guest", "listen"),
        ("guest", "rep"),
        ("guest", "influencer"),
        ("listen", "rep"),
        ("listen", "influencer"),
        ("rep", "influencer"),
    }
    if (current_user.user_role, req.role) not in _allowed_paths:
        return {
            "ok": False,
            "msg": f"Cannot upgrade from {current_user.user_role} to {req.role}",
        }

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
    await invalidate_user_cache(str(current_user.id))

    return {
        "ok": True, 
        "is_upgraded": True,
        "user_role": current_user.user_role,
        "referral_code": current_user.referral_code,
    }


@router.post("/artist-plus")
async def upgrade_artist_plus(
    req: ArtistPlusUpgradeRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    **NOIZE Artist+** — paid add-on for channel artists (₹299–₹599/mo prototype pricing).
    Unlocks merch, events (incl. external ticket links), fan tipping, and campaigns (enforced in API + app).
    """
    if not is_demo_payment_enabled():
        raise HTTPException(
            status_code=403,
            detail="Demo billing is disabled. Artist+ signup is not available until billing is configured.",
        )
    if not current_user.is_artist:
        raise HTTPException(status_code=400, detail="Only artists with a channel can subscribe to Artist+")
    if getattr(current_user, "artist_plus", False):
        return {"ok": False, "msg": "Already on Artist+"}
    t = (req.tier or "standard").lower().strip()
    if t not in ("standard", "pro"):
        raise HTTPException(status_code=400, detail="tier must be standard or pro")
    paise = 29900 if t == "standard" else 59900
    current_user.artist_plus = True
    current_user.artist_plus_monthly_paise = paise
    if req.kyc_verified:
        current_user.kyc_verified = True
    current_user.is_upgraded = True
    db.add(current_user)
    await db.commit()
    await db.refresh(current_user)
    await invalidate_user_cache(str(current_user.id))
    return {
        "ok": True,
        "artist_plus": True,
        "artist_plus_monthly_paise": paise,
        "tier": t,
    }


# Playlist endpoints
@router.get("/playlists")
async def get_playlists(current_user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    """Get all playlists for the current user"""
    try:
        # Use raw SQL to avoid SQLAlchemy metadata cache issues with cover_photo_url
        from sqlalchemy import text
        result = await db.execute(
            text("""
                SELECT id, user_id, name, is_public, created_at
                FROM playlists
                WHERE user_id = :user_id
                ORDER BY created_at DESC
            """),
            {"user_id": str(current_user.id)}
        )
        playlists = result.fetchall()
        
        playlist_results = []
        for row in playlists:
            playlist_id = str(row[0])
            playlist_name = row[2]
            is_public = row[3]
            
            # Get songs for this playlist
            try:
                songs_result = await db.execute(
                    text("""
                        SELECT s.id, s.title, s.album, s.r2_key, s.moderation_status, s.cover_photo_url, s.content_type,
                               u.channel_name as artist
                        FROM playlist_songs ps
                        JOIN songs s ON ps.song_id = s.id
                        LEFT JOIN users u ON s.artist_id = u.id
                        WHERE ps.playlist_id = :playlist_id
                        AND (s.moderation_status IS NULL OR s.moderation_status != 'rejected')
                        ORDER BY ps.created_at ASC
                    """),
                    {"playlist_id": playlist_id}
                )
                songs_rows = songs_result.fetchall()
                songs_data = [{
                    "id": song_row[0],
                    "title": song_row[1],
                    "album": song_row[2],
                    "r2_key": song_row[3],
                    "moderation_status": song_row[4],
                    "cover_photo_url": song_row[5],
                    "content_type": song_row[6],
                    "artist": song_row[7],
                } for song_row in songs_rows]
            except Exception:
                # If songs query fails, just return empty songs list
                songs_data = []
            
            playlist_results.append({
                "id": playlist_id,
                "name": playlist_name,
                "song_count": len(songs_data),
                "songs": songs_data,
                "is_public": is_public,
                "cover_photo_url": None,  # Set to None since backend can't see the column
            })
        
        return playlist_results
    except Exception as e:
        import traceback
        print(f"Error loading playlists: {e}")
        traceback.print_exc()
        await db.rollback()
        # Return empty list on error
        return []

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
    try:
        # Only upgraded users can create public playlists
        if req.is_public and not current_user.is_upgraded:
            raise HTTPException(status_code=403, detail="Upgrade required to create public playlists")
        
        # Use raw SQL to bypass SQLAlchemy metadata cache issues
        from sqlalchemy import text
        is_public_value = req.is_public if current_user.is_upgraded else False
        
        # Try inserting without cover_photo_url first (since backend container can't see it)
        # We'll add it back once the schema sync issue is resolved
        result = await db.execute(
            text("""
                INSERT INTO playlists (id, user_id, name, is_public, created_at)
                VALUES (gen_random_uuid(), :user_id, :name, :is_public, NOW())
                RETURNING id, name, is_public
            """),
            {
                "user_id": str(current_user.id), 
                "name": req.name, 
                "is_public": is_public_value
            }
        )
        row = result.fetchone()
        await db.commit()
        
        return {
            "ok": True,
            "playlist_id": str(row[0]),
            "name": row[1],
            "is_public": row[2],
            "cover_photo_url": None
        }
    except Exception as e:
        import traceback
        error_msg = str(e)
        print(f"Error creating playlist: {error_msg}")
        traceback.print_exc()
        await db.rollback()
        raise HTTPException(status_code=500, detail=f"Failed to create playlist: {error_msg}")

@router.post("/playlist/{playlist_id}/add")
async def add_to_playlist(playlist_id: str, req: PlaylistAddSong, current_user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    """Add a song to a playlist"""
    try:
        # Verify playlist exists and belongs to user
        from sqlalchemy import text
        playlist_check = await db.execute(
            text("SELECT id, user_id FROM playlists WHERE id = :playlist_id AND user_id = :user_id"),
            {"playlist_id": playlist_id, "user_id": str(current_user.id)}
        )
        playlist_row = playlist_check.fetchone()
        if not playlist_row:
            raise HTTPException(status_code=404, detail="Playlist not found")
        
        # Check if song exists
        song_check = await db.execute(
            text("SELECT id FROM songs WHERE id = :song_id"),
            {"song_id": req.song_id}
        )
        song_row = song_check.fetchone()
        if not song_row:
            raise HTTPException(status_code=404, detail="Song not found")
        
        # Check if already in playlist
        exists_check = await db.execute(
            text("SELECT id FROM playlist_songs WHERE playlist_id = :playlist_id AND song_id = :song_id"),
            {"playlist_id": playlist_id, "song_id": req.song_id}
        )
        if exists_check.fetchone():
            return {"ok": True, "added": False, "msg": "Already in playlist"}
        
        # Add song to playlist using raw SQL
        await db.execute(
            text("""
                INSERT INTO playlist_songs (playlist_id, song_id, created_at)
                VALUES (:playlist_id, :song_id, NOW())
            """),
            {"playlist_id": playlist_id, "song_id": req.song_id}
        )
        await db.commit()
        return {"ok": True, "added": True}
    except HTTPException:
        raise
    except Exception as e:
        import traceback
        error_msg = str(e)
        print(f"Error adding song to playlist: {error_msg}")
        traceback.print_exc()
        await db.rollback()
        raise HTTPException(status_code=500, detail=f"Failed to add song to playlist: {error_msg}")

@router.get("/playlist/{playlist_id}")
async def get_playlist(playlist_id: str, current_user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    """Get a single playlist by ID"""
    try:
        # Use raw SQL to avoid SQLAlchemy metadata cache issues
        from sqlalchemy import text
        
        # Get playlist info
        playlist_result = await db.execute(
            text("""
                SELECT id, user_id, name, is_public, created_at
                FROM playlists
                WHERE id = :playlist_id
            """),
            {"playlist_id": playlist_id}
        )
        playlist_row = playlist_result.fetchone()
        if not playlist_row:
            raise HTTPException(status_code=404, detail="Playlist not found")
        
        playlist_id_val = str(playlist_row[0])
        user_id = str(playlist_row[1])
        playlist_name = playlist_row[2]
        is_public = playlist_row[3]
        created_at = playlist_row[4]
        
        # Check if user has access (owner or public)
        if user_id != str(current_user.id) and not is_public:
            raise HTTPException(status_code=403, detail="Access denied")
        
        # Get songs for this playlist
        try:
            songs_result = await db.execute(
                text("""
                    SELECT s.id, s.title, s.album, s.r2_key, s.moderation_status, s.cover_photo_url, s.duration, s.content_type,
                           u.channel_name as artist
                    FROM playlist_songs ps
                    JOIN songs s ON ps.song_id = s.id
                    LEFT JOIN users u ON s.artist_id = u.id
                    WHERE ps.playlist_id = :playlist_id
                    AND (s.moderation_status IS NULL OR s.moderation_status != 'rejected')
                    ORDER BY ps.created_at ASC
                """),
                {"playlist_id": playlist_id}
            )
            songs_rows = songs_result.fetchall()
            songs_data = [{
                "id": song_row[0],
                "title": song_row[1],
                "album": song_row[2],
                "r2_key": song_row[3],
                "moderation_status": song_row[4],
                "cover_photo_url": song_row[5],
                "duration": song_row[6],
                "content_type": song_row[7],
                "artist": song_row[8],
            } for song_row in songs_rows]
        except Exception as songs_error:
            # If songs query fails (e.g., songs table doesn't exist), return empty songs
            print(f"Error loading songs for playlist: {songs_error}")
            songs_data = []
        
        return {
            "id": playlist_id_val,
            "name": playlist_name,
            "song_count": len(songs_data),
            "songs": songs_data,
            "is_public": is_public,
            "cover_photo_url": None,  # Set to None since backend can't see the column
            "created_at": created_at.isoformat() if hasattr(created_at, 'isoformat') else str(created_at),
            "is_owner": user_id == str(current_user.id),
        }
    except HTTPException:
        raise
    except Exception as e:
        import traceback
        error_msg = str(e)
        print(f"Error loading playlist: {error_msg}")
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=f"Failed to load playlist: {error_msg}")

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
    if req.cover_photo_url is not None:
        playlist.cover_photo_url = req.cover_photo_url
    
    await db.commit()
    await db.refresh(playlist)
    
    return {
        "ok": True,
        "playlist_id": str(playlist.id),
        "name": playlist.name,
        "is_public": playlist.is_public,
        "cover_photo_url": playlist.cover_photo_url,
    }

@router.delete("/playlist/{playlist_id}")
async def delete_playlist(playlist_id: str, current_user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    """Delete a playlist"""
    print(f"🗑️ Delete playlist request - playlist_id: {playlist_id}, user_id: {current_user.id}")
    
    # Convert playlist_id string to UUID if needed
    import uuid
    try:
        playlist_uuid = uuid.UUID(playlist_id)
    except ValueError as e:
        print(f"❌ Invalid playlist ID format: {playlist_id}, error: {e}")
        raise HTTPException(status_code=400, detail="Invalid playlist ID format")
    
    # Verify playlist exists and belongs to current user
    q = await db.execute(select(Playlist).where(Playlist.id == playlist_uuid, Playlist.user_id == current_user.id))
    playlist = q.scalars().first()
    if not playlist:
        # Check if playlist exists but belongs to different user
        q_all = await db.execute(select(Playlist).where(Playlist.id == playlist_uuid))
        playlist_exists = q_all.scalars().first()
        if playlist_exists:
            print(f"❌ Playlist {playlist_id} exists but belongs to user {playlist_exists.user_id}, not {current_user.id}")
            raise HTTPException(status_code=403, detail="Access denied: Playlist does not belong to you")
        else:
            print(f"❌ Playlist {playlist_id} not found in database")
            raise HTTPException(status_code=404, detail="Playlist not found")
    
    print(f"✅ Found playlist: {playlist.name}, deleting...")
    
    # Delete the playlist (cascade will handle PlaylistSong records)
    from sqlalchemy import delete
    await db.execute(delete(Playlist).where(Playlist.id == playlist_uuid, Playlist.user_id == current_user.id))
    await db.commit()
    
    print(f"✅ Playlist {playlist_id} deleted successfully")
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

@router.get("/songs/search")
async def search_songs(
    q: str = Query(..., description="Search query"),
    limit: int = Query(50, ge=1, le=100),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Search for songs by title, album, or artist name"""
    if not q or not q.strip():
        return []
    
    from sqlalchemy import or_
    query = (
        select(Song)
        .options(selectinload(Song.artist))
        .where(
            or_(
                Song.moderation_status == None,
                Song.moderation_status == 'approved'
            )
        )
    )
    
    search_term = f"%{q.strip()}%"
    query = query.join(User, Song.artist_id == User.id).where(
        or_(
            Song.title.ilike(search_term),
            Song.album.ilike(search_term),
            User.channel_name.ilike(search_term)
        )
    )
    
    result = await db.execute(query.limit(limit))
    songs = result.scalars().all()
    
    return [{
        "id": song.id,
        "title": song.title,
        "album": song.album,
        "artist": song.artist.channel_name if song.artist else None,
        "r2_key": song.r2_key,
        "cover_photo_url": song.cover_photo_url,
        "duration": song.duration,
        "moderation_status": song.moderation_status,
    } for song in songs]
