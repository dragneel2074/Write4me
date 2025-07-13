import 'dart:io';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:http/http.dart' as http;
import 'package:write4me/models/chat_message.dart';
import 'package:write4me/models/model_parameters.dart';
import 'package:write4me/utils/exceptions.dart';
// Import OfflineModeProvider
import 'package:fllama/fllama.dart'; // Import fllama.dart

class CancelException implements Exception {
  final String message;
  CancelException([this.message = 'Operation cancelled']);
  @override
  String toString() => message;
}

/// Class to manage cancellable operations
class CancelableCompleter {
  final Completer<void> _completer = Completer<void>();
  final CancelToken token = CancelToken();

  bool get isCancelled => token.isCancelled;

  Future<void> get future => _completer.future;

  void complete() {
    if (!_completer.isCompleted) {
      _completer.complete();
    }
  }

  void completeError(Object error, [StackTrace? stackTrace]) {
    if (!_completer.isCompleted) {
      _completer.completeError(error, stackTrace);
    }
  }

  void cancel() {
    if (!token.isCancelled) {
      token.cancel();
    }
  }
}

class OfflineModelService extends ChangeNotifier {
  CancelableCompleter? _downloadCancel;

  static const String _selectedModelKey = 'selected_model';
  static const String _isOfflineModeKey = 'is_offline_mode';
  static const String _isLocalModelActiveKey = 'is_local_model_active';
  static const String _isLocalModelSelectedKey = 'is_local_model_selected';
  static const String _downloadedModelsKey = 'downloaded_models';
  static const String _modelParametersKey = 'model_parameters';

  static const Map<String, String> defaultModels = {
    'Qwen-R1 (1.8 GB)':
        'https://huggingface.co/unsloth/DeepSeek-R1-Distill-Qwen-1.5B-GGUF/resolve/main/DeepSeek-R1-Distill-Qwen-1.5B-Q8_0.gguf',
    'Qwen-2.5-0.5 (650 MB)':
        'https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF/resolve/main/qwen2.5-0.5b-instruct-q8_0.gguf'
  };

  bool _isOfflineMode = false;
  String _selectedModelPath = '';
  List<File> _availableModels = [];
  bool _isLocalModelActive = false;
  bool _isLocalModelSelected = false;
  Set<String> _downloadedUrls = {}; // Track downloaded URLs
  Map<String, ModelParameters> _modelParameters = {};

  bool get isOfflineMode => _isOfflineMode;
  String get selectedModelPath => _selectedModelPath;
  List<File> get availableModels => _availableModels;
  bool get isLocalModelActive => _isLocalModelActive;
  bool get isLocalModelSelected => _isLocalModelSelected;
  Map<String, ModelParameters> get modelParameters => _modelParameters;

  String get currentModelName {
    if (_selectedModelPath.isEmpty) return '';
    return formatModelName(_selectedModelPath);
  }

  Future<void> init() async {
    await _loadPreferences();
    await _checkAvailableModels();
    await _loadDownloadedUrls();
    await _loadModelParameters();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    _isOfflineMode = prefs.getBool(_isOfflineModeKey) ?? false;
    _selectedModelPath = prefs.getString(_selectedModelKey) ?? '';
    _isLocalModelActive = prefs.getBool(_isLocalModelActiveKey) ?? false;
    _isLocalModelSelected = prefs.getBool(_isLocalModelSelectedKey) ?? false;
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

  Future<void> setIsLocalModelActive(bool value) async {
    if (value && _availableModels.isEmpty) {
      throw Exception('No local models available');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isLocalModelActiveKey, value);
    _isLocalModelActive = value;
    notifyListeners();
  }

  Future<void> setIsLocalModelSelected(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isLocalModelSelectedKey, value);
    _isLocalModelSelected = value;
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

    return dir
        .list()
        .where((e) => e is File && e.path.toLowerCase().endsWith('.gguf'))
        .map((e) => e as File)
        .toList();
  }

