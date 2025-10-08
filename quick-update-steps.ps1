# Quick Manual Steps to Fork and Update llama.cpp
# Copy and paste these commands one section at a time

# ==== STEP 1: Fork on GitHub (Manual) ====
# 1. Go to: https://github.com/Telosnex/fllama
# 2. Click "Fork" button
# 3. Wait for fork to complete

# ==== STEP 2: Clone Your Fork ====
cd C:\Users\ADMIN\Documents\HP\old_ssd\MY_FILES
git clone https://github.com/dragneel2074/fllama.git
cd fllama
git remote add upstream https://github.com/Telosnex/fllama.git

# ==== STEP 3: Get Latest llama.cpp ====
cd ..
git clone https://github.com/ggml-org/llama.cpp.git
cd llama.cpp
git checkout master
git pull origin master
git log --oneline -1  # Note this commit hash

# ==== STEP 4: Update fllama with Latest llama.cpp ====
cd ..\fllama

# Update macOS
Remove-Item -Recurse -Force macos\llama.cpp
Copy-Item -Recurse ..\llama.cpp macos\llama.cpp
git add macos\llama.cpp
git commit -m "Update llama.cpp to latest - macOS"

# Update iOS
Remove-Item -Recurse -Force ios\llama.cpp
Copy-Item -Recurse macos\llama.cpp ios\llama.cpp
git add ios\llama.cpp
git commit -m "Update llama.cpp to latest - iOS"

# Update src (ANDROID USES THIS!)
Remove-Item -Recurse -Force src\llama.cpp
Copy-Item -Recurse ..\llama.cpp src\llama.cpp
git add src\llama.cpp
git commit -m "Update llama.cpp to latest - Android/Windows/Linux"

# ==== STEP 5: Push to Your Fork ====
git push origin main

# ==== STEP 6: Update Write4me ====
cd C:\Users\ADMIN\Documents\HP\old_ssd\MY_FILES\flutter_projects\Write4me

# Manual: Edit pubspec.yaml and change:
#   fllama:
#     git:
#       url: https://github.com/dragneel2074/fllama.git  # Your fork!
#       ref: main

# ==== STEP 7: Test Build ====
flutter clean
flutter pub get
flutter build apk --debug

# ==== STEP 8: Test on Device ====
flutter run --release

# ==== IF BUILD FAILS - RESTORE build-info.cpp ====
cd C:\Users\ADMIN\Documents\HP\old_ssd\MY_FILES\fllama

# Restore for macOS
git checkout HEAD~1 macos/llama.cpp/common/build-info.cpp
git add macos/llama.cpp/common/build-info.cpp
git commit -m "Restore build-info.cpp for macOS"

# Restore for iOS
git checkout HEAD~1 ios/llama.cpp/common/build-info.cpp
git add ios/llama.cpp/common/build-info.cpp
git commit -m "Restore build-info.cpp for iOS"

# Push fixes
git push origin main

# Try building again
cd C:\Users\ADMIN\Documents\HP\old_ssd\MY_FILES\flutter_projects\Write4me
flutter clean
flutter pub get
flutter build apk --debug

# ==== ROLLBACK IF NEEDED ====
cd C:\Users\ADMIN\Documents\HP\old_ssd\MY_FILES\fllama
git reset --hard HEAD~3  # Undo last 3 commits
git push -f origin main

# Revert Write4me pubspec.yaml to:
#   fllama:
#     git:
#       url: https://github.com/Telosnex/fllama.git
#       ref: main
