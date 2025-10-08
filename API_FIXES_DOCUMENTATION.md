# API Compatibility Fixes for fllama + Latest llama.cpp

## Summary of Changes

This document details all the API changes needed to make fllama compatible with the latest llama.cpp.

---

## Error 1: flash_attn Parameter Removed

**File**: `src/fllama.cpp`  
**Lines**: 686-687

### Original Code:
```cpp
ctx_params.flash_attn = false;
log_message("[fllama] flash_attn: " + std::to_string(ctx_params.flash_attn), request.dart_logger);
```

### Fixed Code:
```cpp
// Remove both lines - flash_attn no longer exists in llama_context_params
```

**Explanation**: The `flash_attn` parameter was removed from `llama_context_params` struct in newer llama.cpp versions.

---

## Error 2: common_chat_format_example Function Signature Changed

**File**: `src/fllama.cpp`  
**Line**: 968

### Original Code:
```cpp
common_chat_format_example(chat_templates.get(), true);
```

### Fixed Code:
```cpp
common_chat_format_example(chat_templates.get(), llama_chat_builtin_template{}, true);
```

**Explanation**: The function now requires 3 arguments instead of 2. The middle argument is the builtin template parameter.

---

## Error 3: Deprecated Token Functions

### 3.1 llama_n_embd (fllama_llava.cpp, line 126)

**Original**: `llama_n_embd(llama_get_model(ctx_llama))`  
**Fixed**: `llama_model_n_embd(llama_get_model(ctx_llama))`

### 3.2 llama_token_bos (fllama_llava.cpp, line 136)

**Original**: `llama_token_bos(llama_model_get_vocab(llama_get_model(ctx_llama)))`  
**Fixed**: `llama_vocab_bos(llama_model_get_vocab(llama_get_model(ctx_llama)))`

### 3.3 llama_token_eos (fllama_llava.cpp, line 173 & fllama.cpp, line 1406)

**Original**: `llama_token_eos(vocab)`  
**Fixed**: `llama_vocab_eos(vocab)`

### 3.4 llama_add_bos_token (fllama.cpp, line 1270)

**Original**: `llama_add_bos_token(vocab)`  
**Fixed**: `llama_vocab_get_add_bos(vocab)`

### 3.5 llama_token_is_eog (fllama.cpp, lines 1565, 1602)

**Original**: `llama_token_is_eog(vocab, new_token_id)`  
**Fixed**: `llama_vocab_is_eog(vocab, new_token_id)`

### 3.6 llama_load_model_from_file (fllama_tokenize.cpp, line 136)

**Original**: `llama_load_model_from_file(model_path.c_str(), mparams)`  
**Fixed**: `llama_model_load_from_file(model_path.c_str(), mparams)`

### 3.7 llama_free_model (fllama_tokenize.cpp, line 144)

**Original**: `llama_free_model(ptr)`  
**Fixed**: `llama_model_free(ptr)`

---

## API Changes Summary Table

| Old Function | New Function | Reason |
|-------------|--------------|---------|
| `flash_attn` (param) | *removed* | Removed from struct |
| `common_chat_format_example(a, b)` | `common_chat_format_example(a, {}, b)` | Signature changed |
| `llama_n_embd()` | `llama_model_n_embd()` | Renamed for consistency |
| `llama_token_bos()` | `llama_vocab_bos()` | Moved to vocab namespace |
| `llama_token_eos()` | `llama_vocab_eos()` | Moved to vocab namespace |
| `llama_token_is_eog()` | `llama_vocab_is_eog()` | Moved to vocab namespace |
| `llama_add_bos_token()` | `llama_vocab_get_add_bos()` | Renamed for clarity |
| `llama_load_model_from_file()` | `llama_model_load_from_file()` | Renamed for consistency |
| `llama_free_model()` | `llama_model_free()` | Renamed for consistency |

---

## Files That Need Changes

1. **src/fllama.cpp** - Main implementation
   - Remove flash_attn (lines 686-687)
   - Fix common_chat_format_example (line 968)
   - Replace deprecated functions (lines 1270, 1406, 1565, 1602)

2. **src/fllama_llava.cpp** - LLaVA multimodal support
   - Replace deprecated functions (lines 126, 136, 173)

3. **src/fllama_tokenize.cpp** - Tokenization
   - Replace deprecated functions (lines 136, 144)

---

## Testing Checklist

After applying fixes:
- [ ] Build completes without errors
- [ ] Model loading works
- [ ] Text generation works
- [ ] Tokenization works
- [ ] LLaVA/multimodal works (if used)
- [ ] No memory leaks
- [ ] Performance is acceptable

---

## Rollback Plan

If fixes cause issues:
1. Restore from backup directory
2. Use compatible llama.cpp version from Telosnex/fllama
3. Report issues to fllama maintainers

---

## Benefits of Using Latest llama.cpp

✅ **Model Support**
- Qwen 2.5 models
- Llama 3.3 models
- DeepSeek V3
- Other recent architectures

✅ **Performance**
- Faster inference on ARM64
- Better quantization
- Improved memory usage

✅ **Android Improvements**
- Android 15 (16KB page size) support
- Better ARM optimizations
- Reduced latency

✅ **Bug Fixes**
- Stability improvements
- Edge case handling
- Memory leak fixes
