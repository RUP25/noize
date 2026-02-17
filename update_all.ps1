# NOIZE Update Script - PowerShell
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "NOIZE Update Script - PowerShell" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$ErrorActionPreference = "Stop"

try {
    Write-Host "[1/5] Installing backend dependencies..." -ForegroundColor Yellow
    docker-compose exec backend pip install passlib[bcrypt]==1.7.4
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to install backend dependencies"
    }
    Write-Host "✓ Backend dependencies installed" -ForegroundColor Green
    Write-Host ""

    Write-Host "[2/5] Running database migration: email/password columns..." -ForegroundColor Yellow
    docker-compose exec backend python scripts/add_email_password_columns.py
    if ($LASTEXITCODE -ne 0) {
        Write-Host "WARNING: Migration may have failed or columns already exist" -ForegroundColor Yellow
    }
    Write-Host ""

    Write-Host "[3/5] Running database migration: settings columns..." -ForegroundColor Yellow
    docker-compose exec backend python scripts/add_settings_columns.py
    if ($LASTEXITCODE -ne 0) {
        Write-Host "WARNING: Migration may have failed or columns already exist" -ForegroundColor Yellow
    }
    Write-Host ""

    Write-Host "[4/5] Restarting backend service..." -ForegroundColor Yellow
    docker-compose restart backend
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to restart backend"
    }
    Write-Host "✓ Backend restarted" -ForegroundColor Green
    Write-Host ""

    Write-Host "[5/5] Installing Flutter dependencies..." -ForegroundColor Yellow
    Push-Location flutter_app
    flutter pub get
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to install Flutter dependencies"
    }
    Write-Host "✓ Flutter dependencies installed" -ForegroundColor Green
    Pop-Location
    Write-Host ""

    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "All updates completed successfully!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Yellow
    Write-Host "- Backend is running on http://localhost:8000"
    Write-Host "- Run 'cd flutter_app && flutter run -d chrome' to start the app"
    Write-Host ""
}
catch {
    Write-Host ""
    Write-Host "ERROR: $_" -ForegroundColor Red
    Write-Host ""
    exit 1
}
