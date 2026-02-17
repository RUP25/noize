# NOIZE Admin CMS Setup Guide

## Overview

A complete Content Management System for NOIZE.music administrators, built with:
- **Backend**: FastAPI (Python) - Admin API endpoints
- **Frontend**: React + TypeScript + Vite - Modern admin dashboard

## Features

✅ **Dashboard**: Platform statistics and quick actions  
✅ **Content Moderation**: Approve/reject/flag uploaded songs  
✅ **User Management**: View, suspend, activate, promote users  
✅ **Analytics**: Upload trends and user growth charts  
✅ **Settings**: Feature toggles and platform configuration  

## Backend Setup

### 1. Run Database Migration

Add admin columns to existing database.

**Option A: Run inside Docker (Recommended)**

If you're using docker-compose:

```bash
docker-compose exec backend python scripts/add_admin_columns.py
```

**Option B: Run locally (outside Docker)**

If running locally, you need to set the `DATABASE_URL` environment variable first:

**Windows PowerShell:**
```powershell
cd backend
$env:DATABASE_URL="postgresql+asyncpg://noize:noizepass@localhost:5432/noize_db"
python scripts/add_admin_columns.py
```

**Windows CMD:**
```cmd
cd backend
set DATABASE_URL=postgresql+asyncpg://noize:noizepass@localhost:5432/noize_db
python scripts/add_admin_columns.py
```

**Linux/Mac:**
```bash
cd backend
export DATABASE_URL="postgresql+asyncpg://noize:noizepass@localhost:5432/noize_db"
python scripts/add_admin_columns.py
```

**Option C: Run SQL manually**

If you prefer to run SQL directly:

```bash
# If using docker-compose
docker-compose exec db psql -U noize -d noize_db

# Then run these SQL commands:
ALTER TABLE users ADD COLUMN IF NOT EXISTS is_admin BOOLEAN DEFAULT FALSE;
ALTER TABLE users ADD COLUMN IF NOT EXISTS is_suspended BOOLEAN DEFAULT FALSE;
ALTER TABLE songs ADD COLUMN IF NOT EXISTS moderation_status VARCHAR;
```

**Note**: 
- Make sure the database is running and accessible
- Adjust the connection string (user, password, host, port, database) to match your setup
- The script checks if columns already exist, so it's safe to run multiple times

This adds:
- `is_admin` and `is_suspended` columns to `users` table
- `moderation_status` column to `songs` table

### 2. Create Admin User

You need to manually set a user as admin in the database:

```sql
-- Example: Make a user admin (replace email with actual admin email)
UPDATE users SET is_admin = TRUE WHERE email = 'admin@noize.music';
```

Or use Python:

```python
from app.db import AsyncSessionLocal
from app.models import User
from sqlalchemy import select

async def create_admin():
    async with AsyncSessionLocal() as db:
        result = await db.execute(select(User).where(User.email == 'admin@noize.music'))
        user = result.scalars().first()
        if user:
            user.is_admin = True
            await db.commit()
            print("Admin user created!")
```

### 3. Start Backend Server

```bash
cd backend
uvicorn app.main:app --reload --port 8000
```

Admin API endpoints are available at:
- `GET /admin/stats` - Dashboard statistics
- `GET /admin/content/songs/pending` - Pending songs
- `POST /admin/content/songs/moderate` - Moderate a song
- `GET /admin/users` - List users
- `POST /admin/users/manage` - Manage user (suspend/activate/promote)
- `GET /admin/analytics/upload-trends` - Upload trends
- `GET /admin/features` - Feature toggles
- `POST /admin/features/toggle` - Toggle feature

## Frontend Setup

### 1. Install Dependencies

```bash
cd admin_dashboard
npm install
```

### 2. Start Development Server

```bash
npm run dev
```

The admin dashboard will be available at `http://localhost:3001`

### 3. Login

Use the admin user credentials (email/password) you created in the backend setup.

## Production Build

### Frontend

```bash
cd admin_dashboard
npm run build
```

The built files will be in `admin_dashboard/dist/`. Serve these with any static file server (nginx, Apache, etc.).

### Backend

The admin endpoints are already part of the main FastAPI app. Deploy as usual.

## API Authentication

All admin endpoints require:
1. Valid JWT token (from `/auth/login/email`)
2. User must have `is_admin = True` in database

The frontend automatically includes the token in requests after login.

## Content Moderation Workflow

1. Songs uploaded by artists are created with `moderation_status = NULL` (pending)
2. Admins see pending songs in the Content Moderation page
3. Admins can:
   - **Approve**: Sets status to `approved` (song is visible to users)
   - **Reject**: Sets status to `rejected` (song is hidden)
   - **Flag**: Sets status to `flagged` (requires review)

## User Management

Admins can:
- **Suspend**: Set `is_suspended = True` (user cannot login)
- **Activate**: Set `is_suspended = False` (restore access)
- **Promote to Admin**: Set `is_admin = True` (grant admin access)
- **Delete**: Remove user account (use with caution)

## Feature Toggles

Currently available toggles:
- `new_user_registration` - Enable/disable new signups
- `song_uploads` - Enable/disable song uploads
- `playlist_sharing` - Enable/disable playlist sharing
- `donation_features` - Enable/disable donation features
- `rep_program` - Enable/disable REP program
- `kyc_verification` - Enable/disable KYC verification

## Security Notes

⚠️ **Important**: 
- Admin endpoints are protected by `get_admin_user()` dependency
- Only users with `is_admin = True` can access admin routes
- In production, use proper JWT token validation (not mock tokens)
- Consider adding rate limiting to admin endpoints
- Add audit logging for admin actions

## Troubleshooting

### "Admin access required" error
- Verify user has `is_admin = True` in database
- Check that JWT token is valid and included in request headers

### Frontend can't connect to backend
- Verify backend is running on `http://localhost:8000`
- Check CORS settings in `backend/app/main.py`
- Verify proxy configuration in `admin_dashboard/vite.config.ts`

### Database migration fails
- Ensure database connection is working
- Check that tables `users` and `songs` exist
- Columns may already exist (safe to run multiple times)

## Next Steps

- Add audit logging for admin actions
- Implement bulk moderation actions
- Add email notifications for moderation decisions
- Create admin activity logs dashboard
- Add more granular permissions (e.g., content-only admin, user-only admin)
