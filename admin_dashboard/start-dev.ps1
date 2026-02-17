# PowerShell script to start admin dashboard dev server
Write-Host "Installing dependencies..." -ForegroundColor Yellow
npm install

if ($LASTEXITCODE -eq 0) {
    Write-Host "Starting dev server..." -ForegroundColor Green
    npm run dev
} else {
    Write-Host "Failed to install dependencies. Please check errors above." -ForegroundColor Red
}
