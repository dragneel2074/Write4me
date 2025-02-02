import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:write4me/providers/service_provider.dart';
import '../services/offline_model_service.dart';
import 'dart:io';

class OfflineModeState {
  final bool isOfflineMode;
  final bool useLocalModel;
  final String? selectedModelPath;
  final List<File> availableModels;
  final bool isDownloading;
  final double downloadProgress;

  const OfflineModeState({
    this.isOfflineMode = false,
    this.useLocalModel = false,
    this.selectedModelPath,
    this.availableModels = const [],
    this.isDownloading = false,
    this.downloadProgress = 0,
  });

  OfflineModeState copyWith({
    bool? isOfflineMode,
    bool? useLocalModel,
    String? selectedModelPath,
    List<File>? availableModels,
    bool? isDownloading,
    double? downloadProgress,
  }) {
    return OfflineModeState(
      isOfflineMode: isOfflineMode ?? this.isOfflineMode,
      useLocalModel: useLocalModel ?? this.useLocalModel,
      selectedModelPath: selectedModelPath ?? this.selectedModelPath,
      availableModels: availableModels ?? this.availableModels,
      isDownloading: isDownloading ?? this.isDownloading,
      downloadProgress: downloadProgress ?? this.downloadProgress,
    );
  }
}

class OfflineModeNotifier extends StateNotifier<OfflineModeState> {
  final OfflineModelService _service;

  OfflineModeNotifier(this._service) : super(const OfflineModeState()) {
    _init();
  }

  Future<void> _init() async {
    state = state.copyWith(
      isOfflineMode: _service.isOfflineMode,
      useLocalModel: _service.useLocalModel,
      selectedModelPath: _service.selectedModelPath,
      availableModels: _service.availableModels,
    );
  }

  void setOfflineMode(bool value) {
    _service.setOfflineMode(value);
    state = state.copyWith(
      isOfflineMode: value,
      useLocalModel: value ? true : false,
    );
    _service.notifyListeners();
  }

  void setUseLocalModel(bool value) {
    _service.setUseLocalModel(value);
    state = state.copyWith(useLocalModel: value);
    _service.notifyListeners();
  }

  void setSelectedModel(String path) {
    _service.setSelectedModel(path);
    state = state.copyWith(selectedModelPath: path);
    _service.notifyListeners();
  }

  Future<void> downloadModel(
    String url,
    void Function(double) onProgress,
    String fileName,
  ) async {
    state = state.copyWith(isDownloading: true, downloadProgress: 0);
    
    try {
      await _service.downloadModel(url, onProgress, fileName);
      
      state = state.copyWith(
        availableModels: _service.availableModels,
        selectedModelPath: _service.selectedModelPath,
        isDownloading: false,
        useLocalModel: true,
      );
      _service.notifyListeners();
    } catch (e) {
      state = state.copyWith(isDownloading: false);
      rethrow;
    }
  }

  Future<void> deleteModel(String path) async {
    await _service.deleteModel(path);
    state = state.copyWith(
      availableModels: _service.availableModels,
      selectedModelPath: _service.selectedModelPath,
      useLocalModel: _service.availableModels.isNotEmpty ? state.useLocalModel : false,
    );
    _service.notifyListeners();
  }
}

final offlineModeProvider = StateNotifierProvider<OfflineModeNotifier, OfflineModeState>((ref) {
  // Watch the initialization state first
  final initState = ref.watch(offlineModelInitProvider);
  
  return initState.when(
    data: (_) {
      final service = ref.watch(offlineModelServiceProvider);
      return OfflineModeNotifier(service);
    },
    loading: () => throw Exception('OfflineModelService is still initializing'),
    error: (error, _) => throw Exception('Failed to initialize OfflineModelService: $error'),
  );
}); 