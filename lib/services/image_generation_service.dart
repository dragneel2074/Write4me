import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';

class ImageGenerationService {
  static const String baseUrl = 'https://image.pollinations.ai/prompt/';
  final Dio _dio = Dio();

  // List of adult or inappropriate words to filter out
  final List<String> _inappropriateWords = [
    'naked',
    'nude',
    'sexy',
    'porn',
    'sex',
    'adult',
    'explicit',
    'nsfw',
    'nudity',
    'erotic',
    'erotica',
    'ass',
    'asshole',
    'breasts',
    'butt',
    'buttocks',
    'crotch',
    'genitals',
    'nipples',
    'pubic',
    'pubic hair',
    'vagina',
    'penis',
    // Add more words as needed
  ];

  // Function to filter out inappropriate words from the prompt
  String _filterPrompt(String prompt) {
    for (var word in _inappropriateWords) {
      prompt = prompt.replaceAll(RegExp(word, caseSensitive: false), '');
    }
    return prompt;
  }

  Future<Uint8List?> generateImage({
    required String prompt,
    int width = 1024,
    int height = 1024,
    String? model = 'flux',
    String? image,
    String? token,
  }) async {
    try {
      int? seed = 42;
      String noLogo = 'true';
      String enhance = 'true';
      String safe = 'true';
      
      // Filter the prompt to remove any inappropriate words
      final filteredPrompt = _filterPrompt(prompt);

      // URL encode the filtered prompt
      final encodedPrompt = Uri.encodeComponent(filteredPrompt);

      // Build the URL with parameters
      var url =
          '$baseUrl$encodedPrompt?width=$width&height=$height&nologo=$noLogo&enhance=$enhance&safe=$safe&seed=$seed&model=$model';
      if (image != null) {
        url += '&image=$image';
      }
      if (token != null) {
        url += '&token=$token';
      }
      
      if (kDebugMode) {
        print(url);
      }
      
      final response = await _dio.get(url, options: Options(responseType: ResponseType.bytes));

      if (response.statusCode == 200) {
        return response.data;
      } else {
        if (kDebugMode) {
          print(response.data);
        }
        throw HttpException('Server error: ${response.statusCode}');
      }
    } on DioException catch (e) {
      debugPrint('Request failed: ${e.message}');
      throw NetworkException('Request failed: ${e.message}');
    } on SocketException catch (e) {
      debugPrint('No internet connection. ${e.toString()}');
      throw NetworkException('No internet connection.');
    } catch (e) {
      throw Exception('Failed to generate image: $e');
    }
  }
}

// Add custom exception classes
class NetworkException implements Exception {
  final String message;
  NetworkException(this.message);
  @override
  String toString() => message;
}