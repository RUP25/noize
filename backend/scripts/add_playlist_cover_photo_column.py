"""
Script to add cover_photo_url column to the playlists table.
Run this script to add the cover_photo_url column to existing playlists table.
"""
import asyncio
import sys
from pathlib import Path

# Add parent directory to path to import app modules
sys.path.insert(0, str(Path(__file__).parent.parent))

from sqlalchemy import text
from app.db import engine


async def add_playlist_cover_photo_column():
    """Add cover_photo_url column to playlists table."""
    async with engine.begin() as conn:
        # Check if column already exists
        check_query = text("""
            SELECT column_name 
            FROM information_schema.columns 
            WHERE table_name='playlists' AND column_name='cover_photo_url'
        """)
        result = await conn.execute(check_query)
        exists = result.fetchone() is not None
        
        if not exists:
            # Add the column
            alter_query = text("""
                ALTER TABLE playlists 
                ADD COLUMN cover_photo_url VARCHAR
            """)
            await conn.execute(alter_query)
            print("Added cover_photo_url column to playlists table")
        else:
            print("cover_photo_url column already exists in playlists table")


if __name__ == "__main__":
    print("Starting migration: Adding cover_photo_url column to playlists table...")
    try:
        asyncio.run(add_playlist_cover_photo_column())
        print("Migration completed successfully!")
    except Exception as e:
        print(f"Error during migration: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
