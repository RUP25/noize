"""
Script to add merchandise and events tables to the database.
Run this script to create the new tables for merchandise and events.
"""
import asyncio
import sys
from pathlib import Path

# Add parent directory to path to import app modules
sys.path.insert(0, str(Path(__file__).parent.parent))

from sqlalchemy import text
from app.db import async_session_maker, engine


async def create_merchandise_table():
    """Create the merchandise table."""
    async with engine.begin() as conn:
        # Check if table already exists
        check_table = text("""
            SELECT EXISTS (
                SELECT FROM information_schema.tables 
                WHERE table_schema = 'public' 
                AND table_name = 'merchandise'
            );
        """)
        result = await conn.execute(check_table)
        exists = result.scalar()
        
        if exists:
            print("✅ Table 'merchandise' already exists, skipping creation")
            return
        
        # Create merchandise table
        create_table = text("""
            CREATE TABLE merchandise (
                id SERIAL PRIMARY KEY,
                title VARCHAR NOT NULL,
                description VARCHAR,
                price DOUBLE PRECISION NOT NULL,
                image_url VARCHAR,
                purchase_link VARCHAR,
                category VARCHAR,
                stock INTEGER,
                artist_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
            );
            
            CREATE INDEX idx_merchandise_artist_id ON merchandise(artist_id);
            CREATE INDEX idx_merchandise_created_at ON merchandise(created_at);
        """)
        
        await conn.execute(create_table)
        print("✅ Created 'merchandise' table")


async def create_events_table():
    """Create the events table."""
    async with engine.begin() as conn:
        # Check if table already exists
        check_table = text("""
            SELECT EXISTS (
                SELECT FROM information_schema.tables 
                WHERE table_schema = 'public' 
                AND table_name = 'events'
            );
        """)
        result = await conn.execute(check_table)
        exists = result.scalar()
        
        if exists:
            print("✅ Table 'events' already exists, skipping creation")
            return
        
        # Create events table
        create_table = text("""
            CREATE TABLE events (
                id SERIAL PRIMARY KEY,
                title VARCHAR NOT NULL,
                description VARCHAR,
                date DATE NOT NULL,
                time TIME NOT NULL,
                location VARCHAR NOT NULL,
                ticket_price DOUBLE PRECISION,
                artist_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
            );
            
            CREATE INDEX idx_events_artist_id ON events(artist_id);
            CREATE INDEX idx_events_date ON events(date);
            CREATE INDEX idx_events_created_at ON events(created_at);
        """)
        
        await conn.execute(create_table)
        print("✅ Created 'events' table")


async def main():
    """Main function to create tables."""
    print("🚀 Starting migration: Adding merchandise and events tables...")
    print("=" * 60)
    
    try:
        await create_merchandise_table()
        await create_events_table()
        
        print("=" * 60)
        print("✅ Migration completed successfully!")
        print("\nTables created:")
        print("  - merchandise")
        print("  - events")
        
    except Exception as e:
        print(f"❌ Error during migration: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
    finally:
        await engine.dispose()


if __name__ == "__main__":
    asyncio.run(main())
