# backend/app/artist.py
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, delete, func
from sqlalchemy.orm import selectinload
from typing import List, Optional
from .db import get_db
from .models import User, Song, Follow, Like, Dislike, ListenEvent, Playlist, PlaylistSong, Merchandise, Event
from .schemas import SongCreate, SongOut, SongUpdate, UserOut, CreateChannelRequest, MerchandiseOut, EventOut, MerchandiseCreate, EventCreate, MerchandiseUpdate, EventUpdate
from .auth_integration import get_current_user
from .cache_decorator import cache_artist_info, get_cached_artist_info, invalidate_artist_cache


async def _invalidate_engagement_caches(artist_channel_name: Optional[str], listener_user_id) -> None:
    """Invalidate recommendation/chart caches and artist channel cache after like/dislike."""
    try:
        await cache_delete_matching(f"rec:v2:fy:{listener_user_id}:")
        await cache_delete_matching(f"rec:v2:mood:{listener_user_id}:")
        await cache_delete_matching("rec:v2:t:")
        await cache_delete_matching("charts:v1:")
    except Exception as e:
        print(f"rec/charts cache invalidate: {e}")
    if artist_channel_name:
        await invalidate_artist_cache(artist_channel_name)
from .redis_client import publish_notification, cache_delete_matching
from .hls_tasks import generate_hls_for_key

router = APIRouter(prefix="/artist", tags=["artist"])


def _require_artist_plus(user: User) -> None:
    """Merch, events, and related monetisation require NOIZE Artist+."""
    if not user.is_artist:
        raise HTTPException(status_code=403, detail="Only artists can use this feature")
    if not getattr(user, "artist_plus", False):
        raise HTTPException(
            status_code=403,
            detail="Artist+ subscription required for merchandise, events, tipping, and campaigns.",
        )

@router.get("/popular")
async def popular_artists(db: AsyncSession = Depends(get_db), limit: int = 20):
    """Return popular artists ordered by follower count (and song count as tiebreak)."""
    limit = max(1, min(int(limit or 20), 50))

    followers_subq = (
        select(Follow.artist_id.label("artist_id"), func.count(Follow.id).label("followers_count"))
        .group_by(Follow.artist_id)
        .subquery()
    )

    songs_subq = (
        select(Song.artist_id.label("artist_id"), func.count(Song.id).label("songs_count"))
        .group_by(Song.artist_id)
        .subquery()
    )

    q = await db.execute(
        select(
            User,
            func.coalesce(followers_subq.c.followers_count, 0).label("followers_count"),
            func.coalesce(songs_subq.c.songs_count, 0).label("songs_count"),
        )
        .where(User.is_artist == True, User.channel_name != None)
        .outerjoin(followers_subq, followers_subq.c.artist_id == User.id)
        .outerjoin(songs_subq, songs_subq.c.artist_id == User.id)
        .order_by(
            func.coalesce(followers_subq.c.followers_count, 0).desc(),
            func.coalesce(songs_subq.c.songs_count, 0).desc(),
            User.created_at.desc(),
        )
        .limit(limit)
    )
    rows = q.all()
    out = []
    for (u, followers_count, songs_count) in rows:
        out.append(
            {
                "id": str(u.id),
                "channel_name": u.channel_name,
                "photo_url": u.photo_url,
                "banner_url": u.banner_url,
                "followers_count": int(followers_count or 0),
                "songs_count": int(songs_count or 0),
            }
        )
    return out


