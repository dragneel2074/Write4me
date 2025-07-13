# Online/Offline Mode and Model Selection Logic

This document outlines the logic for handling online and offline modes within the application, focusing on how model selection is managed to ensure requests are routed correctly.

## Core Concepts

The application operates in two primary modes:

1.  **Online Mode (Default):** In this mode, the user has access to both the "Cloud" model (which requires an internet connection) and any locally downloaded models.
2.  **Offline Mode:** This mode can be activated in the app's settings. When active, the user can *only* interact with the local models. The "Cloud" model option is hidden, and any features requiring an internet connection (like web search) are disabled.

## State Management

The state for the current mode and model selection is managed through `Riverpod` providers, primarily interacting with `OfflineModelService`. Key state variables include:

-   `isOfflineMode`: A boolean that determines if the application is in the user-activated "Offline Mode".
-   `isLocalModelActive`: A boolean that indicates whether a local model is currently the *active* engine for generating responses. When this is `false`, the "Cloud" model is active.
-   `isLocalModelSelected`: A boolean that tracks whether a user has explicitly tapped on and selected a local model from the list. This is crucial for differentiating between "Online Mode with a local model selected" and "Online Mode with the Cloud model selected".
-   `selectedModelPath`: A string that stores the file path of the currently selected local model.

## The Bug and The Fix

### The Problem

The bug occurred in "Online Mode". The user could select a local model, and the app would correctly use it. However, if the user then switched back to the "Cloud" model, the application would continue to route requests to the previously selected local model.

The root cause was an incomplete state update in the UI. When the "Cloud" model `ChoiceChip` was selected in `lib/components/model_selector.dart`, the `onSelected` callback would correctly set `isLocalModelActive` to `false`, but it failed to reset `isLocalModelSelected` to `false`.

Because `isLocalModelSelected` remained `true`, the logic in `AIService` would still evaluate to true, causing the request to be handled by the `_generateLocalResponse` method instead of the online service.

### The Fix

The solution was to ensure that selecting the "Cloud" model fully resets all relevant local model state flags.

In `lib/components/model_selector.dart`, the `onSelected` callback for the "Cloud" `ChoiceChip` was updated as follows:

**Old Code:**
```dart
onSelected: (selected) {
  if (selected) {
    ref.read(offlineModeProvider.notifier).setIsLocalModelActive(false);
  }
},
```

**New Code:**
```dart
onSelected: (selected) {
  if (selected) {
    ref.read(offlineModeProvider.notifier).setIsLocalModelActive(false);
    ref.read(offlineModeProvider.notifier).setIsLocalModelSelected(false); // <-- This line was added
  }
},
```

By explicitly setting `isLocalModelSelected` to `false`, we now correctly inform the rest of the application that the user has switched away from a local model and intends to use the "Cloud" model. This ensures that `AIService` routes the generation request to the appropriate online service.
