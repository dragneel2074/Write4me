import 'package:fllama/fllama.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'package:write4me/models/chat_message.dart';

class CancelException implements Exception {
  final String message;
  CancelException([this.message = 'Operation cancelled']);
  @override
  String toString() => message;
}

class OfflineModelService extends ChangeNotifier {
  final _dio = Dio();

  static const String _selectedModelKey = 'selected_model';
  static const String _isOfflineModeKey = 'is_offline_mode';
  static const String _useLocalModelKey = 'use_local_model';
  static const String _downloadedModelsKey = 'downloaded_models';
  
  static const Map<String, String> defaultModels = {
    'Qwen-R1': 'https://huggingface.co/unsloth/DeepSeek-R1-Distill-Qwen-1.5B-GGUF/resolve/main/DeepSeek-R1-Distill-Qwen-1.5B-Q8_0.gguf',
    'Qwen-2.5-0.5':'https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF/resolve/main/qwen2.5-0.5b-instruct-q8_0.gguf'
  };

  bool _isOfflineMode = false;
  String _selectedModelPath = '';
  List<File> _availableModels = [];
  bool _useLocalModel = false;
  Set<String> _downloadedUrls = {};  // Track downloaded URLs
  
  bool get isOfflineMode => _isOfflineMode;
  String get selectedModelPath => _selectedModelPath;
  List<File> get availableModels => _availableModels;
  bool get useLocalModel => _useLocalModel;

  String get currentModelName {
    if (_selectedModelPath.isEmpty) return '';
    return formatModelName(_selectedModelPath);
  }

  Future<void> init() async {
    await _loadPreferences();
    await _checkAvailableModels();
    await _loadDownloadedUrls();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    _isOfflineMode = prefs.getBool(_isOfflineModeKey) ?? false;
    _selectedModelPath = prefs.getString(_selectedModelKey) ?? '';
    _useLocalModel = prefs.getBool(_useLocalModelKey) ?? false;
  }

