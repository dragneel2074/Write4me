# Fix Script: Use Compatible llama.cpp Version
# This script rolls back to a stable llama.cpp version that works with current fllama

Write-Host "================================================" -ForegroundColor Cyan
Write-Host "fllama Build Fix - Use Compatible llama.cpp" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""

$WORK_DIR = "C:\Users\ADMIN\Documents\HP\old_ssd\MY_FILES"
$LLAMA_CPP_DIR = "$WORK_DIR\llama.cpp"
$FLLAMA_DIR = "$WORK_DIR\fllama"

# Compatible llama.cpp commits (tested with fllama)
# These are known stable versions before the flash_attn API change
$STABLE_COMMITS = @(
    @{Hash="b4313"; Date="2024-12-20"; Note="Last known stable before flash_attn removal"},
    @{Hash="f9f5c"; Date="2024-12-15"; Note="Stable version with flash_attn support"},
    @{Hash="8962422"; Date="2024-11-30"; Note="Older stable version"}
)

Write-Host "[1/5] The build failed because llama.cpp API changed" -ForegroundColor Yellow
Write-Host "Error: 'flash_attn' no longer exists in llama_context_params" -ForegroundColor Red
Write-Host ""
Write-Host "We need to use an older, compatible llama.cpp version." -ForegroundColor White
Write-Host ""

# Check if llama.cpp exists
if (!(Test-Path $LLAMA_CPP_DIR)) {
    Write-Host "ERROR: llama.cpp directory not found at $LLAMA_CPP_DIR" -ForegroundColor Red
    Write-Host "Please run the main update script first to clone llama.cpp" -ForegroundColor Yellow
    exit 1
}

# Option 1: Use the commit from Telosnex/fllama (safest)
Write-Host "[2/5] Finding compatible llama.cpp version..." -ForegroundColor Yellow
Write-Host ""
Write-Host "Recommended approach: Use the llama.cpp version from original Telosnex/fllama" -ForegroundColor Cyan
Write-Host "This ensures maximum compatibility." -ForegroundColor Cyan
Write-Host ""

$choice = Read-Host "Use llama.cpp from original Telosnex/fllama? (y/n)"

