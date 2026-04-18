"""
Charts API: ranked song lists (Top 50, etc.) backed by the same ranking as recommendations/trending.
Regional chart_ids are accepted for future filtering; today all resolve to the global chart.
"""
from __future__ import annotations

import json
import re
from typing import Any, Dict, List, Set

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession

from .db import get_db
from .experience import new_release_song_ids
from .recommendations import (
    REC_CACHE_TRENDING_TTL,
    REC_TRENDING_DAYS,
    REC_TRENDING_HALF_LIFE_DAYS,
    _load_songs_by_ids,
    song_to_payload,
    trending_song_ids,
)
from .redis_client import cache_get, cache_set

router = APIRouter(prefix="/charts", tags=["charts"])

_CHART_ID_RE = re.compile(r"^[a-zA-Z0-9._-]{1,64}$")


def _interleave_chart_ids(new_ids: List[int], hot_ids: List[int], limit: int, new_bias: int) -> List[int]:
    """
    Merge new-release ids with trending. new_bias: 1 = balanced 1:1, 2 = new_music_heavy (2 new : 1 hot).
    """
    seen: Set[int] = set()
    out: List[int] = []
    i, j = 0, 0
    take_new_streak = 0
    while len(out) < limit and (i < len(new_ids) or j < len(hot_ids)):
        want_new = take_new_streak < new_bias and i < len(new_ids)
        if want_new:
            sid = new_ids[i]
            i += 1
            take_new_streak += 1
        elif j < len(hot_ids):
            sid = hot_ids[j]
            j += 1
            take_new_streak = 0
        elif i < len(new_ids):
            sid = new_ids[i]
            i += 1
            take_new_streak += 1
        else:
            break
        if sid in seen:
            continue
        seen.add(sid)
        out.append(sid)
    return out


@router.get("/top")
async def get_chart_top(
    chart_id: str = Query(
        "top50_global",
        max_length=64,
        description="Chart catalog id (e.g. top50_global, top50_india).",
    ),
    limit: int = Query(50, ge=1, le=80),
    style: str = Query(
        "balanced",
        description="trending_only | balanced (new+trending) | new_music_heavy (favor newest).",
    ),
    db: AsyncSession = Depends(get_db),
):
    """
    Top tracks for a chart. Uses recency-weighted plays + like fallback (same as /recommendations/trending).
    `style` lets listeners favor pure trending vs a blend with newest uploads.
    """
    if not _CHART_ID_RE.match(chart_id or ""):
        raise HTTPException(status_code=400, detail="Invalid chart_id")
    if style not in ("trending_only", "balanced", "new_music_heavy"):
        raise HTTPException(status_code=400, detail="Invalid style")
    limit = min(max(limit, 1), 80)
    cache_key = f"charts:v1:top:{chart_id}:{style}:{REC_TRENDING_DAYS}:{REC_TRENDING_HALF_LIFE_DAYS}:{limit}"
    try:
        cached = await cache_get(cache_key)
        if cached:
            data = json.loads(cached)
            if isinstance(data, list):
                return data
    except Exception as e:
        print(f"charts cache get failed: {e}")

    hot = await trending_song_ids(db, limit * 2)
    if style == "trending_only":
        ids = hot[:limit]
    else:
        nw = await new_release_song_ids(db, limit * 2)
        bias = 2 if style == "new_music_heavy" else 1
        ids = _interleave_chart_ids(nw, hot, limit, new_bias=bias)

    songs = await _load_songs_by_ids(db, ids, set())
    payload: List[Dict[str, Any]] = [song_to_payload(s) for s in songs]
    try:
        await cache_set(cache_key, json.dumps(payload), expiry_seconds=REC_CACHE_TRENDING_TTL)
    except Exception as e:
        print(f"charts cache set failed: {e}")
    return payload
