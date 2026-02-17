# backend/app/notifications.py
"""
Notification service using Redis Pub/Sub for real-time notifications.
"""
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from typing import List, Optional
from .auth_integration import get_current_user
from .models import User
from .redis_client import get_redis, publish_notification
import json

router = APIRouter(prefix="/notifications", tags=["notifications"])


class Notification(BaseModel):
    type: str
    message: str
    data: Optional[dict] = None
    timestamp: str


@router.post("/send")
async def send_notification(
    user_id: str,
    notification: Notification,
    current_user: User = Depends(get_current_user)
):
    """
    Send a notification to a specific user (admin/artist only).
    In production, this should check permissions.
    """
    channel = f"notifications:user:{user_id}"
    message = {
        "type": notification.type,
        "message": notification.message,
        "data": notification.data or {},
        "timestamp": notification.timestamp
    }
    
    subscribers = await publish_notification(channel, message)
    return {
        "ok": True,
        "subscribers": subscribers,
        "message": "Notification sent"
    }


@router.post("/broadcast")
async def broadcast_notification(
    channel: str,
    notification: Notification,
    current_user: User = Depends(get_current_user)
):
    """
    Broadcast notification to a channel (e.g., "notifications:artist:channel_name").
    """
    message = {
        "type": notification.type,
        "message": notification.message,
        "data": notification.data or {},
        "timestamp": notification.timestamp
    }
    
    subscribers = await publish_notification(channel, message)
    return {
        "ok": True,
        "subscribers": subscribers,
        "channel": channel
    }


# Helper function to send common notifications
async def send_user_notification(user_id: str, notification_type: str, message: str, data: Optional[dict] = None):
    """Helper to send notifications to users."""
    from datetime import datetime
    await publish_notification(
        f"notifications:user:{user_id}",
        {
            "type": notification_type,
            "message": message,
            "data": data or {},
            "timestamp": datetime.utcnow().isoformat()
        }
    )


async def send_artist_notification(channel_name: str, notification_type: str, message: str, data: Optional[dict] = None):
    """Helper to send notifications to artists."""
    from datetime import datetime
    await publish_notification(
        f"notifications:artist:{channel_name}",
        {
            "type": notification_type,
            "message": message,
            "data": data or {},
            "timestamp": datetime.utcnow().isoformat()
        }
    )
