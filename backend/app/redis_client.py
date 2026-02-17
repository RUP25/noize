# backend/app/redis_client.py
"""
Redis client for caching, session management, and rate limiting.
"""
import os
import redis.asyncio as redis
from typing import Optional, Tuple
import json

# Redis connection settings
REDIS_HOST = os.getenv("REDIS_HOST", "redis")
REDIS_PORT = int(os.getenv("REDIS_PORT", 6379))
REDIS_DB = int(os.getenv("REDIS_DB", 0))
REDIS_PASSWORD = os.getenv("REDIS_PASSWORD", None)

# Global Redis connection pool
_redis_client: Optional[redis.Redis] = None


async def get_redis() -> redis.Redis:
    """Get or create Redis client connection."""
    global _redis_client
    if _redis_client is None:
        _redis_client = redis.Redis(
            host=REDIS_HOST,
            port=REDIS_PORT,
            db=REDIS_DB,
            password=REDIS_PASSWORD,
            decode_responses=True,  # Automatically decode bytes to strings
            socket_connect_timeout=2,  # Reduced timeout
            socket_timeout=2,  # Reduced timeout
            retry_on_timeout=False,  # Don't retry on timeout
            health_check_interval=30,  # Check connection health
        )
    return _redis_client


async def close_redis():
    """Close Redis connection."""
    global _redis_client
    if _redis_client:
        await _redis_client.aclose()
        _redis_client = None


# OTP Management
async def store_otp(contact: str, otp: str, expiry_seconds: int = 300) -> bool:
    """
    Store OTP in Redis with expiration.
    
    Args:
        contact: Phone number or email
        otp: One-time password
        expiry_seconds: Time to live in seconds (default: 5 minutes)
    
    Returns:
        True if stored successfully
    """
    r = await get_redis()
    key = f"otp:{contact}"
    await r.setex(key, expiry_seconds, otp)
    return True


async def get_otp(contact: str) -> Optional[str]:
    """
    Retrieve OTP from Redis.
    
    Args:
        contact: Phone number or email
    
    Returns:
        OTP string if found, None otherwise
    """
    r = await get_redis()
    key = f"otp:{contact}"
    return await r.get(key)


async def delete_otp(contact: str) -> bool:
    """
    Delete OTP from Redis after successful verification.
    
    Args:
        contact: Phone number or email
    
    Returns:
        True if deleted, False if not found
    """
    r = await get_redis()
    key = f"otp:{contact}"
    return bool(await r.delete(key))


# Rate Limiting
async def check_rate_limit(key: str, max_requests: int, window_seconds: int) -> Tuple[bool, int]:
    """
    Check if request is within rate limit using sliding window.
    
    Args:
        key: Unique identifier for rate limiting (e.g., "ratelimit:login:127.0.0.1")
        max_requests: Maximum number of requests allowed
        window_seconds: Time window in seconds
    
    Returns:
        Tuple of (is_allowed: bool, remaining_requests: int)
    """
    try:
        r = await get_redis()
        current = await r.incr(key)
        
        if current == 1:
            # First request in window, set expiration
            await r.expire(key, window_seconds)
        
        remaining = max(0, max_requests - current)
        is_allowed = current <= max_requests
        
        return is_allowed, remaining
    except Exception as e:
        # If Redis fails, allow the request (fail open)
        print(f"Rate limit check failed (Redis unavailable): {e}")
        return True, max_requests  # Allow request, assume no rate limit


# Caching
async def cache_set(key: str, value: any, expiry_seconds: int = 3600) -> bool:
    """
    Store value in Redis cache.
    
    Args:
        key: Cache key
        value: Value to cache (will be JSON serialized)
        expiry_seconds: Time to live in seconds
    
    Returns:
        True if stored successfully
    """
    r = await get_redis()
    try:
        if isinstance(value, (dict, list)):
            value = json.dumps(value)
        await r.setex(key, expiry_seconds, value)
        return True
    except Exception as e:
        print(f"Redis cache_set error: {e}")
        return False


async def cache_get(key: str) -> Optional[str]:
    """
    Retrieve value from Redis cache.
    
    Args:
        key: Cache key
    
    Returns:
        Cached value as string, or None if not found
    """
    r = await get_redis()
    try:
        return await r.get(key)
    except Exception as e:
        print(f"Redis cache_get error: {e}")
        return None


async def cache_delete(key: str) -> bool:
    """
    Delete value from Redis cache.
    
    Args:
        key: Cache key
    
    Returns:
        True if deleted, False if not found
    """
    r = await get_redis()
    return bool(await r.delete(key))


