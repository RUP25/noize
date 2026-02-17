# backend/app/db.py
import os
import re
import ssl
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession
from sqlalchemy.orm import sessionmaker, declarative_base

# Read DATABASE_URL from env
raw_db_url = os.getenv("DATABASE_URL", "postgresql+asyncpg://noize:noizepass@db:5432/noize_db")

# If user supplied a sync-style URL (postgresql://...) convert to asyncpg scheme
if raw_db_url.startswith("postgresql://"):
    db_url = re.sub(r"^postgresql:", "postgresql+asyncpg:", raw_db_url)
else:
    db_url = raw_db_url

# Remove query params that asyncpg.connect() doesn't accept as kwargs (we'll pass ssl via connect_args)
# We'll keep the query string but strip sslmode and channel_binding from the DSN because asyncpg doesn't accept them as kwargs.
# The safest approach is to remove those params from the URL entirely and pass ssl param to asyncpg.
# Basic implementation: remove 'sslmode' and 'channel_binding' occurrences from the URL string.
db_url = re.sub(r"([?&])(sslmode|channel_binding)=[^&]*", "", db_url)
# Also clean up trailing '&' or '?' leftover
db_url = re.sub(r"[&?]$", "", db_url)

# Build an SSLContext for secure TLS. This uses system CA certificates.
# Only use SSL for production (when DATABASE_URL comes from an external provider)
ssl_ctx = None
if "localhost" not in db_url and "127.0.0.1" not in db_url and "db:" not in db_url:
    ssl_ctx = ssl.create_default_context()
    # If you need custom certs, load them here:
    # ssl_ctx.load_verify_locations(cafile="/path/to/ca.pem")

# Create engine with connect_args to pass ssl context to asyncpg
connect_args = {}
if ssl_ctx is not None:
    connect_args["ssl"] = ssl_ctx

engine = create_async_engine(
    db_url,
    echo=False,
    pool_size=10,
    max_overflow=20,
    pool_pre_ping=True,
    pool_recycle=3600,
    connect_args=connect_args,
)

AsyncSessionLocal = sessionmaker(bind=engine, class_=AsyncSession, expire_on_commit=False)
Base = declarative_base()

async def get_db():
    async with AsyncSessionLocal() as session:
        yield session
