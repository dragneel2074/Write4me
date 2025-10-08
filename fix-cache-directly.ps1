# Apply API fixes directly to Flutter's pub cache

Write-Host "Applying fixes to Flutter's cached fllama..." -ForegroundColor Yellow

$CACHE_DIR = "C:\Users\ADMIN\AppData\Local\Pub\Cache\git\fllama-*"
$FLLAMA_CACHE = Get-Item $CACHE_DIR | Select-Object -First 1

if (!$FLLAMA_CACHE) {
    Write-Host "ERROR: Cached fllama not found" -ForegroundColor Red
    exit 1
}

Write-Host "  Found cache: $($FLLAMA_CACHE.FullName)" -ForegroundColor Cyan

# Fix 1: Remove flash_attn lines
$fllamaFile = Join-Path $FLLAMA_CACHE.FullName "src\fllama.cpp"
$content = Get-Content $fllamaFile -Raw

Write-Host "  Fixing flash_attn..." -ForegroundColor Cyan
# Remove the exact lines
$content = $content -replace 'ctx_params\.flash_attn = false;\r?\n', ''
$content = $content -replace 'log_message\("\[fllama\] flash_attn: " \+ std::to_string\(ctx_params\.flash_attn\), request\.dart_logger\);\r?\n', ''

# Fix 2: Fix common_chat_format_example
Write-Host "  Fixing common_chat_format_example..." -ForegroundColor Cyan
$content = $content -replace 'common_chat_format_example\(chat_templates\.get\(\), true\)', 'common_chat_format_example(chat_templates.get(), llama_chat_builtin_template{}, true)'

# Fix 3: Replace deprecated functions
Write-Host "  Replacing deprecated functions..." -ForegroundColor Cyan
$content = $content -replace 'llama_add_bos_token\(vocab\)', 'llama_vocab_get_add_bos(vocab)'
$content = $content -replace 'llama_token_eos\(vocab\)', 'llama_vocab_eos(vocab)'
$content = $content -replace 'llama_token_is_eog\(vocab,', 'llama_vocab_is_eog(vocab,'

$content | Set-Content $fllamaFile -NoNewline
Write-Host "  fllama.cpp fixed" -ForegroundColor Green

# Fix fllama_llava.cpp
$llavaFile = Join-Path $FLLAMA_CACHE.FullName "src\fllama_llava.cpp"
$content = Get-Content $llavaFile -Raw
$content = $content -replace 'llama_n_embd\(llama_get_model\(ctx_llama\)\)', 'llama_model_n_embd(llama_get_model(ctx_llama))'
$content = $content -replace 'llama_token_bos\(llama_model_get_vocab\(llama_get_model\(ctx_llama\)\)\)', 'llama_vocab_bos(llama_model_get_vocab(llama_get_model(ctx_llama)))'
$content = $content -replace 'llama_token_eos\(llama_model_get_vocab\(llama_get_model\(ctx_llama\)\)\)', 'llama_vocab_eos(llama_model_get_vocab(llama_get_model(ctx_llama)))'
$content | Set-Content $llavaFile -NoNewline
Write-Host "  fllama_llava.cpp fixed" -ForegroundColor Green

# Fix fllama_tokenize.cpp
$tokenizeFile = Join-Path $FLLAMA_CACHE.FullName "src\fllama_tokenize.cpp"
$content = Get-Content $tokenizeFile -Raw
$content = $content -replace 'llama_load_model_from_file\(', 'llama_model_load_from_file('
$content = $content -replace 'llama_free_model\(ptr\)', 'llama_model_free(ptr)'
$content | Set-Content $tokenizeFile -NoNewline
Write-Host "  fllama_tokenize.cpp fixed" -ForegroundColor Green

Write-Host ""
Write-Host "All fixes applied to cache!" -ForegroundColor Green
Write-Host "Now rebuilding..." -ForegroundColor Yellow

cd C:\Users\ADMIN\Documents\HP\old_ssd\MY_FILES\flutter_projects\Write4me
flutter build apk --debug
