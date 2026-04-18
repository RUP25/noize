"""
Hybrid music recommendations (trending + collaborative + artist/album affinity).

Includes: recency decay on trending, per-artist diversity, Redis caching,
and short session history (Redis) to seed personalization.
"""
from __future__ import annotations

import json
import os
from datetime import datetime, timedelta, timezone
from typing import Any, Dict, List, Optional, Set
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel, Field
from sqlalchemy import and_, desc, func, or_, select, text
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import aliased, selectinload

from .auth_integration import get_current_user
from .db import get_db
from .models import Dislike, Follow, Like, ListenEvent, Playlist, PlaylistSong, Song, User
from .redis_client import cache_delete_matching, cache_get, cache_set

router = APIRouter(prefix="/recommendations", tags=["recommendations"])

# Tunable via environment (defaults match sensible prod-ish behavior)
REC_TRENDING_DAYS = float(os.getenv("REC_TRENDING_DAYS", "14"))
REC_TRENDING_HALF_LIFE_DAYS = float(os.getenv("REC_TRENDING_HALF_LIFE_DAYS", "3"))
REC_MAX_PER_ARTIST = int(os.getenv("REC_MAX_PER_ARTIST", "3"))
REC_CACHE_TRENDING_TTL = int(os.getenv("REC_CACHE_TRENDING_TTL", "300"))
REC_CACHE_FORYOU_TTL = int(os.getenv("REC_CACHE_FORYOU_TTL", "180"))
REC_SESSION_MAX = int(os.getenv("REC_SESSION_MAX", "24"))
REC_SESSION_TTL = int(os.getenv("REC_SESSION_TTL", str(7 * 86400)))


def _playable_moderation():
    return or_(Song.moderation_status.is_(None), Song.moderation_status == "approved")


def song_to_payload(song: Song) -> Dict[str, Any]:
    artist = song.artist
    return {
        "id": song.id,
        "title": song.title,
        "album": song.album,
        "r2_key": song.r2_key,
        "content_type": song.content_type,
        "duration": song.duration,
        "cover_photo_url": song.cover_photo_url,
        "lyrics": song.lyrics,
        "genre": getattr(song, "genre", None),
        "created_at": song.created_at.isoformat() if song.created_at else None,
        "moderation_status": song.moderation_status,
        "artist": {
            "id": str(artist.id) if artist else None,
            "contact": artist.contact if artist else None,
            "email": artist.email if artist else None,
            "is_artist": artist.is_artist if artist else None,
            "channel_name": artist.channel_name if artist else None,
            "banner_url": artist.banner_url if artist else None,
            "photo_url": artist.photo_url if artist else None,
            "is_upgraded": artist.is_upgraded if artist else None,
            "created_at": artist.created_at.isoformat() if artist and artist.created_at else None,
        },
    }


async def _load_songs_by_ids(
    db: AsyncSession, ids: List[int], exclude: Set[int]
) -> List[Song]:
    if not ids:
        return []
    q = await db.execute(
        select(Song)
        .where(
            Song.id.in_(ids),
            Song.id.notin_(exclude),
            _playable_moderation(),
        )
        .options(selectinload(Song.artist))
    )
    rows = q.scalars().all()
    by_id = {s.id: s for s in rows}
    return [by_id[i] for i in ids if i in by_id]


async def _trending_song_ids_count_fallback(
    db: AsyncSession, limit: int, since: datetime
) -> List[int]:
    q = await db.execute(
        select(ListenEvent.song_id, func.count(ListenEvent.id).label("c"))
        .where(ListenEvent.played_at >= since)
        .group_by(ListenEvent.song_id)
        .order_by(desc("c"))
        .limit(limit * 2)
    )
    raw = [row[0] for row in q.all()]
    if len(raw) >= limit:
        return raw[:limit]

    likes_sq = (
        select(Like.song_id.label("sid"), func.count(Like.id).label("lc"))
        .group_by(Like.song_id)
        .subquery()
    )
    dislikes_sq = (
        select(Dislike.song_id.label("sid"), func.count(Dislike.id).label("dc"))
        .group_by(Dislike.song_id)
        .subquery()
    )
    net_expr = (func.coalesce(likes_sq.c.lc, 0) - func.coalesce(dislikes_sq.c.dc, 0)).label("net")
    q2 = await db.execute(
        select(Song.id, net_expr)
        .select_from(Song)
        .outerjoin(likes_sq, likes_sq.c.sid == Song.id)
        .outerjoin(dislikes_sq, dislikes_sq.c.sid == Song.id)
        .where(_playable_moderation())
        .order_by(desc("net"))
        .limit(limit * 2)
    )
    likes_ranked = [row[0] for row in q2.all()]
    seen: Set[int] = set()
    out: List[int] = []
    for sid in raw + likes_ranked:
        if sid not in seen:
            seen.add(sid)
            out.append(sid)
        if len(out) >= limit:
            break
    return out


