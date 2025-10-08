# IMMEDIATE FIX: Use llama.cpp from Telosnex/fllama
# This is the safest and quickest solution

Write-Host "Fetching compatible llama.cpp from Telosnex/fllama..." -ForegroundColor Yellow

$WORK_DIR = "C:\Users\ADMIN\Documents\HP\old_ssd\MY_FILES"
$TEMP_DIR = "$WORK_DIR\temp-fllama-fix"

# Clean up any previous temp directory
if (Test-Path $TEMP_DIR) {
    Remove-Item -Recurse -Force $TEMP_DIR
}

# Clone Telosnex/fllama to get their working llama.cpp
Write-Host "Cloning Telosnex/fllama (this may take a few minutes)..." -ForegroundColor Cyan
git clone --depth 1 https://github.com/Telosnex/fllama.git $TEMP_DIR

if (!(Test-Path "$TEMP_DIR\src\llama.cpp")) {
    Write-Host "ERROR: Failed to clone" -ForegroundColor Red
    exit 1
}

Write-Host "✓ Downloaded" -ForegroundColor Green

# Navigate to your fork
cd "$WORK_DIR\fllama"

Write-Host ""
Write-Host "Replacing llama.cpp with compatible version..." -ForegroundColor Yellow

# Replace src/llama.cpp
Write-Host "  Updating src/llama.cpp..." -ForegroundColor Cyan
Remove-Item -Recurse -Force "src\llama.cpp" -ErrorAction SilentlyContinue
Copy-Item -Recurse "$TEMP_DIR\src\llama.cpp" "src\llama.cpp"

# Replace macos/llama.cpp
Write-Host "  Updating macos/llama.cpp..." -ForegroundColor Cyan
Remove-Item -Recurse -Force "macos\llama.cpp" -ErrorAction SilentlyContinue
Copy-Item -Recurse "$TEMP_DIR\macos\llama.cpp" "macos\llama.cpp"

# Replace ios/llama.cpp
Write-Host "  Updating ios/llama.cpp..." -ForegroundColor Cyan
Remove-Item -Recurse -Force "ios\llama.cpp" -ErrorAction SilentlyContinue
Copy-Item -Recurse "$TEMP_DIR\ios\llama.cpp" "ios\llama.cpp"

Write-Host "✓ Replaced all llama.cpp directories" -ForegroundColor Green

# Commit and push
Write-Host ""
Write-Host "Committing changes..." -ForegroundColor Yellow
git add .
git commit -m "Fix: Use compatible llama.cpp from Telosnex/fllama"
git push origin main -f

Write-Host "✓ Pushed to your fork" -ForegroundColor Green

# Clean up temp directory
Remove-Item -Recurse -Force $TEMP_DIR

Write-Host ""
Write-Host "Now rebuilding Write4me..." -ForegroundColor Yellow
cd "C:\Users\ADMIN\Documents\HP\old_ssd\MY_FILES\flutter_projects\Write4me"

flutter clean
flutter pub get

Write-Host ""
Write-Host "Building APK (this will take 10-15 minutes)..." -ForegroundColor Cyan
flutter build apk --debug

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "✓ BUILD SUCCESSFUL!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Next: flutter run --release" -ForegroundColor Cyan
} else {
    Write-Host ""
    Write-Host "✗ Build failed. Check errors above." -ForegroundColor Red
}
