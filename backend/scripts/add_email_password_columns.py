#!/usr/bin/env python3
"""
Add email and password_hash columns to users table.
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
            # Check if email column exists
            check_email = await db.execute(text("""
                SELECT column_name 
                FROM information_schema.columns 
                WHERE table_name='users' AND column_name='email'
            """))
            email_exists = check_email.scalar() is not None
            
            # Check if password_hash column exists
            check_password = await db.execute(text("""
                SELECT column_name 
                FROM information_schema.columns 
                WHERE table_name='users' AND column_name='password_hash'
            """))
            password_exists = check_password.scalar() is not None
            
            if not email_exists:
                print("Adding email column...")
                await db.execute(text("""
                    ALTER TABLE users 
                    ADD COLUMN email VARCHAR UNIQUE
                """))
                await db.execute(text("CREATE INDEX IF NOT EXISTS ix_users_email ON users(email)"))
                print("✓ email column added")
            else:
                print("✓ email column already exists")
            
            if not password_exists:
                print("Adding password_hash column...")
                await db.execute(text("""
                    ALTER TABLE users 
                    ADD COLUMN password_hash VARCHAR
                """))
                print("✓ password_hash column added")
            else:
                print("✓ password_hash column already exists")
            
            await db.commit()
            print("\n✅ Migration completed successfully!")
            
        except Exception as e:
            await db.rollback()
            print(f"❌ Error: {e}")
            raise

if __name__ == "__main__":
    asyncio.run(add_columns())
