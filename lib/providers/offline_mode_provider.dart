import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:write4me/providers/chat_provider.dart';
import 'package:write4me/providers/navigator_provider.dart';
import 'package:write4me/providers/service_provider.dart';
import 'dart:io';
import 'dart:convert'; // Import for JSON encoding/decoding
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Import for SharedPreferences
import 'package:write4me/models/model_parameters.dart'; // Import ModelParameters

class OfflineModeState {
  final bool isOfflineMode;
  final bool useLocalModel;
  final String? selectedModelPath;
  final List<File> availableModels;
  final bool isDownloading;
  final double downloadProgress;
  final Map<String, ModelParameters> modelParameters; // New field

  const OfflineModeState({
    this.isOfflineMode = false,
    this.useLocalModel = false,
    this.selectedModelPath,
    this.availableModels = const [],
    this.isDownloading = false,
    this.downloadProgress = 0,
    this.modelParameters = const {}, // Initialize with empty map
  });

  OfflineModeState copyWith({
    bool? isOfflineMode,
    bool? useLocalModel,
    String? selectedModelPath,
    List<File>? availableModels,
    bool? isDownloading,
    double? downloadProgress,
    Map<String, ModelParameters>? modelParameters, // New field in copyWith
  }) {
    return OfflineModeState(
      isOfflineMode: isOfflineMode ?? this.isOfflineMode,
      useLocalModel: useLocalModel ?? this.useLocalModel,
      selectedModelPath: selectedModelPath ?? this.selectedModelPath,
      availableModels: availableModels ?? this.availableModels,
      isDownloading: isDownloading ?? this.isDownloading,
      downloadProgress: downloadProgress ?? this.downloadProgress,
      modelParameters: modelParameters ?? this.modelParameters,
    );
  }
}

class OfflineModeNotifier extends StateNotifier<OfflineModeState> {
  final Ref ref;

  OfflineModeNotifier(this.ref) : super(const OfflineModeState()) {
    _loadState();
  }

  Future<void> _loadState() async {
    final models = await ref.read(offlineModelServiceProvider).getAvailableModels();
    final prefs = await SharedPreferences.getInstance();
    final Map<String, ModelParameters> loadedParameters = {};
    for (final modelFile in models) {
      final modelPath = modelFile.path;
      final paramsJson = prefs.getString('model_params_$modelPath');
      if (paramsJson != null) {
        loadedParameters[modelPath] = ModelParameters.fromJson(jsonDecode(paramsJson));
      } else {
        loadedParameters[modelPath] = const ModelParameters(); // Default parameters
      }
    }

    state = state.copyWith(
      isOfflineMode: ref.read(offlineModelServiceProvider).isOfflineMode,
      useLocalModel: ref.read(offlineModelServiceProvider).useLocalModel,
      selectedModelPath: ref.read(offlineModelServiceProvider).selectedModelPath,
      availableModels: models,
      modelParameters: loadedParameters,
    );
  }