async def trending_song_ids(
    db: AsyncSession, limit: int, days: Optional[float] = None, half_life_days: Optional[float] = None
) -> List[int]:
    """
    Rank tracks by recency-weighted listen scores (exponential decay), then net (likes − dislikes) fallback.
    """
    days = days if days is not None else REC_TRENDING_DAYS
    half_life_days = half_life_days if half_life_days is not None else REC_TRENDING_HALF_LIFE_DAYS
    since = datetime.now(timezone.utc) - timedelta(days=days)
    lim = max(limit * 3, limit)

    try:
        q = await db.execute(
            text(
                """
                SELECT song_id, SUM(
                    EXP(-GREATEST(0, EXTRACT(EPOCH FROM (NOW() - played_at))) / 86400.0 / :half_life)
                ) AS score
                FROM listen_events
                WHERE played_at >= :since
                GROUP BY song_id
                ORDER BY score DESC NULLS LAST
                LIMIT :lim
                """
            ),
            {"since": since, "half_life": float(half_life_days), "lim": lim},
        )
        rows = q.all()
        raw = [row[0] for row in rows if row[0] is not None]
        if len(raw) >= min(limit, 1):
            return raw[:limit]
    except Exception as e:
        print(f"recency trending query failed, using fallback: {e}")

    return await _trending_song_ids_count_fallback(db, limit, since)


def _diversify_ids(
    ordered: List[int],
    artist_by_song: Dict[int, Optional[UUID]],
    max_out: int,
    max_per_artist: int,
) -> List[int]:
    counts: Dict[Optional[UUID], int] = {}
    out: List[int] = []
    for sid in ordered:
        aid = artist_by_song.get(sid)
        n = counts.get(aid, 0)
        if n >= max_per_artist:
            continue
        counts[aid] = n + 1
        out.append(sid)
        if len(out) >= max_out:
            break
    return out


async def _artist_map_for_songs(db: AsyncSession, song_ids: List[int]) -> Dict[int, Optional[UUID]]:
    if not song_ids:
        return {}
    q = await db.execute(select(Song.id, Song.artist_id).where(Song.id.in_(song_ids)))
    return {row[0]: row[1] for row in q.all()}


async def _redis_session_seed_ids(user_id: UUID) -> List[int]:
    try:
        raw = await cache_get(f"rec:session:{user_id}")
        if not raw:
            return []
        data = json.loads(raw)
        if not isinstance(data, list):
            return []
        out: List[int] = []
        for x in data[: REC_SESSION_MAX + 20]:
            if isinstance(x, int):
                out.append(x)
            elif isinstance(x, str) and x.isdigit():
                out.append(int(x))
        return out
    except Exception as e:
        print(f"session seed read failed: {e}")
        return []


async def _redis_session_append(user_id: UUID, song_id: int) -> None:
    try:
        prev = await _redis_session_seed_ids(user_id)
        nxt = [song_id] + [x for x in prev if x != song_id][: REC_SESSION_MAX - 1]
        await cache_set(
            f"rec:session:{user_id}",
            json.dumps(nxt),
            expiry_seconds=REC_SESSION_TTL,
        )
    except Exception as e:
        print(f"session append failed: {e}")


async def _user_disliked_song_ids(db: AsyncSession, user_id: UUID) -> Set[int]:
    r = await db.execute(select(Dislike.song_id).where(Dislike.user_id == user_id))
    return {row[0] for row in r.all()}


