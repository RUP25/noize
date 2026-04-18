#!/usr/bin/env python3
"""Simple script to add lyrics column to songs table."""
import asyncio
import sys
import os

# Add parent directory to path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.db import engine
from sqlalchemy import text

async def add_lyrics_column():
    """Add lyrics column to songs table if it doesn't exist."""
    try:
        async with engine.begin() as conn:
            # Use IF NOT EXISTS equivalent for PostgreSQL
            check_query = text("""
                SELECT column_name 
                FROM information_schema.columns 
                WHERE table_name='songs' AND column_name='lyrics'
            """)
            result = await conn.execute(check_query)
            exists = result.fetchone() is not None
            
            if not exists:
                alter_query = text("ALTER TABLE songs ADD COLUMN lyrics TEXT")
                await conn.execute(alter_query)
                print("✅ Successfully added lyrics column to songs table")
            else:
                print("✅ lyrics column already exists")
    except Exception as e:
        print(f"❌ Error: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
    finally:
        await engine.dispose()

if __name__ == "__main__":
    asyncio.run(add_lyrics_column())