  Future<void> setOfflineMode(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isOfflineModeKey, value);
    _isOfflineMode = value;
    notifyListeners();
  }

  Future<void> setSelectedModel(String modelPath) async {
    _selectedModelPath = modelPath;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_selectedModelKey, _selectedModelPath);
    notifyListeners();
  }

  Future<void> setUseLocalModel(bool value) async {
    if (value && _availableModels.isEmpty) {
      throw Exception('No local models available');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_useLocalModelKey, value);
    _useLocalModel = value;
    notifyListeners();
  }

  bool get canUseLocalModel => _availableModels.isNotEmpty;

  Future<void> _checkAvailableModels() async {
    try {
      debugPrint('Checking available models...');
      final directory = await getApplicationDocumentsDirectory();
      final dir = Directory(directory.path);
      
      if (!await dir.exists()) {
        debugPrint('Directory does not exist: ${directory.path}');
        return;
      }

      final List<FileSystemEntity> entities = await dir.list().toList();
      debugPrint('Found ${entities.length} files in directory');
      
      _availableModels = entities
          .whereType<File>()
          .where((file) {
            final isGguf = file.path.toLowerCase().endsWith('.gguf');
            debugPrint('File: ${file.path}, isGguf: $isGguf');
            return isGguf;
          })
          .toList();
      
      debugPrint('Available models: ${_availableModels.length}');
      
      if (_availableModels.isNotEmpty && _selectedModelPath.isEmpty) {
        debugPrint('Setting first model as selected: ${_availableModels.first.path}');
        await setSelectedModel(_availableModels.first.path);
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Error checking for models: $e');
    }
  }

  Future<void> _loadDownloadedUrls() async {
    final prefs = await SharedPreferences.getInstance();
    _downloadedUrls = Set<String>.from(
      prefs.getStringList(_downloadedModelsKey) ?? []
    );
  }

  Future<void> _saveDownloadedUrls() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _downloadedModelsKey, 
      _downloadedUrls.toList()
    );
  }

  Future<void> downloadModel(
    String url,
    void Function(double) onProgress,
    String fileName,
  ) async {
    debugPrint('Starting model download: $fileName');
    if (_downloadedUrls.contains(url)) {
      throw Exception('Model already downloaded');
    }

    // Ensure filename ends with .gguf
    if (!fileName.toLowerCase().endsWith('.gguf')) {
      fileName = '$fileName.gguf';
    }

    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/$fileName');

    try {
      // Download and write file
      final response = await _dio.get(
        url,
        options: Options(
          responseType: ResponseType.bytes,
          followRedirects: true,
          validateStatus: (status) => status != null && status < 500,
        ),
        onReceiveProgress: (received, total) {
          if (total != -1) {
            onProgress(received / total);
          }
        },
      );

      await file.writeAsBytes(response.data);
      debugPrint('Model file written successfully to: ${file.path}');

      // Update state in a single batch
      _downloadedUrls.add(url);
      await Future.wait([
        _saveDownloadedUrls(),
        _checkAvailableModels(),
      ]);

      // Set as selected model if available
      if (_availableModels.isNotEmpty) {
        final modelPath = file.path;
        debugPrint('Setting newly downloaded model as selected: $modelPath');
        
        // Update all state at once
        _selectedModelPath = modelPath;
        _useLocalModel = true;
        
        // Save all preferences
        final prefs = await SharedPreferences.getInstance();
        await Future.wait([
          prefs.setString(_selectedModelKey, _selectedModelPath),
          prefs.setBool(_useLocalModelKey, true),
          prefs.setStringList(_downloadedModelsKey, _downloadedUrls.toList()),
        ]);
      }

      // Notify listeners only once after all updates
      notifyListeners();
      
    } catch (e) {
      debugPrint('Error downloading model: $e');
      if (await file.exists()) {
        await file.delete();
      }
      rethrow;
    }
  }

  Future<void> downloadCustomModel(
    String url, 
    void Function(double) onProgress,
    CancelToken cancelToken,
  ) async {
    debugPrint('Starting custom model download from: $url');
    if (_downloadedUrls.contains(url)) {
      throw Exception('Model already downloaded');
    }

    try {
      final modelPath = await _downloadFile(url, onProgress, cancelToken);
      debugPrint('Custom model downloaded to: $modelPath');
      
      _downloadedUrls.add(url);
      await _saveDownloadedUrls();
      
      // Force a refresh of available models
      await _checkAvailableModels();
      
      // Set the newly downloaded model as selected
      if (_availableModels.isNotEmpty) {
        debugPrint('Setting newly downloaded custom model as selected');
        await setSelectedModel(modelPath);
        _useLocalModel = true;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_useLocalModelKey, true);
      } else {
        debugPrint('Warning: No models found after download');
      }
      
      notifyListeners();
    } catch (e) {
      if (e is DioException && e.type == DioExceptionType.cancel) {
        throw CancelException();
      }
      debugPrint('Error downloading custom model: $e');
      rethrow;
    }
  }

  Future<String> _downloadFile(
    String url, 
    void Function(double) onProgress,
    CancelToken cancelToken,
  ) async {
    debugPrint('_downloadFile called with URL: $url');
    if (!url.toLowerCase().endsWith('.gguf')) {
      throw Exception('Invalid model file. URL must end with .gguf');
    }

    try {
      final directory = await getApplicationDocumentsDirectory();
      final fileName = url.split('/').last;
      final modelPath = '${directory.path}/$fileName';
      debugPrint('Will download to path: $modelPath');

      final file = File(modelPath);
      if (await file.exists()) {
        debugPrint('File already exists at path: $modelPath');
        throw Exception('A model with this name already exists');
      }

      final options = Options(
        responseType: ResponseType.bytes,
        followRedirects: true,
        validateStatus: (status) => status != null && status < 500,
      );

      debugPrint('Starting download...');
      final response = await _dio.get(
        url,
        options: options,
        cancelToken: cancelToken,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            onProgress(received / total);
            // debugPrint('Download progress: ${(received/total * 100).toStringAsFixed(1)}%');
          }
        },
      );

      if (response.statusCode != 200) {
        debugPrint('Download failed with status: ${response.statusCode}');
        throw Exception('Failed to download model: ${response.statusCode}');
      }

      debugPrint('Writing file to: $modelPath');
      await file.writeAsBytes(response.data);
      debugPrint('File written successfully');

      if (!await file.exists()) {
        debugPrint('Error: File not found after writing');
        throw Exception('File not created successfully');
      }

      return modelPath;
    } catch (e) {
      debugPrint('Error in _downloadFile: $e');
      rethrow;
    }
  }

  Future<void> generateStreamingResponse(
    String prompt,
    void Function(String, bool) onResponse, {
    List<ChatMessage> history = const [],
  }) async {
    if (_selectedModelPath.isEmpty) {
      throw Exception('No model selected');
    }

    final modelFile = File(_selectedModelPath);
    if (!await modelFile.exists()) {
      throw Exception('Model file not found');
    }

    try {
      bool firstResponse = true;
      final messages = <Message>[];
      
      // Add system message with enhanced context handling
      messages.add(Message(
        Role.system, 
        '''You are a helpful assistant who answers concisely.
When provided with document context, analyze it carefully to provide accurate answers.
For images with text, refer to the extracted text to provide relevant information.'''
      ));

      // Add recent history (last 6 messages)
      final recentHistory = history.length > 6 
          ? history.sublist(history.length - 6) 
          : history;
          
      for (final msg in recentHistory) {
        messages.add(Message(
          msg.isUser ? Role.user : Role.assistant,
          msg.content,
        ));
      }

      // Add current prompt
      messages.add(Message(Role.user, prompt));

      final request = OpenAiRequest(
        maxTokens: 512,
        messages: messages,
        numGpuLayers: 99,
        modelPath: _selectedModelPath,
        frequencyPenalty: 0.0,
        presencePenalty: 1.1,
        topP: 1.0,
        contextSize: 2048,
        temperature: 0.7,
        logger: (log) => debugPrint('[llama.cpp] $log'),
      );

      await fllamaChat(
        request,
        (response, done) {
          // Replace placeholder with first real response
          if (firstResponse && response.trim().isNotEmpty) {
            firstResponse = false;
          }
          onResponse(response, done);
        },
      );
    } catch (e) {
      debugPrint('Error generating response: $e');
      rethrow;
    }
  }

  Future<void> deleteModel(String modelPath) async {
    try {
      final file = File(modelPath);
      if (await file.exists()) {
        await file.delete();
        
        // Remove from available models first
        _availableModels.removeWhere((f) => f.path == modelPath);
        
        // Remove the URL from downloaded list
        final modelUrl = _downloadedUrls.firstWhere(
          (url) => url.contains(file.uri.pathSegments.last),
          orElse: () => '',
        );
        if (modelUrl.isNotEmpty) {
          _downloadedUrls.remove(modelUrl);
          await _saveDownloadedUrls();
        }
        
        // Update selected model if needed
        if (modelPath == _selectedModelPath) {
          if (_availableModels.isNotEmpty) {
            await setSelectedModel(_availableModels.first.path);
          } else {
            await setSelectedModel('');
            await setOfflineMode(false);
            await setUseLocalModel(false);
          }
        }
        
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error deleting model: $e');
      rethrow;
    }
  }

  // Add a method to format model name
  String formatModelName(String path) {
    final fileName = path.split('/').last.replaceAll('.gguf', '');
    
    // Handle Qwen model naming specifically
    if (fileName.toLowerCase().contains('qwen')) {
      final match = RegExp(r'qwen[^b]*b').firstMatch(fileName.toLowerCase());
      if (match != null) {
        return match.group(0)!.replaceAll('-', ' ').toUpperCase();
      }
    }
    
    return fileName;
  }

  @override
  void dispose() {
    _dio.close();
    super.dispose();
  }
} 