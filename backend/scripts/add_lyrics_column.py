import asyncio
import sys
import os

# Add parent directory to path to import app module
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.db import engine
from sqlalchemy import text

async def add_column():
    async with engine.begin() as conn:
        # Check if column exists
        check_query = text("""
            SELECT column_name 
            FROM information_schema.columns 
            WHERE table_name='songs' AND column_name='lyrics'
        """)
        result = await conn.execute(check_query)
        exists = result.fetchone() is not None
        
        if not exists:
            # Add the column as TEXT type (for potentially long lyrics)
            alter_query = text("""
                ALTER TABLE songs 
                ADD COLUMN lyrics TEXT
            """)
            await conn.execute(alter_query)
            print("✓ Added lyrics column to songs table")
        else:
            print("✓ lyrics column already exists")

if __name__ == "__main__":
    asyncio.run(add_column())
