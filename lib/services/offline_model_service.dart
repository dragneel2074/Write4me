import 'package:fllama/fllama.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'package:write4me/models/chat_message.dart';
import 'package:http/http.dart' as http;

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
      
      _availableModels = entities.whereType<File>().where((file) {
        final isGguf = file.path.toLowerCase().endsWith('.gguf');
        debugPrint('File: ${file.path}, isGguf: $isGguf');
        return isGguf;
      }).toList();
      
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
    final urls = prefs.getStringList(_downloadedModelsKey) ?? [];
    _downloadedUrls = Set<String>.from(urls);
    debugPrint('Loaded downloaded URLs: $_downloadedUrls');
  }

  Future<void> _saveDownloadedUrls() async {
    debugPrint('Saving downloaded URLs: $_downloadedUrls');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_downloadedModelsKey, _downloadedUrls.toList());
  }

  Future<void> downloadModel(
    String url,
    void Function(double) onProgress,
    String fileName,
  ) async {
    debugPrint('Starting model download: $fileName');

    // Ensure filename ends with .gguf
    if (!fileName.toLowerCase().endsWith('.gguf')) {
      fileName = '$fileName.gguf';
    }

    final directory = await getApplicationDocumentsDirectory();
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
      // Use http.Client for better memory management
      final client = http.Client();
      final response = await client.send(http.Request('GET', Uri.parse(url)));
      
      if (response.statusCode != 200) {
        throw Exception('Failed to download model: ${response.statusCode}');
      }

      final contentLength = response.contentLength ?? 0;
      final sink = file.openWrite();
      int downloaded = 0;

      try {
        await for (final chunk in response.stream) {
          sink.add(chunk);
          downloaded += chunk.length;
          if (contentLength > 0) {
            onProgress(downloaded / contentLength);
          }
        }
        
        await sink.flush();
        await sink.close();
        client.close();

        // Update state after successful download
        _downloadedUrls.add(url);
        await Future.wait([
          _saveDownloadedUrls(),
          _checkAvailableModels(),
        ]);

        if (_availableModels.isNotEmpty) {
          final downloadedFile = _availableModels.lastWhere(
            (file) => file.path.endsWith(fileName),
            orElse: () => _availableModels.last,
          );
          await setSelectedModel(downloadedFile.path);
          await setUseLocalModel(true);
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
        throw Exception('Failed to download model: ${response.statusCode}');
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
    if (fileName.toLowerCase().contains('qwen')) {
      final match = RegExp(r'qwen[^b]*b').firstMatch(fileName.toLowerCase());
      if (match != null) {
        return match.group(0)!.replaceAll('-', ' ').toUpperCase();
      }
    }
    return fileName;
  }

  Future<List<File>> getAvailableModels() async {
    try {
      debugPrint('Checking available models...');
      final directory = await getApplicationDocumentsDirectory();
      final dir = Directory(directory.path);
      
      if (!await dir.exists()) {
        debugPrint('Directory does not exist: ${directory.path}');
        return [];
      }

      final List<FileSystemEntity> entities = await dir.list().toList();
      debugPrint('Found ${entities.length} files in directory');
      
      _availableModels = entities.whereType<File>().where((file) {
        final isGguf = file.path.toLowerCase().endsWith('.gguf');
        debugPrint('File: ${file.path}, isGguf: $isGguf');
        return isGguf;
      }).toList();
      
      debugPrint('Available models: ${_availableModels.length}');
      return _availableModels;
    } catch (e) {
      debugPrint('Error checking for models: $e');
      return [];
    }
  }

  @override
  void dispose() {
    _dio.close();
    super.dispose();
  }
}
