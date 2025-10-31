# Test RouteTest locally
# This script starts the local development server for testing

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "RouteTest Local Development Server" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check if Node.js is installed
Write-Host "Checking Node.js installation..." -ForegroundColor Yellow
$nodeVersion = node --version 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Node.js is not installed. Please install from https://nodejs.org/" -ForegroundColor Red
    exit 1
}
Write-Host "Node.js is installed (version: $nodeVersion)" -ForegroundColor Green
Write-Host ""

# Check if npm is installed
Write-Host "Checking npm installation..." -ForegroundColor Yellow
$npmVersion = npm --version 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: npm is not installed" -ForegroundColor Red
    exit 1
}
Write-Host "npm is installed (version: $npmVersion)" -ForegroundColor Green
Write-Host ""

# Check if SWA CLI is installed
Write-Host "Checking SWA CLI installation..." -ForegroundColor Yellow
$swaVersion = swa --version 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "SWA CLI is not installed. Installing..." -ForegroundColor Yellow
    npm install -g @azure/static-web-apps-cli
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERROR: Failed to install SWA CLI" -ForegroundColor Red
        exit 1
    }
    Write-Host "SWA CLI installed" -ForegroundColor Green
} else {
    Write-Host "SWA CLI is installed (version: $swaVersion)" -ForegroundColor Green
}
Write-Host ""

# Check if Azure Functions Core Tools is installed
Write-Host "Checking Azure Functions Core Tools..." -ForegroundColor Yellow
$funcVersion = func --version 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "WARNING: Azure Functions Core Tools is not installed" -ForegroundColor Yellow
    Write-Host "Functions may not work properly. Install from: https://aka.ms/azfunc-install" -ForegroundColor Yellow
} else {
    Write-Host "Azure Functions Core Tools is installed (version: $funcVersion)" -ForegroundColor Green
}
Write-Host ""

Write-Host "Starting development server..." -ForegroundColor Yellow
Write-Host "The app will be available at: http://localhost:4280" -ForegroundColor Cyan
Write-Host "Press Ctrl+C to stop the server" -ForegroundColor Yellow
Write-Host ""

# Start the SWA CLI
swa start webapp --api-location server

