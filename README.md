# 🎵 NOIZE.music - Decentralized Music Platform Prototype

A full-stack music streaming and discovery platform built with Flutter and FastAPI, featuring multiple user roles, cloud storage integration, and a modern decentralized architecture.

## 📋 Table of Contents

- [Features](#features)
- [Architecture](#architecture)
- [Tech Stack](#tech-stack)
- [Project Structure](#project-structure)
- [Prerequisites](#prerequisites)
- [Setup & Installation](#setup--installation)
- [Running the Application](#running-the-application)
- [User Roles & Features](#user-roles--features)
- [API Documentation](#api-documentation)
- [Development Notes](#development-notes)
- [Troubleshooting](#troubleshooting)

## ✨ Features

### Core Functionality
- 🎧 **Audio Streaming**: Real-time MP3 playback with Cloudflare R2
- 📤 **Music Upload**: Direct upload to cloud storage with metadata
- 🔍 **Unified Search**: Search songs, albums, and channels
- 👥 **Multi-Role System**: Guest, Listener, Artist, and more
- 🔐 **OTP Authentication**: Mock SMS/Email authentication for demo
- 📱 **Cross-Platform**: Flutter app for Android, iOS, and web

### User Experience
- 🎨 **Modern UI**: Dark theme with vibrant accent colors
- 📑 **Album Grouping**: Organize tracks by album
- ❤️ **Likes & Follows**: Social features for engagement
- 🎵 **Playlists**: Create and manage music collections
- 🚀 **Guest Mode**: Explore without signing up

## 🏗️ Architecture

```
┌─────────────────┐
│  Flutter App    │  ← UI Layer (Mobile/Web)
│  (Client)       │
└────────┬────────┘
         │ HTTP/REST
         ▼
┌─────────────────┐
│   FastAPI       │  ← Backend API
│   (Backend)     │
└────────┬────────┘
         │
    ┌────┴────┐
    ▼         ▼
┌────────┐  ┌──────────────┐
│ Postgres│  │ Cloudflare R2│  ← Data & Media Storage
│   DB    │  │   (Storage)   │
└────────┘  └──────────────┘
```

## 🛠️ Tech Stack

### Frontend (Flutter)
- **Framework**: Flutter 3.0+
- **Language**: Dart 3.0+
- **State Management**: Provider
- **HTTP Client**: `http` package
- **Audio Playback**: `just_audio`
- **File Selection**: `file_selector`
- **Local Storage**: `shared_preferences`

### Backend (FastAPI)
- **Framework**: FastAPI 0.95.2
- **Runtime**: Python 3.11
- **ASGI Server**: Uvicorn
- **ORM**: SQLAlchemy 1.4.49 (async)
- **Database Driver**: asyncpg 0.27.0
- **Cloud Storage**: boto3 (Cloudflare R2 compatible)

### Infrastructure
- **Database**: PostgreSQL 15
- **Storage**: Cloudflare R2
- **Containerization**: Docker & Docker Compose
- **Dev Server**: Hot reload enabled

## 📁 Project Structure

```
noize_prototype_repo/
├── backend/
│   ├── app/
│   │   ├── main.py              # FastAPI app entry
│   │   ├── db.py                # Database config
│   │   ├── models.py            # SQLAlchemy models
│   │   ├── schemas.py           # Pydantic schemas
│   │   ├── auth.py              # OTP authentication
│   │   ├── auth_integration.py  # Auth middleware
│   │   ├── artist.py            # Artist endpoints
│   │   ├── media.py             # Media upload/download
│   │   └── user.py              # User management
│   ├── scripts/                 # Database migrations
│   ├── Dockerfile               # Backend container
│   └── requirements.txt         # Python dependencies
│
├── flutter_app/
│   ├── lib/
│   │   ├── config/
│   │   │   └── api_config.dart  # API URL config
│   │   ├── screens/
│   │   │   ├── splash_screen.dart
│   │   │   ├── welcome_screen.dart
│   │   │   ├── login_screen.dart
│   │   │   ├── guest_home_screen.dart
│   │   │   └── listener_home_screen.dart
│   │   ├── services/
│   │   │   ├── auth_service.dart
│   │   │   ├── media_service.dart
│   │   │   └── upload_service.dart
│   │   ├── widgets/
│   │   │   ├── artist_tab.dart
│   │   │   ├── artist_channel_page.dart
│   │   │   ├── listener_search_tab.dart
│   │   │   └── listener_login_tab.dart
│   │   └── main.dart            # App entry
│   ├── android/                 # Android config
│   └── pubspec.yaml             # Flutter dependencies
│
├── docker-compose.yml           # Multi-container setup
└── README.md                    # This file
```

## 📦 Prerequisites

Before starting, ensure you have:

1. **Docker & Docker Compose** (v20.10+)
   - [Install Docker Desktop](https://www.docker.com/products/docker-desktop)

2. **Flutter SDK** (v3.0+)
   - [Install Flutter](https://flutter.dev/docs/get-started/install)

3. **Cloudflare R2 Account** (free tier works)
   - [Sign up for Cloudflare](https://www.cloudflare.com/)
   - Create an R2 bucket
   - Generate API tokens

4. **Git** (for cloning)

## 🚀 Setup & Installation

### 1. Clone the Repository

```bash
git clone <repository-url>
cd noize_prototype_repo
```

### 2. Configure Cloudflare R2

Create a `.env` file in the `backend/` directory:

```bash
cd backend
cat > .env << EOF
DATABASE_URL=postgresql://noize:noizepass@db:5432/noize_db
R2_ENDPOINT=https://<your-account-id>.r2.cloudflarestorage.com
R2_ACCESS_KEY=<your-access-key>
R2_SECRET_KEY=<your-secret-key>
R2_BUCKET=noize-dev
EOF
cd ..
```

**Important**: Replace the placeholders with your actual Cloudflare R2 credentials.

### 3. Build and Start Backend Services

```bash
docker-compose up -d --build
```

This will:
- Pull PostgreSQL image
- Build the FastAPI backend container
- Start both services
- Set up database volumes

### 4. Verify Backend is Running

Check the logs:
```bash
docker-compose logs backend --tail=50
```

You should see:
```
INFO:     Uvicorn running on http://0.0.0.0:8000
INFO:     Application startup complete.
==== Registered routes ====
...
```

Test the API:
```bash
curl http://localhost:8000/
# Expected: {"ok":true,"app":"noize-prototype"}
```

### 5. Setup Flutter App

```bash
cd flutter_app
flutter pub get
```

### 6. Run Flutter App

**On Android Emulator:**
```bash
flutter run
```

**On Physical Device:**
```bash
# Find your local IP address
ipconfig  # Windows
ifconfig  # Mac/Linux

# Run with custom API URL
flutter run --dart-define=API_BASE_URL=http://<your-ip>:8000
```

**On iOS Simulator (Mac only):**
```bash
open -a Simulator
flutter run
```

## 🎮 User Roles & Features

### 1️⃣ NOIZE Guest
**Features:**
- Browse pre-seeded tracks
- View Top 50 Charts
- Limited playback options
- Search preview
- **Sign Up**: No registration required

**Navigation:** `Welcome Screen` → `Continue as Guest`

### 2️⃣ NOIZE Listen
**Features:**
- Full music library access
- Search songs, albums, channels
- Like and follow artists
- Create playlists
- Personalized home feed

**Authentication:** 
- Phone/Email OTP
- Username creation on signup

**Navigation:** `Welcome Screen` → `Sign In / Sign Up`

### 3️⃣ NOIZE Artist
**Features:**
- Create branded channel
- Upload MP3 tracks
- Organize by albums
- View track analytics
- Manage metadata

**Signup Flow:**
1. `Welcome Screen` → `Sign Up as Artist`
2. Enter channel name
3. Upload music files
4. Add metadata (title, album)

**Navigation:** `Artist Tab` → `Create Channel` / `Open My Channel`

## 📡 API Documentation

Once the backend is running, visit:

- **Interactive Docs**: http://localhost:8000/docs
- **ReDoc**: http://localhost:8000/redoc
- **OpenAPI Schema**: http://localhost:8000/openapi.json

### Key Endpoints

#### Authentication
```
POST /auth/otp/request     # Request OTP
POST /auth/otp/verify      # Verify OTP and get token
```

#### Media
```
POST /media/upload-presign              # Get presigned upload URL
GET  /media/download/{key:path}         # Get presigned download URL
```

#### Artist
```
GET  /artist/{channel_name}             # Get artist's songs
POST /artist/create                      # Create channel
POST /artist/metadata                    # Register uploaded song
POST /artist/{channel_name}/follow       # Follow artist
POST /artist/song/{song_id}/like         # Like song
GET  /artist/search?q={query}            # Search artists
```

#### User
```
GET  /user/me             # Get current user info
POST /user/upgrade         # Upgrade to premium
```

## 🔧 Development Notes

### Hot Reload

**Backend:** Changes to `backend/app/` are automatically picked up by Uvicorn reloader.

**Flutter:** Press `r` in the terminal to hot reload, `R` for full restart.

### Database Migrations

Run Alembic migrations:
```bash
docker-compose exec backend alembic upgrade head
```

Create a new migration:
```bash
docker-compose exec backend alembic revision --autogenerate -m "description"
```

### Testing OTP

OTP values are printed to the console for demo purposes:
```
============================================================
📱 OTP for <phone>: 540628
============================================================
```

### Android Development

For local development on Android, the app uses cleartext HTTP. Production builds should enforce HTTPS.

Configuration: `flutter_app/android/app/src/main/AndroidManifest.xml`
```xml
<application
    android:usesCleartextTraffic="true">
```

### Production Deployment

For production:
1. Remove debug `print()` statements
2. Configure real SMS/Email OTP service
3. Enforce HTTPS on all endpoints
4. Remove `--reload` from Uvicorn command
5. Use production PostgreSQL with SSL
6. Set proper CORS origins
7. Configure rate limiting
8. Enable file validation on upload

## 🐛 Troubleshooting

### Issue: "Already has a channel" error
**Solution:** Each user can only have one channel. Use the "Open My Channel" button if you already created one.

### Issue: "connection is closed" (asyncpg)
**Solution:** Ensure Docker containers are properly started:
```bash
docker-compose restart backend
```

### Issue: Audio playback fails (404)
**Solution:** 
1. Verify Cloudflare R2 credentials in `.env`
2. Check backend logs: `docker-compose logs backend --tail=50`
3. Ensure the uploaded file exists in R2

### Issue: "Failed to fetch songs: 500"
**Solution:** Check database connection and migrations:
```bash
docker-compose exec db psql -U noize -d noize_db
```

### Issue: Flutter can't connect to backend
**Solution:** 
- **Emulator**: Use `http://10.0.2.2:8000` (default)
- **Physical Device**: Use `http://<your-local-ip>:8000`
- Verify backend is running: `curl http://localhost:8000/`

### Issue: Android playback blocked
**Solution:** Ensure `android:usesCleartextTraffic="true"` is in AndroidManifest.xml

### Issue: Hot reload not working
**Solution:** 
- **Backend**: Restart with `docker-compose restart backend`
- **Flutter**: Press `R` for full restart

## 📝 License

This is a prototype project for demonstration purposes.

## 🤝 Contributing

Contributions are welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Open a Pull Request

## 📧 Contact

For questions or support, please open an issue on GitHub.

---

**Built with ❤️ for the decentralized music revolution 🎵**
