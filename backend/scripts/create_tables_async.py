import asyncio
from app.db import engine, Base
import app.models  # register metadata

async def create():
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    print("Tables created")

if __name__ == "__main__":
    asyncio.run(create())
