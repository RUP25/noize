from fastapi import APIRouter, Body, HTTPException, Depends, Request
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
import secrets
from typing import Dict
from pydantic import BaseModel, validator
from .db import get_db
from .models import User
from .schemas import EmailPasswordLogin, EmailPasswordSignup
from .password_utils import hash_password, verify_password
from .redis_client import store_otp, get_otp, delete_otp, check_rate_limit

router = APIRouter()

# Fallback in-memory store (only used if Redis is unavailable)
_OTPS: Dict[str, str] = {}

class OTPRequest(BaseModel):
    contact: str

    @validator("contact")
    def strip_contact(cls, v: str) -> str:
        return v.strip()


class OTPVerify(BaseModel):
    contact: str
    otp: str

    @validator("contact", "otp")
    def strip_fields(cls, v: str) -> str:
        return v.strip()

@router.post("/otp/request")
async def request_otp(req: OTPRequest, request: Request):
    """Request OTP with rate limiting."""
    # Rate limiting: max 3 OTP requests per 15 minutes per IP
    try:
        client_ip = request.client.host if request.client else "unknown"
        rate_limit_key = f"ratelimit:otp_request:{client_ip}"
        is_allowed, remaining = await check_rate_limit(rate_limit_key, max_requests=3, window_seconds=900)
        
        if not is_allowed:
            raise HTTPException(
                status_code=429,
                detail=f"Too many OTP requests. Please try again later. Remaining: {remaining}"
            )
    except Exception as e:
        # If rate limiting fails (Redis unavailable), continue without it
        print(f"Rate limiting unavailable, continuing without it: {e}")
    
    # Generate OTP
    otp = f"{secrets.randbelow(900000)+100000}"
    
    # Store in Redis (with 5 minute expiry)
    try:
        await store_otp(req.contact, otp, expiry_seconds=300)
    except Exception as e:
        # Fallback to in-memory if Redis fails
        print(f"Redis error, using in-memory fallback: {e}")
        _OTPS[req.contact] = otp
    
    # In prod send via SMS/Email
    print(f"\n{'='*60}")
    print(f"📱 OTP for {req.contact}: {otp}")
    print(f"{'='*60}\n")
    return {"ok": True, "mock_otp": otp}

@router.post("/otp/verify")
async def verify_otp(req: OTPVerify):
    """Verify OTP with rate limiting."""
    # Rate limiting: max 5 verification attempts per 15 minutes per contact
    try:
        rate_limit_key = f"ratelimit:otp_verify:{req.contact}"
        is_allowed, remaining = await check_rate_limit(rate_limit_key, max_requests=5, window_seconds=900)
        
        if not is_allowed:
            raise HTTPException(
                status_code=429,
                detail=f"Too many verification attempts. Please request a new OTP. Remaining: {remaining}"
            )
    except HTTPException:
        raise
    except Exception as e:
        # If rate limiting fails (Redis unavailable), continue without it
        print(f"Rate limiting unavailable, continuing without it: {e}")
    
    # Try Redis first, fallback to in-memory
    expected = None
    try:
        expected = await get_otp(req.contact)
    except Exception as e:
        print(f"Redis error, checking in-memory fallback: {e}")
        expected = _OTPS.get(req.contact)
    
    if expected and expected == req.otp:
        # Delete OTP after successful verification (one-time use)
        try:
            await delete_otp(req.contact)
        except Exception:
            # Fallback cleanup
            _OTPS.pop(req.contact, None)
        
        # Return mock JWT token (NOT secure for prod)
        return {"access_token": f"mocktoken-{req.contact}", "token_type": "bearer"}
    
    raise HTTPException(status_code=400, detail="invalid_otp")

@router.post("/login/email")
async def login_email_password(req: EmailPasswordLogin, db: AsyncSession = Depends(get_db)):
    """Login with email and password."""
    result = await db.execute(select(User).where(User.email == req.email))
    user = result.scalars().first()
    
    if not user or not user.password_hash:
        raise HTTPException(status_code=401, detail="Invalid email or password")
    
    if not verify_password(req.password, user.password_hash):
        raise HTTPException(status_code=401, detail="Invalid email or password")
    
    # Return mock token (use contact for token generation to maintain compatibility)
    return {"access_token": f"mocktoken-{user.contact}", "token_type": "bearer"}

@router.post("/signup/email")
async def signup_email_password(req: EmailPasswordSignup, db: AsyncSession = Depends(get_db)):
    """Sign up with email and password."""
    # Check if email already exists
    result = await db.execute(select(User).where(User.email == req.email))
    if result.scalars().first():
        raise HTTPException(status_code=400, detail="Email already registered")
    
    # Check if contact already exists
    result = await db.execute(select(User).where(User.contact == req.contact))
    if result.scalars().first():
        raise HTTPException(status_code=400, detail="Phone number already registered")
    
    # Create new user
    password_hash = hash_password(req.password)
    new_user = User(
        contact=req.contact,
        email=req.email,
        password_hash=password_hash,
        is_artist=True  # Artists sign up through this endpoint
    )
    db.add(new_user)
    await db.commit()
    await db.refresh(new_user)
    
    return {"access_token": f"mocktoken-{new_user.contact}", "token_type": "bearer"}

@router.post("/introspect")
async def introspect(data: dict = Body(...)):
    """
    Simple token introspection endpoint for worker usage.
    For demo: accepts mocktoken-<contact>.
    """
    token = data.get("token")
    if not token or not token.startswith("mocktoken-"):
        return {"active": False}
    contact = token[len("mocktoken-"):]
    # Lazy DB lookup: import here to avoid circular import at startup
    from .db import AsyncSessionLocal
    from .models import User
    async with AsyncSessionLocal() as db:
        result = await db.execute(__import__("sqlalchemy").select(User).where(User.contact == contact))
        user = result.scalars().first()
        if not user:
            return {"active": False}
        return {
            "active": True,
            "contact": user.contact,
            "is_upgraded": user.is_upgraded,
            "is_artist": user.is_artist,
            "channel_name": user.channel_name,
        }

