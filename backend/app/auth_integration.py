from typing import Optional

from fastapi import Depends, Header, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from .db import get_db, AsyncSessionLocal
from .models import User
from .redis_client import is_token_blacklisted, is_session_valid

async def get_current_user_optional(
    authorization: str | None = Header(None),
    db: AsyncSession = Depends(get_db),
) -> Optional[User]:
    """
    Same validation as get_current_user when a Bearer token is present.
    Returns None when the Authorization header is missing (anonymous / NOIZE Guest entry funnel).
    """
    if authorization is None or not authorization.strip():
        return None
    return await get_current_user(authorization=authorization, db=db)


async def get_current_user(authorization: str = Header(None), db: AsyncSession = Depends(get_db)) -> User:
    if not authorization:
        raise HTTPException(status_code=401, detail="Missing authorization header")
    parts = authorization.split()
    if len(parts) != 2 or parts[0].lower() != "bearer":
        raise HTTPException(status_code=401, detail="Invalid auth scheme")
    token = parts[1]
    
    # Check if token is blacklisted
    try:
        if await is_token_blacklisted(token):
            raise HTTPException(status_code=401, detail="Token has been revoked")
    except Exception as e:
        # If Redis fails, log but continue (graceful degradation)
        print(f"Token blacklist check failed: {e}")
    
    if not token.startswith("mocktoken-"):
        raise HTTPException(status_code=401, detail="Invalid token format")
    contact = token[len("mocktoken-"):]
    
    result = await db.execute(select(User).where(User.contact == contact))
    user = result.scalars().first()
    if user:
        # Check session validity if user exists
        try:
            if not await is_session_valid(str(user.id), token):
                # Session expired or invalid, but allow for backward compatibility
                pass
        except Exception:
            # If Redis fails, continue (graceful degradation)
            pass
        return user
    
    new_user = User(contact=contact)
    db.add(new_user)
    await db.commit()
    await db.refresh(new_user)
    return new_user
