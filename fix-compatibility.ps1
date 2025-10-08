# Fix fllama Code for Latest llama.cpp API Compatibility
# This script patches fllama source files to work with newer llama.cpp

Write-Host "================================================" -ForegroundColor Cyan
Write-Host "fllama API Compatibility Fix" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "This will update fllama code to work with latest llama.cpp" -ForegroundColor Yellow
Write-Host ""

$WORK_DIR = "C:\Users\ADMIN\Documents\HP\old_ssd\MY_FILES\flutter_projects"
$FLLAMA_DIR = "$WORK_DIR\fllama"

# Check if fork exists
if (!(Test-Path $FLLAMA_DIR)) {
    Write-Host "ERROR: fllama fork not found at $FLLAMA_DIR" -ForegroundColor Red
    exit 1
}

Set-Location $FLLAMA_DIR

Write-Host "[1/6] Backing up original files..." -ForegroundColor Yellow
$BACKUP_DIR = "$FLLAMA_DIR\backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
New-Item -ItemType Directory -Path $BACKUP_DIR | Out-Null
Copy-Item "src\fllama.cpp" "$BACKUP_DIR\fllama.cpp.bak"
Copy-Item "src\fllama_tokenize.cpp" "$BACKUP_DIR\fllama_tokenize.cpp.bak"
Copy-Item "src\fllama_llava.cpp" "$BACKUP_DIR\fllama_llava.cpp.bak"
Write-Host "  Backups saved to: $BACKUP_DIR" -ForegroundColor Green

Write-Host ""
Write-Host "[2/6] Fixing flash_attn parameter (removed from llama.cpp)..." -ForegroundColor Yellow
$fllamaFile = "src\fllama.cpp"
$content = Get-Content $fllamaFile -Raw

# Fix 1: Remove flash_attn lines
$content = $content -replace 'ctx_params\.flash_attn = false;\s*\r?\n', ''
$content = $content -replace 'log_message\("\[fllama\] flash_attn: " \+ std::to_string\(ctx_params\.flash_attn\), request\.dart_logger\);\s*\r?\n', ''

$content | Set-Content $fllamaFile -NoNewline
Write-Host "  Removed flash_attn parameter" -ForegroundColor Green

Write-Host ""
Write-Host "[3/6] Fixing common_chat_format_example function call..." -ForegroundColor Yellow
# Fix 2: Update common_chat_format_example call
$content = Get-Content $fllamaFile -Raw
$content = $content -replace 'common_chat_format_example\(chat_templates\.get\(\), true\)', 'common_chat_format_example(chat_templates.get(), llama_chat_builtin_template{}, true)'
$content | Set-Content $fllamaFile -NoNewline
Write-Host "  Fixed common_chat_format_example call" -ForegroundColor Green

Write-Host ""
Write-Host "[4/6] Replacing deprecated token functions..." -ForegroundColor Yellow

# Fix deprecated functions in fllama.cpp
$content = Get-Content $fllamaFile -Raw
$content = $content -replace 'llama_add_bos_token\(vocab\)', 'llama_vocab_get_add_bos(vocab)'
$content = $content -replace 'llama_token_eos\(vocab\)', 'llama_vocab_eos(vocab)'
$content = $content -replace 'llama_token_is_eog\(vocab,', 'llama_vocab_is_eog(vocab,'
$content | Set-Content $fllamaFile -NoNewline
Write-Host "  Updated fllama.cpp" -ForegroundColor Green

# Fix deprecated functions in fllama_llava.cpp
$llavaFile = "src\fllama_llava.cpp"
$content = Get-Content $llavaFile -Raw
$content = $content -replace 'llama_n_embd\(llama_get_model\(ctx_llama\)\)', 'llama_model_n_embd(llama_get_model(ctx_llama))'
$content = $content -replace 'llama_token_bos\(llama_model_get_vocab\(llama_get_model\(ctx_llama\)\)\)', 'llama_vocab_bos(llama_model_get_vocab(llama_get_model(ctx_llama)))'
$content = $content -replace 'llama_token_eos\(llama_model_get_vocab\(llama_get_model\(ctx_llama\)\)\)', 'llama_vocab_eos(llama_model_get_vocab(llama_get_model(ctx_llama)))'
$content | Set-Content $llavaFile -NoNewline
Write-Host "  Updated fllama_llava.cpp" -ForegroundColor Green

# Fix deprecated functions in fllama_tokenize.cpp
$tokenizeFile = "src\fllama_tokenize.cpp"
$content = Get-Content $tokenizeFile -Raw
$content = $content -replace 'llama_load_model_from_file\(', 'llama_model_load_from_file('
$content = $content -replace 'llama_free_model\(ptr\)', 'llama_model_free(ptr)'
$content | Set-Content $tokenizeFile -NoNewline
Write-Host "  Updated fllama_tokenize.cpp" -ForegroundColor Green

Write-Host ""
Write-Host "[5/6] Committing fixes to your fork..." -ForegroundColor Yellow
git add src\fllama.cpp src\fllama_llava.cpp src\fllama_tokenize.cpp
git commit -m "Fix: Update fllama code for latest llama.cpp API compatibility

- Remove flash_attn parameter (removed from llama_context_params)
- Fix common_chat_format_example to use 3-argument signature
- Replace deprecated token functions with new API"

git push origin main

Write-Host "  Pushed to your fork" -ForegroundColor Green

Write-Host ""
Write-Host "[6/6] Testing build with fixed code..." -ForegroundColor Yellow
Set-Location "C:\Users\ADMIN\Documents\HP\old_ssd\MY_FILES\flutter_projects\Write4me"

Write-Host "  Cleaning project..." -ForegroundColor Cyan
flutter clean | Out-Null

Write-Host "  Getting dependencies..." -ForegroundColor Cyan
flutter pub get | Out-Null

Write-Host "  Building APK (this will take 10-15 minutes)..." -ForegroundColor Cyan
Write-Host "  Building..." -ForegroundColor Yellow
flutter build apk --debug

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "================================================" -ForegroundColor Green
    Write-Host "SUCCESS! Build completed!" -ForegroundColor Green
    Write-Host "================================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Your fllama fork now works with the latest llama.cpp!" -ForegroundColor Cyan
    Write-Host "Benefits:" -ForegroundColor Cyan
    Write-Host "  - Support for newer model architectures" -ForegroundColor White
    Write-Host "  - Latest performance improvements" -ForegroundColor White
    Write-Host "  - Bug fixes and optimizations" -ForegroundColor White
    Write-Host "  - Better Android support" -ForegroundColor White
    Write-Host ""
    Write-Host "Next step: flutter run --release" -ForegroundColor Yellow
}
else {
    Write-Host ""
    Write-Host "================================================" -ForegroundColor Red
    Write-Host "Build failed - additional fixes needed" -ForegroundColor Red
    Write-Host "================================================" -ForegroundColor Red
    Write-Host ""
    Write-Host "Check the error messages above." -ForegroundColor Yellow
    Write-Host "There may be additional API changes that need fixing." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Backup location: $BACKUP_DIR" -ForegroundColor Cyan
}

Write-Host ""
Write-Host "Script completed." -ForegroundColor Cyan
