# Update Commands for Artist Dashboard Features

This document contains all the commands needed to apply the recent changes to the backend and Flutter app.

## 🚀 Quick Start - Run All Commands at Once

### Windows (PowerShell - Recommended)
```powershell
.\update_all.ps1
```

### Windows (Command Prompt)
```cmd
update_all.bat
```

### Linux/Mac (Bash)
```bash
chmod +x update_all.sh
./update_all.sh
```

**That's it!** The script will run all updates automatically.

---

## Manual Commands (If Needed)

## Backend Updates (Docker Commands)

### 1. Install New Python Dependencies

```bash
# Install passlib[bcrypt] for password hashing
docker-compose exec backend pip install passlib[bcrypt]==1.7.4

# Verify installation
docker-compose exec backend pip list | grep passlib
```

### 2. Run Database Migrations

```bash
# Add email and password_hash columns to users table
docker-compose exec backend python scripts/add_email_password_columns.py

# Add settings columns (notification_settings, privacy_settings, language, location)
docker-compose exec backend python scripts/add_settings_columns.py
```

### 3. Restart Backend Service

```bash
# Restart the backend to apply all changes
docker-compose restart backend

# Or if you want to see logs
docker-compose restart backend && docker-compose logs -f backend
```

### 4. Verify Backend is Running

```bash
# Check backend status
docker-compose ps backend

# Check backend logs for any errors
docker-compose logs backend --tail=50
```

## Flutter Updates

### 1. Navigate to Flutter App Directory

```bash
cd flutter_app
```

### 2. Install New Dependencies

```bash
# Install url_launcher and other dependencies
flutter pub get

# Verify installation
flutter pub deps
```

### 3. Run Flutter App

```bash
# For web (Chrome)
flutter run -d chrome

# For Android
flutter run -d android

# For iOS (Mac only)
flutter run -d ios

# List available devices
flutter devices
```

### 4. Hot Reload/Restart

```bash
# While app is running:
# Press 'r' for hot reload
# Press 'R' for hot restart
# Press 'q' to quit
```

## Complete Update Sequence

Run these commands in order:

```bash
# 1. Backend: Install dependencies
docker-compose exec backend pip install passlib[bcrypt]==1.7.4

# 2. Backend: Run migrations
docker-compose exec backend python scripts/add_email_password_columns.py
docker-compose exec backend python scripts/add_settings_columns.py

# 3. Backend: Restart
docker-compose restart backend

# 4. Flutter: Install dependencies
cd flutter_app
flutter pub get

# 5. Flutter: Run app
flutter run -d chrome
```

## Troubleshooting

### If Backend Migration Fails

```bash
# Check database connection
docker-compose exec backend python -c "from app.db import engine; print('DB OK')"

# Check if columns already exist
docker-compose exec backend python -c "
from app.db import AsyncSessionLocal
from sqlalchemy import text
import asyncio

async def check():
    async with AsyncSessionLocal() as db:
        result = await db.execute(text(\"SELECT column_name FROM information_schema.columns WHERE table_name='users'\"))
        print([r[0] for r in result])

asyncio.run(check())
"
```

### If Flutter Dependencies Fail

```bash
# Clean and reinstall
cd flutter_app
flutter clean
flutter pub get

# If still failing, check pubspec.yaml syntax
flutter pub upgrade
```

### Check Docker Services Status

```bash
# View all services
docker-compose ps

# View logs for all services
docker-compose logs

# Restart all services
docker-compose restart
```

## Verification Checklist

After running all commands, verify:

- [ ] Backend is running: `docker-compose ps backend`
- [ ] Backend logs show no errors: `docker-compose logs backend --tail=20`
- [ ] Flutter dependencies installed: `cd flutter_app && flutter pub get` (should show "Got dependencies")
- [ ] Flutter app runs without errors
- [ ] Can login with email/password in artist login
- [ ] Settings tab shows all options
- [ ] Support tab opens email/phone/URLs
- [ ] Feedback tab submits feedback

## Quick Reference

```bash
# Backend commands
docker-compose exec backend <command>          # Run command in backend container
docker-compose restart backend                 # Restart backend
docker-compose logs -f backend                 # Follow backend logs

# Flutter commands
cd flutter_app                                 # Navigate to Flutter app
flutter pub get                                # Install dependencies
flutter run -d chrome                         # Run on Chrome
flutter clean                                  # Clean build
```
