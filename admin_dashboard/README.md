# NOIZE Admin CMS Dashboard

Web-based Content Management System for NOIZE.music administrators.

## Features

- **Dashboard**: Overview statistics and quick actions
- **Content Moderation**: Approve, reject, or flag uploaded songs
- **User Management**: View, suspend, activate, or promote users
- **Analytics**: Upload trends and user growth charts
- **Settings**: Feature toggles and platform configuration

## Tech Stack

- **Frontend**: React 18 + TypeScript
- **Build Tool**: Vite
- **State Management**: TanStack Query (React Query)
- **Charts**: Recharts
- **Icons**: Lucide React
- **Styling**: Inline styles (dark theme)

## Setup

1. Install dependencies:
```bash
npm install
```

2. Start development server:
```bash
npm run dev
```

The admin dashboard will be available at `http://localhost:3001`

## Configuration

The dashboard connects to the FastAPI backend at `http://localhost:8000` via proxy (configured in `vite.config.ts`).

## Admin Access

To create an admin user, you have several options:

### Option 1: Using the Admin User Script (Recommended)

The easiest way is to use the provided Python script:

**If using Docker:**
```bash
docker-compose exec backend python scripts/create_admin_user.py
```

**If running locally (Windows PowerShell):**
```powershell
cd backend
$env:DATABASE_URL="postgresql+asyncpg://noize:noizepass@localhost:5432/noize_db"
python scripts/create_admin_user.py
```

**If running locally (Windows CMD):**
```cmd
cd backend
set DATABASE_URL=postgresql+asyncpg://noize:noizepass@localhost:5432/noize_db
python scripts/create_admin_user.py
```

**If running locally (Linux/Mac):**
```bash
cd backend
export DATABASE_URL="postgresql+asyncpg://noize:noizepass@localhost:5432/noize_db"
python scripts/create_admin_user.py
```

The script will prompt you for:
- Admin email
- Admin password (minimum 6 characters)
- Phone number (required)

It will either create a new admin user or update an existing user to admin status.

### Option 2: Using SQL Directly

If you prefer to use SQL directly:

```sql
-- Make an existing user an admin (replace email with actual email)
UPDATE users SET is_admin = TRUE WHERE email = 'your-email@example.com';
```

### Option 3: Using Python Code

You can also create an admin user programmatically:

```python
from app.db import AsyncSessionLocal
from app.models import User
from app.password_utils import hash_password
from sqlalchemy import select

async def make_admin(email: str):
    async with AsyncSessionLocal() as db:
        result = await db.execute(select(User).where(User.email == email))
        user = result.scalars().first()
        if user:
            user.is_admin = True
            await db.commit()
            print(f"User '{email}' is now an admin!")
```

### After Creating Admin User

Once you've created an admin user:
1. Login to the admin dashboard at `http://localhost:3001` using the admin email and password
2. You'll have access to all admin features including content moderation, user management, and analytics

## Production Build

```bash
npm run build
```

The built files will be in the `dist` directory.
