#!/bin/bash

# NOIZE Update Script - Bash (Linux/Mac)
echo "========================================"
echo "NOIZE Update Script - Bash"
echo "========================================"
echo ""

set -e  # Exit on error

echo "[1/5] Installing backend dependencies..."
docker-compose exec backend pip install passlib[bcrypt]==1.7.4
echo "✓ Backend dependencies installed"
echo ""

echo "[2/5] Running database migration: email/password columns..."
docker-compose exec backend python scripts/add_email_password_columns.py || echo "WARNING: Migration may have failed or columns already exist"
echo ""

echo "[3/5] Running database migration: settings columns..."
docker-compose exec backend python scripts/add_settings_columns.py || echo "WARNING: Migration may have failed or columns already exist"
echo ""

echo "[4/5] Restarting backend service..."
docker-compose restart backend
echo "✓ Backend restarted"
echo ""

echo "[5/5] Installing Flutter dependencies..."
cd flutter_app
flutter pub get
echo "✓ Flutter dependencies installed"
cd ..
echo ""

echo "========================================"
echo "All updates completed successfully!"
echo "========================================"
echo ""
echo "Next steps:"
echo "- Backend is running on http://localhost:8000"
echo "- Run 'cd flutter_app && flutter run -d chrome' to start the app"
echo ""
