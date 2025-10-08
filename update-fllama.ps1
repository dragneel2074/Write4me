# Automated script to fork and update llama.cpp in fllama
# Run this script from PowerShell as Administrator

Write-Host "================================================" -ForegroundColor Cyan
Write-Host "fllama Fork & llama.cpp Update Automation" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""

# Configuration
$WORK_DIR = "C:\Users\ADMIN\Documents\HP\old_ssd\MY_FILES"
$FLLAMA_DIR = "$WORK_DIR\fllama"
$LLAMA_CPP_DIR = "$WORK_DIR\llama.cpp"
$WRITE4ME_DIR = "$WORK_DIR\flutter_projects\Write4me"
$YOUR_GITHUB_USERNAME = "dragneel2074"

# Step 1: Check prerequisites
Write-Host "[1/9] Checking prerequisites..." -ForegroundColor Yellow

if (!(Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Host "ERROR: Git is not installed or not in PATH" -ForegroundColor Red
    exit 1
}
Write-Host "  ✓ Git found" -ForegroundColor Green

if (!(Get-Command flutter -ErrorAction SilentlyContinue)) {
    Write-Host "ERROR: Flutter is not installed or not in PATH" -ForegroundColor Red
    exit 1
}
Write-Host "  ✓ Flutter found" -ForegroundColor Green

# Create work directory if needed
if (!(Test-Path $WORK_DIR)) {
    New-Item -ItemType Directory -Path $WORK_DIR | Out-Null
}

# Step 2: Prompt for fork confirmation
Write-Host ""
Write-Host "[2/9] Fork Setup" -ForegroundColor Yellow
Write-Host "Before continuing, you need to fork the repository on GitHub:" -ForegroundColor White
Write-Host "  1. Go to: https://github.com/Telosnex/fllama" -ForegroundColor Cyan
Write-Host "  2. Click 'Fork' button (top-right)" -ForegroundColor Cyan
Write-Host "  3. This creates: https://github.com/$YOUR_GITHUB_USERNAME/fllama" -ForegroundColor Cyan
Write-Host ""
$forked = Read-Host "Have you completed the fork? (y/n)"
if ($forked -ne 'y') {
    Write-Host "Please fork the repository first, then run this script again." -ForegroundColor Yellow
    exit 0
}

# Step 3: Clone your fork
Write-Host ""
Write-Host "[3/9] Cloning your fllama fork..." -ForegroundColor Yellow

if (Test-Path $FLLAMA_DIR) {
    Write-Host "  Directory already exists. Do you want to remove it and re-clone? (y/n)" -ForegroundColor Yellow
    $remove = Read-Host
    if ($remove -eq 'y') {
        Remove-Item -Recurse -Force $FLLAMA_DIR
    } else {
        Write-Host "  Using existing directory" -ForegroundColor Green
        Set-Location $FLLAMA_DIR
    }
}

if (!(Test-Path $FLLAMA_DIR)) {
    Set-Location $WORK_DIR
    git clone "https://github.com/$YOUR_GITHUB_USERNAME/fllama.git"
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERROR: Failed to clone fork. Check your GitHub username and fork status." -ForegroundColor Red
        exit 1
    }
    Set-Location $FLLAMA_DIR
}

# Add upstream remote
git remote add upstream https://github.com/Telosnex/fllama.git 2>$null
Write-Host "  ✓ Fork cloned and upstream configured" -ForegroundColor Green

# Step 4: Clone llama.cpp
Write-Host ""
Write-Host "[4/9] Getting latest llama.cpp..." -ForegroundColor Yellow

if (Test-Path $LLAMA_CPP_DIR) {
    Set-Location $LLAMA_CPP_DIR
    git fetch --all
    git checkout master
    git pull origin master
    Write-Host "  ✓ llama.cpp updated to latest" -ForegroundColor Green
} else {
    Set-Location $WORK_DIR
    git clone https://github.com/ggml-org/llama.cpp.git
    Set-Location $LLAMA_CPP_DIR
    Write-Host "  ✓ llama.cpp cloned" -ForegroundColor Green
}

$llamaCppCommit = git log --oneline -1
Write-Host "  Current llama.cpp: $llamaCppCommit" -ForegroundColor Cyan

# Step 5: Confirm update
Write-Host ""
Write-Host "[5/9] Ready to update fllama" -ForegroundColor Yellow
Write-Host "This will:" -ForegroundColor White
Write-Host "  - Copy llama.cpp to macos/" -ForegroundColor White
Write-Host "  - Copy llama.cpp to ios/" -ForegroundColor White
Write-Host "  - Copy llama.cpp to src/ (Android build)" -ForegroundColor White
Write-Host "  - Create commits for each step" -ForegroundColor White
Write-Host ""
$proceed = Read-Host "Proceed with update? (y/n)"
if ($proceed -ne 'y') {
    Write-Host "Update cancelled." -ForegroundColor Yellow
    exit 0
}

# Step 6: Update macOS
Write-Host ""
Write-Host "[6/9] Updating llama.cpp in fllama..." -ForegroundColor Yellow
Set-Location $FLLAMA_DIR

