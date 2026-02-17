import asyncio
from app.db import AsyncSessionLocal
from sqlalchemy import text

async def main():
    async with AsyncSessionLocal() as db:
        tables = (await db.execute(text("select table_name from information_schema.tables where table_schema='public' order by table_name"))).scalars().all()
        print('tables:', tables)
        cols = (await db.execute(text("select column_name,data_type,udt_name,is_nullable,column_default from information_schema.columns where table_schema='public' and table_name='users' order by ordinal_position"))).all()
        print('users columns:')
        for c in cols:
            print(' -', c)

asyncio.run(main())
