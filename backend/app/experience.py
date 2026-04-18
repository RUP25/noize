"""
Discovery: new releases, global upcoming events feed, trending, merch from followed artists.
"""
from __future__ import annotations

from datetime import date
from typing import Any, Dict, List, Optional

from fastapi import APIRouter, Depends, Query
from sqlalchemy import desc, or_, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from .auth_integration import get_current_user
from .db import get_db
from .models import Event, Follow, Merchandise, Song, User
from .recommendations import _load_songs_by_ids, _playable_moderation, song_to_payload, trending_song_ids

router = APIRouter(prefix="/experience", tags=["experience"])


def _playable_song():
    return or_(Song.moderation_status.is_(None), Song.moderation_status == "approved")


async def new_release_song_ids(db: AsyncSession, limit: int) -> List[int]:
    limit = min(max(limit, 1), 100)
    q = await db.execute(
        select(Song.id)
        .where(_playable_song())
        .order_by(desc(Song.created_at))
        .limit(limit)
    )
    return [row[0] for row in q.all()]


@router.get("/new-releases")
async def get_new_releases(
    limit: int = Query(24, ge=1, le=60),
    db: AsyncSession = Depends(get_db),
):
    """Recently uploaded approved tracks (newest first)."""
    ids = await new_release_song_ids(db, limit)
    songs = await _load_songs_by_ids(db, ids, set())
    return [song_to_payload(s) for s in songs]


@router.get("/trending")
async def get_experience_trending(
    limit: int = Query(20, ge=1, le=50),
    db: AsyncSession = Depends(get_db),
):
    """Trending tracks (same ranking engine as /recommendations/trending)."""
    limit = min(max(limit, 1), 50)
    ids = await trending_song_ids(db, limit)
    songs = await _load_songs_by_ids(db, ids, set())
    return [song_to_payload(s) for s in songs]


@router.get("/events")
async def get_events_feed(
    db: AsyncSession = Depends(get_db),
    location_hint: Optional[str] = Query(
        None,
        max_length=120,
        description="Optional city/region — events matching this substring in `location` are listed first.",
    ),
    limit: int = Query(10, ge=1, le=40),
):
    """
    Next upcoming concerts/events across NOIZE (not limited to followed artists).
    Default limit 10. Ordered by date; optional `location_hint` soft-prioritizes matching venues/cities.
    """
    limit = min(max(limit, 1), 40)
    today = date.today()

    q = await db.execute(
        select(Event, User)
        .join(User, User.id == Event.artist_id)
        .where(Event.date >= today)
        .order_by(Event.date.asc(), Event.time.asc())
        .limit(limit * 3)
    )
    rows = q.all()
    hint = (location_hint or "").strip().lower()
    scored: List[tuple] = []
    for ev, artist in rows:
        loc = (ev.location or "").lower()
        score = 2 if hint and hint in loc else 1
        scored.append((score, ev, artist))
    scored.sort(key=lambda x: (-x[0], x[1].date, x[1].time))
    scored = scored[:limit]

    out: List[Dict[str, Any]] = []
    for _, ev, artist in scored:
        merch_rows = await db.execute(
            select(Merchandise)
            .where(Merchandise.artist_id == artist.id)
            .order_by(desc(Merchandise.created_at))
            .limit(3)
        )
        merch_list = merch_rows.scalars().all()
        out.append(
            {
                "id": ev.id,
                "title": ev.title,
                "description": ev.description,
                "date": ev.date.isoformat() if ev.date else None,
                "time": ev.time.isoformat() if ev.time else None,
                "location": ev.location,
                "ticket_price": ev.ticket_price,
                "ticket_link": ev.ticket_link,
                "artist": {
                    "id": str(artist.id),
                    "channel_name": artist.channel_name,
                    "photo_url": artist.photo_url,
                },
                "merch": [
                    {
                        "id": m.id,
                        "title": m.title,
                        "price": m.price,
                        "image_url": m.image_url,
                        "purchase_link": m.purchase_link,
                        "category": m.category,
                    }
                    for m in merch_list
                ],
            }
        )
    return out


@router.get("/merch/followed")
async def get_merch_from_followed(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
    limit: int = Query(24, ge=1, le=60),
):
    """Merchandise from artists you follow (newest first)."""
    limit = min(max(limit, 1), 60)
    sub = select(Follow.artist_id).where(Follow.user_id == current_user.id)
    q = await db.execute(
        select(Merchandise)
        .options(selectinload(Merchandise.artist))
        .where(Merchandise.artist_id.in_(sub))
        .order_by(desc(Merchandise.created_at))
        .limit(limit)
    )
    items = q.scalars().all()
    out = []
    for m in items:
        a = m.artist
        out.append(
            {
                "id": m.id,
                "title": m.title,
                "description": m.description,
                "price": m.price,
                "image_url": m.image_url,
                "purchase_link": m.purchase_link,
                "category": m.category,
                "artist": {
                    "id": str(a.id) if a else None,
                    "channel_name": a.channel_name if a else None,
                    "photo_url": a.photo_url if a else None,
                },
            }
        )
    return out
