import 'dart:async';
import 'dart:io'; // For SocketException
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../utils/text_utils.dart';
import '../models/chat_message.dart';

class TextGenerationService {
  static const String baseUrl = 'https://text.pollinations.ai/';
  static const String unwanted1 = 'Chat Service is Online. Ask Me Anything.';
  static const String unwanted2 = 'Image Service is Online. Generate Amazing Images';

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
    if (history.isNotEmpty) {
      formattedPrompt.writeln('Previous conversation:');
      if (!useInternet){
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

  Future<String> generateText(
    String prompt, {
    List<String>? context,
    bool useInternet = false,
    List<ChatMessage> history = const [],
  }) async {
    try {
      final model = useInternet ? 'searchgpt' : 'mistral-large';
      final system = useInternet
          ? 'You are a helpful AI assistant with access to current internet information'
          : 'You are a helpful AI assistant who answers concisely';

      // Format and trim prompt with history
      final formattedPrompt = _formatPrompt(prompt, context, useInternet, history);
      final trimmedPrompt = TextUtils.trimToWordLimit(formattedPrompt);

      // URL encode the prompt and create URL
      final url = _buildUrl(trimmedPrompt, model, system);
      if (kDebugMode) {
        print(url);
      }

      final response = await http.get(url).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw TimeoutException('Request timed out'),
      );

      // Handle HTTP errors
      if (response.statusCode == 200) {
        return response.body;
      } else {
        throw HttpException('Failed to generate text: ${response.statusCode}', uri: url);
      }
    } on SocketException catch (e) {
      // Handle network errors (e.g., no internet, host lookup failure)
      throw Exception('Network error: Please check your internet connection. Details: $e');
    } on TimeoutException catch (e) {
      // Handle timeout errors
      throw Exception('Request timed out: Please try again later. Details: $e');
    } on HttpException catch (e) {
      // Handle HTTP errors (e.g., 404, 500)
      throw Exception('Server error: ${e.message}');
    } catch (e) {
      // Handle all other unexpected errors
      throw Exception('Unexpected error: $e');
    }
  }

  Uri _buildUrl(String prompt, String model, String system) {
    final encodedPrompt = Uri.encodeComponent(prompt);
    return Uri.parse('$baseUrl$encodedPrompt?model=$model&system=$system');
  }
}