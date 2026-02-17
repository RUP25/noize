# backend/app/rate_limit.py
"""
Rate limiting middleware using Redis.
"""
from fastapi import Request, HTTPException
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.responses import Response
from .redis_client import check_rate_limit


class RateLimitMiddleware(BaseHTTPMiddleware):
    """Rate limiting middleware for API endpoints."""
    
    def __init__(self, app, default_limit: int = 100, window_seconds: int = 60):
        super().__init__(app)
        self.default_limit = default_limit
        self.window_seconds = window_seconds
    
    async def dispatch(self, request: Request, call_next):
        # Skip rate limiting for health checks and docs
        if request.url.path in ["/", "/docs", "/redoc", "/openapi.json"]:
            return await call_next(request)
        
        # Get client identifier (IP address)
        client_ip = request.client.host if request.client else "unknown"
        
        # Create rate limit key based on path and IP
        path = request.url.path
        rate_limit_key = f"ratelimit:api:{path}:{client_ip}"
        
        # Check rate limit
        try:
            is_allowed, remaining = await check_rate_limit(
                rate_limit_key,
                max_requests=self.default_limit,
                window_seconds=self.window_seconds
            )
            
            if not is_allowed:
                return Response(
                    content='{"detail": "Rate limit exceeded. Please try again later."}',
                    status_code=429,
                    headers={
                        "X-RateLimit-Limit": str(self.default_limit),
                        "X-RateLimit-Remaining": str(remaining),
                        "X-RateLimit-Reset": str(self.window_seconds),
                        "Content-Type": "application/json",
                    }
                )
            
            # Add rate limit headers to response
            response = await call_next(request)
            response.headers["X-RateLimit-Limit"] = str(self.default_limit)
            response.headers["X-RateLimit-Remaining"] = str(remaining)
            response.headers["X-RateLimit-Reset"] = str(self.window_seconds)
            return response
            
        except Exception as e:
            # If Redis fails, allow request but log error
            print(f"Rate limit check failed: {e}")
            return await call_next(request)
