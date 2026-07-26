import 'dart:async';
import 'dart:io'; // For SocketException
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';

import '../models/chat_message.dart';
import 'credential_storage_service.dart';

import 'package:write4me/services/online_model_service.dart';

class TextGenerationService {
  static const String baseUrl = 'https://text.pollinations.ai/';

  final OnlineModelService _onlineModelService;

  TextGenerationService(this._onlineModelService);
  static const String jinaSearchUrl = 'https://s.jina.ai/';
  static const String unwanted1 = 'Chat Service is Online. Ask Me Anything.';
  static const String unwanted2 =
      'Image Service is Online. Generate Amazing Images';

  final _dio = Dio();

  String _formatPrompt(
    String prompt,
    List<String>? context,
    bool useWebSearch,
    List<ChatMessage> history,
  ) {
    final StringBuffer formattedPrompt = StringBuffer();

    // Function to replace unwanted characters
    String cleanText(String text) {
      return text.replaceAll(unwanted1, '').replaceAll(unwanted2, '').trim();
    }

    // Determine which mode we're in
    final bool hasDocuments = context != null && context.isNotEmpty;
    final bool hasWebSearch = useWebSearch;

    if (kDebugMode) {
      print(
          'TextGenerationService: Formatting prompt for mode: ${hasWebSearch ? "Web" : hasDocuments ? "Document" : "Simple"}');
    }

    // Choose appropriate prompt based on mode
    if (hasWebSearch) {
      _buildWebSearchPrompt(
          formattedPrompt, prompt, history, cleanText, context ?? []);
    } else if (hasDocuments) {
      _buildDocumentPrompt(
          formattedPrompt, prompt, context, history, cleanText);
    } else {
      _buildSimplePrompt(
          formattedPrompt, prompt, history, cleanText, context ?? []);
    }

    return formattedPrompt.toString();
  }

  /// Builds a prompt for simple QA mode (no documents, no web search)
  void _buildSimplePrompt(StringBuffer buffer, String prompt,
      List<ChatMessage> history, Function cleanText, List<String> context) {
    // Add conversation history for simple queries
    if (history.isNotEmpty) {
      buffer.writeln('Previous conversation:');
      for (var message in history.take(6)) {
        final cleanedContent = cleanText(message.content);
        if (kDebugMode) {
          print(cleanedContent);
        }
        buffer.writeln('${message.role}: $cleanedContent');
      }
      buffer.writeln();
    }

    // Add context if available
    if (context.isNotEmpty) {
      buffer.writeln('\nCONTEXT:');
      for (int i = 0; i < context.length; i++) {
        buffer.writeln('---');
        buffer.writeln(context[i]);
      }
      buffer.writeln('---');
    }

    // Add the current query
    buffer.write(prompt);
  }

  /// Builds a prompt for document QA mode
  void _buildDocumentPrompt(StringBuffer buffer, String prompt,
      List<String> context, List<ChatMessage> history, Function cleanText) {
    // For documents, we focus more on the context than conversation history

    // Enhanced formatting for multiple context chunks
    if (kDebugMode) {
      print('Formatting ${context.length} context chunks for API request');
    }

    buffer.write('''
Query: Answer based on the context about: 
$prompt

Context (${context.length} relevant passages):
''');

    // Add each context chunk with clear separators
    for (int i = 0; i < context.length; i++) {
      buffer.writeln('----- PASSAGE ${i + 1}/${context.length} -----');
      buffer.writeln(context[i]);
      buffer.writeln('-----------------------------');
    }

    // Add limited history for document queries if available
    if (history.isNotEmpty) {
      buffer.writeln('\nPrevious relevant conversation:');
      for (var message in history.take(3)) {
        final cleanedContent = cleanText(message.content);
        buffer.writeln('${message.role}: $cleanedContent');
      }
    }
  }

  /// Builds a prompt for web search QA mode
  void _buildWebSearchPrompt(StringBuffer buffer, String prompt,
      List<ChatMessage> history, Function cleanText, List<String> context) {
    // For web search, we focus entirely on the current query
    // History is typically not included for web search to keep the prompt clean

    buffer.write(
        'Search the internet and provide accurate information about: $prompt');

    // Add document context if available
    if (context.isNotEmpty) {
      buffer.writeln('\nADDITIONAL CONTEXT:');
      for (int i = 0; i < context.length; i++) {
        buffer.writeln('---');
        buffer.writeln(context[i]);
      }
      buffer.writeln('---');
    }

    // We could add limited history here if needed in the future
  }

