import 'package:http/http.dart' as http;
import 'dart:typed_data';

class ImageGenerationService {
  static const String baseUrl = 'https://image.pollinations.ai/prompt/';

  Future<Uint8List?> generateImage({
    required String prompt,
    int width = 1024,
    int height = 1024,
    String? model,
    int? seed,
    bool noLogo = true,
    bool enhance = true,
    bool safe = false,
  }) async {
    try {
      // URL encode the prompt
      final encodedPrompt = Uri.encodeComponent(prompt);

      // Build the URL with parameters
      final url = Uri.parse('$baseUrl$encodedPrompt?width=$width&height=$height&nologo=${noLogo ? 'true' : 'false'}&enhance=${enhance ? 'true' : 'false'}&safe=${safe ? 'true' : 'false'}${model != null ? '&model=$model' : ''}${seed != null ? '&seed=$seed' : ''}');

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
