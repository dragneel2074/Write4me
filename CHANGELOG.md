# Changelog

Notable project changes are organized by the date they were completed. This
project currently uses the app version declared in `pubspec.yaml`; dated entries
avoid assigning release numbers retroactively.

## 2026-07-25

### Added

- Android on-device GGUF inference through `llama_flutter_android`.
- Importing GGUF models from device storage and downloading them by URL.
- Local generation controls for context, output length, sampling, penalties,
  and GPU layers.
- Configurable local-model auto-unload timer to reduce idle memory use.
- Bring-your-own-key support for Pollinations, Gemini, and OpenRouter.
- Dynamic authenticated model loading for every cloud provider.
- Pollinations text, image, and video generation flows.
- Persistent chat history with reopening and deleting older conversations.
- PDF, image/OCR, and text-file attachments with visible processing state.
- Attachment metadata on sent messages and restored chat history.
- Approximate context-used and context-remaining indicators.

### Changed

- Replaced fixed cloud model names with provider-returned catalogs and an
  explicit **Load models** action.
- Reworked local chat generation to pass structured role history and respect
  chat-template stop behavior.
- Limited document retrieval context instead of inserting entire PDFs into a
  small model context.
- Moved PDF indexing to background processing with a bounded raw-text fallback.
- Cleared composer attachments after sending while retaining them on the sent
  message.
- Redesigned status notifications and attachment cards for clearer hierarchy,
  progress, and error actions.
- Updated project documentation for the Android-first local/cloud architecture.

### Fixed

- On-device selection not opening or reflecting the selected local model.
- Device file import actions appearing to do nothing.
- Short prompts continuing generation unnecessarily with compatible chat
  templates.
- Conversation history not being passed consistently to generation.
- Attached images/files remaining in the composer after a message was sent.
- PDFs appearing unresponsive while extraction and indexing were running.
- Large PDF text causing context usage to exceed the configured local window.

## 2025-10-08

### Changed

- Updated the earlier local llama.cpp integration and related model handling.
- Applied follow-up stability fixes.

## 2025-07-27

### Changed

- Updated the application version and release configuration.

## 2025-07-22

### Changed

- Updated About content and supporting project assets.

## 2025-07-21

### Fixed

- Corrected context clearing behavior around vision processing.

## Earlier history

Earlier changes predate the maintained dated changelog. Consult Git history for
commit-level detail.