async def collect_seed_songs(db: AsyncSession, user_id) -> Set[int]:
    seeds: Set[int] = set()

    for sid in await _redis_session_seed_ids(user_id):
        seeds.add(sid)

    r = await db.execute(select(Like.song_id).where(Like.user_id == user_id).limit(80))
    seeds.update(row[0] for row in r.all())

    r2 = await db.execute(
        select(ListenEvent.song_id)
        .where(ListenEvent.user_id == user_id)
        .order_by(desc(ListenEvent.played_at))
        .limit(40)
    )
    seeds.update(row[0] for row in r2.all())

    r3 = await db.execute(
        select(PlaylistSong.song_id)
        .join(Playlist, PlaylistSong.playlist_id == Playlist.id)
        .where(Playlist.user_id == user_id)
        .limit(120)
    )
    seeds.update(row[0] for row in r3.all())
    seeds -= await _user_disliked_song_ids(db, user_id)
    return seeds


async def collaborative_candidates(
    db: AsyncSession, seeds: List[int], exclude: Set[int], limit: int
) -> List[int]:
    if not seeds:
        return []
    L1 = aliased(Like)
    L2 = aliased(Like)
    q = await db.execute(
        select(L2.song_id, func.count().label("cnt"))
        .select_from(L1)
        .join(L2, L1.user_id == L2.user_id)
        .join(Song, Song.id == L2.song_id)
        .where(
            and_(
                L1.song_id.in_(seeds[:25]),
                L2.song_id != L1.song_id,
                L2.song_id.notin_(exclude),
                _playable_moderation(),
            )
        )
        .group_by(L2.song_id)
        .order_by(desc("cnt"))
        .limit(limit)
    )
    return [row[0] for row in q.all()]


async def same_artist_candidates(
    db: AsyncSession, seeds: List[int], exclude: Set[int], limit: int
) -> List[int]:
    if not seeds:
        return []
    r = await db.execute(
        select(Song.artist_id).where(Song.id.in_(seeds[:30])).distinct()
    )
    artist_ids = [row[0] for row in r.all() if row[0]]
    if not artist_ids:
        return []
    q = await db.execute(
        select(Song.id)
        .where(
            Song.artist_id.in_(artist_ids),
            Song.id.notin_(exclude),
            _playable_moderation(),
        )
        .order_by(desc(Song.created_at))
        .limit(limit)
    )
    return [row[0] for row in q.all()]


async def followed_artist_candidates(
    db: AsyncSession, user_id, exclude: Set[int], limit: int
) -> List[int]:
    sub = select(Follow.artist_id).where(Follow.user_id == user_id)
    q = await db.execute(
        select(Song.id)
        .where(
            Song.artist_id.in_(sub),
            Song.id.notin_(exclude),
            _playable_moderation(),
        )
        .order_by(desc(Song.created_at))
        .limit(limit)
    )
    return [row[0] for row in q.all()]


async def album_neighbors(
    db: AsyncSession, seed_song_id: int, exclude: Set[int], limit: int
) -> List[int]:
    r = await db.execute(select(Song.album, Song.artist_id).where(Song.id == seed_song_id))
    row = r.first()
    if not row or not row[0] or not row[1]:
        return []
    album, artist_id = row[0], row[1]
    q = await db.execute(
        select(Song.id)
        .where(
            Song.artist_id == artist_id,
            Song.album == album,
            Song.id != seed_song_id,
            Song.id.notin_(exclude),
            _playable_moderation(),
        )
        .order_by(desc(Song.created_at))
        .limit(limit)
    )
    return [x[0] for x in q.all()]