  Future<void> _checkAvailableModels() async {
    try {
      _availableModels = await _getModelFiles();
      debugPrint('Available models: ${_availableModels.length}');

      // Don't automatically set first model when initializing
      // if (_availableModels.isNotEmpty && _selectedModelPath.isEmpty) {
      //   debugPrint('Setting first model as selected: ${_availableModels.first.path}');
      //   await setSelectedModel(_availableModels.first.path);
      // }

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

  Future<void> _loadModelParameters() async {
    final prefs = await SharedPreferences.getInstance();
    final String? paramsJsonString = prefs.getString(_modelParametersKey);
    if (paramsJsonString != null) {
      final Map<String, dynamic> decodedMap = json.decode(paramsJsonString);
      _modelParameters = decodedMap.map((key, value) =>
          MapEntry(key, ModelParameters.fromJson(value as Map<String, dynamic>)));
      debugPrint('Loaded model parameters: $_modelParameters');
    } else {
      _modelParameters = {};
      debugPrint('No model parameters found, initializing empty map.');
    }
  }

  Future<void> _saveModelParameters() async {
    final prefs = await SharedPreferences.getInstance();
    final String encodedMap = json.encode(_modelParameters.map((key, value) => MapEntry(key, value.toJson())));
    await prefs.setString(_modelParametersKey, encodedMap);
    debugPrint('Saved model parameters: $_modelParameters');
  }

  Future<void> setModelParameters(String modelPath, ModelParameters params) async {
    _modelParameters[modelPath] = params;
    await _saveModelParameters();
    notifyListeners();
  }

  /// Common download logic for both default and custom models
  Future<void> downloadModel(
    String url,
    void Function(double) onProgress,
    String fileName,
  ) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$fileName');

      if (await file.exists()) {
        throw Exception('Model already exists');
      }

      if (_downloadCancel != null) {
        throw Exception('Another download is in progress');
      }

      _downloadCancel = CancelableCompleter();

      await _downloadWithProgress(
        url,
        file,
        onProgress,
        _downloadCancel!.token,
      );

      _downloadCancel = null;
      await _checkAvailableModels();

      // Don't automatically set selected model or enable local model
      _downloadedUrls.add(url);
      await _saveDownloadedUrls();

      // Log that model was downloaded without auto-switching
      debugPrint('Model downloaded successfully: ${file.path}');
      debugPrint('Available models: ${_availableModels.length}');

      notifyListeners();
    } catch (e) {
      _downloadCancel = null;
      debugPrint('Error downloading model: $e');
      rethrow;
    }
  }

