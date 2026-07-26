# Write4Me

![Write4Me logo](assets/images/playstore.png)

Write4Me is an Android-first Flutter writing assistant with private on-device
GGUF inference, bring-your-own-key cloud providers, persistent conversations,
and document-aware chat.

## What it can do

- Run compatible GGUF language models locally with
  `llama_flutter_android`.
- Import a GGUF file from device storage or download one from a URL.
- Tune local generation settings, including context size, output length,
  temperature, top-p, top-k, min-p, repeat penalty, frequency penalty,
  presence penalty, and GPU layers.
- Automatically unload an idle local model to reduce memory pressure.
- Use Pollinations, Gemini, or OpenRouter with an API key supplied by the user.
- Fetch each provider's current model catalog after a key is saved; cloud model
  names are not hardcoded.
- Generate text with all three cloud providers and generate images or videos
  with supported Pollinations models.
- Attach PDFs, images, and supported text files to a conversation.
- Index documents locally and retrieve relevant excerpts for a response.
- Save chats locally, reopen older conversations, and display sent attachments
  with the message that used them.
- Show approximate context usage while a conversation is in progress.

## Current limitations

- The local GGUF runtime is Android-only and requires Android API 26 or newer.
- Image attachments are processed with on-device OCR; they are not passed as
  native multimodal image inputs.
- Attachments are limited to 2 MB each.
- Cloud access, model availability, pricing, and media capabilities are
  controlled by the selected provider.
- A model that is too large for the device can still exhaust memory. Use a
  smaller quantization, fewer GPU layers, a smaller context, and auto-unload.

## Run the project

Prerequisites:

- Flutter stable
- Android SDK and an Android API 26+ device or emulator

```shell
flutter pub get
flutter run
```

Build a debug APK:

```shell
flutter build apk --debug
```

The APK is written to `build/app/outputs/apk/debug/app-debug.apk`.

## First use

### On-device mode

1. Open the model selector and choose **On device**.
2. Import a `.gguf` model from device storage or download one by URL.
3. Select and load the model.
4. Open local model settings to tune generation and auto-unload.
5. Start a chat.

Only use GGUF models whose architecture is supported by the bundled runtime.
Model compatibility, memory requirements, and licenses vary by publisher.

### Cloud mode

1. Open the model selector and choose Pollinations, Gemini, or OpenRouter.
2. Enter and save an API key for that provider.
3. Tap **Load models**.
4. Select a model returned by the provider.
5. Choose Write, Image, or Video where the selected provider/model supports it.

API keys are encrypted with Android Keystore-backed secure storage and sent
directly to the selected provider. They are not included in the repository.

### Attachments

Use the attachment button to add a PDF, image, or supported text file. The app
shows processing progress, extracts/indexes its text, and includes relevant
content within the prompt budget. After sending, the attachment is cleared from
the composer and remains visible on the sent message.

## Documentation

- [Contributing](CONTRIBUTING.md)
- [Privacy policy](PRIVACY.md)

Internal research and migration notes are intentionally excluded from the
public repository.

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE).