@router.get("/trending")
async def get_trending(
    limit: int = Query(30, ge=1, le=80),
    db: AsyncSession = Depends(get_db),
):
    """Globally trending tracks (recency-weighted plays, then likes). Cached in Redis."""
    limit = min(max(limit, 1), 80)
    cache_key = f"rec:v2:t:{REC_TRENDING_DAYS}:{REC_TRENDING_HALF_LIFE_DAYS}:{limit}"
    try:
        cached = await cache_get(cache_key)
        if cached:
            data = json.loads(cached)
            if isinstance(data, list):
                return data
    except Exception as e:
        print(f"trending cache get failed: {e}")

    ids = await trending_song_ids(db, limit)
    songs = await _load_songs_by_ids(db, ids, set())
    payload = [song_to_payload(s) for s in songs]
    try:
        await cache_set(cache_key, json.dumps(payload), expiry_seconds=REC_CACHE_TRENDING_TTL)
    except Exception as e:
        print(f"trending cache set failed: {e}")
    return payload


async def _collect_personalized_song_ids(db: AsyncSession, uid, limit: int) -> List[int]:
    """Core pool used by for-you and mood-for-you."""
    disliked = await _user_disliked_song_ids(db, uid)
    seeds = await collect_seed_songs(db, uid)
    exclude: Set[int] = set(seeds) | disliked

    seed_list = list(seeds)[:40]
    pool: List[int] = []
    pool_limit = max(limit * 4, 80)

    def extend(xs: List[int]) -> None:
        for sid in xs:
            if sid not in exclude and sid not in pool:
                pool.append(sid)
                exclude.add(sid)

    extend(await collaborative_candidates(db, seed_list, exclude, limit=50))
    extend(await same_artist_candidates(db, seed_list, exclude, 40))
    extend(await followed_artist_candidates(db, uid, exclude, 36))
    if len(pool) < pool_limit:
        extend(await trending_song_ids(db, pool_limit))

    artist_map = await _artist_map_for_songs(db, pool)
    div = _diversify_ids(pool, artist_map, max_out=max(limit, 1), max_per_artist=REC_MAX_PER_ARTIST)

    if len(div) < limit:
        seen2 = set(div) | seeds
        for sid in await trending_song_ids(db, limit * 3):
            if sid in seen2:
                continue
            div.append(sid)
            seen2.add(sid)
            if len(div) >= limit:
                break

    return div[:limit]


