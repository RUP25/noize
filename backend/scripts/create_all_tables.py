import asyncio
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))

from app.db import engine, Base
import app.models  # register metadata

async def create():
    try:
        async with engine.begin() as conn:
            await conn.run_sync(Base.metadata.create_all)
        print("Tables created successfully")
    except Exception as e:
        print(f"Error creating tables: {e}")
        import traceback
        traceback.print_exc()
        raise
    finally:
        await engine.dispose()

if __name__ == "__main__":
    asyncio.run(create())
