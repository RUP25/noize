from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager
from .auth import router as auth_router
from .media import router as media_router
from .artist import router as artist_router
from .user import router as user_router
from .notifications import router as notifications_router
from .admin import router as admin_router
from .rate_limit import RateLimitMiddleware
from .redis_client import get_redis, close_redis


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Manage application lifespan: startup and shutdown."""
    # Startup: Initialize Redis connection
    try:
        await get_redis()
        print("✅ Redis connected")
    except Exception as e:
        print(f"⚠️  Redis connection failed (will use fallback): {e}")
    
    yield
    
    # Shutdown: Close Redis connection
    await close_redis()
    print("✅ Redis connection closed")


app = FastAPI(title="NOIZE Prototype Backend", lifespan=lifespan)

# Add rate limiting middleware (before CORS)
# Default: 100 requests per minute per IP per endpoint
app.add_middleware(RateLimitMiddleware, default_limit=100, window_seconds=60)

# Add CORS middleware to allow web requests
# For development: Allow all origins (credentials not strictly needed for Bearer token auth)
# In production, specify exact origins and enable credentials if needed
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Allow all origins for development
    allow_credentials=False,  # Set to False to allow wildcard origins
    allow_methods=["GET", "POST", "PUT", "DELETE", "OPTIONS", "PATCH"],
    allow_headers=["*"],
    expose_headers=["*"],
)

app.include_router(auth_router, prefix="/auth")
app.include_router(media_router)
# artist and user routers already define their own prefixes internally
app.include_router(artist_router)
app.include_router(user_router)
app.include_router(notifications_router)
app.include_router(admin_router)

@app.get("/")
async def root():
    return {"ok": True, "app": "noize-prototype"}
print("==== Registered routes ====")
for r in app.routes:
    try:
        print(r.path, r.methods)
    except Exception:
        pass
print("===========================")