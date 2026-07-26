# 📚 Flutter Gemma vs fllama - Architecture Study

## Executive Summary

**Flutter Gemma** uses **MediaPipe GenAI** (Google's official framework) while **fllama** uses **llama.cpp** directly. Both are MIT-licensed alternatives to build your own wrapper.

---

## 🔍 Side-by-Side Comparison

| Aspect | flutter_gemma | fllama | Your Custom Wrapper |
|--------|---------------|--------|---------------------|
| **License** | MIT ✅ | GPLv2 ❌ (commercial restrictive) | Your choice (MIT recommended) |
| **Core Engine** | MediaPipe GenAI | llama.cpp | llama.cpp (direct) |
| **Models** | Gemma, Phi, DeepSeek, Qwen, Llama | Universal (any GGUF) | Universal (any GGUF) |
| **Multimodal** | ✅ Gemma 3 Nano vision | ❌ (LLaVA experimental) | Can add later |
| **Function Calling** | ✅ Built-in | ❌ | Can add later |
| **Communication** | Pigeon (type-safe) | FFI (manual bindings) | FFI or Pigeon |
| **Complexity** | ~15KB C++, ~20KB Dart | ~30KB C++, ~30KB Dart | **~10KB C++, ~15KB Dart** |
| **Platform Support** | iOS, Android, Web | iOS, Android, Desktop | Start with Android |

---

## 🏗️ Architecture Comparison

### flutter_gemma Architecture

```
Flutter App (Dart)
    ↓
Pigeon Generated Bindings (Type-safe)
    ↓
Platform-Specific Implementation
    ├── iOS: Swift + MediaPipe GenAI (CocoaPod)
    ├── Android: Kotlin + MediaPipe GenAI (Maven)
    └── Web: JavaScript + MediaPipe WASM
    ↓
MediaPipe GenAI Framework
    ↓
TensorFlow Lite (quantized models)
```

**Key Files:**
- `pigeon.dart` - Single source of truth for API
- `PigeonInterface.g.swift` - Auto-generated iOS bindings
- `PigeonInterface.g.kt` - Auto-generated Android bindings
- `InferenceModel.swift` - iOS MediaPipe wrapper
- `InferenceModel.kt` - Android MediaPipe wrapper

### fllama Architecture

```
Flutter App (Dart)
    ↓
Manual FFI Bindings (dart:ffi)
    ↓
C++ Bridge Layer
    ├── fllama.cpp - Main inference loop
    ├── fllama_tokenize.cpp - Tokenization
    └── fllama_llava.cpp - Multimodal (experimental)
    ↓
llama.cpp (Latest from master)
    ↓
GGML (Metal/CUDA/CPU backends)
```

**Key Files:**
- `fllama_bindings_generated.dart` - FFI bindings
- `fllama.cpp` - Main C++ bridge (~73KB)
- `fllama_inference_queue.cpp` - Queue management (~19KB)
- Direct integration with llama.cpp

### Your Custom Wrapper (Recommended Approach)

```
Flutter App (Dart)
    ↓
Pigeon Generated Bindings (Best Practice)
    OR
Manual FFI (Simpler but less safe)
    ↓
Minimal C++ Bridge (~10KB)
    ├── llama_bridge.cpp - 5 core functions
    └── Thin wrapper around llama.cpp
    ↓
llama.cpp (Latest from master)
    ↓
GGML (optimized for ARM)
```

---

## 💡 Key Learnings from flutter_gemma

### 1. **Pigeon for Type Safety** ⭐⭐⭐⭐⭐

flutter_gemma uses **Pigeon** to auto-generate platform bindings:

```dart
// pigeon.dart - Single source of truth
@HostApi()
abstract class PlatformService {
  @async
  void createModel({
    required int maxTokens,
    required String modelPath,
    required List<int>? loraRanks,
    PreferredBackend? preferredBackend,
    int? maxNumImages,
  });
  
  @async
  String generateResponse();
  
  @async
  void closeModel();
}
```

**Benefits:**
- ✅ Type-safe communication (compile-time checks)
- ✅ Auto-generates Swift, Kotlin, and Dart code
- ✅ Handles serialization automatically
- ✅ Cleaner than manual FFI

**For Your Wrapper:**
```bash
# Add to pubspec.yaml
dev_dependencies:
  pigeon: ^20.0.0

# Generate bindings
dart run pigeon --input pigeon.dart
```

### 2. **Session vs Chat Pattern** ⭐⭐⭐⭐

flutter_gemma separates:
- **Session** - Single inference, manual management
- **Chat** - Conversation context, automatic session refresh

```dart
// Session (single use)
final session = await model.createSession();
await session.addQueryChunk(Message.text(text: 'Hello'));
final response = await session.getResponse();
await session.close(); // Must close manually

// Chat (conversation)
final chat = await model.createChat();
await chat.addQueryChunk(Message.text(text: 'Hello'));
final response1 = await chat.generateChatResponse();
// Chat manages sessions automatically
await chat.addQueryChunk(Message.text(text: 'Follow-up'));
final response2 = await chat.generateChatResponse();
```

**For Your Wrapper:**
Start with Session only, add Chat later.

### 3. **Streaming via EventChannel** ⭐⭐⭐⭐⭐

flutter_gemma uses `EventChannel` for streaming tokens:

**iOS (Swift):**
```swift
class PlatformServiceImpl: NSObject, FlutterStreamHandler {
    private var eventSink: FlutterEventSink?
    
    func onListen(withArguments arguments: Any?, 
                  eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        return nil
    }
    
    func generateResponseAsync() {
        Task {
            for try await token in session.generateResponseAsync() {
                // Send each token to Flutter
                eventSink?(token)
            }
        }
    }
}
```

**Android (Kotlin):**
```kotlin
class PlatformServiceImpl : EventChannel.StreamHandler {
    private var eventSink: EventChannel.EventSink? = null
    
    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }
    
    fun generateResponseAsync() {
        scope.launch {
            session.generateResponseAsync().collect { token ->
                // Send each token to Flutter
                eventSink?.success(token)
            }
        }
    }
}
```

**Dart:**
```dart
EventChannel('flutter_gemma_stream')
    .receiveBroadcastStream()
    .listen((token) {
  print('Received token: $token');
});
```

**For Your Wrapper:**
Use EventChannel for token streaming - much cleaner than callbacks!

### 4. **Model File Management** ⭐⭐⭐⭐

flutter_gemma has sophisticated model management:

```dart
class ModelFileManager {
  // Check if model is valid
  static Future<bool> isFileValid(String path, {int minSize = 1024*1024}) async {
    final file = File(path);
    if (!await file.exists()) return false;
    final size = await file.length();
    return size >= minSize;
  }
  
  // Ensure model is ready (auto-download if needed)
  Future<void> ensureModelReady(String modelName, String url) async {
    final modelPath = await getModelPath(modelName);
    
    if (await isFileValid(modelPath)) {
      print('Model already exists');
      return;
    }
    
    print('Downloading model...');
    await downloadModel(url, modelPath);
  }
  
  // Replace policy: keep or replace old models
  Future<void> setReplacePolicy(ModelReplacePolicy policy) async {
    // Save to SharedPreferences
  }
}
```

**For Your Wrapper:**
Start simple - just load from path. Add download/management later.

### 5. **Error Handling with Pigeon** ⭐⭐⭐⭐

flutter_gemma uses structured errors:

**Swift:**
```swift
class PigeonError: Error {
    let code: String
    let message: String?
    let details: Sendable?
}

func createModel(...) {
    do {
        model = try InferenceModel(modelPath: path)
        completion(.success(()))
    } catch {
        completion(.failure(PigeonError(
            code: "ModelLoadError",
            message: error.localizedDescription,
            details: nil
        )))
    }
}
```

**Dart:**
```dart
try {
  await platformService.createModel(maxTokens: 1024, modelPath: '/path/to/model');
} on PlatformException catch (e) {
  print('Error ${e.code}: ${e.message}');
  // Handle specific error types
}
```

**For Your Wrapper:**
Use error codes: "ModelNotFound", "OutOfMemory", "InvalidModel", etc.

### 6. **Background Processing** ⭐⭐⭐⭐⭐

flutter_gemma uses Isolates for heavy work:

```dart
class MobileInferenceModel {
  Completer<InferenceModel>? _initCompleter;
  
  Future<InferenceModel> createModel(...) async {
    if (_initCompleter case Completer<InferenceModel> completer) {
      // Already initializing, return same future
      return completer.future;
    }
    
    final completer = _initCompleter = Completer<InferenceModel>();
    
    try {
      // Heavy work in background
      await platformService.createModel(...);
      completer.complete(this);
    } catch (e) {
      completer.completeError(e);
    }
    
    return completer.future;
  }
}
```

**For Your Wrapper:**
Native code already runs in background. Just ensure UI doesn't block.

### 7. **Memory Management** ⭐⭐⭐⭐⭐

flutter_gemma has strict cleanup:

```dart
class MobileInferenceModelSession {
  bool _isClosed = false;
  
  void _assertNotClosed() {
    if (_isClosed) {
      throw Exception('Model is closed. Create a new instance to use it again');
    }
  }
  
  @override
  Future<void> addQueryChunk(Message message) async {
    _assertNotClosed();
    await _awaitLastResponse(); // Wait for previous response
    // ... add chunk
  }
  
  @override
  Future<void> close() async {
    if (_isClosed) return;
    _isClosed = true;
    await platformService.closeSession();
  }
}
```

**For Your Wrapper:**
Always provide close() methods and enforce single-use sessions.

---

## 🎯 What to Learn from Each

### From flutter_gemma (⭐ Highly Recommended):

1. **Use Pigeon** for type-safe communication
2. **EventChannel** for streaming tokens
3. **Session vs Chat** separation
4. **Proper error handling** with error codes
5. **Memory management** patterns
6. **Model file validation** before loading
7. **Platform-specific setup** (iOS entitlements, Android OpenCL)

### From fllama:

1. **Direct llama.cpp integration** - no middleman
2. **Support for latest models** (GGUF format)
3. **Queue-based inference** for multiple requests
4. **LLaVA support** (multimodal) - experimental
5. **LoRA weights** handling
6. **Minimal overhead** - thin wrapper

### From Both:

1. **Async/await everywhere** - no blocking UI
2. **Streaming responses** - better UX
3. **Context management** - track token usage
4. **Cross-platform** abstractions
5. **Model download** with progress
6. **Resource cleanup** to prevent leaks

---

## 🚀 Recommended Approach for Your Wrapper

### Phase 1: Minimal Viable Wrapper (Like flutter_gemma architecture)

```dart
// Use Pigeon for type safety
@HostApi()
abstract class LlamaService {
  @async
  void loadModel(String path, int contextSize);
  
  @async
  String generate(String prompt, int maxTokens);
  
  @async
  void unloadModel();
}
```

```cpp
// Minimal C++ bridge (llama_bridge.cpp)
#include "llama.cpp/llama.h"
#include "llama.cpp/common/common.h"

extern "C" {
  // Simple, focused API
  void* llama_load_model(const char* path, int ctx_size) {
    auto params = llama_model_default_params();
    auto model = llama_model_load_from_file(path, params);
    
    auto ctx_params = llama_context_default_params();
    ctx_params.n_ctx = ctx_size;
    auto ctx = llama_new_context_with_model(model, ctx_params);
    
    return ctx; // Return opaque handle
  }
  
  const char* llama_generate(void* ctx, const char* prompt, int max_tokens) {
    // Simple generation logic
    // Return generated text
  }
  
  void llama_unload(void* ctx) {
    llama_free((llama_context*)ctx);
  }
}
```

### Phase 2: Add Streaming (Like flutter_gemma)

```dart
// Add EventChannel
class LlamaPlugin {
  static const EventChannel _tokenStream = EventChannel('llama_token_stream');
  
  Stream<String> generateStream(String prompt) {
    return _tokenStream.receiveBroadcastStream(prompt);
  }
}
```

```cpp
// C++ callback for tokens
void token_callback(const char* token, void* user_data) {
  FlutterEventSink* sink = (FlutterEventSink*)user_data;
  // Send token to Flutter
  sink->send(token);
}
```

### Phase 3: Advanced Features

- Chat context management
- Model file validation
- Download with progress
- LoRA support
- Multimodal (later)

---

## 📦 Recommended Stack

### Core Communication:
- **Pigeon** - Type-safe bindings (learn from flutter_gemma)
- **EventChannel** - Token streaming
- **MethodChannel** - Simple calls (alternative to Pigeon)

### Build System:
- **CMake** - Cross-platform C++ builds (like fllama)
- **Gradle** - Android integration
- **CocoaPods** - iOS integration

### Architecture:
```
Your Wrapper
├── pigeon.dart (API definition)
├── lib/
│   ├── llama_flutter.dart (High-level API)
│   ├── pigeon.g.dart (Generated)
│   └── llama_session.dart (Session management)
├── ios/
│   ├── llama_bridge.cpp (Thin C++ wrapper)
│   └── LlamaPlugin.swift (Swift glue)
├── android/
│   ├── llama_bridge.cpp (Same C++ code)
│   └── LlamaPlugin.kt (Kotlin glue)
└── src/
    └── llama.cpp/ (Git submodule)
```

---

## 🎓 Implementation Priorities

### Must Have (Week 1):
1. ✅ Pigeon setup for type-safe API
2. ✅ Model loading from file path
3. ✅ Basic text generation (blocking)
4. ✅ Android CMake build
5. ✅ Memory cleanup (close methods)

### Should Have (Week 2):
1. ✅ EventChannel for streaming tokens
2. ✅ Error handling with codes
3. ✅ Session management
4. ✅ Context size tracking
5. ✅ iOS build support

### Nice to Have (Week 3):
1. ⚪ Chat context management
2. ⚪ Model file validation
3. ⚪ Download with progress
4. ⚪ Multiple model support
5. ⚪ LoRA weights

### Future:
1. ⚪ Multimodal support
2. ⚪ Function calling
3. ⚪ Embeddings
4. ⚪ RAG pipeline
5. ⚪ Web support

---

## 🔧 Practical Code Snippets

### 1. Pigeon Definition (Your API)

```dart
// pigeon.dart
import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(PigeonOptions(
  dartOut: 'lib/pigeon.g.dart',
  kotlinOut: 'android/src/main/kotlin/com/yourcompany/llama_flutter/Pigeon.g.kt',
  swiftOut: 'ios/Classes/Pigeon.g.swift',
))

@HostApi()
abstract class LlamaApi {
  @async
  void loadModel(String modelPath, int contextSize);
  
  @async
  String generate(String prompt, int maxTokens);
  
  @async
  int getContextSize();
  
  @async
  void unload();
}
```

### 2. Android Implementation (Kotlin + C++)

```kotlin
// LlamaPlugin.kt
class LlamaPlugin: FlutterPlugin, LlamaApi {
    private external fun nativeLoadModel(path: String, ctxSize: Int): Long
    private external fun nativeGenerate(handle: Long, prompt: String, maxTokens: Int): String
    private external fun nativeUnload(handle: Long)
    
    private var modelHandle: Long = 0
    
    override fun loadModel(modelPath: String, contextSize: Long, callback: (Result<Unit>) -> Unit) {
        try {
            modelHandle = nativeLoadModel(modelPath, contextSize.toInt())
            callback(Result.success(Unit))
        } catch (e: Exception) {
            callback(Result.failure(e))
        }
    }
    
    override fun generate(prompt: String, maxTokens: Long, callback: (Result<String>) -> Unit) {
        try {
            val result = nativeGenerate(modelHandle, prompt, maxTokens.toInt())
            callback(Result.success(result))
        } catch (e: Exception) {
            callback(Result.failure(e))
        }
    }
    
    companion object {
        init {
            System.loadLibrary("llama_flutter")
        }
    }
}
```

### 3. iOS Implementation (Swift + C++)

```swift
// LlamaPlugin.swift
class LlamaPlugin: NSObject, FlutterPlugin, LlamaApi {
    private var modelHandle: OpaquePointer?
    
    func loadModel(modelPath: String, contextSize: Int64, 
                   completion: @escaping (Result<Void, Error>) -> Void) {
        do {
            modelHandle = llama_load_model(modelPath, Int32(contextSize))
            if modelHandle == nil {
                throw NSError(domain: "LlamaPlugin", code: 1, 
                             userInfo: [NSLocalizedDescriptionKey: "Failed to load model"])
            }
            completion(.success(()))
        } catch {
            completion(.failure(error))
        }
    }
    
    func generate(prompt: String, maxTokens: Int64, 
                  completion: @escaping (Result<String, Error>) -> Void) {
        let result = llama_generate(modelHandle, prompt, Int32(maxTokens))
        if let result = result {
            completion(.success(String(cString: result)))
        } else {
            completion(.failure(NSError(domain: "LlamaPlugin", code: 2)))
        }
    }
}
```

### 4. C++ Bridge (Cross-platform)

```cpp
// llama_bridge.cpp
#include "llama.cpp/llama.h"
#include "llama.cpp/common/common.h"
#include <string>

extern "C" {

struct LlamaContext {
    llama_model* model;
    llama_context* ctx;
    llama_vocab_view vocab;
};

void* llama_load_model(const char* path, int ctx_size) {
    auto* llama_ctx = new LlamaContext();
    
    // Load model
    auto model_params = llama_model_default_params();
    llama_ctx->model = llama_model_load_from_file(path, model_params);
    if (!llama_ctx->model) {
        delete llama_ctx;
        return nullptr;
    }
    
    // Create context
    auto ctx_params = llama_context_default_params();
    ctx_params.n_ctx = ctx_size;
    llama_ctx->ctx = llama_new_context_with_model(llama_ctx->model, ctx_params);
    if (!llama_ctx->ctx) {
        llama_model_free(llama_ctx->model);
        delete llama_ctx;
        return nullptr;
    }
    
    llama_ctx->vocab = llama_model_get_vocab(llama_ctx->model);
    return llama_ctx;
}

const char* llama_generate(void* handle, const char* prompt, int max_tokens) {
    auto* llama_ctx = (LlamaContext*)handle;
    
    // Tokenize prompt
    std::vector<llama_token> tokens;
    tokens.resize(strlen(prompt) + 16);
    int n_tokens = llama_tokenize(
        llama_ctx->model,
        prompt,
        strlen(prompt),
        tokens.data(),
        tokens.size(),
        true,
        false
    );
    tokens.resize(n_tokens);
    
    // Generate
    std::string result;
    llama_batch batch = llama_batch_init(tokens.size(), 0, 1);
    
    for (size_t i = 0; i < tokens.size(); i++) {
        llama_batch_add(batch, tokens[i], i, {0}, false);
    }
    batch.logits[batch.n_tokens - 1] = true;
    
    llama_decode(llama_ctx->ctx, batch);
    
    // Sample and generate tokens
    for (int i = 0; i < max_tokens; i++) {
        llama_token token = llama_vocab_sample(llama_ctx->ctx, llama_ctx->vocab, batch, 0.8f, 40, 0.95f);
        
        if (llama_vocab_is_eog(llama_ctx->vocab, token)) {
            break;
        }
        
        // Detokenize
        char buf[256];
        int len = llama_token_to_piece(llama_ctx->model, token, buf, sizeof(buf), 0, false);
        if (len > 0) {
            result.append(buf, len);
        }
        
        // Prepare next batch
        llama_batch_clear(batch);
        llama_batch_add(batch, token, tokens.size() + i, {0}, true);
        llama_decode(llama_ctx->ctx, batch);
    }
    
    llama_batch_free(batch);
    
    // Return as static string (simplified - use better memory management in production)
    static std::string static_result;
    static_result = result;
    return static_result.c_str();
}

void llama_unload(void* handle) {
    auto* llama_ctx = (LlamaContext*)handle;
    if (llama_ctx) {
        llama_free(llama_ctx->ctx);
        llama_model_free(llama_ctx->model);
        delete llama_ctx;
    }
}

} // extern "C"
```

---

## 📊 Complexity Comparison

| Component | flutter_gemma | fllama | Your Wrapper (Recommended) |
|-----------|---------------|--------|----------------------------|
| **API Layer** | Pigeon (auto-gen) | Manual FFI | Pigeon (learn from flutter_gemma) |
| **C++ Bridge** | MediaPipe wrapper | Direct llama.cpp | Thin llama.cpp wrapper |
| **Lines of Code** | ~15K C++, ~20K Dart | ~30K C++, ~30K Dart | **~10K C++, ~15K Dart** |
| **Build Complexity** | CocoaPods/Gradle auto | CMake manual | CMake (copy from fllama) |
| **Maintenance** | Google maintains | You maintain | You maintain |
| **Flexibility** | Limited to MediaPipe | Full llama.cpp | Full llama.cpp |
| **License** | MIT ✅ | GPLv2 ❌ | Your choice ✅ |

---

## 🎯 Final Recommendation

### For Write4me Project:

**Build your own using flutter_gemma's architecture + fllama's llama.cpp integration:**

1. **Use Pigeon** (from flutter_gemma) for type-safe API
2. **Thin C++ wrapper** (from fllama) around latest llama.cpp
3. **EventChannel** (from flutter_gemma) for streaming
4. **CMake build** (from fllama) for Android/iOS
5. **Session management** (from flutter_gemma) patterns

### Estimated Timeline:

- **Week 1**: Pigeon + basic generation (50% complete)
- **Week 2**: Streaming + session management (80% complete)
- **Week 3**: Polish + documentation (100% complete)

### Why This Approach:

- ✅ **Best of both worlds**
- ✅ **MIT license** (no restrictions)
- ✅ **Latest llama.cpp** (newest models)
- ✅ **Type-safe** (Pigeon)
- ✅ **Simple** (~10KB of meaningful code)
- ✅ **Maintainable** (clear architecture)

---

## 📚 Additional Resources

### flutter_gemma:
- GitHub: https://github.com/DenisovAV/flutter_gemma
- Pub.dev: https://pub.dev/packages/flutter_gemma
- Uses: MediaPipe GenAI v0.10.24
- License: MIT

### fllama:
- GitHub: https://github.com/Telosnex/fllama (upstream)
- Your fork: https://github.com/dragneel2074/fllama
- Uses: llama.cpp (latest master)
- License: GPLv2 (restrictive)

### Pigeon:
- Pub.dev: https://pub.dev/packages/pigeon
- Guide: https://docs.flutter.dev/packages-and-plugins/developing-packages#pigeon

### llama.cpp:
- GitHub: https://github.com/ggml-org/llama.cpp
- License: MIT
- Latest API docs in header files

---

**Next Steps**: Start with Pigeon setup and minimal C++ bridge. Use flutter_gemma patterns but llama.cpp engine! 🚀

**Status**: Ready to implement
**Estimated Time**: 3-4 weeks for production-ready wrapper
**Confidence**: High (both projects prove it's achievable)
