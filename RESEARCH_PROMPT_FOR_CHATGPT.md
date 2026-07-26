

## Research Request: Android-Only Flutter Plugin with llama.cpp (January 2025)

I need you to research and provide up-to-date information (as of January 2025 or latest available) for building a Flutter plugin that wraps llama.cpp for Android only. Please provide:

### 1. Flutter Plugin Architecture (Android-Only)
- Latest Flutter plugin structure for Android-only packages
- Best practices for `pubspec.yaml` configuration (platform: android only)
- Current Android embedding API (V2 or V3?)
- Recommended project structure for single-platform plugins

### 2. Native Communication Methods
Research these options and recommend the best for 2025:

**Option A: Method Channels**
- Current best practices
- Performance considerations
- Example code structure
- When to use vs other options

**Option B: Pigeon**
- Latest Pigeon version (check pub.dev)
- Setup and configuration for Android-only
- Code generation workflow
- Advantages over Method Channels
- Example usage with Kotlin

**Option C: FFI (dart:ffi)**
- Current state of FFI support for Android
- JNI vs direct FFI considerations
- Performance vs Method Channels
- Example structure

**Recommendation**: Which method would you recommend for a text generation streaming API in 2025?

### 3. Android Native Development Stack
- Minimum Android SDK version recommended for AI/ML workloads (2025)
- Kotlin version compatibility with latest Flutter
- Android Gradle Plugin (AGP) version recommendations
- NDK version for C++ compilation (latest stable)
- CMake version (latest stable vs what Flutter/Android supports)

### 4. CMake and C++ Build System
- Latest CMake best practices for Android NDK
- How to link external C++ libraries (llama.cpp)
- ARM64 optimization flags for 2025 devices
- Example `CMakeLists.txt` structure for Flutter plugin
- How to handle C++17/20 with current NDK

### 5. Streaming Data from Native to Dart
Research best approaches for streaming tokens:

**Option A: EventChannel**
- Current implementation patterns
- Performance characteristics
- Example code (Kotlin + Dart)
- Memory management concerns

**Option B: StreamHandler**
- Latest patterns
- Comparison with EventChannel

**Option C: Platform-specific streams**
- Kotlin Flow/Coroutines → Dart Stream
- Performance considerations

**Recommendation**: Best practice for real-time token streaming in 2025?

### 6. Background Processing
- WorkManager vs Foreground Service for long inference
- Kotlin Coroutines best practices with Flutter
- How to prevent Android from killing inference process
- Example code for background-safe inference

### 7. Memory Management
- Current Android memory limits for apps
- How to handle large models (4-8GB GGUF files)
- Memory-mapped files on Android
- OOM prevention strategies
- Example code for safe model loading

### 8. llama.cpp Integration
- Latest llama.cpp API patterns (check GitHub as of Jan 2025)
- Common build flags for Android ARM64
- Required compiler flags for optimal performance
- Known issues with llama.cpp on Android (if any)
- Example JNI wrapper patterns

### 9. Permissions and Security
- Android 15 requirements (16KB page size, permissions)
- Storage permissions for model files in 2025
- Scoped storage considerations
- Security best practices for AI models

### 10. Testing and Debugging
- How to debug C++ code in Flutter Android plugins
- Android Studio setup for native debugging
- Logging best practices (native → Dart)
- Example test structure

### 11. Performance Optimization
- Current ARM64 SIMD optimization flags
- Android-specific optimizations for inference
- Battery usage considerations
- Thermal management for sustained inference

### 12. Package Structure Best Practices
Provide example structure:
```
llama_flutter_android/
├── android/
│   ├── build.gradle
│   ├── CMakeLists.txt
│   └── src/main/
│       ├── kotlin/
│       └── cpp/
├── lib/
└── pubspec.yaml
```

With explanations for each part.

### 13. Dependencies to Research
Please check and provide latest versions:

**Pub.dev packages:**
- `pigeon` - latest version and changelog
- `ffi` - latest version
- `path_provider` - for model storage
- Any other recommended packages

**Android dependencies:**
- Kotlin stdlib version
- Coroutines version
- What else is commonly needed?

### 14. Example Code Requests

Please provide minimal example code for:
1. A Pigeon definition for text generation API
2. Kotlin implementation with streaming
3. CMakeLists.txt for linking C++ library
4. EventChannel streaming example
5. Proper resource cleanup (closing models)

### 15. Common Pitfalls
- Known issues with Flutter + Android NDK in 2025
- Common mistakes when building Android-only plugins
- Memory leak patterns to avoid
- Performance gotchas

### 16. Documentation Links
Please provide official links (that should work in Jan 2025):
- Flutter plugin development guide
- Android NDK documentation
- Pigeon documentation
- Best tutorials or examples you can find

---

## Output Format

Please structure your response as:

### Section 1: Recommended Architecture
[Your recommendation with reasoning]

### Section 2: Native Communication
[Comparison table + recommendation]

### Section 3: Build System
[Latest versions + example configs]

[Continue for all sections...]

### Final Recommendation Summary
- Suggested tech stack
- Estimated complexity
- Potential issues to watch for

---

**Important**: Please prioritize information from 2024-2025. If something has changed recently (like new Android APIs, Flutter updates, etc.), please highlight it.

Thank you!
