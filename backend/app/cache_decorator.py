# backend/app/cache_decorator.py
"""
Caching decorator for FastAPI endpoints using Redis.
"""
from functools import wraps
from typing import Callable, Optional
import json
from .redis_client import cache_get, cache_set, cache_delete, invalidate_user_cache, invalidate_artist_cache


def cached(key_prefix: str, expiry_seconds: int = 3600, key_func: Optional[Callable] = None):
    """
    Decorator to cache endpoint responses in Redis.
    
    Args:
        key_prefix: Prefix for cache key (e.g., "user_profile")
        expiry_seconds: Cache TTL in seconds
        key_func: Optional function to generate cache key from function arguments
    
    Example:
        @cached("user_profile", expiry_seconds=1800)
        async def get_user_profile(user_id: str):
            # This will be cached
            return {"id": user_id, "name": "John"}
    """
    def decorator(func: Callable):
        @wraps(func)
        async def wrapper(*args, **kwargs):
            # Generate cache key
            if key_func:
                cache_key = f"cache:{key_prefix}:{key_func(*args, **kwargs)}"
            else:
                # Use first argument or kwargs as key
                if args:
                    cache_key = f"cache:{key_prefix}:{str(args[0])}"
                elif kwargs:
                    first_key = next(iter(kwargs))
                    cache_key = f"cache:{key_prefix}:{str(kwargs[first_key])}"
                else:
                    cache_key = f"cache:{key_prefix}:default"
            
            # Try to get from cache
            cached_value = await cache_get(cache_key)
            if cached_value:
                try:
                    return json.loads(cached_value)
                except (json.JSONDecodeError, TypeError):
                    return cached_value
            
            # Cache miss - execute function
            result = await func(*args, **kwargs)
            
            # Store in cache
            if result is not None:
                await cache_set(cache_key, result, expiry_seconds)
            
            return result
        
        return wrapper
    return decorator


async def cache_user_profile(user_id: str, profile_data: dict, expiry_seconds: int = 1800):
    """Cache user profile data."""
    key = f"cache:user_profile:{user_id}"
    await cache_set(key, profile_data, expiry_seconds)


async def get_cached_user_profile(user_id: str) -> Optional[dict]:
    """Get cached user profile."""
    key = f"cache:user_profile:{user_id}"
    cached = await cache_get(key)
    if cached:
        try:
            return json.loads(cached)
        except (json.JSONDecodeError, TypeError):
            return None
    return None


async def cache_artist_info(channel_name: str, artist_data: dict, expiry_seconds: int = 3600):
    """Cache artist channel data."""
    key = f"cache:artist:{channel_name}"
    await cache_set(key, artist_data, expiry_seconds)


async def get_cached_artist_info(channel_name: str) -> Optional[dict]:
    """Get cached artist info."""
    key = f"cache:artist:{channel_name}"
    cached = await cache_get(key)
    if cached:
        try:
            return json.loads(cached)
        except (json.JSONDecodeError, TypeError):
            return None
    return None


# Re-export invalidate functions for convenience
__all__ = [
    'cached',
    'cache_user_profile',
    'get_cached_user_profile',
    'cache_artist_info',
    'get_cached_artist_info',
    'invalidate_user_cache',
    'invalidate_artist_cache',
]
