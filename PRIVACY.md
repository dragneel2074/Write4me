# Write4Me privacy policy

Last updated: July 26, 2026

Write4Me is an Android writing assistant that can run language models locally
or connect directly to third-party AI providers chosen by the user.

## Data stored on the device

Write4Me stores chat history, app preferences, imported model metadata, and
document indexes on the user's device. Provider API keys are encrypted using
Android Keystore-backed secure storage. Legacy plaintext key values are removed
when migrated.

Users can delete individual chat conversations, remove imported models, clear a
saved provider key, or uninstall Write4Me to remove app-managed local data.

## On-device processing

GGUF model inference runs on the Android device. PDF text extraction, image OCR,
document chunking, embeddings, and document retrieval also run locally.

## Cloud providers

When a user chooses Pollinations, Gemini, or OpenRouter, Write4Me sends the
current request, relevant recent conversation turns, and bounded excerpts from
selected attachments directly to that provider. Image and video prompts are
sent to Pollinations when those modes are used.

Write4Me does not operate an intermediary server for these requests. Each
provider processes data under its own terms and privacy policy. Users should not
send sensitive material to a cloud provider unless they accept that provider's
policies.

## Permissions

Write4Me requests internet access for cloud providers and model downloads.
Camera access is requested only when the user chooses to capture an image.
Android system pickers provide scoped access to files selected by the user.

## Logging

Production builds do not intentionally log complete prompts, extracted document
text, API keys, or provider response content. Diagnostic metadata may be shown
in development builds.

## Children and sensitive data

Write4Me is not designed for children under 13. Users are responsible for
ensuring they have permission to process uploaded files and for avoiding
regulated or confidential data when using third-party cloud providers.

## Changes

This policy may be updated when application behavior or supported providers
change. The latest revision date appears at the top of this document.