Write-Host "  Updating macos/llama.cpp..." -ForegroundColor Cyan
if (Test-Path "macos\llama.cpp") {
    Remove-Item -Recurse -Force "macos\llama.cpp"
}
Copy-Item -Recurse "$LLAMA_CPP_DIR" "macos\llama.cpp"
git add macos\llama.cpp
git commit -m "Update llama.cpp to latest ($llamaCppCommit) - macOS"
Write-Host "  ✓ macOS updated" -ForegroundColor Green

# Step 7: Update iOS
Write-Host "  Updating ios/llama.cpp..." -ForegroundColor Cyan
if (Test-Path "ios\llama.cpp") {
    Remove-Item -Recurse -Force "ios\llama.cpp"
}
Copy-Item -Recurse "macos\llama.cpp" "ios\llama.cpp"
git add ios\llama.cpp
git commit -m "Update llama.cpp to latest ($llamaCppCommit) - iOS"
Write-Host "  ✓ iOS updated" -ForegroundColor Green

# Step 8: Update src (Android/Windows/Linux)
Write-Host "  Updating src/llama.cpp..." -ForegroundColor Cyan
if (Test-Path "src\llama.cpp") {
    Remove-Item -Recurse -Force "src\llama.cpp"
}
Copy-Item -Recurse "$LLAMA_CPP_DIR" "src\llama.cpp"
git add src\llama.cpp
git commit -m "Update llama.cpp to latest ($llamaCppCommit) - Android/Windows/Linux"
Write-Host "  ✓ Android/Windows/Linux updated" -ForegroundColor Green

# Step 9: Push to fork
Write-Host ""
Write-Host "[7/9] Pushing to your fork..." -ForegroundColor Yellow
git push origin main
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Failed to push. Check your GitHub credentials." -ForegroundColor Red
    exit 1
}
Write-Host "  ✓ Changes pushed to https://github.com/$YOUR_GITHUB_USERNAME/fllama" -ForegroundColor Green

# Step 10: Update Write4me pubspec.yaml
Write-Host ""
Write-Host "[8/9] Updating Write4me to use your fork..." -ForegroundColor Yellow

$pubspecPath = "$WRITE4ME_DIR\pubspec.yaml"
$pubspecContent = Get-Content $pubspecPath -Raw

if ($pubspecContent -match "url: https://github.com/Telosnex/fllama.git") {
    $newContent = $pubspecContent -replace "url: https://github.com/Telosnex/fllama.git", "url: https://github.com/$YOUR_GITHUB_USERNAME/fllama.git"
    $newContent | Set-Content $pubspecPath
    Write-Host "  ✓ pubspec.yaml updated to use your fork" -ForegroundColor Green
} else {
    Write-Host "  ⚠ pubspec.yaml may already be using your fork or has custom config" -ForegroundColor Yellow
}

# Step 11: Test build
Write-Host ""
Write-Host "[9/9] Testing Android build..." -ForegroundColor Yellow
Set-Location $WRITE4ME_DIR

Write-Host "  Cleaning project..." -ForegroundColor Cyan
flutter clean | Out-Null
if (Test-Path ".dart_tool") {
    Remove-Item -Recurse -Force ".dart_tool"
}

Write-Host "  Getting dependencies..." -ForegroundColor Cyan
flutter pub get

Write-Host "  Building APK (this may take several minutes)..." -ForegroundColor Cyan
Write-Host "  Press Ctrl+C if this hangs or shows errors" -ForegroundColor Yellow
flutter build apk --debug

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "================================================" -ForegroundColor Green
    Write-Host "SUCCESS! Build completed successfully!" -ForegroundColor Green
    Write-Host "================================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Cyan
    Write-Host "  1. Test the app: flutter run --release" -ForegroundColor White
    Write-Host "  2. Test model loading and inference" -ForegroundColor White
    Write-Host "  3. Monitor for crashes or performance issues" -ForegroundColor White
    Write-Host ""
    Write-Host "Your fork: https://github.com/$YOUR_GITHUB_USERNAME/fllama" -ForegroundColor Cyan
} else {
    Write-Host ""
    Write-Host "================================================" -ForegroundColor Red
    Write-Host "BUILD FAILED" -ForegroundColor Red
    Write-Host "================================================" -ForegroundColor Red
    Write-Host ""
    Write-Host "Troubleshooting steps:" -ForegroundColor Yellow
    Write-Host "  1. Check the error messages above" -ForegroundColor White
    Write-Host "  2. Run: flutter build apk --debug --verbose" -ForegroundColor White
    Write-Host "  3. See FLLAMA_UPDATE_GUIDE.md for common issues" -ForegroundColor White
    Write-Host "  4. Consider restoring build-info.cpp (see guide)" -ForegroundColor White
    Write-Host ""
    Write-Host "Rollback:" -ForegroundColor Yellow
    Write-Host "  cd $FLLAMA_DIR" -ForegroundColor White
    Write-Host "  git reset --hard HEAD~3" -ForegroundColor White
    Write-Host "  git push -f origin main" -ForegroundColor White
}

Write-Host ""
Write-Host "Script completed. Check the output above for any issues." -ForegroundColor Cyan
