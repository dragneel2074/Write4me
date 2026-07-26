# Android-Only llama.cpp Flutter Wrapper - Implementation Plan

## 🎯 Project Overview

**Goal**: Create a Flutter plugin that wraps llama.cpp for Android only, allowing Write4me to use local LLMs without GPLv2 restrictions.

**Timeline**: 3-4 weeks
**License**: MIT (or your choice)
**Target**: Android ARM64 devices only

---

## 📋 Phase 1: Project Setup (Days 1-2)

### Day 1: Project Structure

#### 1.1 Create Flutter Plugin
```bash
# Create Android-only plugin
flutter create --template=plugin --platforms=android llama_flutter_android
cd llama_flutter_android
```

#### 1.2 Update pubspec.yaml
```yaml
name: llama_flutter_android
description: Flutter plugin for running llama.cpp models on Android
version: 0.1.0
homepage: https://github.com/yourusername/llama_flutter_android

environment:
  sdk: '>=3.3.0 <4.0.0'
  flutter: ">=3.24.0"

dependencies:
  flutter:
    sdk: flutter
  # WAIT FOR RESEARCH: Check latest version
  path_provider: ^2.1.0  # For model storage paths

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^4.0.0
  # WAIT FOR RESEARCH: Check if Pigeon is recommended
  pigeon: ^20.0.0  # Tentative, verify latest version

flutter:
  plugin:
    platforms:
      android:
        package: com.yourcompany.llama_flutter_android
        pluginClass: LlamaFlutterAndroidPlugin
```

#### 1.3 Project Structure
```
llama_flutter_android/
├── android/
│   ├── build.gradle
│   ├── CMakeLists.txt                 # C++ build config
│   ├── src/main/
│   │   ├── kotlin/com/yourcompany/llama_flutter_android/
│   │   │   ├── LlamaFlutterAndroidPlugin.kt  # Main plugin
│   │   │   ├── LlamaInference.kt             # Inference logic
│   │   │   └── StreamHandler.kt              # Token streaming
│   │   └── cpp/
│   │       ├── llama_bridge.cpp       # JNI bridge
│   │       ├── llama_bridge.h
│   │       └── CMakeLists.txt         # Or top-level
│   └── libs/                          # For llama.cpp if needed
├── lib/
│   ├── llama_flutter_android.dart     # Main API
│   ├── llama_model.dart               # Model wrapper
│   ├── llama_session.dart             # Session management
│   └── pigeon.g.dart                  # WAIT FOR RESEARCH: if using Pigeon
├── src/
│   └── llama.cpp/                     # Git submodule
├── example/
│   └── lib/main.dart                  # Example app
├── test/
├── pigeon.dart                        # WAIT FOR RESEARCH: if using Pigeon
├── LICENSE
└── README.md
```

### Day 2: Add llama.cpp Submodule

```bash
# Initialize git if not already
git init

# Add llama.cpp as submodule
git submodule add https://github.com/ggml-org/llama.cpp.git src/llama.cpp
git submodule update --init --recursive

# Or specific commit if needed
cd src/llama.cpp
git checkout <specific-commit-hash>
cd ../..
```

---

## 📋 Phase 2: Native Communication Setup (Days 3-5)

### Decision Point: Wait for ChatGPT Research

**Options to evaluate:**
1. **Pigeon** (type-safe, auto-generated)
2. **Method Channels** (traditional, manual)
3. **FFI** (direct, complex on Android)

### Option A: Using Pigeon (Tentative - Best Practice)

#### Day 3: Define API with Pigeon

