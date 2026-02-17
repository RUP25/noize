import asyncio
from app.db import engine
from sqlalchemy import text

async def add_column():
    async with engine.begin() as conn:
        # Check if column exists
        check_query = text("""
            SELECT column_name 
            FROM information_schema.columns 
            WHERE table_name='songs' AND column_name='cover_photo_url'
        """)
        result = await conn.execute(check_query)
        exists = result.fetchone() is not None
        
        if not exists:
            # Add the column
            alter_query = text("""
                ALTER TABLE songs 
                ADD COLUMN cover_photo_url VARCHAR
            """)
            await conn.execute(alter_query)
            print("✓ Added cover_photo_url column to songs table")
        else:
            print("✓ cover_photo_url column already exists")

if __name__ == "__main__":
    asyncio.run(add_column())