# Session/Token Management
async def store_token_blacklist(token: str, expiry_seconds: int = 86400) -> bool:
    """
    Add token to blacklist (e.g., after logout).
    
    Args:
        token: JWT token to blacklist
        expiry_seconds: Time to live (should match token expiry)
    
    Returns:
        True if stored successfully
    """
    r = await get_redis()
    key = f"blacklist:token:{token}"
    await r.setex(key, expiry_seconds, "1")
    return True


async def is_token_blacklisted(token: str) -> bool:
    """
    Check if token is blacklisted.
    
    Args:
        token: JWT token to check
    
    Returns:
        True if token is blacklisted
    """
    r = await get_redis()
    key = f"blacklist:token:{token}"
    return bool(await r.exists(key))


# Session Management
async def create_session(user_id: str, token: str, expiry_seconds: int = 86400) -> bool:
    """
    Create a user session in Redis.
    
    Args:
        user_id: User UUID
        token: Authentication token
        expiry_seconds: Session expiry time
    
    Returns:
        True if created successfully
    """
    r = await get_redis()
    session_key = f"session:{user_id}:{token}"
    user_sessions_key = f"user_sessions:{user_id}"
    
    # Store session
    await r.setex(session_key, expiry_seconds, "1")
    # Add to user's session list
    await r.sadd(user_sessions_key, token)
    await r.expire(user_sessions_key, expiry_seconds)
    return True


async def delete_session(user_id: str, token: str) -> bool:
    """
    Delete a specific session.
    
    Args:
        user_id: User UUID
        token: Authentication token
    
    Returns:
        True if deleted
    """
    r = await get_redis()
    session_key = f"session:{user_id}:{token}"
    user_sessions_key = f"user_sessions:{user_id}"
    
    await r.delete(session_key)
    await r.srem(user_sessions_key, token)
    return True


async def delete_all_user_sessions(user_id: str) -> int:
    """
    Delete all sessions for a user (e.g., on password change).
    
    Args:
        user_id: User UUID
    
    Returns:
        Number of sessions deleted
    """
    r = await get_redis()
    user_sessions_key = f"user_sessions:{user_id}"
    
    # Get all tokens
    tokens = await r.smembers(user_sessions_key)
    deleted = 0
    
    for token in tokens:
        session_key = f"session:{user_id}:{token}"
        if await r.delete(session_key):
            deleted += 1
    
    await r.delete(user_sessions_key)
    return deleted


async def is_session_valid(user_id: str, token: str) -> bool:
    """
    Check if a session is valid.
    
    Args:
        user_id: User UUID
        token: Authentication token
    
    Returns:
        True if session exists and is valid
    """
    r = await get_redis()
    session_key = f"session:{user_id}:{token}"
    return bool(await r.exists(session_key))


# Pub/Sub for Real-time Notifications
async def publish_notification(channel: str, message: dict) -> int:
    """
    Publish a notification to a Redis channel.
    
    Args:
        channel: Channel name (e.g., "notifications:user:123")
        message: Message dictionary to publish
    
    Returns:
        Number of subscribers that received the message
    """
    try:
        r = await get_redis()
        message_json = json.dumps(message)
        return await r.publish(channel, message_json)
    except Exception as e:
        # If Redis is unavailable, just log and continue (fail silently)
        print(f"Notification publish failed (Redis unavailable): {e}")
        return 0


async def get_pubsub():
    """
    Get a pubsub object for subscribing to channels.
    
    Returns:
        Redis pubsub object
    """
    r = await get_redis()
    return r.pubsub()


# Cache invalidation helpers
async def invalidate_user_cache(user_id: str):
    """Invalidate all cache entries for a user."""
    try:
        r = await get_redis()
        patterns = [
            f"cache:user:{user_id}",
            f"cache:user_profile:{user_id}",
            f"cache:user_settings:{user_id}",
        ]
        for pattern in patterns:
            try:
                await r.delete(pattern)
            except Exception:
                pass  # Ignore individual delete failures
    except Exception as e:
        # If Redis is unavailable, just log and continue
        print(f"Cache invalidation failed (Redis unavailable): {e}")
        pass


async def invalidate_artist_cache(channel_name: str):
    """Invalidate cache entries for an artist."""
    try:
        r = await get_redis()
        key = f"cache:artist:{channel_name}"
        await r.delete(key)
    except Exception as e:
        # If Redis is unavailable, just log and continue
        print(f"Cache invalidation failed (Redis unavailable): {e}")
        pass