```dart
// pigeon.dart
import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(PigeonOptions(
  dartOut: 'lib/pigeon.g.dart',
  kotlinOut: 'android/src/main/kotlin/com/yourcompany/llama_flutter_android/Pigeon.g.kt',
  kotlinOptions: KotlinOptions(
    package: 'com.yourcompany.llama_flutter_android',
  ),
))

@HostApi()
abstract class LlamaApi {
  /// Load a model from the given path
  @async
  void loadModel(String modelPath, int contextSize, int threads);
  
  /// Generate text (blocking - for simple use)
  @async
  String generateText(String prompt, int maxTokens);
  
  /// Get context usage
  @async
  int getTokenCount(String text);
  
  /// Unload the model
  @async
  void unloadModel();
}

// Generate with: dart run pigeon --input pigeon.dart
```

#### Day 4: Implement Kotlin Side

**WAIT FOR RESEARCH**: Best Kotlin patterns for 2025

```kotlin
// LlamaFlutterAndroidPlugin.kt
package com.yourcompany.llama_flutter_android

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel

class LlamaFlutterAndroidPlugin: FlutterPlugin, LlamaApi {
    private lateinit var inference: LlamaInference
    private lateinit var eventChannel: EventChannel

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        inference = LlamaInference(binding.applicationContext)
        
        // Setup Pigeon
        LlamaApi.setUp(binding.binaryMessenger, this)
        
        // Setup EventChannel for streaming
        eventChannel = EventChannel(binding.binaryMessenger, "llama_token_stream")
        eventChannel.setStreamHandler(LlamaStreamHandler(inference))
    }

    override fun loadModel(
        modelPath: String,
        contextSize: Long,
        threads: Long,
        callback: (Result<Unit>) -> Unit
    ) {
        // WAIT FOR RESEARCH: Coroutine patterns
        try {
            inference.loadModel(modelPath, contextSize.toInt(), threads.toInt())
            callback(Result.success(Unit))
        } catch (e: Exception) {
            callback(Result.failure(e))
        }
    }

    // ... other methods
    
    companion object {
        init {
            System.loadLibrary("llama_bridge")
        }
    }
}
```

#### Day 5: EventChannel for Streaming

```kotlin
// LlamaStreamHandler.kt
class LlamaStreamHandler(private val inference: LlamaInference) : EventChannel.StreamHandler {
    private var eventSink: EventChannel.EventSink? = null
    
    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
        inference.setTokenCallback { token ->
            eventSink?.success(token)
        }
    }
    
    override fun onCancel(arguments: Any?) {
        eventSink = null
        inference.clearTokenCallback()
    }
}
```

---

## 📋 Phase 3: C++ Bridge (Days 6-9)

### Day 6: CMakeLists.txt Setup

**WAIT FOR RESEARCH**: Latest CMake patterns, NDK version

```cmake
# android/CMakeLists.txt
cmake_minimum_required(VERSION 3.22.1)
project(llama_bridge)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# WAIT FOR RESEARCH: Latest optimization flags
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -march=armv8.2-a+dotprod -O3")

# Add llama.cpp
add_subdirectory(${CMAKE_CURRENT_SOURCE_DIR}/../src/llama.cpp ${CMAKE_CURRENT_BINARY_DIR}/llama_cpp)

# Your JNI bridge
add_library(llama_bridge SHARED
    src/main/cpp/llama_bridge.cpp
)

# WAIT FOR RESEARCH: Required llama.cpp components
target_link_libraries(llama_bridge
    llama
    common
    log  # Android logging
)

# WAIT FOR RESEARCH: Required compile definitions
target_compile_definitions(llama_bridge PRIVATE
    GGML_USE_CPU=1
    # Add OpenMP, etc. as needed
)
```

### Day 7: JNI Bridge Header

