import 'package:fllama/fllama.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'package:write4me/models/chat_message.dart';
import 'package:http/http.dart' as http;
import 'package:write4me/utils/exceptions.dart';

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
    'Qwen-R1 (1.8 GB)': 'https://huggingface.co/unsloth/DeepSeek-R1-Distill-Qwen-1.5B-GGUF/resolve/main/DeepSeek-R1-Distill-Qwen-1.5B-Q8_0.gguf',
    'Qwen-2.5-0.5 (650 MB)': 'https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF/resolve/main/qwen2.5-0.5b-instruct-q8_0.gguf'
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

  Future<List<File>> _getModelFiles() async {
    final directory = await getApplicationDocumentsDirectory();
    final dir = Directory(directory.path);
    
    if (!await dir.exists()) {
      debugPrint('Models directory missing');
      return [];
    }
    
    return dir.list()
      .where((e) => e is File && e.path.toLowerCase().endsWith('.gguf'))
      .map((e) => e as File)
      .toList();
  }

  Future<void> _checkAvailableModels() async {
    try {
      _availableModels = await _getModelFiles();
      debugPrint('Available models: ${_availableModels.length}');
      
      if (_availableModels.isNotEmpty && _selectedModelPath.isEmpty) {
        debugPrint('Setting first model as selected: ${_availableModels.first.path}');
        await setSelectedModel(_availableModels.first.path);
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Error checking models: $e');
    }
  }

  Future<void> _loadDownloadedUrls() async {
    final prefs = await SharedPreferences.getInstance();
    final urls = prefs.getStringList(_downloadedModelsKey) ?? [];
    _downloadedUrls = Set<String>.from(urls);
    debugPrint('Loaded downloaded URLs: $_downloadedUrls');
  }

  Future<void> _saveDownloadedUrls() async {
    debugPrint('Saving downloaded URLs: $_downloadedUrls');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_downloadedModelsKey, _downloadedUrls.toList());
  }

  /// Common download logic for both default and custom models
  Future<void> downloadModel(
    String url,
    void Function(double) onProgress,
    String fileName,
  ) async {
    debugPrint('Starting model download:');
    debugPrint('URL: $url');
    debugPrint('Filename: $fileName');

    final directory = await getApplicationDocumentsDirectory();
    final filePath = '${directory.path}/$fileName';
    final file = File(filePath);

    // Check if model is already downloaded
    if (_downloadedUrls.contains(url)) {
      if (!await file.exists()) {
        _downloadedUrls.remove(url);
        await _saveDownloadedUrls();
      } else {
        throw Exception('Model already downloaded');
      }
    }

    try {
      await _downloadFile(url, file, onProgress);
      await _processDownloadedModel(url, file);
    } catch (e) {
      debugPrint('Error downloading model: $e');
      if (await file.exists()) {
        await file.delete();
      }
      rethrow;
    }
  }

  /// Downloads file from URL with progress tracking
  Future<void> _downloadFile(
    String url, 
    File file, 
    void Function(double) onProgress,
  ) async {
    final client = http.Client();
    try {
      final response = await client.send(http.Request('GET', Uri.parse(url)));
      
      if (response.statusCode != 200) {
        throw DownloadException(
          'Download failed: HTTP ${response.statusCode}',
        );
      }

      final contentLength = response.contentLength ?? 0;
      final sink = file.openWrite();
      int downloaded = 0;

      await for (final chunk in response.stream) {
        sink.add(chunk);
        downloaded += chunk.length;
        if (contentLength > 0) {
          onProgress(downloaded / contentLength);
        }
      }
      
      await sink.flush();
      await sink.close();
    } finally {
      client.close();
    }
  }

  /// Process downloaded model file and update state
  Future<void> _processDownloadedModel(String url, File file) async {
    _downloadedUrls.add(url);
    await Future.wait([
      _saveDownloadedUrls(),
      _checkAvailableModels(),
    ]);

    if (_availableModels.isNotEmpty) {
      final downloadedFile = _availableModels.lastWhere(
        (f) => f.path == file.path,
        orElse: () => _availableModels.last,
      );
      await setSelectedModel(downloadedFile.path);
      await setUseLocalModel(true);
    }
    notifyListeners();
  }

  Future<void> downloadCustomModel(
    String url, 
    void Function(double) onProgress,
    CancelToken cancelToken,
  ) async {
    debugPrint('Starting custom model download from: $url');

    final directory = await getApplicationDocumentsDirectory();
    final fileName = url.split('/').last;
    final filePath = '${directory.path}/$fileName';
    final file = File(filePath);

    if (_downloadedUrls.contains(url)) {
      if (!await file.exists()) {
        _downloadedUrls.remove(url);
        await _saveDownloadedUrls();
      } else {
        throw Exception('Model already downloaded');
      }
    }

    try {
      final client = http.Client();
      final response = await client.send(http.Request('GET', Uri.parse(url)));
      
      if (response.statusCode != 200) {
        throw DownloadException(
          'Model download failed',
          statusCode: response.statusCode,
          uri: Uri.parse(url),
        );
      }

      final contentLength = response.contentLength ?? 0;
      final sink = file.openWrite();
      int downloaded = 0;

      try {
        await for (final chunk in response.stream) {
          if (cancelToken.isCancelled) {
            await sink.close();
            client.close();
            await file.delete();
            throw CancelException();
          }
          sink.add(chunk);
          downloaded += chunk.length;
          if (contentLength > 0) {
            onProgress(downloaded / contentLength);
          }
        }
        
        await sink.flush();
        await sink.close();
        client.close();

        _downloadedUrls.add(url);
        await _saveDownloadedUrls();
        await _checkAvailableModels();
        
        if (_availableModels.isNotEmpty) {
          await setSelectedModel(file.path);
          _useLocalModel = true;
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool(_useLocalModelKey, true);
        }
        notifyListeners();
      } catch (e) {
        await sink.close();
        client.close();
        if (await file.exists()) {
          await file.delete();
        }
        rethrow;
      }
    } catch (e) {
      debugPrint('Error downloading custom model: $e');
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
      
      messages.add(Message(
        Role.system, 
        '''You are a helpful assistant who answers concisely.
When provided with document context, analyze it carefully to provide accurate answers.
For images with text, refer to the extracted text to provide relevant information.'''
      ));

      final recentHistory = history.length > 6 
          ? history.sublist(history.length - 6) 
          : history;
          
      for (final msg in recentHistory) {
        messages.add(Message(
          msg.isUser ? Role.user : Role.assistant,
          msg.content,
        ));
      }
      messages.add(Message(Role.user, prompt));

      final request = OpenAiRequest(
        maxTokens: 512,
        messages: messages,
        numGpuLayers: 99,
        modelPath: _selectedModelPath,
        frequencyPenalty: 0.5,
        presencePenalty: 0.7,
        topP: 1.0,
        contextSize: 1024,
        temperature: 0.5,
        logger: (log) => debugPrint('[llama.cpp] $log'),
      );

      await fllamaChat(
        request,
        (response, done) {
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
    debugPrint('Deleting model: $modelPath');
    final file = File(modelPath);
    
    try {
      if (await file.exists()) {
        await file.delete();
        debugPrint('Model file deleted');

        final url = _getUrlForModel(modelPath);
        if (url != null) {
          _downloadedUrls.remove(url);
          await _saveDownloadedUrls();
          debugPrint('Removed from downloaded URLs: $url');
        }

        if (modelPath == _selectedModelPath) {
          _selectedModelPath = '';
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_selectedModelKey, '');
          debugPrint('Cleared selected model path');
        }

        await _checkAvailableModels();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error deleting model: $e');
      rethrow;
    }
  }

  String? _getUrlForModel(String modelPath) {
    final fileName = modelPath.split('/').last.toLowerCase();
    
    for (var entry in defaultModels.entries) {
      if (entry.value.split('/').last.toLowerCase() == fileName) {
        return entry.value;
      }
    }
    for (var url in _downloadedUrls) {
      if (url.split('/').last.toLowerCase() == fileName) {
        return url;
      }
    }
    return null;
  }

  String formatModelName(String path) {
    final fileName = path.split('/').last.replaceAll('.gguf', '');
    
    // Check for sizes (like 0.5b, 7b, etc.) and cut at the "b"
    final sizeMatch = RegExp(r'.*?(\d+(\.\d+)?b)', caseSensitive: false).firstMatch(fileName);
    if (sizeMatch != null) {
      // Get everything up to and including the "b"
      final result = fileName.substring(0, sizeMatch.end);
      return _capitalizeModelName(result);
    }
    
    // If no size found, take first two words separated by dash or underscore
    final parts = fileName.split(RegExp(r'[-_]'));
    if (parts.length >= 2) {
      final result = '${parts[0]} ${parts[1]}';
      return _capitalizeModelName(result);
    }
    
    // Fallback to full name if no pattern matches
    return _capitalizeModelName(fileName);
  }
  
  String _capitalizeModelName(String name) {
    // Split by spaces, dashes, or underscores
    final parts = name.split(RegExp(r'[ _-]'));
    final capitalizedParts = parts.map((part) {
      if (part.isEmpty) return '';
      // Don't capitalize size indicators like '7b', '0.5b'
      if (RegExp(r'^\d+(\.\d+)?b$', caseSensitive: false).hasMatch(part)) {
        return part.toLowerCase();
      }
      // Capitalize first letter of each part
      return part[0].toUpperCase() + (part.length > 1 ? part.substring(1).toLowerCase() : '');
    });
    return capitalizedParts.join(' ');
  }

  Future<List<File>> getAvailableModels() async {
    return _getModelFiles();
  }

  @override
  void dispose() {
    _dio.close();
    super.dispose();
  }
}

extension DownloadErrorX on Exception {
  String get downloadError {
    if (this is SocketException) return 'No internet connection';
    if (this is DownloadException) {
      final e = this as DownloadException;
      return e.statusCode != null 
          ? 'Download error (HTTP ${e.statusCode})'
          : 'Download failed';
    }
    if (toString().contains('host lookup')) return 'Invalid URL';
    return 'Download failed';
  }
}
