import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../utils/text_utils.dart';
import '../models/chat_message.dart';

class TextGenerationService {
  static const String baseUrl = 'https://text.pollinations.ai/';

  String _formatPrompt(
    String prompt,
    List<String>? context,
    bool useInternet,
    List<ChatMessage> history,
  ) {
    final StringBuffer formattedPrompt = StringBuffer();

    // Add conversation history
    if (history.isNotEmpty) {
      formattedPrompt.writeln('Previous conversation:');
      for (var message in history.take(6)) {
        // Keep last 6 messages for context
        formattedPrompt.writeln('${message.role}: ${message.content}');
      }
      formattedPrompt.writeln();
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
      String model = useInternet ? 'searchgpt' : 'llama';
      String system = useInternet
          ? 'You are a helpful AI assistant with access to current internet information'
          : 'You are a helpful AI assistant who answers concisely';

      // Format and trim prompt with history
      final formattedPrompt =
          _formatPrompt(prompt, context, useInternet, history);
      final trimmedPrompt = TextUtils.trimToWordLimit(formattedPrompt);

      // URL encode the prompt and create URL
      final encodedPrompt = Uri.encodeComponent(trimmedPrompt);
      final url =
          Uri.parse('$baseUrl$encodedPrompt?model=$model&system=$system');
      if (kDebugMode) {
        print(url);
      }
      final response = await http.get(url).timeout(
            const Duration(seconds: 30),
            onTimeout: () => throw Exception('Request timed out'),
          );

      if (response.statusCode == 200) {
        return response.body;
      } else {
        throw Exception('Failed to generate text: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error generating text: $e');
    }
  }
}