```cpp
// android/src/main/cpp/llama_bridge.h
#ifndef LLAMA_BRIDGE_H
#define LLAMA_BRIDGE_H

#include <jni.h>

extern "C" {

// Model management
JNIEXPORT jlong JNICALL
Java_com_yourcompany_llama_1flutter_1android_LlamaInference_nativeLoadModel(
    JNIEnv* env, jobject thiz, jstring model_path, jint ctx_size, jint threads);

JNIEXPORT void JNICALL
Java_com_yourcompany_llama_1flutter_1android_LlamaInference_nativeUnloadModel(
    JNIEnv* env, jobject thiz, jlong handle);

// Text generation
JNIEXPORT jstring JNICALL
Java_com_yourcompany_llama_1flutter_1android_LlamaInference_nativeGenerate(
    JNIEnv* env, jobject thiz, jlong handle, jstring prompt, jint max_tokens);

// Streaming generation (with callback)
JNIEXPORT void JNICALL
Java_com_yourcompany_llama_1flutter_1android_LlamaInference_nativeGenerateStream(
    JNIEnv* env, jobject thiz, jlong handle, jstring prompt, jint max_tokens);

// Tokenization
JNIEXPORT jint JNICALL
Java_com_yourcompany_llama_1flutter_1android_LlamaInference_nativeGetTokenCount(
    JNIEnv* env, jobject thiz, jlong handle, jstring text);

} // extern "C"

#endif // LLAMA_BRIDGE_H
```

### Days 8-9: JNI Bridge Implementation

```cpp
// android/src/main/cpp/llama_bridge.cpp
#include "llama_bridge.h"
#include "llama.cpp/llama.h"
#include "llama.cpp/common/common.h"
#include <android/log.h>
#include <string>
#include <vector>

#define LOG_TAG "LlamaBridge"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

struct LlamaContext {
    llama_model* model = nullptr;
    llama_context* ctx = nullptr;
    llama_vocab_view vocab;
    int n_ctx = 2048;
    int n_threads = 4;
};

// Global callback for streaming (simplified - improve in production)
static JavaVM* g_vm = nullptr;
static jobject g_callback_obj = nullptr;
static jmethodID g_callback_method = nullptr;

JNIEXPORT jint JNI_OnLoad(JavaVM* vm, void* reserved) {
    g_vm = vm;
    return JNI_VERSION_1_6;
}

JNIEXPORT jlong JNICALL
Java_com_yourcompany_llama_1flutter_1android_LlamaInference_nativeLoadModel(
    JNIEnv* env, jobject thiz, jstring model_path, jint ctx_size, jint threads) {
    
    const char* path = env->GetStringUTFChars(model_path, nullptr);
    LOGI("Loading model from: %s", path);
    
    auto* llama_ctx = new LlamaContext();
    llama_ctx->n_ctx = ctx_size;
    llama_ctx->n_threads = threads;
    
    try {
        // Load model
        auto model_params = llama_model_default_params();
        llama_ctx->model = llama_model_load_from_file(path, model_params);
        
        if (!llama_ctx->model) {
            LOGE("Failed to load model");
            delete llama_ctx;
            env->ReleaseStringUTFChars(model_path, path);
            return 0;
        }
        
        // Create context
        auto ctx_params = llama_context_default_params();
        ctx_params.n_ctx = ctx_size;
        ctx_params.n_threads = threads;
        
        llama_ctx->ctx = llama_new_context_with_model(llama_ctx->model, ctx_params);
        
        if (!llama_ctx->ctx) {
            LOGE("Failed to create context");
            llama_model_free(llama_ctx->model);
            delete llama_ctx;
            env->ReleaseStringUTFChars(model_path, path);
            return 0;
        }
        
        llama_ctx->vocab = llama_model_get_vocab(llama_ctx->model);
        
        LOGI("Model loaded successfully");
        env->ReleaseStringUTFChars(model_path, path);
        return reinterpret_cast<jlong>(llama_ctx);
        
    } catch (const std::exception& e) {
        LOGE("Exception loading model: %s", e.what());
        delete llama_ctx;
        env->ReleaseStringUTFChars(model_path, path);
        return 0;
    }
}

JNIEXPORT void JNICALL
Java_com_yourcompany_llama_1flutter_1android_LlamaInference_nativeUnloadModel(
    JNIEnv* env, jobject thiz, jlong handle) {
    
    auto* llama_ctx = reinterpret_cast<LlamaContext*>(handle);
    if (llama_ctx) {
        LOGI("Unloading model");
        if (llama_ctx->ctx) llama_free(llama_ctx->ctx);
        if (llama_ctx->model) llama_model_free(llama_ctx->model);
        delete llama_ctx;
    }
}

// WAIT FOR RESEARCH: Best streaming callback pattern for 2025
JNIEXPORT void JNICALL
Java_com_yourcompany_llama_1flutter_1android_LlamaInference_nativeGenerateStream(
    JNIEnv* env, jobject thiz, jlong handle, jstring prompt, jint max_tokens) {
    
    auto* llama_ctx = reinterpret_cast<LlamaContext*>(handle);
    if (!llama_ctx || !llama_ctx->ctx) return;
    
    // WAIT FOR RESEARCH: Implement streaming with callback
    // Tokenize, generate, call Java callback for each token
}

// ... other functions
```

