import 'package:http/http.dart' as http;
import '../utils/text_utils.dart';

class TextGenerationService {
  static const String baseUrl = 'https://text.pollinations.ai/';

  String _formatPrompt(String prompt, List<String>? context) {
    if (context == null || context.isEmpty) {
      return prompt;
    }

    return '''
Query: Answer the following question based on the provided Context in very brief.
$prompt

Context:
${context.join('\n')}

''';
  }

  Future<String> generateText(String prompt, {List<String>? context}) async {
    try {
      String model = 'llama';
      // Format and trim prompt
      final formattedPrompt = _formatPrompt(prompt, context);
      final trimmedPrompt = TextUtils.trimToWordLimit(formattedPrompt);

      // URL encode the prompt and create URL
      final encodedPrompt = Uri.encodeComponent(trimmedPrompt);
      final url = Uri.parse('$baseUrl$encodedPrompt?model=$model');

      // Make GET request
      final response = await http.get(url).timeout(
            const Duration(seconds: 30),
            onTimeout: () => throw Exception('Request timed out'),
          );

      // Handle response
      if (response.statusCode == 200) {
        return response.body;
      } else {
        throw Exception('Failed to generate text: ${response.statusCode}');
      }
    } on http.ClientException catch (e) {
      throw Exception('Network error: $e');
    } catch (e) {
      throw Exception('Error generating text: $e');
    }
  }
}
