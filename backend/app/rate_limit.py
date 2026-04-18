"""
Rate limiting middleware.

This file was accidentally overwritten previously; it provides a lightweight
per-IP + per-path rate limiter. It prefers Redis, but fails open (allows)
when Redis is unavailable, to avoid blocking dev environments.
"""

from __future__ import annotations

import time
from typing import Dict, Tuple

from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from starlette.responses import JSONResponse, Response

from .redis_client import check_rate_limit


class RateLimitMiddleware(BaseHTTPMiddleware):
    """
    Simple rate limiting middleware.

    - Key: ip + method + path (no query string)
    - Window: `window_seconds`
    - Limit: `default_limit`
    """

    def __init__(self, app, default_limit: int = 100, window_seconds: int = 60):
        super().__init__(app)
        self.default_limit = max(1, int(default_limit))
        self.window_seconds = max(1, int(window_seconds))
        # In-memory fallback: key -> (reset_ts, count)
        self._mem: Dict[str, Tuple[float, int]] = {}

    async def dispatch(self, request: Request, call_next) -> Response:
        # Allow health/static/options without limiting
        if request.method == "OPTIONS" or request.url.path in {"/", "/docs", "/openapi.json"}:
            return await call_next(request)

        ip = request.headers.get("x-forwarded-for", "").split(",")[0].strip() or (
            request.client.host if request.client else "unknown"
        )
        key = f"ratelimit:{ip}:{request.method}:{request.url.path}"

        # Prefer Redis sliding window via INCR/EXPIRE
        try:
            allowed, remaining = await check_rate_limit(key, self.default_limit, self.window_seconds)
            if not allowed:
                return JSONResponse(
                    {"detail": "Rate limit exceeded", "remaining": remaining},
                    status_code=429,
                    headers={"Retry-After": str(self.window_seconds)},
                )
        except Exception:
            # Fallback to in-memory limiter (best-effort)
            now = time.time()
            reset_ts, count = self._mem.get(key, (now + self.window_seconds, 0))
            if now > reset_ts:
                reset_ts, count = (now + self.window_seconds, 0)
            count += 1
            self._mem[key] = (reset_ts, count)
            if count > self.default_limit:
                return JSONResponse(
                    {"detail": "Rate limit exceeded"},
                    status_code=429,
                    headers={"Retry-After": str(int(max(0, reset_ts - now)))},
                )

        return await call_next(request)