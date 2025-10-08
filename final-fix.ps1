# Final fix for common_chat_format_example

$CACHE_DIR = "C:\Users\ADMIN\AppData\Local\Pub\Cache\git\fllama-*"
$FLLAMA_CACHE = Get-Item $CACHE_DIR | Select-Object -First 1

$fllamaFile = Join-Path $FLLAMA_CACHE.FullName "src\fllama.cpp"
$content = Get-Content $fllamaFile -Raw

Write-Host "Fixing common_chat_format_example with correct signature..." -ForegroundColor Yellow

# The function needs 3 args: tmpls, use_jinja (bool), chat_template_kwargs (map)
# We need to pass an empty map as the third argument
$content = $content -replace 'common_chat_format_example\(chat_templates\.get\(\), llama_chat_builtin_template\{\}, true\)', 'common_chat_format_example(chat_templates.get(), true, std::map<std::string, std::string>{})'

$content | Set-Content $fllamaFile -NoNewline

Write-Host "Fixed! Now rebuilding..." -ForegroundColor Green

cd C:\Users\ADMIN\Documents\HP\old_ssd\MY_FILES\flutter_projects\Write4me
flutter build apk --debug
