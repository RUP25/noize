@echo off
echo ========================================
echo Flutter App - API Configuration Helper
echo ========================================
echo.
echo Your local IP: 192.168.31.113
echo Backend should be running at: http://localhost:8000
echo.
echo Choose platform:
echo   1. Web (Chrome) - uses localhost:8000
echo   2. Android Emulator - uses 10.0.2.2:8000  
echo   3. Physical Device - uses 192.168.31.113:8000
echo   4. iOS Simulator - uses 127.0.0.1:8000
echo.
set /p platform="Enter choice (1-4, default=1): "
if "%platform%"=="" set platform=1

cd flutter_app

if "%platform%"=="1" (
    echo.
    echo Running on Web (Chrome) with localhost:8000...
    echo If you see connection errors, try option 3 with your IP address.
    flutter run -d chrome
) else if "%platform%"=="2" (
    echo.
    echo Running on Android Emulator with 10.0.2.2:8000...
    flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
) else if "%platform%"=="3" (
    echo.
    echo Running with your local IP: 192.168.31.113:8000
    echo Make sure your device/emulator is on the same network!
    flutter run --dart-define=API_BASE_URL=http://192.168.31.113:8000
) else if "%platform%"=="4" (
    echo.
    echo Running on iOS Simulator with 127.0.0.1:8000...
    flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8000
) else (
    echo Invalid choice. Running on Chrome...
    flutter run -d chrome
)
