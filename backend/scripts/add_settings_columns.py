#!/usr/bin/env python3
"""
Add settings columns to users table.
Run this script to update the database schema.
"""
import asyncio
import sys
import os

# Add parent directory to path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.db import AsyncSessionLocal
from sqlalchemy import text

async def add_columns():
    async with AsyncSessionLocal() as db:
        try:
            # Check if notification_settings column exists
            check_notif = await db.execute(text("""
                SELECT column_name 
                FROM information_schema.columns 
                WHERE table_name='users' AND column_name='notification_settings'
            """))
            notif_exists = check_notif.scalar() is not None
            
            # Check if privacy_settings column exists
            check_privacy = await db.execute(text("""
                SELECT column_name 
                FROM information_schema.columns 
                WHERE table_name='users' AND column_name='privacy_settings'
            """))
            privacy_exists = check_privacy.scalar() is not None
            
            # Check if language column exists
            check_lang = await db.execute(text("""
                SELECT column_name 
                FROM information_schema.columns 
                WHERE table_name='users' AND column_name='language'
            """))
            lang_exists = check_lang.scalar() is not None
            
            # Check if location column exists
            check_loc = await db.execute(text("""
                SELECT column_name 
                FROM information_schema.columns 
                WHERE table_name='users' AND column_name='location'
            """))
            loc_exists = check_loc.scalar() is not None
            
            if not notif_exists:
                print("Adding notification_settings column...")
                await db.execute(text("""
                    ALTER TABLE users 
                    ADD COLUMN notification_settings JSONB DEFAULT '{}'::jsonb
                """))
                print("✓ notification_settings column added")
            else:
                print("✓ notification_settings column already exists")
            
            if not privacy_exists:
                print("Adding privacy_settings column...")
                await db.execute(text("""
                    ALTER TABLE users 
                    ADD COLUMN privacy_settings JSONB DEFAULT '{}'::jsonb
                """))
                print("✓ privacy_settings column added")
            else:
                print("✓ privacy_settings column already exists")
            
            if not lang_exists:
                print("Adding language column...")
                await db.execute(text("""
                    ALTER TABLE users 
                    ADD COLUMN language VARCHAR DEFAULT 'en'
                """))
                print("✓ language column added")
            else:
                print("✓ language column already exists")
            
            if not loc_exists:
                print("Adding location column...")
                await db.execute(text("""
                    ALTER TABLE users 
                    ADD COLUMN location VARCHAR
                """))
                print("✓ location column added")
            else:
                print("✓ location column already exists")
            
            await db.commit()
            print("\n✅ Migration completed successfully!")
            
        except Exception as e:
            await db.rollback()
            print(f"❌ Error: {e}")
            raise

if __name__ == "__main__":
    asyncio.run(add_columns())