@router.get("/me/stats")
async def artist_my_engagement_stats(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Aggregated streams (listens), likes, dislikes, and subscribers for the signed-in artist."""
    if not current_user.is_artist or not current_user.channel_name:
        raise HTTPException(status_code=403, detail="Artist channel required")

    qf = await db.execute(select(func.count(Follow.id)).where(Follow.artist_id == current_user.id))
    followers = int(qf.scalar() or 0)

    qs = await db.execute(select(Song.id).where(Song.artist_id == current_user.id))
    song_ids = [row[0] for row in qs.all()]

    total_listens = 0
    total_likes = 0
    total_dislikes = 0
    if song_ids:
        ql = await db.execute(
            select(func.count(ListenEvent.id)).where(ListenEvent.song_id.in_(song_ids))
        )
        total_listens = int(ql.scalar() or 0)
        qk = await db.execute(select(func.count(Like.id)).where(Like.song_id.in_(song_ids)))
        total_likes = int(qk.scalar() or 0)
        qd = await db.execute(select(func.count(Dislike.id)).where(Dislike.song_id.in_(song_ids)))
        total_dislikes = int(qd.scalar() or 0)

    return {
        "streams": total_listens,
        "likes": total_likes,
        "dislikes": total_dislikes,
        "subs": followers,
    }


@router.get("/search")
async def search_artist(q: str, db: AsyncSession = Depends(get_db)):
    if not q or not q.strip():
        return []
    like = f"%{q.strip()}%"
    qres = await db.execute(
        select(User).where(User.channel_name.ilike(like)).limit(20)
    )
    users = qres.scalars().all()
    # Return enough metadata for clients to render avatars in search results.
    # (Older clients expected a list of strings; those clients should be updated to handle objects.)
    return [
        {
            "channel_name": u.channel_name,
            "photo_url": u.photo_url,
            "banner_url": u.banner_url,
        }
        for u in users
        if u.channel_name
    ]

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
        lyrics=payload.lyrics,
        genre=payload.genre.strip() if payload.genre else None,
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

    # Enqueue background HLS generation job (best-effort)
    try:
        generate_hls_for_key.send(song.r2_key)
    except Exception as e:
        # Log but don't block metadata registration on job enqueue failure
        print(f"Failed to enqueue HLS job for {song.r2_key}: {e}")
    
    return song

@router.get("/{channel_name}", response_model=List[SongOut])
async def get_artist_channel(channel_name: str, db: AsyncSession = Depends(get_db)):
    """Get artist channel with caching."""
    # Try cache first, but only use it if songs have required fields
    # (to avoid using old cached data without moderation_status or lyrics)
    cached_data = await get_cached_artist_info(channel_name)
    if cached_data and "songs" in cached_data:
        # Check if cached songs have required fields (to avoid old cache)
        cached_songs = cached_data["songs"]
        if cached_songs and len(cached_songs) > 0:
            # Check if first song has moderation_status field (lyrics is optional, so we don't require it)
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

    song_ids = [s.id for s in songs]
    like_map: dict = {}
    dislike_map: dict = {}
    if song_ids:
        lr = await db.execute(
            select(Like.song_id, func.count(Like.id))
            .where(Like.song_id.in_(song_ids))
            .group_by(Like.song_id)
        )
        like_map = {row[0]: int(row[1]) for row in lr.all()}
        dr = await db.execute(
            select(Dislike.song_id, func.count(Dislike.id))
            .where(Dislike.song_id.in_(song_ids))
            .group_by(Dislike.song_id)
        )
        dislike_map = {row[0]: int(row[1]) for row in dr.all()}

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
            "lyrics": song.lyrics,
            "genre": getattr(song, "genre", None),
            "created_at": song.created_at,
            "moderation_status": song.moderation_status,
            "like_count": like_map.get(song.id, 0),
            "dislike_count": dislike_map.get(song.id, 0),
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

@router.get("/{channel_name}/merchandise", response_model=List[MerchandiseOut])
async def get_artist_merchandise(channel_name: str, db: AsyncSession = Depends(get_db)):
    """Get artist merchandise items."""
    q = await db.execute(select(User).where(User.channel_name == channel_name))
    artist = q.scalars().first()
    if not artist:
        raise HTTPException(status_code=404, detail="Artist not found")
    
    # Query merchandise for this artist
    merch_query = await db.execute(
        select(Merchandise)
        .where(Merchandise.artist_id == artist.id)
        .order_by(Merchandise.created_at.desc())
    )
    merchandise = merch_query.scalars().all()
    
    return merchandise

@router.get("/{channel_name}/events", response_model=List[EventOut])
async def get_artist_events(channel_name: str, db: AsyncSession = Depends(get_db)):
    """Get artist events."""
    q = await db.execute(select(User).where(User.channel_name == channel_name))
    artist = q.scalars().first()
    if not artist:
        raise HTTPException(status_code=404, detail="Artist not found")
    
    # Query events for this artist, ordered by date and time
    events_query = await db.execute(
        select(Event)
        .where(Event.artist_id == artist.id)
        .order_by(Event.date.asc(), Event.time.asc())
    )
    events = events_query.scalars().all()
    
    return events

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
    q = await db.execute(select(Song).where(Song.id == song_id).options(selectinload(Song.artist)))
    song = q.scalars().first()
    if not song:
        raise HTTPException(status_code=404, detail="Song not found")
    ch = song.artist.channel_name if song.artist else None
    q2 = await db.execute(select(Like).where(Like.user_id == current_user.id, Like.song_id == song_id))
    exists = q2.scalars().first()
    if exists:
        await db.execute(delete(Like).where(Like.id == exists.id))
        await db.commit()
        await _invalidate_engagement_caches(ch, current_user.id)
        return {"ok": True, "liked": False}
    qd = await db.execute(select(Dislike).where(Dislike.user_id == current_user.id, Dislike.song_id == song_id))
    dis = qd.scalars().first()
    if dis:
        await db.execute(delete(Dislike).where(Dislike.id == dis.id))
    like = Like(user_id=current_user.id, song_id=song_id)
    db.add(like)
    await db.commit()
    await _invalidate_engagement_caches(ch, current_user.id)
    return {"ok": True, "liked": True}


@router.post("/song/{song_id}/dislike")
async def dislike_song(song_id: int, current_user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    q = await db.execute(select(Song).where(Song.id == song_id).options(selectinload(Song.artist)))
    song = q.scalars().first()
    if not song:
        raise HTTPException(status_code=404, detail="Song not found")
    ch = song.artist.channel_name if song.artist else None
    q2 = await db.execute(select(Dislike).where(Dislike.user_id == current_user.id, Dislike.song_id == song_id))
    exists = q2.scalars().first()
    if exists:
        await db.execute(delete(Dislike).where(Dislike.id == exists.id))
        await db.commit()
        await _invalidate_engagement_caches(ch, current_user.id)
        return {"ok": True, "disliked": False}
    ql = await db.execute(select(Like).where(Like.user_id == current_user.id, Like.song_id == song_id))
    lk = ql.scalars().first()
    if lk:
        await db.execute(delete(Like).where(Like.id == lk.id))
    db.add(Dislike(user_id=current_user.id, song_id=song_id))
    await db.commit()
    await _invalidate_engagement_caches(ch, current_user.id)
    return {"ok": True, "disliked": True}

@router.put("/song/{song_id}", response_model=SongOut)
async def update_song(
    song_id: int,
    update_data: SongUpdate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Update a song's metadata (title, album, cover photo). Only the song owner can update it."""
    if not current_user.is_artist:
        raise HTTPException(status_code=403, detail="Only artists can update songs")
    
    result = await db.execute(
        select(Song).where(Song.id == song_id).options(selectinload(Song.artist))
    )
    song = result.scalars().first()
    
    if not song:
        raise HTTPException(status_code=404, detail="Song not found")
    
    # Verify ownership
    if song.artist_id != current_user.id:
        raise HTTPException(status_code=403, detail="You can only update your own songs")
    
    # Update fields if provided
    if update_data.title is not None:
        song.title = update_data.title
    if update_data.album is not None:
        song.album = update_data.album
    if update_data.cover_photo_url is not None:
        song.cover_photo_url = update_data.cover_photo_url
    if update_data.lyrics is not None:
        song.lyrics = update_data.lyrics
    if update_data.genre is not None:
        song.genre = update_data.genre.strip() if update_data.genre else None
    
    await db.commit()
    await db.refresh(song)
    
    # Invalidate cache for this artist's channel
    if current_user.channel_name:
        await invalidate_artist_cache(current_user.channel_name)
    
    lc = await db.execute(select(func.count(Like.id)).where(Like.song_id == song_id))
    dc = await db.execute(select(func.count(Dislike.id)).where(Dislike.song_id == song_id))
    # Convert to SongOut format
    song_dict = {
        "id": song.id,
        "title": song.title,
        "album": song.album,
        "r2_key": song.r2_key,
        "content_type": song.content_type,
        "duration": song.duration,
        "cover_photo_url": song.cover_photo_url,
        "lyrics": song.lyrics,
        "genre": getattr(song, "genre", None),
        "created_at": song.created_at,
        "moderation_status": song.moderation_status,
        "like_count": int(lc.scalar() or 0),
        "dislike_count": int(dc.scalar() or 0),
        "artist": {
            "id": str(song.artist.id),
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
    return SongOut(**song_dict)

@router.delete("/song/{song_id}")
async def delete_song(
    song_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Delete a song. Only the song owner can delete it."""
    if not current_user.is_artist:
        raise HTTPException(status_code=403, detail="Only artists can delete songs")
    
    result = await db.execute(
        select(Song).where(Song.id == song_id).options(selectinload(Song.artist))
    )
    song = result.scalars().first()
    
    if not song:
        raise HTTPException(status_code=404, detail="Song not found")
    
    # Verify ownership
    if song.artist_id != current_user.id:
        raise HTTPException(status_code=403, detail="You can only delete your own songs")
    
    # Store channel name for cache invalidation
    artist_channel_name = song.artist.channel_name if song.artist else None
    
    # Delete the song (cascade will handle related records like likes, playlist_songs)
    await db.execute(delete(Song).where(Song.id == song_id))
    await db.commit()
    
    # Invalidate cache for this artist's channel
    if artist_channel_name:
        await invalidate_artist_cache(artist_channel_name)
    
    return {"ok": True, "song_id": song_id, "deleted": True}

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


# ==================== Artist Merchandise Endpoints ====================

@router.post("/merchandise", response_model=MerchandiseOut)
async def create_merchandise(
    merch: MerchandiseCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Create a new merchandise item for the current artist."""
    if not current_user.is_artist:
        raise HTTPException(status_code=403, detail="Only artists can create merchandise")
    _require_artist_plus(current_user)

    # Create merchandise item
    merchandise = Merchandise(
        title=merch.title,
        description=merch.description,
        price=merch.price,
        image_url=merch.image_url,
        purchase_link=merch.purchase_link,
        category=merch.category,
        stock=merch.stock,
        artist_id=current_user.id
    )
    
    db.add(merchandise)
    await db.commit()
    await db.refresh(merchandise)
    
    return merchandise


@router.put("/merchandise/{merch_id}", response_model=MerchandiseOut)
async def update_merchandise(
    merch_id: int,
    update_data: MerchandiseUpdate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Update a merchandise item. Only the owner can update it."""
    if not current_user.is_artist:
        raise HTTPException(status_code=403, detail="Only artists can update merchandise")
    _require_artist_plus(current_user)

    # Get the merchandise item
    result = await db.execute(select(Merchandise).where(Merchandise.id == merch_id))
    merchandise = result.scalars().first()
    
    if not merchandise:
        raise HTTPException(status_code=404, detail="Merchandise not found")
    
    # Verify ownership
    if merchandise.artist_id != current_user.id:
        raise HTTPException(status_code=403, detail="You can only update your own merchandise")
    
    # Update fields
    update_dict = update_data.dict(exclude_unset=True)
    for field, value in update_dict.items():
        setattr(merchandise, field, value)
    
    await db.commit()
    await db.refresh(merchandise)
    
    return merchandise


@router.delete("/merchandise/{merch_id}")
async def delete_merchandise(
    merch_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Delete a merchandise item. Only the owner can delete it."""
    if not current_user.is_artist:
        raise HTTPException(status_code=403, detail="Only artists can delete merchandise")
    _require_artist_plus(current_user)

    # Get the merchandise item
    result = await db.execute(select(Merchandise).where(Merchandise.id == merch_id))
    merchandise = result.scalars().first()
    
    if not merchandise:
        raise HTTPException(status_code=404, detail="Merchandise not found")
    
    # Verify ownership
    if merchandise.artist_id != current_user.id:
        raise HTTPException(status_code=403, detail="You can only delete your own merchandise")
    
    # Delete the merchandise
    await db.execute(delete(Merchandise).where(Merchandise.id == merch_id))
    await db.commit()
    
    return {"ok": True, "merch_id": merch_id, "deleted": True}


# ==================== Artist Event Endpoints ====================

@router.post("/events", response_model=EventOut)
async def create_event(
    event: EventCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Create a new event for the current artist."""
    if not current_user.is_artist:
        raise HTTPException(status_code=403, detail="Only artists can create events")
    _require_artist_plus(current_user)

    # Convert time string to Time object
    from datetime import time as time_class
    time_parts = event.time.split(':')
    event_time = time_class(int(time_parts[0]), int(time_parts[1]) if len(time_parts) > 1 else 0)
    
    # Create event
    new_event = Event(
        title=event.title,
        description=event.description,
        date=event.date,
        time=event_time,
        location=event.location,
        ticket_price=event.ticket_price,
        ticket_link=getattr(event, "ticket_link", None),
        artist_id=current_user.id
    )
    
    db.add(new_event)
    await db.commit()
    await db.refresh(new_event)
    
    return new_event


@router.put("/events/{event_id}", response_model=EventOut)
async def update_event(
    event_id: int,
    update_data: EventUpdate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Update an event. Only the owner can update it."""
    if not current_user.is_artist:
        raise HTTPException(status_code=403, detail="Only artists can update events")
    _require_artist_plus(current_user)

    # Get the event
    result = await db.execute(select(Event).where(Event.id == event_id))
    event = result.scalars().first()
    
    if not event:
        raise HTTPException(status_code=404, detail="Event not found")
    
    # Verify ownership
    if event.artist_id != current_user.id:
        raise HTTPException(status_code=403, detail="You can only update your own events")
    
    # Update fields
    update_dict = update_data.dict(exclude_unset=True)
    
    # Handle time conversion if time is being updated
    if 'time' in update_dict and update_dict['time']:
        from datetime import time as time_class
        time_parts = update_dict['time'].split(':')
        update_dict['time'] = time_class(int(time_parts[0]), int(time_parts[1]) if len(time_parts) > 1 else 0)
    
    for field, value in update_dict.items():
        setattr(event, field, value)
    
    await db.commit()
    await db.refresh(event)
    
    return event


@router.delete("/events/{event_id}")
async def delete_event(
    event_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Delete an event. Only the owner can delete it."""
    if not current_user.is_artist:
        raise HTTPException(status_code=403, detail="Only artists can delete events")
    _require_artist_plus(current_user)

    # Get the event
    result = await db.execute(select(Event).where(Event.id == event_id))
    event = result.scalars().first()
    
    if not event:
        raise HTTPException(status_code=404, detail="Event not found")
    
    # Verify ownership
    if event.artist_id != current_user.id:
        raise HTTPException(status_code=403, detail="You can only delete your own events")
    
    # Delete the event
    await db.execute(delete(Event).where(Event.id == event_id))
    await db.commit()
    
    return {"ok": True, "event_id": event_id, "deleted": True}
