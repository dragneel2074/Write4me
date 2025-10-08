# fllama Fork and llama.cpp Update Guide

This guide will help you fork fllama and update llama.cpp for the Write4me Android app.

## Prerequisites

1. Git installed
2. GitHub account (dragneel2074)
3. Android NDK installed (via Android Studio)
4. CMake 3.10+ (comes with Android Studio)

## Step 1: Fork fllama on GitHub

1. Go to https://github.com/Telosnex/fllama
2. Click the "Fork" button in the top-right corner
3. This creates `https://github.com/dragneel2074/fllama`

## Step 2: Clone Your Fork Locally

```powershell
# Navigate to a working directory (NOT inside Write4me project)
cd C:\Users\ADMIN\Documents\HP\old_ssd\MY_FILES\

# Clone your fork
git clone https://github.com/dragneel2074/fllama.git
cd fllama

# Add upstream remote (original repo)
git remote add upstream https://github.com/Telosnex/fllama.git
```

## Step 3: Get Latest llama.cpp

```powershell
# Navigate outside fllama directory
cd ..

# Clone llama.cpp (if not already cloned)
git clone https://github.com/ggml-org/llama.cpp.git
cd llama.cpp

# Get the latest version
git fetch --all
git checkout master
git pull origin master

# Note the current commit for reference
git log --oneline -1
```

## Step 4: Update llama.cpp in Your fllama Fork

### For Android (Primary Target)

Follow this order as per fllama README:

```powershell
cd C:\Users\ADMIN\Documents\HP\old_ssd\MY_FILES\fllama

# 1. Copy to macOS first (for consistency, even though we're on Windows)
Remove-Item -Recurse -Force macos\llama.cpp
Copy-Item -Recurse C:\Users\ADMIN\Documents\HP\old_ssd\MY_FILES\flutter_projects\llama.cpp macos\llama.cpp
git add macos\llama.cpp
git commit -m "Update llama.cpp to latest - macOS copy"

# 2. Copy to iOS
Remove-Item -Recurse -Force ios\llama.cpp
Copy-Item -Recurse macos\llama.cpp ios\llama.cpp
git add ios\llama.cpp
git commit -m "Update llama.cpp to latest - iOS copy"

# 3. Copy to src (ANDROID BUILD USES THIS)
Remove-Item -Recurse -Force src\llama.cpp
Copy-Item -Recurse C:\Users\ADMIN\Documents\HP\old_ssd\MY_FILES\flutter_projects\llama.cpp src\llama.cpp
git add src\llama.cpp
git commit -m "Update llama.cpp to latest - Android/Windows/Linux"

# 4. Push to your fork
git push origin main
```

## Step 5: Update Write4me to Use Your Fork

```yaml
# In Write4me/pubspec.yaml, change:
dependencies:
  fllama:
    git:
      url: https://github.com/dragneel2074/fllama.git
      ref: main
```

## Step 6: Test the Build

```powershell
cd C:\Users\ADMIN\Documents\HP\old_ssd\MY_FILES\flutter_projects\Write4me

# Clean everything
flutter clean
Remove-Item -Recurse -Force .dart_tool
Remove-Item -Recurse -Force build

# Get dependencies
flutter pub get

# Build for Android (this will compile llama.cpp)
flutter build apk --debug

# If successful, test on device
flutter run --release
```

## Step 7: Monitor for Build Errors

### Common Android Build Issues:

1. **CMake errors**: Check `src/CMakeLists.txt` compatibility
2. **NDK version**: Ensure you're using NDK 25.1.8937393 or newer
3. **Missing symbols**: May need to update FFI bindings

### If Build Fails:

```powershell
# Check the Android build logs
flutter build apk --debug --verbose

# Look for errors related to:
# - llama.cpp compilation
# - Missing headers
# - Linker errors
```

## Step 8: Fix Build Issues (If Any)

### Restore build-info.cpp (Common Issue)

The README mentions this is often needed:

```powershell
cd C:\Users\ADMIN\Documents\HP\old_ssd\MY_FILES\fllama

# For macOS
git checkout HEAD~1 macos/llama.cpp/common/build-info.cpp
git add macos/llama.cpp/common/build-info.cpp
git commit -m "Restore build-info.cpp for macOS"

# For iOS
git checkout HEAD~1 ios/llama.cpp/common/build-info.cpp
git add ios/llama.cpp/common/build-info.cpp
git commit -m "Restore build-info.cpp for iOS"

# Push fixes
git push origin main
```

## Step 9: Verify Android-Specific Features

Check that these Android optimizations are still working:

1. **ARM64 optimizations** (ARMv8.2-A with dot product)
2. **16KB page size support** (Android 15)
3. **Static library linking**

These are configured in `src/CMakeLists.txt`:

```cmake
if(ANDROID)
    # ARM64 optimization
    if(CMAKE_ANDROID_ARCH_ABI STREQUAL "arm64-v8a")
        set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -march=armv8.2-a+dotprod -O3")
        set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -march=armv8.2-a+dotprod -O3")
    endif()
    
    # Android 15 support
    target_link_options(fllama PRIVATE "-Wl,-z,max-page-size=16384")
endif()
```

## Step 10: Final Testing

```powershell
# Run on actual Android device
flutter run --release

# Test key features:
# 1. Model loading
# 2. Inference speed
# 3. Memory usage
# 4. No crashes
```

## Rollback Plan (If Things Go Wrong)

```powershell
cd C:\Users\ADMIN\Documents\HP\old_ssd\MY_FILES\fllama

# Reset to previous working state
git reset --hard HEAD~3  # Goes back 3 commits (before updates)
git push -f origin main

# In Write4me, revert to original fllama
# pubspec.yaml:
#   fllama:
#     git:
#       url: https://github.com/Telosnex/fllama.git
#       ref: main
```

## Notes

- **Android is tested at step 10** in the official process via Codemagic CI
- **Your fork will only test on your devices**, so thorough testing is crucial
- **Consider creating a branch** instead of updating main directly:
  ```powershell
  git checkout -b update-llama-cpp-$(Get-Date -Format 'yyyy-MM-dd')
  ```

## Maintenance

When Telosnex updates fllama officially:

```powershell
cd C:\Users\ADMIN\Documents\HP\old_ssd\MY_FILES\fllama

# Sync with upstream
git fetch upstream
git checkout main
git merge upstream/main
git push origin main
```

## Quick Reference

- **Your fork**: https://github.com/dragneel2074/fllama
- **Original repo**: https://github.com/Telosnex/fllama
- **llama.cpp source**: https://github.com/ggml-org/llama.cpp
- **Write4me repo**: https://github.com/dragneel2074/Write4me

## Support

If you encounter issues:
1. Check fllama's GitHub Issues: https://github.com/Telosnex/fllama/issues
2. Check llama.cpp's docs: https://github.com/ggml-org/llama.cpp/tree/master/docs
3. Review Android build logs carefully
