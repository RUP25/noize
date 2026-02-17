#!/usr/bin/env python3
"""
Migration script to add admin and moderation columns.
Run this once to update existing database schema.
"""
import asyncio
import sys
import os

# Add parent directory to path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.db import AsyncSessionLocal
from sqlalchemy import text


async def add_admin_columns():
    """Add is_admin, is_suspended to users and moderation_status to songs."""
    async with AsyncSessionLocal() as db:
        try:
            # Check if is_admin column exists
            check_admin = await db.execute(text("""
                SELECT column_name 
                FROM information_schema.columns 
                WHERE table_name='users' AND column_name='is_admin'
            """))
            admin_exists = check_admin.scalar() is not None
            
            # Check if is_suspended column exists
            check_suspended = await db.execute(text("""
                SELECT column_name 
                FROM information_schema.columns 
                WHERE table_name='users' AND column_name='is_suspended'
            """))
            suspended_exists = check_suspended.scalar() is not None
            
            # Check if moderation_status column exists
            check_moderation = await db.execute(text("""
                SELECT column_name 
                FROM information_schema.columns 
                WHERE table_name='songs' AND column_name='moderation_status'
            """))
            moderation_exists = check_moderation.scalar() is not None
            
            if not admin_exists:
                print("Adding is_admin column...")
                await db.execute(text("""
                    ALTER TABLE users 
                    ADD COLUMN is_admin BOOLEAN DEFAULT FALSE
                """))
                print("✓ is_admin column added")
            else:
                print("✓ is_admin column already exists")
            
            if not suspended_exists:
                print("Adding is_suspended column...")
                await db.execute(text("""
                    ALTER TABLE users 
                    ADD COLUMN is_suspended BOOLEAN DEFAULT FALSE
                """))
                print("✓ is_suspended column added")
            else:
                print("✓ is_suspended column already exists")
            
            if not moderation_exists:
                print("Adding moderation_status column...")
                await db.execute(text("""
                    ALTER TABLE songs 
                    ADD COLUMN moderation_status VARCHAR
                """))
                print("✓ moderation_status column added")
            else:
                print("✓ moderation_status column already exists")
            
            await db.commit()
            print("\n✅ Migration completed successfully!")
            
        except Exception as e:
            await db.rollback()
            error_msg = str(e)
            
            # Check for connection errors
            if "getaddrinfo failed" in error_msg or "could not translate host name" in error_msg.lower():
                print("\n❌ Database Connection Error!")
                print("=" * 60)
                print("Cannot connect to database. The default host 'db' is a Docker container name.")
                print("\nOptions:")
                print("1. Set DATABASE_URL environment variable:")
                print("   Windows PowerShell:")
                print('   $env:DATABASE_URL="postgresql+asyncpg://user:pass@localhost:5432/dbname"')
                print("   Windows CMD:")
                print('   set DATABASE_URL=postgresql+asyncpg://user:pass@localhost:5432/dbname')
                print("   Linux/Mac:")
                print('   export DATABASE_URL="postgresql+asyncpg://user:pass@localhost:5432/dbname"')
                print("\n2. Or run this script inside Docker:")
                print("   docker-compose exec backend python scripts/add_admin_columns.py")
                print("\n3. Or if using docker-compose, use:")
                print("   docker-compose exec db psql -U noize -d noize_db")
                print("   Then run the SQL commands manually (see below)")
                print("=" * 60)
                print("\nManual SQL commands (if you prefer to run directly):")
                print("ALTER TABLE users ADD COLUMN IF NOT EXISTS is_admin BOOLEAN DEFAULT FALSE;")
                print("ALTER TABLE users ADD COLUMN IF NOT EXISTS is_suspended BOOLEAN DEFAULT FALSE;")
                print("ALTER TABLE songs ADD COLUMN IF NOT EXISTS moderation_status VARCHAR;")
            else:
                print(f"\n❌ Error: {error_msg}")
            raise


if __name__ == "__main__":
    try:
        asyncio.run(add_admin_columns())
    except KeyboardInterrupt:
        print("\n\n⚠️  Migration cancelled by user")
        sys.exit(1)
    except Exception as e:
        sys.exit(1)