  Future<String> searchWithJina(String query) async {
    final apiKey = await getJinaApiKey();
    if (apiKey.isEmpty) {
      throw Exception('Jina API key not found');
    }

    try {
      final now = DateTime.now();
      final dateStr =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      final enhancedQuery = '''$query $dateStr''';
      debugPrint(enhancedQuery);

      final response = await _dio.get(
        '$jinaSearchUrl${Uri.encodeComponent(enhancedQuery)}?count=5',
        options: Options(
          headers: {
            'Authorization': 'Bearer $apiKey',
            'X-Retain-Images': 'none',
            'X-Return-Format': 'text',
          },
        ),
      );

      if (response.statusCode == 200) {
        return '${response.data} \n\n Today is $dateStr';
      } else {
        throw Exception('Failed to search: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error searching with Jina: $e');
      rethrow;
    }
  }

  Future<void> generateStreamingResponse(
    String prompt,
    List<String> context, // Changed from List<PDFMemory> selectedMemories
    void Function(String, bool) onResponse, {
    bool useWebSearch = false,
    List<ChatMessage> history = const [],
    String? model, // New optional parameter
    Map<String, dynamic>? visionMessage,
  }) async {
    try {
      // Removed redundant context extraction from selectedMemories
      // The context is now directly passed from AIService

      if (visionMessage != null) {
        final config = _onlineModelService.activeProviderConfig;
        final key = await _onlineModelService
            .getApiKey(_onlineModelService.activeProvider);
        if (key == null || key.isEmpty) {
          throw MissingApiKeyException(config.label);
        }

        final response = await _dio.post(
          config.chatUrl,
          data: visionMessage,
          options: Options(
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $key',
            },
          ),
        );

        if (response.statusCode == 200) {
          onResponse(response.data['choices'][0]['message']['content'], true);
        } else {
          throw HttpException(
              'Failed to generate text: ${response.statusCode}');
        }
        return;
      }

      if (useWebSearch) {
        // Show searching status
        onResponse('Searching the web...', false);

        try {
          if (kDebugMode) {
            debugPrint('Starting web search (${prompt.length} characters)');
          }
          final searchResults = await searchWithJina(prompt);

          // Show search complete status
          onResponse('Search results found. Generating response...', false);

          if (kDebugMode) {
            debugPrint(
                'Web search returned ${searchResults.length} characters');
          }

          // Generate response with search results
          // Use provided model or default
          const system =
              'You are Aura, a helpful AI assistant. Use the provided search results to answer the question accurately. First look for latest date and when answering mention the date if available.';

          final formattedPrompt = '''
Search Results:
$searchResults

Based on these search results, please answer:
$prompt
''';
          final text = await _chatCompletion(system, formattedPrompt, model!);
          onResponse(text, true);
        } catch (e) {
          debugPrint('Error during web search or response generation: $e');
          rethrow;
        }
      } else {
        // Non-web search flow
        onResponse('Generating response...', false);
        final response = await generateText(
          prompt,
          context: context, // Pass the provided context
          useWebSearch: false,
          history: history,
          model: model, // Pass the model parameter
        );
        onResponse(response, true);
      }
    } catch (e) {
      onResponse(_getUserFriendlyError(e), true);
      return;
    }
  }

  String _getUserFriendlyError(dynamic error) {
    if (error is SocketException) {
      return 'No internet connection. Please check your network and try again.';
    } else if (error is TimeoutException) {
      return 'Request took too long. Please try again.';
    } else if (error is HttpException) {
      return 'Temporary service issue. Please try again in a moment.';
    } else if (error is MissingApiKeyException) {
      return 'No API key for ${error.providerLabel}. Add it in Settings.';
    } else if (error is DioException) {
      return providerErrorMessage(
        error,
        _onlineModelService.activeProviderConfig.label,
      );
    } else if (error.toString().contains('Jina API key')) {
      return 'API key missing. Please add your Jina API key in settings.';
    }
    return 'Oops! Something went wrong. Please try again.';
  }

  Future<String> generateText(
    String prompt, {
    List<String> context = const [], // Changed to non-nullable with default
    bool useWebSearch = false,
    List<ChatMessage> history = const [],
    String? model, // New optional parameter
  }) async {
    try {
      String searchResults = '';
      if (useWebSearch) {
        try {
          if (kDebugMode) {
            debugPrint('Starting web search (${prompt.length} characters)');
          }
          searchResults = await searchWithJina(prompt);
          if (kDebugMode) {
            debugPrint(
                'Web search returned ${searchResults.length} characters');
          }
        } catch (e) {
          debugPrint('Error during Jina search: $e');
          // return 'Error: $e'; // Return error to user
          rethrow;
        }
      }

      final selectedModel =
          model ?? _onlineModelService.selectedOnlineModel?.name;
      if (selectedModel == null || selectedModel.isEmpty) {
        throw Exception(
            'No text model selected for ${_onlineModelService.activeProviderConfig.label}');
      }

      // Customize system prompts based on the mode
      final String system;
      if (useWebSearch) {
        system =
            'You are Aura, a helpful AI assistant. Use the provided search results to answer the question accurately. First look for latest date and when answering mention the date if available.';
      } else if (context.isNotEmpty) {
        // Changed condition to check context.isNotEmpty
        system =
            'You are Aura, a helpful AI assistant who answers concisely based on the provided context documents. Be sure to consider ALL provided context passages before answering.';
      } else {
        system =
            'You are Aura, a helpful AI assistant who answers questions based on knowledge and provided conversation history. Be concise but thorough in your responses.';
      }

      // Format prompt with search results if available
      final formattedPrompt = useWebSearch
          ? '''
Search Results:
$searchResults

Based on these search results, please answer:
$prompt
'''
          : _formatPrompt(prompt, context, useWebSearch, const []);

      if (kDebugMode) {
        debugPrint(
            'Online prompt prepared (${formattedPrompt.length} characters)');
      }

      return await _chatCompletion(
        system,
        formattedPrompt,
        selectedModel,
        history: history,
      );
    } catch (e) {
      debugPrint('Error generating text: $e');
      rethrow;
    }
  }

