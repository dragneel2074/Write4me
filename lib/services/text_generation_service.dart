import 'package:flutter/foundation.dart';
import 'package:fllama/fllama.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/chat_message.dart';

class TextGenerationService {
  final _model = GenerativeModel(
    model: 'gemini-pro',
    apiKey: dotenv.env['GEMINI_API_KEY'] ?? '',
  );

  Future<void> generateStreamingResponse(
    String prompt,
    void Function(String, bool) onResponse,
  ) async {
    try {
      String response = '';
      await fllamaChat(
        prompt,
        (text, done) {
          response += text;
          onResponse(response, done);
        },
      );
    } catch (e) {
      debugPrint('Error generating response: $e');
      onResponse('Error: $e', true);
    }
  }

  Future<String> generateCloudResponse(
    String prompt, {
    String? context,
    List<ChatMessage>? history,
  }) async {
    try {
      final chat = _model.startChat(
        history: history?.map((m) => Content(
          parts: [TextPart(m.content)],
          role: m.isUser ? 'user' : 'model',
        )).toList(),
      );

      final promptWithContext = context != null && context.isNotEmpty
          ? '''
Context:
$context

Based on the above context, ${prompt.trim()}'''
          : prompt;

      final response = await chat.sendMessage(Content.text(promptWithContext));
      return response.text ?? 'No response generated';
    } catch (e) {
      debugPrint('Error in cloud generation: $e');
      rethrow;
    }
  }
}
