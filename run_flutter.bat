@echo off
echo Starting Flutter app...
echo.
echo Your local IP address: 192.168.31.113
echo.
echo Choose how to run:
echo 1. Web (Chrome) - uses localhost:8000
echo 2. Android Emulator - uses 10.0.2.2:8000 (default)
echo 3. Physical Device - uses your IP: 192.168.31.113:8000
echo.
set /p choice="Enter choice (1-3, default=1): "
if "%choice%"=="" set choice=1
if "%choice%"=="1" (
    cd flutter_app
    flutter run -d chrome
) else if "%choice%"=="2" (
    cd flutter_app
    flutter run
) else if "%choice%"=="3" (
    cd flutter_app
    flutter run --dart-define=API_BASE_URL=http://192.168.31.113:8000
) else (
    echo Invalid choice. Running on Chrome...
    cd flutter_app
    flutter run -d chrome
)
