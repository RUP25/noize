# Flutter App Connection Fix

## Problem
Login works but loading songs fails with: "Cannot connect to server at http://localhost:8000"

## Root Cause
The app is using `http://localhost:8000` which works for login but may fail for other endpoints due to:
1. **Platform differences**: On web, `localhost` works. On physical devices/emulators, you need your computer's IP
2. **CORS issues**: Some browsers block certain requests
3. **Channel name**: The channel might not exist yet

## Solutions

### Solution 1: Run with Your IP Address (Recommended for Physical Devices)

```bash
cd flutter_app
flutter run --dart-define=API_BASE_URL=http://192.168.31.113:8000
```

### Solution 2: Use the Helper Script

```bash
.\run_flutter_with_api.bat
```
Choose option 3 for physical device or option 1 for web.

### Solution 3: Check Your Channel Name

If you just logged in and don't have a channel yet:
1. Go to the Artist tab
2. Create a channel first
3. Then try loading songs

### Solution 4: For Web (Chrome)

If running on web and still getting errors:
```bash
cd flutter_app
flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:8000
```

## Debug Information

The updated code now includes debug logging. Check your Flutter console for:
- 🔍 The URL being requested
- ✅/⚠️ Auth token status
- 📥 Response status codes
- ❌ Error details

## Verify Backend is Running

```bash
curl http://localhost:8000/
# Should return: {"ok":true,"app":"noize-prototype"}
```

## Common Issues

1. **"Channel not found"**: Create a channel first in the Artist tab
2. **"Cannot connect"**: Use your IP address instead of localhost
3. **"Timeout"**: Check if backend is running and accessible