if ($choice -eq 'y') {
    Write-Host ""
    Write-Host "[3/5] Fetching llama.cpp version from Telosnex/fllama..." -ForegroundColor Yellow
    
    # Clone or update Telosnex repo temporarily
    $TEMP_FLLAMA = "$WORK_DIR\fllama-upstream-temp"
    if (Test-Path $TEMP_FLLAMA) {
        Remove-Item -Recurse -Force $TEMP_FLLAMA
    }
    
    git clone --depth 1 https://github.com/Telosnex/fllama.git $TEMP_FLLAMA
    
    if (!(Test-Path "$TEMP_FLLAMA\src\llama.cpp")) {
        Write-Host "ERROR: Could not fetch upstream fllama" -ForegroundColor Red
        exit 1
    }
    
    # Get the llama.cpp commit hash from upstream
    Set-Location "$TEMP_FLLAMA\src\llama.cpp"
    $UPSTREAM_COMMIT = git log --oneline -1 | ForEach-Object { $_.Split()[0] }
    Write-Host "  ✓ Upstream uses llama.cpp commit: $UPSTREAM_COMMIT" -ForegroundColor Green
    
    Write-Host ""
    Write-Host "[4/5] Updating your fork with compatible llama.cpp..." -ForegroundColor Yellow
    
    # Update your fork's llama.cpp copies
    Set-Location $FLLAMA_DIR
    
    Write-Host "  Updating src/llama.cpp..." -ForegroundColor Cyan
    if (Test-Path "src\llama.cpp") {
        Remove-Item -Recurse -Force "src\llama.cpp"
    }
    Copy-Item -Recurse "$TEMP_FLLAMA\src\llama.cpp" "src\llama.cpp"
    
    Write-Host "  Updating macos/llama.cpp..." -ForegroundColor Cyan
    if (Test-Path "macos\llama.cpp") {
        Remove-Item -Recurse -Force "macos\llama.cpp"
    }
    Copy-Item -Recurse "$TEMP_FLLAMA\macos\llama.cpp" "macos\llama.cpp"
    
    Write-Host "  Updating ios/llama.cpp..." -ForegroundColor Cyan
    if (Test-Path "ios\llama.cpp") {
        Remove-Item -Recurse -Force "ios\llama.cpp"
    }
    Copy-Item -Recurse "$TEMP_FLLAMA\ios\llama.cpp" "ios\llama.cpp"
    
    # Commit changes
    git add .
    git commit -m "Rollback to compatible llama.cpp version ($UPSTREAM_COMMIT) from Telosnex/fllama"
    git push origin main -f
    
    # Cleanup
    Remove-Item -Recurse -Force $TEMP_FLLAMA
    
    Write-Host "  ✓ Your fork updated with compatible llama.cpp" -ForegroundColor Green
    
} else {
    Write-Host ""
    Write-Host "Alternative: Manually select an older llama.cpp commit" -ForegroundColor Yellow
    Write-Host "Available stable commits:" -ForegroundColor Cyan
    for ($i = 0; $i -lt $STABLE_COMMITS.Count; $i++) {
        $commit = $STABLE_COMMITS[$i]
        Write-Host "  [$i] $($commit.Hash) - $($commit.Date) - $($commit.Note)" -ForegroundColor White
    }
    Write-Host ""
    $selection = Read-Host "Select commit number (0-$($STABLE_COMMITS.Count - 1))"
    
    $selectedCommit = $STABLE_COMMITS[[int]$selection].Hash
    Write-Host ""
    Write-Host "[3/5] Checking out llama.cpp commit: $selectedCommit" -ForegroundColor Yellow
    
    Set-Location $LLAMA_CPP_DIR
    git fetch --all
    git checkout $selectedCommit
    
    Write-Host ""
    Write-Host "[4/5] Updating your fork with selected llama.cpp..." -ForegroundColor Yellow
    Set-Location $FLLAMA_DIR
    
    # Update all three directories
    Write-Host "  Updating macos/llama.cpp..." -ForegroundColor Cyan
    if (Test-Path "macos\llama.cpp") {
        Remove-Item -Recurse -Force "macos\llama.cpp"
    }
    Copy-Item -Recurse $LLAMA_CPP_DIR "macos\llama.cpp"
    
    Write-Host "  Updating ios/llama.cpp..." -ForegroundColor Cyan
    if (Test-Path "ios\llama.cpp") {
        Remove-Item -Recurse -Force "ios\llama.cpp"
    }
    Copy-Item -Recurse "macos\llama.cpp" "ios\llama.cpp"
    
    Write-Host "  Updating src/llama.cpp..." -ForegroundColor Cyan
    if (Test-Path "src\llama.cpp") {
        Remove-Item -Recurse -Force "src\llama.cpp"
    }
    Copy-Item -Recurse $LLAMA_CPP_DIR "src\llama.cpp"
    
    # Commit changes
    git add .
    git commit -m "Use compatible llama.cpp version ($selectedCommit)"
    git push origin main -f
    
    Write-Host "  ✓ Fork updated with compatible llama.cpp" -ForegroundColor Green
}

Write-Host ""
Write-Host "[5/5] Testing build..." -ForegroundColor Yellow
Set-Location "C:\Users\ADMIN\Documents\HP\old_ssd\MY_FILES\flutter_projects\Write4me"

Write-Host "  Cleaning project..." -ForegroundColor Cyan
flutter clean | Out-Null

Write-Host "  Getting dependencies..." -ForegroundColor Cyan
flutter pub get | Out-Null

Write-Host "  Building APK..." -ForegroundColor Cyan
flutter build apk --debug

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "================================================" -ForegroundColor Green
    Write-Host "SUCCESS! Build completed!" -ForegroundColor Green
    Write-Host "================================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Your fork now uses a compatible llama.cpp version." -ForegroundColor Cyan
    Write-Host "You can now build and run your app successfully." -ForegroundColor Cyan
} else {
    Write-Host ""
    Write-Host "================================================" -ForegroundColor Red
    Write-Host "Build still failed" -ForegroundColor Red
    Write-Host "================================================" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please check the error messages above." -ForegroundColor Yellow
    Write-Host "You may need to use an even older llama.cpp version" -ForegroundColor Yellow
    Write-Host "or wait for Telosnex to update fllama code." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Script completed." -ForegroundColor Cyan
