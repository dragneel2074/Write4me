import 'dart:async';
import 'dart:io'; // For SocketException
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/chat_message.dart';
import '../file_processing/file_processor.dart';

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

    // Determine which mode we're in
    final bool hasDocuments = context != null && context.isNotEmpty;
    final bool hasWebSearch = useWebSearch;
    
    if (kDebugMode) {
      print('TextGenerationService: Formatting prompt for mode: ${hasWebSearch ? "Web" : hasDocuments ? "Document" : "Simple"}');
    }

    // Choose appropriate prompt based on mode
    if (hasWebSearch) {
      _buildWebSearchPrompt(formattedPrompt, prompt, history, cleanText, context ?? []);
    } else if (hasDocuments) {
      _buildDocumentPrompt(formattedPrompt, prompt, context, history, cleanText);
    } else {
      _buildSimplePrompt(formattedPrompt, prompt, history, cleanText, context ?? []);
    }

    return formattedPrompt.toString();
  }
  
  /// Builds a prompt for simple QA mode (no documents, no web search)
  void _buildSimplePrompt(StringBuffer buffer, String prompt, List<ChatMessage> history, Function cleanText, List<String> context) {
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
  void _buildDocumentPrompt(StringBuffer buffer, String prompt, List<String> context, List<ChatMessage> history, Function cleanText) {
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
      buffer.writeln('----- PASSAGE ${i+1}/${context.length} -----');
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
  void _buildWebSearchPrompt(StringBuffer buffer, String prompt, List<ChatMessage> history, Function cleanText, List<String> context) {
    // For web search, we focus entirely on the current query
    // History is typically not included for web search to keep the prompt clean
    
    buffer.write('Search the internet and provide accurate information about: $prompt');

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

        final response = await _dio.post(
          'https://text.pollinations.ai/openai',
          data: visionMessage,
          options: Options(
            headers: {
              'Content-Type': 'application/json',
            },
          ),
        );

        if (response.statusCode == 200) {
          onResponse(response.data['choices'][0]['message']['content'], true);
        } else {
          throw HttpException('Failed to generate text: ${response.statusCode}');
        }
        return;
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
   // Use provided model or default
          const system = 'You are Aura, a helpful AI assistant. Use the provided search results to answer the question accurately. First look for latest date and when answering mention the date if available.';
          
          

          final formattedPrompt = '''
Search Results:
$searchResults

Based on these search results, please answer:
$prompt
''';
          final url = _buildUrl(formattedPrompt, model!, system);
          
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
          context: context, // Pass the provided context
          useWebSearch: false,
          history: history,
          model: model, // Pass the model parameter
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
    List<String> context = const [], // Changed to non-nullable with default
    bool useWebSearch = false,
    List<ChatMessage> history = const [],
    String? model, // New optional parameter
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

      final selectedModel = model ?? 'gpt-4o-mini'; // Use provided model or default
      
      // Customize system prompts based on the mode
      final String system;
      if (useWebSearch) {
        system = 'You are Aura, a helpful AI assistant. Use the provided search results to answer the question accurately. First look for latest date and when answering mention the date if available.';
      } else if (context.isNotEmpty) { // Changed condition to check context.isNotEmpty
        system = 'You are Aura, a helpful AI assistant who answers concisely based on the provided context documents. Be sure to consider ALL provided context passages before answering.';
      } else {
        system = 'You are Aura, a helpful AI assistant who answers questions based on knowledge and provided conversation history. Be concise but thorough in your responses.';
      }

      // Format prompt with search results if available
      final formattedPrompt = useWebSearch
          ? '''
Search Results:
$searchResults

Based on these search results, please answer:
$prompt
'''
          : _formatPrompt(prompt, context, useWebSearch, history); // Pass context directly

      if (kDebugMode) {        print("Original prompt length: \${formattedPrompt.length} characters");        debugPrint('--- FULL PROMPT (ONLINE ---\n$formattedPrompt\n--------------------------');      }
      
      final url = _buildUrl(formattedPrompt, selectedModel, system);
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
    // Clean prompt before encoding to remove problematic characters
    if (kDebugMode) {
      print('\n========== URL GENERATION DETAILS ==========');
      print('Original prompt length: ${prompt.length}');
      // Show a preview of the prompt
      final previewLength = prompt.length > 50 ? 50 : prompt.length;
      print('Original prompt preview: ${prompt.substring(0, previewLength)}...');
    }
    
    final cleanedPrompt = _sanitizeTextForUrl(prompt);
    final encodedPrompt = Uri.encodeComponent(cleanedPrompt);
    final url = Uri.parse('$baseUrl$encodedPrompt?model=$model&system=$system');
    
    if (kDebugMode) {
      print('Final URL length: ${url.toString().length}');
      print('URL preview: ${url.toString().substring(0, url.toString().length > 100 ? 100 : url.toString().length)}...');
      print('===========================================\n');
    }
    
    return url;
  }
  
  // Private method to sanitize text before URL encoding
  String _sanitizeTextForUrl(String text) {
    if (text.isEmpty) return text;
    
    if (kDebugMode) {
      print('TextGenerationService: Sanitizing prompt text of length ${text.length} for API request');
      // Print a small sample of the text before cleaning
      final previewLength = text.length > 100 ? 100 : text.length;
      print('TextGenerationService: First $previewLength chars before cleaning: ${text.substring(0, previewLength)}');
    }
    
    // Import the cleaning function if not already imported
    try {
      // Try to use the FileProcessor's method if available
      final cleanedText = FileProcessor.cleanTextForApiSubmission(text);
      
      if (kDebugMode) {
        print('TextGenerationService: Text cleaned for API submission, new length: ${cleanedText.length}');
        if (cleanedText.length != text.length) {
          print('TextGenerationService: Text length changed during cleaning (${text.length} -> ${cleanedText.length})');
        }
      }
      
      return cleanedText;
    } catch (e) {
      // Fallback implementation if the FileProcessor method is not available
      if (kDebugMode) {
        print('TextGenerationService: Using fallback text cleaning method: $e');
      }
      
      // Remove problematic sequences like $1, $2, etc.
      String cleaned = text.replaceAll(RegExp(r'\$\d+'), '');
      
      // Strip non-printable ASCII characters
      cleaned = cleaned.replaceAll(RegExp(r'[^\x20-\x7E\n\r]'), '');
      
      // Normalize whitespace
      cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
      
      if (kDebugMode && cleaned.length != text.length) {
        if (kDebugMode) {
          print('TextGenerationService: Text length changed during fallback cleaning (${text.length} -> ${cleaned.length})');
        }
      }
      
      return cleaned;
    }
  }

  Future<String> getJinaApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jina_api_key') ?? '';
  }

  Future<String> getPollinationApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('pollination_api_key') ?? '';
  }

  void dispose() {
    _dio.close();
  }
}
