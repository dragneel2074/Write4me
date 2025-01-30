import 'package:fllama/fllama.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

import 'package:write4me/models/chat_message.dart';

class OfflineModelService extends ChangeNotifier {
  static const String _selectedModelKey = 'selected_model';
  static const String _isOfflineModeKey = 'is_offline_mode';
  static const String _useLocalModelKey = 'use_local_model';
  
  static const Map<String, String> defaultModels = {
    'Qwen-R1': 'https://huggingface.co/unsloth/DeepSeek-R1-Distill-Qwen-1.5B-GGUF/resolve/main/DeepSeek-R1-Distill-Qwen-1.5B-Q8_0.gguf',
    'Qwen-2.5-0.5':'https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF/resolve/main/qwen2.5-0.5b-instruct-q8_0.gguf'
  };

  bool _isOfflineMode = false;
  String _selectedModelPath = '';
  List<File> _availableModels = [];
  bool _useLocalModel = false;
  
  bool get isOfflineMode => _isOfflineMode;
  String get selectedModelPath => _selectedModelPath;
  List<File> get availableModels => _availableModels;
  bool get useLocalModel => _useLocalModel;

  String get currentModelName {
    if (_selectedModelPath.isEmpty) return '';
    return _selectedModelPath.split('/').last.replaceAll('.gguf', '');
  }

  Future<void> init() async {
    await _loadPreferences();
    await _checkAvailableModels();
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
      final directory = await getApplicationDocumentsDirectory();
      final dir = Directory(directory.path);
      final List<FileSystemEntity> entities = await dir.list().toList();
      
      _availableModels = entities
          .whereType<File>()
          .where((file) => file.path.endsWith('.gguf'))
          .toList();
      
      if (_availableModels.isNotEmpty && _selectedModelPath.isEmpty) {
        await setSelectedModel(_availableModels.first.path);
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error checking for models: $e');
    }
  }

  Future<void> downloadModel(String modelName, Function(double) onProgress) async {
    final modelUrl = defaultModels[modelName];
    if (modelUrl == null) return;

    try {
      final directory = await getApplicationDocumentsDirectory();
      final fileName = '$modelName.gguf';
      final modelPath = '${directory.path}/$fileName';

      final file = File(modelPath);
      if (await file.exists()) {
        await file.delete();
      }

      final response = await http.Client().send(
        http.Request('GET', Uri.parse(modelUrl))
      );
      
      final contentLength = response.contentLength ?? 0;
      final sink = file.openWrite();
      int downloaded = 0;

      await for (final chunk in response.stream) {
        sink.add(chunk);
        downloaded += chunk.length;
        onProgress(downloaded / contentLength);
      }
      
      await sink.flush();
      await sink.close();

      await setSelectedModel(modelPath);
      await _checkAvailableModels();
    } catch (e) {
      debugPrint('Error downloading model: $e');
      rethrow;
    }
  }

  Future<void> downloadCustomModel(String url, Function(double) onProgress) async {
    if (!url.toLowerCase().endsWith('.gguf')) {
      throw Exception('Invalid model file. URL must end with .gguf');
    }

    try {
      final directory = await getApplicationDocumentsDirectory();
      final fileName = url.split('/').last;
      final modelPath = '${directory.path}/$fileName';

      final file = File(modelPath);
      if (await file.exists()) {
        throw Exception('A model with this name already exists');
      }

      final response = await http.Client().send(
        http.Request('GET', Uri.parse(url))
      );
      
      if (response.statusCode != 200) {
        throw Exception('Failed to download model: ${response.statusCode}');
      }

      final contentLength = response.contentLength ?? 0;
      final sink = file.openWrite();
      int downloaded = 0;

      await for (final chunk in response.stream) {
        sink.add(chunk);
        downloaded += chunk.length;
        onProgress(downloaded / contentLength);
      }
      
      await sink.flush();
      await sink.close();

      await setSelectedModel(modelPath);
      await _checkAvailableModels();
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
      // Convert history to messages
      final messages = <Message>[];
      
      // Add system message first
      messages.add(Message(
        Role.system, 
        'You are a helpful assistant who answers concisely and thinks less.'
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

      await fllamaChat(request, onResponse);
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
        
        // If we deleted the selected model, select another one if available
        if (modelPath == _selectedModelPath) {
          _availableModels.remove(file);
          if (_availableModels.isNotEmpty) {
            await setSelectedModel(_availableModels.first.path);
          } else {
            await setSelectedModel('');
            await setOfflineMode(false);
          }
        } else {
          _availableModels.remove(file);
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error deleting model: $e');
      rethrow;
    }
  }
} 