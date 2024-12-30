import 'package:http/http.dart' as http;
import 'dart:typed_data';

class ImageGenerationService {
  static const String baseUrl = 'https://image.pollinations.ai/prompt/';

  Future<Uint8List?> generateImage({
    required String prompt,
    int width = 1024,
    int height = 1024,
    String? model,
  }) async {
    try {
      int? seed;
      String noLogo = 'true';
      String enhance = 'true';
      String safe = 'false';
      // URL encode the prompt
      final encodedPrompt = Uri.encodeComponent(prompt);

      // Build the URL with parameters
      final url = Uri.parse(
          '$baseUrl$encodedPrompt?width=$width&height=$height&nologo=$noLogo&enhance=$enhance&safe=$safe&model=$model&seed=$seed=42');

      final response = await http.get(url);

      if (response.statusCode == 200) {
        return response.bodyBytes;
      } else {
        throw Exception('Failed to generate image: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error generating image: $e');
    }
  }
}
