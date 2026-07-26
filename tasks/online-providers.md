# Write4me — Multi-provider online LLM (Pollinations modernize + Google + OpenRouter)

## Problem
- App's online text gen uses the DEAD Pollinations style:
  `GET https://text.pollinations.ai/{prompt}?model=&system=&token=`.
  Pollinations moved to `https://gen.pollinations.ai` + OpenAI-compatible
  `POST /v1/chat/completions` with `Authorization: Bearer <key>`, and keys are now
  mandatory (register + domain/referrer at enter.pollinations.ai; pk_ = client,
  rate-limited 1/hr; sk_ = server, unlimited). → keyless access is gone = app broke.
- Fix: modernize Pollinations AND add Google (Gemini) + OpenRouter as alternatives.

## Decisions (from user)
- **User picks the active provider** (radio in settings), each with its own key field.
- **Modernize Pollinations** to gen.pollinations.ai POST /v1/chat/completions + Bearer.

## Why this is clean
All three expose **OpenAI-compatible `/chat/completions` POST**:
- Pollinations: `https://gen.pollinations.ai/v1/chat/completions`, `Authorization: Bearer pk_/sk_`
- OpenRouter:   `https://openrouter.ai/api/v1/chat/completions`, `Authorization: Bearer sk-or-...`
- Google:       `https://generativelanguage.googleapis.com/v1beta/openai/chat/completions`,
                `Authorization: Bearer <GEMINI_API_KEY>` (Google's OpenAI-compat shim)
→ ONE request/response shape, 3 base URLs + keys.

Current online flow is effectively NON-streaming (single GET → `onResponse(full, true)`),
so non-streaming POST keeps the exact same callback contract. No UI streaming changes.

## Design

### New: `lib/services/online_provider.dart`
- `enum OnlineProvider { pollinations, google, openrouter }`
- Small config map: base URL, prefs-key name, docs URL, default model id, human label.
- Prefs keys: keep existing `pollination_api_key`; add `google_api_key`,
  `openrouter_api_key`, and `active_online_provider` (stores enum name).

### `online_model_service.dart` — becomes provider-aware
- Add `activeProvider` getter/setter (persisted).
- Add generic key get/has/set keyed by provider (keep `pollination_api_key` name
  for back-compat; the 2 existing Pollinations methods delegate).
- Model catalog: `text.pollinations.ai/models` is Pollinations-only. For MVP:
  - Pollinations: keep fetching its /models (but from gen host if it moved).
  - Google / OpenRouter: ship a small **static curated model list** per provider
    (e.g. OpenRouter: `openai/gpt-4o-mini`, `google/gemini-2.0-flash-exp:free`,
    `meta-llama/llama-3.3-70b-instruct`; Google: `gemini-2.0-flash`,
    `gemini-1.5-flash`). Fetching each provider's live catalog = later enhancement.
  - `availableTextModels` returns the active provider's list.

### `text_generation_service.dart` — unify request
- Replace `_buildUrl` GET path with `_chatCompletion(messages, model)`:
  `POST {activeProvider.baseUrl}/chat/completions`, header
  `Authorization: Bearer <activeProvider key>`, body
  `{model, messages:[{role,content}...], (optional) temperature}`.
  Parse `choices[0].message.content` → return string.
- Build proper `messages` from system + context + history + prompt (the old GET
  only sent the bare prompt — this is also a fix).
- Vision path (line 190): already POSTs to Pollinations openai endpoint — repoint
  to `gen.pollinations.ai/v1/chat/completions` + Bearer; other providers' vision =
  later.
- `_getUserFriendlyError`: add 401/403 → "Invalid or missing <provider> API key.
  Add it in Settings." + no-key-set guard before request.

### Settings UI (extend existing key entry)
- Existing Pollinations key field lives near Jina key (find in homepage/settings
  widget). Add: provider radio (Pollinations / Google / OpenRouter) + a key field
  per provider + a "Get a key" link (launch provider docs URL via url_launcher,
  already a dep). Persist via the service.

## Files
- NEW `lib/services/online_provider.dart`
- `lib/services/online_model_service.dart` (provider-aware keys + catalog)
- `lib/services/text_generation_service.dart` (POST /chat/completions unify)
- settings widget (provider radio + 3 key fields + get-key links) — locate exact file
- `lib/services/image_generation_service.dart` — uses Pollinations image; check if it
  also needs the key/host bump (image gen is separate; may defer)

## Verification
1. `flutter analyze lib` clean.
2. With an OpenRouter key set + provider=OpenRouter: send a chat, get a real reply.
3. With a Google (Gemini) key + provider=Google: reply works.
4. With a Pollinations pk_ key + provider=Pollinations: reply works via gen host.
5. No key for active provider → friendly "add key in settings" message, no crash.
6. Web-search flow still works (feeds results into the same POST).

## Open items to confirm
- Exact settings widget file for key entry (grep 'pollination_api_key' / Jina key UI).
- Does image generation also need modernizing now, or defer? (user only said text.)
- Google OpenAI-compat endpoint model-id format (`gemini-2.0-flash` w/o `models/`).

## Out of scope (this task)
- Live model-catalog fetch for Google/OpenRouter (static list for now).
- Auto-fallback between providers (user picks one).
- Streaming token output for online (stays single-response like today).
- Image generation modernization (deferred per user; still on old Pollinations).

## Done (analyze clean: 0 errors/warnings)
- [x] NEW `online_provider.dart`: enum + config (base URL, prefs key, get-key URL,
      static model list) for pollinations(gen.pollinations.ai)/google/openrouter.
- [x] `online_model_service.dart`: activeProvider persistence (`loadActiveProvider`/
      `setActiveProvider`), generic `getApiKey/hasApiKey/setApiKey(provider)`,
      Pollinations back-compat shims, provider-aware catalog (static list for
      google/openrouter, live fetch kept for pollinations).
- [x] `text_generation_service.dart`: unified `_chatCompletion(system,user,model)`
      POST /chat/completions + Bearer; replaced GET `_buildUrl` in BOTH normal and
      web-search paths; vision path repointed to active provider + key; removed dead
      `_buildUrl`/`_sanitizeTextForUrl` + unused FileProcessor import; added
      `MissingApiKeyException` + 401/403 + missing-key friendly errors.
- [x] `service_providers.dart`: loadActiveProvider() before fetchModels().
- [x] `online_model_selection_dialog.dart`: `_ProviderKeysSection` (radio + obscured
      key field + Save + "Get a key" link via url_launcher).
- [ ] Device test: set OpenRouter/Google key, send chat, verify reply. PENDING.

## Note for user
- Pollinations now needs a key from enter.pollinations.ai (register domain/referrer;
  pk_ = client rate-limited 1/hr, sk_ = server unlimited). Google key:
  aistudio.google.com/apikey. OpenRouter: openrouter.ai/keys.