@router.get("/for-you")
async def get_for_you(
    limit: int = Query(40, ge=1, le=80),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Personalized feed with collaborative + graph signals, diversity cap, trending fill.
    Cached per user; invalidated on new play events.
    """
    limit = min(max(limit, 1), 80)
    uid = current_user.id
    uid_str = str(uid)
    cache_key = f"rec:v2:fy:{uid_str}:{limit}"

    try:
        cached = await cache_get(cache_key)
        if cached:
            data = json.loads(cached)
            if isinstance(data, list):
                return data
    except Exception as e:
        print(f"for-you cache get failed: {e}")

    ordered_ids = await _collect_personalized_song_ids(db, uid, limit)
    songs = await _load_songs_by_ids(db, ordered_ids, set())
    by_id = {s.id: s for s in songs}
    ordered = [by_id[i] for i in ordered_ids if i in by_id]
    payload = [song_to_payload(s) for s in ordered]

    try:
        await cache_set(cache_key, json.dumps(payload), expiry_seconds=REC_CACHE_FORYOU_TTL)
    except Exception as e:
        print(f"for-you cache set failed: {e}")

    return payload


@router.get("/mood-for-you")
async def get_mood_for_you(
    limit: int = Query(30, ge=1, le=80),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Like for-you, but boosts tracks whose `genre` matches the user's mood board
    (`experience_preferences.mood_board_genres`). Discovery-first when moods are set.
    """
    limit = min(max(limit, 1), 80)
    uid = current_user.id
    uid_str = str(uid)
    cache_key = f"rec:v2:mood:{uid_str}:{limit}"

    try:
        cached = await cache_get(cache_key)
        if cached:
            data = json.loads(cached)
            if isinstance(data, list):
                return data
    except Exception as e:
        print(f"mood-for-you cache get failed: {e}")

    moods = {
        str(m).lower().strip()
        for m in (current_user.experience_preferences or {}).get("mood_board_genres", [])
        if m
    }

    disliked_ids = await _user_disliked_song_ids(db, uid)
    ordered_ids = await _collect_personalized_song_ids(db, uid, limit)

    if moods:
        r = await db.execute(
            select(Song.id)
            .where(
                _playable_moderation(),
                Song.genre.isnot(None),
                func.lower(Song.genre).in_(list(moods)),
                Song.id.notin_(set(ordered_ids)),
                Song.id.notin_(disliked_ids),
            )
            .order_by(desc(Song.created_at))
            .limit(min(12, limit)),
        )
        pre = [row[0] for row in r.all()]
        seen: Set[int] = set()
        merged: List[int] = []
        for sid in pre + ordered_ids:
            if sid not in seen:
                seen.add(sid)
                merged.append(sid)
        ordered_ids = merged[:limit]

    songs = await _load_songs_by_ids(db, ordered_ids, set())
    by_id = {s.id: s for s in songs}
    ordered = [by_id[i] for i in ordered_ids if i in by_id]

    if moods:
        ordered.sort(
            key=lambda s: (
                0
                if (s.genre or "").lower().strip() in moods
                else 1
            )
        )

    payload = [song_to_payload(s) for s in ordered]

    try:
        await cache_set(cache_key, json.dumps(payload), expiry_seconds=REC_CACHE_FORYOU_TTL)
    except Exception as e:
        print(f"mood-for-you cache set failed: {e}")

    return payload


@router.get("/similar/{song_id}")
async def get_similar(
    song_id: int,
    limit: int = Query(20, ge=1, le=50),
    db: AsyncSession = Depends(get_db),
):
    """Radio-style neighbors with per-artist diversity."""
    limit = min(max(limit, 1), 50)
    r = await db.execute(
        select(Song).where(Song.id == song_id).options(selectinload(Song.artist))
    )
    base = r.scalars().first()
    if not base:
        raise HTTPException(status_code=404, detail="Song not found")

    exclude: Set[int] = {song_id}
    pool: List[int] = []

    for sid in await album_neighbors(db, song_id, exclude, 20):
        pool.append(sid)
        exclude.add(sid)

    q = await db.execute(
        select(Song.id)
        .where(
            Song.artist_id == base.artist_id,
            Song.id != song_id,
            Song.id.notin_(exclude),
            _playable_moderation(),
        )
        .order_by(desc(Song.created_at))
        .limit(40)
    )
    for row in q.all():
        sid = row[0]
        if sid not in exclude:
            pool.append(sid)
            exclude.add(sid)

    for sid in await collaborative_candidates(db, [song_id], exclude, 40):
        if sid not in exclude:
            pool.append(sid)
            exclude.add(sid)

    amap = await _artist_map_for_songs(db, pool)
    div = _diversify_ids(pool, amap, max_out=limit, max_per_artist=max(REC_MAX_PER_ARTIST, 4))
    if len(div) < limit:
        for sid in pool:
            if sid not in div:
                div.append(sid)
            if len(div) >= limit:
                break
    ordered_ids = div[:limit]

    songs = await _load_songs_by_ids(db, ordered_ids, {song_id})
    by_id = {s.id: s for s in songs}
    ordered = [by_id[i] for i in ordered_ids if i in by_id]
    return [song_to_payload(s) for s in ordered]


class PlayEventIn(BaseModel):
    song_id: int = Field(..., ge=1)
    listen_ms: Optional[int] = Field(None, ge=0, le=86_400_000)


@router.post("/play")
async def record_play(
    body: PlayEventIn,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Record a listen for ranking (call after ~30s of playback or on completion).
    Updates session history and invalidates personalized recommendation cache.
    """
    r = await db.execute(
        select(Song).where(Song.id == body.song_id, _playable_moderation())
    )
    if not r.scalars().first():
        raise HTTPException(status_code=404, detail="Song not found or not playable")

    ev = ListenEvent(
        user_id=current_user.id,
        song_id=body.song_id,
        listen_ms=body.listen_ms,
    )
    db.add(ev)
    await db.commit()

    await _redis_session_append(current_user.id, body.song_id)
    try:
        await cache_delete_matching(f"rec:v2:fy:{current_user.id}:")
        await cache_delete_matching(f"rec:v2:mood:{current_user.id}:")
        await cache_delete_matching("charts:v1:")
    except Exception as e:
        print(f"recommendation/charts cache invalidate failed: {e}")

    return {"ok": True}