---

## 📋 Phase 4: Dart API (Days 10-12)

### Day 10: High-Level API

```dart
// lib/llama_flutter_android.dart
import 'dart:async';
import 'package:flutter/services.dart';
import 'pigeon.g.dart'; // If using Pigeon

class LlamaFlutterAndroid {
  static const EventChannel _tokenStream = EventChannel('llama_token_stream');
  static final LlamaApi _api = LlamaApi();
  
  /// Load a model from file path
  Future<void> loadModel({
    required String modelPath,
    int contextSize = 2048,
    int threads = 4,
  }) async {
    await _api.loadModel(modelPath, contextSize, threads);
  }
  
  /// Generate text (blocking)
  Future<String> generateText({
    required String prompt,
    int maxTokens = 512,
  }) async {
    return await _api.generateText(prompt, maxTokens);
  }
  
  /// Generate text with streaming
  Stream<String> generateStream({
    required String prompt,
    int maxTokens = 512,
  }) {
    // WAIT FOR RESEARCH: Best streaming pattern
    return _tokenStream.receiveBroadcastStream({
      'prompt': prompt,
      'maxTokens': maxTokens,
    }).cast<String>();
  }
  
  /// Get token count for text
  Future<int> getTokenCount(String text) async {
    return await _api.getTokenCount(text);
  }
  
  /// Unload the model
  Future<void> unloadModel() async {
    await _api.unloadModel();
  }
}
```

### Day 11: Session Management

```dart
// lib/llama_session.dart
class LlamaSession {
  final LlamaFlutterAndroid _llama;
  bool _isClosed = false;
  
  LlamaSession(this._llama);
  
  void _assertNotClosed() {
    if (_isClosed) {
      throw StateError('Session is closed');
    }
  }
  
  Future<String> generate(String prompt, {int maxTokens = 512}) async {
    _assertNotClosed();
    return await _llama.generateText(prompt: prompt, maxTokens: maxTokens);
  }
  
  Stream<String> generateStream(String prompt, {int maxTokens = 512}) {
    _assertNotClosed();
    return _llama.generateStream(prompt: prompt, maxTokens: maxTokens);
  }
  
  Future<void> close() async {
    if (_isClosed) return;
    _isClosed = true;
    await _llama.unloadModel();
  }
}
```

### Day 12: Model Wrapper

```dart
// lib/llama_model.dart
class LlamaModel {
  final String modelPath;
  final int contextSize;
  final int threads;
  
  LlamaFlutterAndroid? _instance;
  
  LlamaModel({
    required this.modelPath,
    this.contextSize = 2048,
    this.threads = 4,
  });
  
  Future<LlamaSession> createSession() async {
    _instance ??= LlamaFlutterAndroid();
    
    await _instance!.loadModel(
      modelPath: modelPath,
      contextSize: contextSize,
      threads: threads,
    );
    
    return LlamaSession(_instance!);
  }
}
```

