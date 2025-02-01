import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ImageGenerationService {
  final String _apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
  final String _baseUrl = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-pro-vision:generateContent';

  Future<Uint8List?> generateImage(String prompt) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl?key=$_apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [{
            'parts': [{
              'text': prompt
            }]
          }],
          'generationConfig': {
            'temperature': 0.7,
            'topK': 32,
            'topP': 1,
            'maxOutputTokens': 2048,
          },
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final imageUrl = data['candidates'][0]['content']['parts'][0]['text'];
        
        // Download the generated image
        final imageResponse = await http.get(Uri.parse(imageUrl));
        if (imageResponse.statusCode == 200) {
          return imageResponse.bodyBytes;
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error generating image: $e');
      return null;
    }
  }
}
