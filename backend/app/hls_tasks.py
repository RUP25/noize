import os
import asyncio

import dramatiq
from dramatiq.brokers.redis import RedisBroker

# Configure Redis broker for Dramatiq
REDIS_HOST = os.getenv("REDIS_HOST", "redis")
REDIS_PORT = int(os.getenv("REDIS_PORT", 6379))
REDIS_DB = int(os.getenv("REDIS_DB", 0))
REDIS_PASSWORD = os.getenv("REDIS_PASSWORD", None)

broker = RedisBroker(
    host=REDIS_HOST,
    port=REDIS_PORT,
    db=REDIS_DB,
    password=REDIS_PASSWORD,
)
dramatiq.set_broker(broker)

from .media import _generate_hls_from_audio


@dramatiq.actor(max_retries=5, time_limit=10 * 60)  # 10 minute time limit
def generate_hls_for_key(key: str) -> None:
    """
    Background job to generate HLS assets for a given R2 object key.

    This wraps the existing async _generate_hls_from_audio helper so it can be
    run safely inside a Dramatiq worker process.
    """
    # Run the async function in a fresh event loop
    asyncio.run(_generate_hls_from_audio(key))

