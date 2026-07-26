# Write4me — Migrate fllama → llama_flutter_android

## Goal
Replace the dead `fllama` git dependency with the maintained
`llama_flutter_android` (0.2.6) package. App must build and generate on-device
responses again. Success = `flutter pub get` resolves, app builds, and offline
model chat streams tokens as before.

## Why
- `fllama` dep points at `github.com/dragneel2074/fllama.git` → **404, repo gone**.
  `pub get` fails; app is currently un-buildable.
- We now maintain `llama_flutter_android`; Write4me should use it, not the fork.

## Key findings (from investigation)
- **All fllama coupling is in ONE file**: `lib/services/offline_model_service.dart`,
  ONE method: `generateStreamingResponse`. API used: `Message`, `Role`,
  `OpenAiRequest`, `fllamaChat`. Everything else (download, prefs, prompt-building,
  token estimate) is package-agnostic — untouched.
- Write4me does its **own prompt engineering** (builds one big string, sends as a
  single `Message(Role.user, ...)`). So we can use the package's simpler
  `generate(prompt:)` (raw completion) — **no chat templates needed**, avoids
  template-mismatch bugs.
- **Two semantic gaps to bridge:**
  1. Lifecycle: fllama is stateless (loads model per call); package is stateful
     (`loadModel()` once, then `generate()`). → add load-on-demand + reload when
     selected model changes.
  2. Streaming: fllama callback gives **cumulative** text; package yields a
     **Stream of deltas**. → accumulate deltas into a buffer, keep feeding the
     existing `onResponse(fullText, done)` contract → **zero UI changes**.

## Plan
1. **Dependency swap** → verify: `flutter pub get` resolves.
   - `pubspec.yaml`: remove `fllama` git dep; add
     `llama_flutter_android: ^0.2.6` (from pub.dev).
   - Keep `fonnx` (repoint if its git also 404s — check separately).
2. **Rewrite the LLM call in `offline_model_service.dart`** → verify: analyzer clean.
   - Hold a single `LlamaController` instance in the service.
   - `_ensureModelLoaded(path, contextSize)`: if not loaded or path changed →
     `dispose()`/`loadModel(modelPath: path, contextSize: …)`.
   - Replace `fllamaChat(...)` block: build the same `truncatedPrompt`, call
     `controller.generate(prompt: truncatedPrompt, maxTokens:…, temperature:…,
     topP:…, frequencyPenalty:…, presencePenalty:…)`; accumulate deltas; call
     `onResponse(buffer, false)` per delta, `onResponse(buffer, true)` on done.
   - Remove `Message`/`Role`/`OpenAiRequest` usage + the `fllama` import.
   - Cancellation: use `controller.stop()` where fllama cancel was used.
3. **Dispose wiring** → verify: no leaked native context.
   - Dispose `LlamaController` in `OfflineModelService.dispose()` / app teardown.
4. **Build** → verify: `flutter build apk --debug` succeeds.
5. **Runtime smoke test** on device → verify: download/select a small GGUF,
   send a prompt, tokens stream, output coherent, stop works.

## Decisions
- Dep source: pub.dev `llama_flutter_android: ^0.2.6`.
- Scope: migration **+** modernization (SDK/gradle/deps/lints). Sequence:
  **(A) get building on new package first**, then **(B) modernize** on top of a
  known-good baseline.

## Phase B — modernization (after A builds)
6. `flutter pub outdated` → bump deps (`flutter pub upgrade --major-versions`),
   fix breaking changes package-by-package. verify: analyzer + build.
7. Android: Groovy `build.gradle` → `.kts`, bump AGP/Gradle/compileSdk/targetSdk,
   `flutter_lints ^3 → ^6`. verify: `flutter build apk --release`.
8. Re-run device smoke test. verify: parity with Phase A behavior.

## Out of scope (this task)
- Any UI/RAG/prompt-logic changes — behavior preserved exactly.

## Open items to confirm during step 1
- Does `fonnx` git dep still resolve? (separate 404 risk.)
- Does the package's `generate()` cover all params Write4me sets? (topK/minP have
  defaults; frequencyPenalty/presencePenalty/topP/temperature/maxTokens all map.)

## Progress (Phase A)
- [x] pubspec: fllama removed, `llama_flutter_android: ^0.2.6` added; `pub get`
      resolves (fonnx still OK).
- [x] `offline_model_service.dart` rewritten: LlamaController field +
      `_ensureModelLoaded` (stateful load/reload), `dispose()` override,
      `generate()` delta→cumulative accumulation, history inlined into prompt,
      `hide ChatMessage` on package import.
- [x] `flutter analyze lib/` — 0 errors (20 info: pre-existing deprecations +
      path_provider lint). No fllama refs remain anywhere.
- [ ] `flutter build apk --debug` — pending.
- [ ] Device smoke test — pending.

## Review (Opus, Fable was credit-blocked)
Verdict: migration correct on happy path. Fixed 2 IMPORTANT regressions + 1 dead-code:
- [x] Stop button dead → `OfflineModelService.stopGeneration()` calls `_llama.stop()`,
      wired from `AIService.stopGeneration()`.
- [x] `dispose()` never ran → provider now `ChangeNotifierProvider` (frees native
      model at teardown). Verified all `ref.read/watch/listen` call sites still work.
- [x] Dropped dead `firstResponse` local.
- Analyze clean (0 errors/warnings; 20 pre-existing info lints).
Deferred (minor, Phase B): StateError→friendly msg, char-truncation mid-multibyte,
download method dup.
