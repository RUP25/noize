# 🚀 Quick Start Guide - NOIZE.music Project

## Prerequisites

1. **Docker Desktop** - [Download here](https://www.docker.com/products/docker-desktop)
2. **Flutter SDK** (3.0+) - [Install here](https://flutter.dev/docs/get-started/install)
3. **Cloudflare R2 Account** (optional for basic testing, required for uploads)

## Step-by-Step Setup

### 1. Start Backend Services (Docker)

Open a terminal in the project root and run:

```bash
# Start PostgreSQL and FastAPI backend
docker-compose up -d --build
```

**Wait for services to start** (about 30-60 seconds). Check logs:

```bash
docker-compose logs backend --tail=50
```

You should see:
```
INFO:     Uvicorn running on http://0.0.0.0:8000
INFO:     Application startup complete.
```

**Test the backend:**
```bash
curl http://localhost:8000/
# Should return: {"ok":true,"app":"noize-prototype"}
```

### 2. Configure Cloudflare R2 (Optional - for uploads)

If you want to test file uploads, create `backend/.env`:

```bash
cd backend
```

Create `.env` file with:
```env
DATABASE_URL=postgresql://noize:noizepass@db:5432/noize_db
R2_ENDPOINT=https://<your-account-id>.r2.cloudflarestorage.com
R2_ACCESS_KEY=<your-access-key>
R2_SECRET_KEY=<your-secret-key>
R2_BUCKET=noize-dev
```

**Note:** Without R2 credentials, the app will work but uploads will fail. You can still browse and test other features.

### 3. Setup Flutter App

```bash
cd flutter_app
flutter pub get
```

### 4. Run Flutter App

**For Web (Chrome):**
```bash
flutter run -d chrome
```

**For Android Emulator:**
```bash
# Make sure emulator is running first
flutter run
```

**For Physical Device:**
```bash
# Find your computer's IP address
# Windows: ipconfig
# Mac/Linux: ifconfig

# Run with your IP
flutter run --dart-define=API_BASE_URL=http://<your-ip>:8000
```

## Common Issues & Solutions

### Backend not starting?

1. **Check Docker is running:**
   ```bash
   docker ps
   ```

2. **Restart services:**
   ```bash
   docker-compose restart
   ```

3. **Check logs:**
   ```bash
   docker-compose logs backend
   docker-compose logs db
   ```

### "Failed to fetch" errors?

1. **Verify backend is running:**
   ```bash
   curl http://localhost:8000/
   ```

2. **Check if port 8000 is available:**
   ```bash
   # Windows
   netstat -ano | findstr :8000
   
   # Mac/Linux
   lsof -i :8000
   ```

3. **For web apps, ensure backend allows CORS** (already configured in `main.py`)

### Flutter can't connect to backend?

- **Web:** Use `http://127.0.0.1:8000` (default)
- **Android Emulator:** Use `http://10.0.2.2:8000` (default)
- **Physical Device:** Use your computer's local IP address

### Database connection errors?

```bash
# Restart database
docker-compose restart db

# Check database logs
docker-compose logs db
```

## Stopping the Project

```bash
# Stop all services
docker-compose down

# Stop and remove volumes (clears database)
docker-compose down -v
```

## Development Workflow

1. **Backend changes:** Auto-reloads with `--reload` flag (already enabled)
2. **Flutter changes:** Press `r` in terminal for hot reload, `R` for full restart
3. **Database changes:** Run migrations if you modify models

## Next Steps

1. ✅ Backend running on http://localhost:8000
2. ✅ Flutter app running
3. 🎵 Test the app:
   - Browse as Guest
   - Sign up as Listener
   - Create Artist channel
   - Upload music (requires R2 setup)

## API Documentation

Once backend is running, visit:
- **Swagger UI:** http://localhost:8000/docs
- **ReDoc:** http://localhost:8000/redoc
