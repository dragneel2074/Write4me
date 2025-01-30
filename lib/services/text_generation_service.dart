import 'dart:async';
import 'dart:io'; // For SocketException
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/text_utils.dart';
import '../models/chat_message.dart';

class TextGenerationService {
  static const String baseUrl = 'https://text.pollinations.ai/';
  static const String jinaSearchUrl = 'https://s.jina.ai/';
  static const String unwanted1 = 'Chat Service is Online. Ask Me Anything.';
  static const String unwanted2 =
      'Image Service is Online. Generate Amazing Images';

  String _formatPrompt(
    String prompt,
    List<String>? context,
    bool useInternet,
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
        if (!useInternet) {
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
      formattedPrompt.write(useInternet
          ? 'Search the internet and provide accurate information about: $prompt'
          : prompt);
    } else {
      formattedPrompt.write('''
Query: ${useInternet ? 'Search the internet and answer based on both the context and current information about' : 'Answer based on the context about'}: 
$prompt

Context:
${context.join('\n')}
''');
    }

    return formattedPrompt.toString();
  }

  Future<String> _searchWithJina(String query) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final apiKey = prefs.getString('jina_api_key');
      
      if (apiKey == null || apiKey.isEmpty) {
        throw Exception('Jina API key not found. Please add it in settings.');
      }

      // Format current date and time
      final now = DateTime.now();
      final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      // final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
      
      // Add date and time to query
      final enhancedQuery = '''
$query $dateStr 
''';
      if (kDebugMode) {
        print(enhancedQuery);
      }
      final response = await http.get(
        Uri.parse('$jinaSearchUrl${Uri.encodeComponent(enhancedQuery)}?count=5'),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'X-Retain-Images': 'none',
          'X-Return-Format': 'text',
        },
      );

      if (response.statusCode == 200) {
        return '${response.body} \n\n Today is $dateStr';
      } else {
        throw Exception('Failed to search: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error searching with Jina: $e');
      rethrow;
    }
  }

  Future<String> generateText(
    String prompt, {
    List<String>? context,
    bool useInternet = false,
    List<ChatMessage> history = const [],
  }) async {
    try {
      String searchResults = '';
      if (useInternet) {
        try {
          // print(prompt);
          searchResults = await _searchWithJina(prompt);
          debugPrint('Jina search results: $searchResults');
        } catch (e) {
          debugPrint('Error during Jina search: $e');
          return 'Error: $e'; // Return error to user
        }
      }

      const model = 'mistral'; // Always use mistral for text generation
      final system = useInternet
          ? 'You are Aura, a helpful AI assistant. Use the provided search results to answer the question accurately. First look for latest date and when answering mention the date if available.'
          : 'You are Aura, a helpful AI assistant who answers concisely';

      // Format prompt with search results if available
      final formattedPrompt = useInternet
          ? '''
Search Results:
$searchResults

Based on these search results, please answer:
$prompt
'''
          : _formatPrompt(prompt, context, useInternet, history);

      final trimmedPrompt = TextUtils.trimToWordLimit(formattedPrompt);
      final url = _buildUrl(trimmedPrompt, model, system);

      final response = await http.get(url).timeout(
            const Duration(seconds: 30),
            onTimeout: () => throw TimeoutException('Request timed out'),
          );

      if (response.statusCode == 200) {
        return response.body;
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
}