  /// Downloads a file with progress tracking and cancellation support
  Future<void> _downloadWithProgress(
    String url,
    File file,
    void Function(double) onProgress,
    CancelToken cancelToken,
  ) async {
    debugPrint('Downloading with progress from: $url');

    final client = http.Client();
    try {
      final response = await client.send(http.Request('GET', Uri.parse(url)));

      if (response.statusCode != 200) {
        throw DownloadException(
          'Download failed: HTTP ${response.statusCode}',
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

        debugPrint('Download completed successfully: ${file.path}');
      } catch (e) {
        await sink.close();
        client.close();
        if (await file.exists()) {
          await file.delete();
        }
        rethrow;
      }
    } finally {
      client.close();
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

        // Don't automatically switch to downloaded model
        // if (_availableModels.isNotEmpty) {
        //   await setSelectedModel(file.path);
        //   _useLocalModel = true;
        //   final prefs = await SharedPreferences.getInstance();
        //   await prefs.setBool(_useLocalModelKey, true);
        // }

        // Just log that the model was downloaded
        debugPrint('Custom model downloaded: ${file.path}');
        debugPrint('Available models: ${_availableModels.length}');

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
    void Function(String, bool) onResponse,
    {
    List<ChatMessage> history = const [],
    List<String>? context,
    String? searchResults,
  }) async {
    final modelParameters = _modelParameters[_selectedModelPath] ?? const ModelParameters();

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

      final fullPrompt = StringBuffer();

      // Determine which mode we're in
      final bool hasDocuments = context != null && context.isNotEmpty;
      final bool hasWebSearch = searchResults != null;

      if (kDebugMode) {
        print(
            'Generating prompt for mode: ${hasWebSearch ? "Web" : hasDocuments ? "Document" : "Simple"}');
      }

      // Choose appropriate prompt based on mode
      if (hasWebSearch) {
        _buildWebSearchPrompt(fullPrompt, prompt, searchResults, context ?? []);
      } else if (hasDocuments) {
        _buildDocumentPrompt(fullPrompt, prompt, context);
      } else {
        _buildSimplePrompt(fullPrompt, prompt);
      }

      messages.add(Message(Role.user, fullPrompt.toString()));

      final recentHistory =
          history.length > 6 ? history.sublist(history.length - 6) : history;

      for (final msg in recentHistory) {
        messages.add(Message(
          msg.isUser ? Role.user : Role.assistant,
          msg.content,
        ));
      }

      final request = OpenAiRequest(
        maxTokens: modelParameters.maxTokens,
        messages: messages,
        numGpuLayers: modelParameters.numGpuLayers,
        modelPath: _selectedModelPath,
        frequencyPenalty: modelParameters.frequencyPenalty,
        presencePenalty: modelParameters.presencePenalty,
        topP: modelParameters.topP,
        contextSize: modelParameters.contextSize,
        temperature: modelParameters.temperature,
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

  Future<List<File>> getAvailableModels() async {
    return _getModelFiles();
  }

}

/// Builds a prompt for simple QA mode (no documents, no web search)
void _buildSimplePrompt(StringBuffer buffer, String prompt) {
  buffer.writeln(
      'You are a helpful assistant answering questions based on your knowledge.');
  buffer.writeln('\nQUESTION: $prompt');
  buffer.writeln('\nANSWER:');
}

/// Builds a prompt for document QA mode
void _buildDocumentPrompt(
    StringBuffer buffer, String prompt, List<String> context) {
  buffer.writeln(
      'You are a document assistant analyzing and answering questions based on specific information.');

  // Add document context
  buffer.writeln('\nDOCUMENT CONTEXT:');
  for (int i = 0; i < context.length; i++) {
    buffer.writeln('---');
    buffer.writeln(context[i]);
  }
  buffer.writeln('---');

  buffer.writeln('\nQUESTION: $prompt');
  buffer.writeln('\nINSTRUCTIONS:');
  buffer.writeln(
      '1. Answer based ONLY on the provided document context above');
  buffer.writeln('2. Be concise but thorough in your response');
  buffer.writeln('\nANSWER:');
}

/// Builds a prompt for web search QA mode
void _buildWebSearchPrompt(StringBuffer buffer, String prompt,
    String searchResults, List<String> context) {
  buffer.writeln(
      'You are a research assistant helping with questions using web search results.');

  // Add web search results
  buffer.writeln('\nWEB SEARCH RESULTS:');
  buffer.writeln(searchResults);

  // Add document context if available
  if (context.isNotEmpty) {
    buffer.writeln('\nADDITIONAL DOCUMENT CONTEXT:');
    for (int i = 0; i < context.length; i++) {
      buffer.writeln('---');
      buffer.writeln(context[i]);
    }
    buffer.writeln('---');
  }

  buffer.writeln('\nQUESTION: $prompt');
  buffer.writeln('\nINSTRUCTIONS:');
  buffer.writeln(
      '1. Use the web search results to provide an up-to-date answer');
  buffer.writeln(
      '2. Synthesize information from multiple sources when possible');
  buffer.writeln(
      '4. If search results don\'t contain the answer, acknowledge the limitations');
  buffer.writeln('\nANSWER:');
}

String formatModelName(String path) {
  final fileName = path.split('/').last.replaceAll('.gguf', '');

  // Check for sizes (like 0.5b, 7b, etc.) and cut at the "b"
  final sizeMatch =
      RegExp(r'.*?(\d+(\.\d+)?b)', caseSensitive: false).firstMatch(fileName);
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
    return part[0].toUpperCase() +
        (part.length > 1 ? part.substring(1).toLowerCase() : '');
  });
  return capitalizedParts.join(' ');
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