---

## 📋 Phase 5: Android Build Configuration (Days 13-14)

### Day 13: build.gradle Setup

**WAIT FOR RESEARCH**: Latest Gradle, AGP, Kotlin versions

```gradle
// android/build.gradle
buildscript {
    // WAIT FOR RESEARCH: Latest versions
    ext.kotlin_version = '1.9.22'  // Check latest
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        // WAIT FOR RESEARCH: Latest AGP
        classpath 'com.android.tools.build:gradle:8.3.0'
        classpath "org.jetbrains.kotlin:kotlin-gradle-plugin:$kotlin_version"
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

apply plugin: 'com.android.library'
apply plugin: 'kotlin-android'

android {
    // WAIT FOR RESEARCH: Minimum SDK for AI workloads in 2025
    compileSdkVersion 34
    
    compileOptions {
        sourceCompatibility JavaVersion.VERSION_17
        targetCompatibility JavaVersion.VERSION_17
    }
    
    kotlinOptions {
        jvmTarget = '17'
    }
    
    // WAIT FOR RESEARCH: Latest NDK version
    ndkVersion "25.1.8937393"
    
    defaultConfig {
        minSdkVersion 24  // WAIT FOR RESEARCH: Recommended minimum
        targetSdkVersion 34
        
        ndk {
            abiFilters 'arm64-v8a'  // Android only, ARM64 only
        }
        
        externalNativeBuild {
            cmake {
                // WAIT FOR RESEARCH: Latest optimization flags
                arguments "-DGGML_OPENMP=ON",
                          "-DCMAKE_BUILD_TYPE=Release"
                cppFlags "-std=c++17 -march=armv8.2-a+dotprod -O3"
            }
        }
    }
    
    externalNativeBuild {
        cmake {
            path "CMakeLists.txt"
            version "3.22.1"  // WAIT FOR RESEARCH: Latest compatible version
        }
    }
    
    buildTypes {
        release {
            minifyEnabled false
        }
    }
}

dependencies {
    implementation "org.jetbrains.kotlin:kotlin-stdlib:$kotlin_version"
    // WAIT FOR RESEARCH: Coroutines version
    implementation "org.jetbrains.kotlinx:kotlinx-coroutines-android:1.7.3"
}
```

### Day 14: AndroidManifest.xml

```xml
<!-- android/src/main/AndroidManifest.xml -->
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.yourcompany.llama_flutter_android">
    
    <!-- WAIT FOR RESEARCH: Required permissions for Android 15 -->
    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"
        android:maxSdkVersion="32" />
    <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE"
        android:maxSdkVersion="32" />
    
    <!-- For large model files -->
    <application android:requestLegacyExternalStorage="true">
    </application>
</manifest>
```

---

## 📋 Phase 6: Testing & Example App (Days 15-17)

### Day 15: Example App

```dart
// example/lib/main.dart
import 'package:flutter/material.dart';
import 'package:llama_flutter_android/llama_flutter_android.dart';
import 'package:path_provider/path_provider.dart';

void main() => runApp(MyApp());

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _llama = LlamaFlutterAndroid();
  String _output = '';
  bool _isLoading = false;
  
  Future<void> _loadModel() async {
    setState(() => _isLoading = true);
    
    try {
      final dir = await getApplicationDocumentsDirectory();
      final modelPath = '${dir.path}/model.gguf';
      
      await _llama.loadModel(
        modelPath: modelPath,
        contextSize: 2048,
      );
      
      setState(() {
        _output = 'Model loaded!';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _output = 'Error: $e';
        _isLoading = false;
      });
    }
  }
  
  Future<void> _generateText() async {
    setState(() => _isLoading = true);
    
    try {
      _llama.generateStream(
        prompt: 'Hello, how are you?',
        maxTokens: 100,
      ).listen((token) {
        setState(() => _output += token);
      }, onDone: () {
        setState(() => _isLoading = false);
      });
    } catch (e) {
      setState(() {
        _output = 'Error: $e';
        _isLoading = false;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: Text('Llama Flutter Android')),
        body: Column(
          children: [
            ElevatedButton(
              onPressed: _isLoading ? null : _loadModel,
              child: Text('Load Model'),
            ),
            ElevatedButton(
              onPressed: _isLoading ? null : _generateText,
              child: Text('Generate Text'),
            ),
            Expanded(
              child: SingleChildScrollView(
                child: Text(_output),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

### Days 16-17: Testing

- Test model loading
- Test generation
- Test streaming
- Test memory cleanup
- Test error handling

---

## 📋 Phase 7: Documentation & Polish (Days 18-21)

### Day 18: README.md

```markdown
# llama_flutter_android

