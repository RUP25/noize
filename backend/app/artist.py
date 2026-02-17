# backend/app/artist.py
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, delete
from sqlalchemy.orm import selectinload
from typing import List
from .db import get_db
from .models import User, Song, Follow, Like, Playlist, PlaylistSong
from .schemas import SongCreate, SongOut, UserOut, CreateChannelRequest
from .auth_integration import get_current_user
from .cache_decorator import cache_artist_info, get_cached_artist_info, invalidate_artist_cache
from .redis_client import publish_notification

router = APIRouter(prefix="/artist", tags=["artist"])

@router.get("/search")
async def search_artist(q: str, db: AsyncSession = Depends(get_db)):
    if not q or not q.strip():
        return []
    like = f"%{q.strip()}%"
    qres = await db.execute(
        select(User).where(User.channel_name.ilike(like)).limit(20)
    )
    users = qres.scalars().all()
    return [u.channel_name for u in users if u.channel_name]

@router.post("/create", response_model=UserOut)
async def create_channel(payload: CreateChannelRequest, current_user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    if current_user.channel_name:
        raise HTTPException(status_code=400, detail="Already has a channel")
    q = await db.execute(select(User).where(User.channel_name == payload.channel_name))
    exists = q.scalars().first()
    if exists:
        raise HTTPException(status_code=400, detail="Channel name taken")
    current_user.channel_name = payload.channel_name
    current_user.is_artist = True
    db.add(current_user)
    await db.commit()
    await db.refresh(current_user)
    return current_user

@router.post("/metadata", response_model=SongOut)
async def register_song_metadata(payload: SongCreate, current_user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    if not current_user.is_artist:
        raise HTTPException(status_code=403, detail="Only artists can register songs. Create a channel first.")
    if not payload.r2_key.startswith(f"uploads/{current_user.contact}/"):
        raise HTTPException(status_code=400, detail="r2_key ownership mismatch")
    song = Song(
        title=payload.title,
        album=payload.album,
        r2_key=payload.r2_key,
        content_type=payload.content_type,
        duration=payload.duration,
        cover_photo_url=payload.cover_photo_url,
        artist_id=current_user.id
    )
    db.add(song)
    await db.commit()
    await db.refresh(song)
    await db.refresh(current_user)
    
    # Invalidate artist cache when new song is added
    if current_user.channel_name:
        await invalidate_artist_cache(current_user.channel_name)
    
    # Notify followers of new song
    await publish_notification(
        f"notifications:artist:{current_user.channel_name}",
        {
            "type": "new_song",
            "artist": current_user.channel_name,
            "song_id": song.id,
            "song_title": song.title,
            "timestamp": str(song.created_at)
        }
    )
    
    return song

@router.get("/{channel_name}", response_model=List[SongOut])
async def get_artist_channel(channel_name: str, db: AsyncSession = Depends(get_db)):
    """Get artist channel with caching."""
    # Try cache first, but only use it if songs have moderation_status field
    # (to avoid using old cached data without moderation_status)
    cached_data = await get_cached_artist_info(channel_name)
    if cached_data and "songs" in cached_data:
        # Check if cached songs have moderation_status field (to avoid old cache)
        cached_songs = cached_data["songs"]
        if cached_songs and len(cached_songs) > 0:
            # Check if first song has moderation_status field
            if isinstance(cached_songs[0], dict) and "moderation_status" in cached_songs[0]:
                return cached_songs
            # If cached data doesn't have moderation_status, invalidate and refetch
            from .cache_decorator import invalidate_artist_cache
            await invalidate_artist_cache(channel_name)
    
    q = await db.execute(select(User).where(User.channel_name == channel_name))
    artist = q.scalars().first()
    if not artist:
        raise HTTPException(status_code=404, detail="Artist not found")
    
    # Use selectinload to eagerly load the artist relationship
    # Filter out rejected songs, but include flagged (suspended) songs so listeners can see the message
    from sqlalchemy import or_
    qq = await db.execute(
        select(Song)
        .where(
            Song.artist_id == artist.id,
            or_(
                Song.moderation_status == None,  # Pending/approved songs
                Song.moderation_status == 'approved',  # Explicitly approved
                Song.moderation_status == 'flagged'  # Suspended - show message to listeners
            )
        )
        .options(selectinload(Song.artist))
        .order_by(Song.created_at.desc())
    )
    songs = qq.scalars().all()
    
    # Manually convert to ensure UUID is converted to string
    from .schemas import SongOut
    songs_out = []
    for song in songs:
        song_dict = {
            "id": song.id,
            "title": song.title,
            "album": song.album,
            "r2_key": song.r2_key,
            "content_type": song.content_type,
            "duration": song.duration,
            "cover_photo_url": song.cover_photo_url,
            "created_at": song.created_at,
            "moderation_status": song.moderation_status,
            "artist": {
                "id": str(song.artist.id),  # Convert UUID to string
                "contact": song.artist.contact,
                "email": song.artist.email,
                "is_artist": song.artist.is_artist,
                "channel_name": song.artist.channel_name,
                "banner_url": song.artist.banner_url,
                "photo_url": song.artist.photo_url,
                "is_upgraded": song.artist.is_upgraded,
                "created_at": song.artist.created_at,
            }
        }
        songs_out.append(SongOut(**song_dict))
    
    # Cache the result (1 hour) - cache the dict representation
    await cache_artist_info(channel_name, {"songs": [s.dict() for s in songs_out]}, expiry_seconds=3600)
    
    return songs_out

@router.post("/{channel_name}/follow")
async def follow_channel(channel_name: str, current_user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    q = await db.execute(select(User).where(User.channel_name == channel_name))
    artist = q.scalars().first()
    if not artist:
        raise HTTPException(status_code=404, detail="Artist not found")
    if artist.id == current_user.id:
        raise HTTPException(status_code=400, detail="Cannot follow yourself")
    q2 = await db.execute(select(Follow).where(Follow.user_id == current_user.id, Follow.artist_id == artist.id))
    exists = q2.scalars().first()
    if exists:
        await db.execute(delete(Follow).where(Follow.id == exists.id))
        await db.commit()
        return {"ok": True, "following": False}
    follow = Follow(user_id=current_user.id, artist_id=artist.id)
    db.add(follow)
    await db.commit()
    
    # Notify artist of new follower
    await publish_notification(
        f"notifications:artist:{channel_name}",
        {
            "type": "new_follower",
            "follower_id": str(current_user.id),
            "follower_contact": current_user.contact,
            "timestamp": str(follow.created_at) if hasattr(follow, 'created_at') else ""
        }
    )
    
    return {"ok": True, "following": True}

@router.post("/song/{song_id}/like")
async def like_song(song_id: int, current_user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    q = await db.execute(select(Song).where(Song.id == song_id))
    song = q.scalars().first()
    if not song:
        raise HTTPException(status_code=404, detail="Song not found")
    q2 = await db.execute(select(Like).where(Like.user_id == current_user.id, Like.song_id == song_id))
    exists = q2.scalars().first()
    if exists:
        await db.execute(delete(Like).where(Like.id == exists.id))
        await db.commit()
        return {"ok": True, "liked": False}
    like = Like(user_id=current_user.id, song_id=song_id)
    db.add(like)
    await db.commit()
    return {"ok": True, "liked": True}

@router.post("/playlist/create")
async def create_playlist(name: str = "My Playlist", current_user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    p = Playlist(user_id=current_user.id, name=name)
    db.add(p)
    await db.commit()
    await db.refresh(p)
    return {"ok": True, "playlist_id": p.id, "name": p.name}

@router.post("/playlist/{playlist_id}/add")
async def add_to_playlist(playlist_id: int, song_id: int, current_user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    q = await db.execute(select(Playlist).where(Playlist.id == playlist_id, Playlist.user_id == current_user.id))
    playlist = q.scalars().first()
    if not playlist:
        raise HTTPException(status_code=404, detail="Playlist not found")
    q2 = await db.execute(select(PlaylistSong).where(PlaylistSong.playlist_id == playlist_id, PlaylistSong.song_id == song_id))
    exists = q2.scalars().first()
    if exists:
        return {"ok": True, "added": False, "msg": "Already in playlist"}
    ps = PlaylistSong(playlist_id=playlist_id, song_id=song_id)
    db.add(ps)
    await db.commit()
    return {"ok": True, "added": True}
