#!/usr/bin/env python3
"""Add banner_url and photo_url columns to users table if missing."""
import asyncio
import sys
import os

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.db import AsyncSessionLocal
from sqlalchemy import text

COLUMNS = [
    ("banner_url", "VARCHAR"),
    ("photo_url", "VARCHAR"),
]

async def add_columns():
    async with AsyncSessionLocal() as db:
        try:
            for name, sql_type in COLUMNS:
                exists = (await db.execute(text(
                    """
                    SELECT 1
                    FROM information_schema.columns
                    WHERE table_schema='public' AND table_name='users' AND column_name=:c
                    """),
                    {"c": name}
                )).scalar() is not None

                if exists:
                    print(f"âœ“ {name} already exists")
                    continue

                print(f"Adding {name}...")
                await db.execute(text(f"ALTER TABLE users ADD COLUMN {name} {sql_type}"))
                print(f"âœ“ {name} added")

            await db.commit()
            print("\nâœ… Done")
        except Exception as e:
            await db.rollback()
            print(f"âŒ Error: {e}")
            raise

if __name__ == '__main__':
    asyncio.run(add_columns())
