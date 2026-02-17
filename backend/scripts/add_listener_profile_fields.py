"""
Add listener profile fields to users table:
- full_name (TEXT)
- date_of_birth (DATE)

Run:
  python scripts/add_listener_profile_fields.py
"""
import asyncio
import sys
import os

# Add parent directory to path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.db import AsyncSessionLocal
from sqlalchemy import text


async def main():
    async with AsyncSessionLocal() as db:
        try:
            # Check if full_name column exists
            check_full_name = await db.execute(text("""
                SELECT column_name 
                FROM information_schema.columns 
                WHERE table_name='users' AND column_name='full_name'
            """))
            full_name_exists = check_full_name.scalar() is not None
            
            # Check if date_of_birth column exists
            check_dob = await db.execute(text("""
                SELECT column_name 
                FROM information_schema.columns 
                WHERE table_name='users' AND column_name='date_of_birth'
            """))
            dob_exists = check_dob.scalar() is not None
            
            if not full_name_exists:
                print("Adding full_name column...")
                await db.execute(text("ALTER TABLE users ADD COLUMN full_name TEXT"))
                print("✓ full_name column added")
            else:
                print("✓ full_name column already exists")
            
            if not dob_exists:
                print("Adding date_of_birth column...")
                await db.execute(text("ALTER TABLE users ADD COLUMN date_of_birth DATE"))
                print("✓ date_of_birth column added")
            else:
                print("✓ date_of_birth column already exists")
            
            await db.commit()
            print("\n✅ Migration completed successfully!")
            
        except Exception as e:
            await db.rollback()
            print(f"❌ Error: {e}")
            raise


if __name__ == "__main__":
    asyncio.run(main())