  // Check internet connectivity
  Future<bool> _checkInternetConnection() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false;
    }
  }

  Future<bool> _handleOnlineSwitch() async {
    final hasInternet = await _checkInternetConnection();
    if (!hasInternet) {
      final context = ref.read(navigatorKeyProvider).currentContext;
      if (context == null) return false;

      final shouldSwitch = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('No Internet Connection'),
            content: const Text(
              'Would you like to stay in offline mode?'
            ),
            actions: [
              TextButton(
                child: const Text('Continue Online'),
                onPressed: () => Navigator.of(context).pop(false),
              ),
              ElevatedButton(
                child: const Text('Stay Offline'),
                onPressed: () => Navigator.of(context).pop(true),
              ),
            ],
          );
        },
      );

      return shouldSwitch ?? false;
    }
    return false;
  }

  Future<void> _safeSetOfflineMode(bool value) async {
    if (value == state.isOfflineMode) return;
    
    if (!value) {
      final shouldStayOffline = await _handleOnlineSwitch();
      if (shouldStayOffline) return;
    }
    
    await ref.read(offlineModelServiceProvider).setOfflineMode(value);
    
    // When switching to offline mode
    if (value) {
      // Ensure we have at least one offline model
      if (state.availableModels.isEmpty) {
        // Don't allow switching to offline mode if no models are available
        debugPrint('Cannot switch to offline mode: no models available');
        return;
      }
      
      // Force use of local model when in offline mode
      await ref.read(offlineModelServiceProvider).setUseLocalModel(true);
      
      debugPrint('Switched to offline mode - enforcing local model usage');
      state = state.copyWith(
        isOfflineMode: value,
        useLocalModel: true,
      );
    } else {
      // When switching back to online mode, keep settings as is
      state = state.copyWith(
        isOfflineMode: value,
      );
      debugPrint('Switched back to online mode');
    }
    
    ref.read(chatProvider.notifier).clearError();
    if (value) _cleanupErrorMessages();
  }

  Future<void> setOfflineMode(bool value) => _safeSetOfflineMode(value);

  void _cleanupErrorMessages() {
    final chatNotifier = ref.read(chatProvider.notifier);
    final messages = ref.read(chatProvider).messages;

    if (messages.isNotEmpty) {
      final lastMessage = messages.last;
      if (!lastMessage.isUser && 
          lastMessage.content.contains('Error Generating Response')) {
        // Remove the last message
        final updatedMessages = messages.take(messages.length - 1).toList();
        chatNotifier.loadMessages(updatedMessages);
      }
    }
  }

  void setUseLocalModel(bool value) {
    // Don't allow disabling local model when in offline mode
    if (state.isOfflineMode && !value) {
      debugPrint('Cannot disable local model in offline mode');
      return;
    }
    
    ref.read(offlineModelServiceProvider).setUseLocalModel(value);
    state = state.copyWith(useLocalModel: value);
    // Debug output for offline mode changes
    debugPrint('Local model usage set to: $value (offline mode: ${state.isOfflineMode})');
  }

  void setSelectedModel(String path) {
    ref.read(offlineModelServiceProvider).setSelectedModel(path);
    state = state.copyWith(selectedModelPath: path);
    // _service.notifyListeners();
  }

  Future<void> setModelParameters(String modelPath, ModelParameters params) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('model_params_$modelPath', jsonEncode(params.toJson()));

    state = state.copyWith(
      modelParameters: Map.from(state.modelParameters)..[modelPath] = params,
    );
    debugPrint('Model parameters updated for $modelPath: ${params.toJson()}');
  }

  Future<void> downloadModel(
    String url,
    void Function(double) onProgress,
    String fileName,
  ) async {
    state = state.copyWith(isDownloading: true, downloadProgress: 0);
    
    try {
      await ref.read(offlineModelServiceProvider).downloadModel(url, onProgress, fileName);
      
      // Refresh available models and state after download
      await _refreshModels();
      
      debugPrint('Download complete:');
      debugPrint('- Available models: ${state.availableModels.length}');
      debugPrint('- Selected model: ${state.selectedModelPath}');
      debugPrint('- Use local model: ${state.useLocalModel}');
    } catch (e) {
      state = state.copyWith(isDownloading: false);
      rethrow;
    }
  }

  Future<void> _refreshModels() async {
    final models = await ref.read(offlineModelServiceProvider).getAvailableModels();
    
    // Just update the available models list without auto-selecting or enabling
    state = state.copyWith(
      availableModels: models,
      isDownloading: false,
      // Don't auto-switch to the new model
      // selectedModelPath: newModelPath,
      // Don't auto-enable local model
      // useLocalModel: models.isNotEmpty,
    );

    // Debug info only - no automatic switching
    debugPrint('Models refreshed:');
    debugPrint('- Available models: ${models.length}');
    debugPrint('- Current selected model: ${state.selectedModelPath}');
    debugPrint('- Current local model usage: ${state.useLocalModel}');
    
    // Don't automatically update the service state
    // if (newModelPath != null) {
    //   await ref.read(offlineModelServiceProvider).setSelectedModel(newModelPath);
    //   await ref.read(offlineModelServiceProvider).setUseLocalModel(true);
    // }
  }

  Future<void> deleteModel(String path) async {
    await ref.read(offlineModelServiceProvider).deleteModel(path);
    state = state.copyWith(
      availableModels: ref.read(offlineModelServiceProvider).availableModels,
      selectedModelPath: ref.read(offlineModelServiceProvider).selectedModelPath,
      useLocalModel: ref.read(offlineModelServiceProvider).availableModels.isNotEmpty ? state.useLocalModel : false,
    );
    // _service.notifyListeners();
  }

  Future<void> initialize() async {
    try {
      await _loadState();
      await _refreshModels();
      
      debugPrint('Initialized OfflineModeNotifier:');
      debugPrint('- Models available: ${state.availableModels.length}');
      debugPrint('- Is offline mode: ${state.isOfflineMode}');
      debugPrint('- Use local model: ${state.useLocalModel}');
      debugPrint('- Selected model: ${state.selectedModelPath}');
    } catch (e) {
      debugPrint('Error initializing offline mode: $e');
      state = state.copyWith(
        availableModels: [],
        useLocalModel: false,
      );
    }
  }

  // Future<void> _saveState() async {
  //   // Implementation of _saveState method
  // }
}

final offlineModeProvider = StateNotifierProvider<OfflineModeNotifier, OfflineModeState>((ref) {
  return OfflineModeNotifier(ref);
}); 