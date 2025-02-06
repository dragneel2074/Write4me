import 'dart:async';
import 'dart:io'; // For SocketException
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/text_utils.dart';
import '../models/chat_message.dart';
import '../models/pdf_memory.dart';

class TextGenerationService {
  static const String baseUrl = 'https://text.pollinations.ai/';
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

    // Add conversation history
    if (context == null || context.isEmpty) {
      if (history.isNotEmpty) {
        formattedPrompt.writeln('Previous conversation:');
        if (!useWebSearch) {
          for (var message in history.take(6)) {
            final cleanedContent = cleanText(message.content);
            if (kDebugMode) {
              print(cleanedContent);
            }
            formattedPrompt.writeln('${message.role}: $cleanedContent');
          }
          formattedPrompt.writeln();
        }
      }
    }

    // Add current query
    if (context == null || context.isEmpty) {
      formattedPrompt.write(useWebSearch
          ? 'Search the internet and provide accurate information about: $prompt'
          : prompt);
    } else {
      formattedPrompt.write('''
Query: ${useWebSearch ? 'Search the internet and answer based on both the context and current information about' : 'Answer based on the context about'}: 
$prompt

Context:
${context.join('\n')}
''');
    }

    return formattedPrompt.toString();
  }

  Future<String> searchWithJina(String query) async {
    final apiKey = await getJinaApiKey();
    if (apiKey.isEmpty) {
      throw Exception('Jina API key not found');
    }

    try {
      final now = DateTime.now();
      final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      
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
    List<PDFMemory> selectedMemories,
    void Function(String, bool) onResponse, {
    bool useWebSearch = false,
    List<ChatMessage> history = const [],
  }) async {
    try {
      // Build context from selected memories
      List<String> context = [];
      if (selectedMemories.isNotEmpty) {
        for (var memory in selectedMemories) {
          if (memory.isSelected) {
            final trimmedText = TextUtils.trimToWordLimit(memory.extractedText);
            context.add(trimmedText);
          }
        }
      }

      if (useWebSearch) {
        // Show searching status
        onResponse('Searching the web...', false);
        
        try {
          debugPrint('prompt in generateText: $prompt');
          final searchResults = await searchWithJina(prompt);
          
          // Show search complete status
          onResponse('Search results found. Generating response...', false);
          
          debugPrint('Jina search results: $searchResults');
          
          // Generate response with search results
          const model = 'mistral';
          const system = 'You are Aura, a helpful AI assistant. Use the provided search results to answer the question accurately. First look for latest date and when answering mention the date if available.';
          
          final formattedPrompt = '''
Search Results:
$searchResults

Based on these search results, please answer:
$prompt
''';

          final trimmedPrompt = TextUtils.trimToWordLimit(formattedPrompt);
          final url = _buildUrl(trimmedPrompt, model, system);
          
          final response = await _dio.get(
            url.toString(),
            options: Options(
              responseType: ResponseType.plain,
              sendTimeout: const Duration(seconds: 30),
              receiveTimeout: const Duration(seconds: 30),
            ),
          );

          if (response.statusCode == 200) {
            onResponse(response.data.toString(), true);
          } else {
            throw HttpException('Failed to generate text: ${response.statusCode}');
          }
          
        } catch (e) {
          debugPrint('Error during web search or response generation: $e');
          rethrow;
        }
      } else {
        // Non-web search flow
        onResponse('Generating response...', false);
        final response = await generateText(
          prompt,
          context: context.isNotEmpty ? context : null,
          useWebSearch: false,
          history: history,
        );
        onResponse(response, true);
      }
    } catch (e) {
      onResponse(_getUserFriendlyError(e), true);
      throw Exception('Failed to get response: $e');
    }
  }

  String _getUserFriendlyError(dynamic error) {
    if (error is SocketException) {
      return 'No internet connection. Please check your network and try again.';
    } else if (error is TimeoutException) {
      return 'Request took too long. Please try again.';
    } else if (error is HttpException) {
      return 'Temporary service issue. Please try again in a moment.';
    } else if (error.toString().contains('Jina API key')) {
      return 'API key missing. Please add your Jina API key in settings.';
    }
    return 'Oops! Something went wrong. Please try again.';
  }


  Future<String> generateText(
    String prompt, {
    List<String>? context,
    bool useWebSearch = false,
    List<ChatMessage> history = const [],
  }) async {
    try {
      String searchResults = '';
      if (useWebSearch) {
        try {
          debugPrint('prompt in generateText: $prompt');
          searchResults = await searchWithJina(prompt);
          debugPrint('Jina search results: $searchResults');
        } catch (e) {
          debugPrint('Error during Jina search: $e');
          // return 'Error: $e'; // Return error to user
          rethrow;
        }
      }

      const model = 'mistral'; // Always use mistral for text generation
      final system = useWebSearch
          ? 'You are Aura, a helpful AI assistant. Use the provided search results to answer the question accurately. First look for latest date and when answering mention the date if available.'
          : 'You are Aura, a helpful AI assistant who answers concisely. Before answering, first understand that if previous conversations are required to answer the present question.';

      // Format prompt with search results if available
      final formattedPrompt = useWebSearch
          ? '''
Search Results:
$searchResults

Based on these search results, please answer:
$prompt
'''
          : _formatPrompt(prompt, context, useWebSearch, history);

      final trimmedPrompt = TextUtils.trimToWordLimit(formattedPrompt);
      final url = _buildUrl(trimmedPrompt, model, system);
      debugPrint('url: $url');
      final response = await _dio.get(
        url.toString(),
        options: Options(
          responseType: ResponseType.plain,
          sendTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
        ),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw TimeoutException('Request timed out'),
      );

      if (response.statusCode == 200) {
        return response.data.toString();
      } else {
        throw HttpException('Failed to generate text: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error generating text: $e');
      rethrow;
    }
  }

  Uri _buildUrl(String prompt, String model, String system) {
    final encodedPrompt = Uri.encodeComponent(prompt);
    return Uri.parse('$baseUrl$encodedPrompt?model=$model&system=$system');
  }

  Future<String> getJinaApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jina_api_key') ?? '';
  }

  void dispose() {
    _dio.close();
  }
}