Flutter plugin for running llama.cpp models on Android.

## Features

- 🚀 Fast local inference with llama.cpp
- 📱 Android ARM64 optimized
- 🔄 Streaming token generation
- 💾 Memory efficient
- 🎯 Simple API

## Installation

```yaml
dependencies:
  llama_flutter_android: ^0.1.0
```

## Usage

[Complete usage examples]

## Requirements

- Android SDK 24+
- ARM64 device
- Model in GGUF format

## License

MIT
```

### Days 19-20: Performance Testing

- Benchmark inference speed
- Memory usage profiling
- Battery consumption testing
- Thermal testing

### Day 21: Release Preparation

- Finalize documentation
- Create pub.dev package
- Tag v0.1.0
- Publish

---

## 🔍 Research Checkpoints

Before proceeding with each phase, verify with ChatGPT research:

### Checkpoint 1 (Before Day 3):
- [ ] Best communication method (Pigeon vs Method Channel vs FFI)
- [ ] Latest Pigeon version and setup
- [ ] EventChannel best practices

### Checkpoint 2 (Before Day 6):
- [ ] CMake version compatibility
- [ ] NDK version recommendations
- [ ] Optimization flags for ARM64
- [ ] llama.cpp build configuration

### Checkpoint 3 (Before Day 13):
- [ ] Latest Gradle/AGP/Kotlin versions
- [ ] Android 15 compatibility requirements
- [ ] Memory management best practices

### Checkpoint 4 (Before Day 15):
- [ ] Storage permissions for Android 12+
- [ ] Background processing requirements
- [ ] Battery optimization exemptions

---

## ⚠️ Known Considerations

### To Research:
1. Android 15's 16KB page size impact on llama.cpp
2. Scoped storage limitations for large model files
3. Background execution limits
4. OOM handling for 4-8GB models
5. ARM64 SIMD optimization flags
6. JNI reference management
7. Kotlin Coroutines + Native callbacks
8. Flutter 3.24+ changes

### To Decide:
1. Pigeon vs Method Channel vs FFI
2. Minimum Android SDK version
3. NDK version to target
4. llama.cpp features to enable (OpenMP, etc.)
5. Memory mapping vs loading models
6. Foreground service for long inference?

---

## 📊 Success Criteria

- [ ] Model loads successfully from file
- [ ] Text generation works (blocking)
- [ ] Streaming tokens works smoothly
- [ ] No memory leaks (tested with profiler)
- [ ] Works on Android 12-15
- [ ] Handles 4-8GB models
- [ ] Clean API, good documentation
- [ ] Example app demonstrates all features
- [ ] Published to pub.dev

---

## 🚀 Next Steps

1. **Copy prompt from `RESEARCH_PROMPT_FOR_CHATGPT.md` to ChatGPT**
2. **Get research results**
3. **Update this plan with latest information**
4. **Start Day 1 implementation**

---

**Status**: Waiting for research results
**Created**: October 8, 2025
**Project**: Write4me - Android-Only llama.cpp Wrapper