  /// Unified OpenAI-compatible chat completion against the active provider
  /// (Pollinations / Google / OpenRouter). Non-streaming: returns the full text.
  Future<String> _chatCompletion(
      String system, String userContent, String model,
      {List<ChatMessage> history = const []}) async {
    final provider = _onlineModelService.activeProvider;
    final config = _onlineModelService.activeProviderConfig;
    final key = await _onlineModelService.getApiKey(provider);

    if (key == null || key.isEmpty) {
      throw MissingApiKeyException(config.label);
    }

    final response = await _dio
        .post(
          config.chatUrl,
          data: {
            'model': model,
            'max_tokens': 384,
            'messages': [
              {'role': 'system', 'content': system},
              ..._recentHistory(history).map((message) => {
                    'role': message.isUser ? 'user' : 'assistant',
                    'content': message.content,
                  }),
              {'role': 'user', 'content': userContent},
            ],
          },
          options: Options(
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $key',
            },
            sendTimeout: const Duration(seconds: 60),
            receiveTimeout: const Duration(seconds: 60),
          ),
        )
        .timeout(
          const Duration(seconds: 60),
          onTimeout: () => throw TimeoutException('Request timed out'),
        );

    if (response.statusCode == 200) {
      final content = response.data['choices']?[0]?['message']?['content'];
      if (content is String) return content;
      throw HttpException('Unexpected response from ${config.label}');
    } else {
      throw HttpException('Failed to generate text: ${response.statusCode}');
    }
  }

  List<ChatMessage> _recentHistory(List<ChatMessage> history) {
    final meaningful =
        history.where((message) => message.content.trim().isNotEmpty).toList();
    return meaningful.length <= 12
        ? meaningful
        : meaningful.sublist(meaningful.length - 12);
  }

  Future<String> getJinaApiKey() async {
    return await CredentialStorageService.read('jina_api_key') ?? '';
  }

  Future<String> getPollinationApiKey() async {
    return await CredentialStorageService.read('pollination_api_key') ?? '';
  }

  void dispose() {
    _dio.close();
  }
}

String providerErrorMessage(DioException error, String providerLabel) {
  final status = error.response?.statusCode;
  final retryAfter = error.response?.headers.value('retry-after');
  final detail = _providerErrorDetail(error.response?.data);

  return switch (status) {
    400 => detail ?? 'The selected model rejected this request.',
    401 ||
    403 =>
      'The $providerLabel API key is invalid or lacks permission for this model.',
    402 =>
      '$providerLabel credits or the API-key spending limit have been exhausted.',
    404 =>
      'The selected $providerLabel model is no longer available. Reload models.',
    408 => 'The $providerLabel request timed out. Please try again.',
    429 =>
      '$providerLabel is rate-limiting this model. ${retryAfter == null ? 'Try again later or choose another model.' : 'Try again after $retryAfter seconds.'}',
    500 ||
    502 ||
    503 ||
    504 =>
      '$providerLabel is temporarily unavailable. Please retry or choose another model.',
    _
        when error.type == DioExceptionType.connectionTimeout ||
            error.type == DioExceptionType.sendTimeout ||
            error.type == DioExceptionType.receiveTimeout =>
      'The $providerLabel request timed out. Please try again.',
    _ when error.type == DioExceptionType.connectionError =>
      'Could not connect to $providerLabel. Check your internet connection.',
    _ => detail ?? 'The $providerLabel request failed. Please try again.',
  };
}

String? _providerErrorDetail(dynamic data) {
  if (data is String && data.trim().isNotEmpty) return data.trim();
  if (data is! Map) return null;
  final error = data['error'];
  if (error is Map && error['message'] != null) {
    return error['message'].toString();
  }
  final message = data['message'];
  return message?.toString();
}

/// Thrown when the active online provider has no API key configured.
class MissingApiKeyException implements Exception {
  final String providerLabel;
  MissingApiKeyException(this.providerLabel);
  @override
  String toString() => 'Missing API key for $providerLabel';
}
