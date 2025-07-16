import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  Future<String?> _getPollinationToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('pollination_api_key');
  }

  Future<Uint8List?> generateImage({
    required String prompt,
    int width = 1024,
    int height = 1024,
    String? model = 'flux',
    String? image,
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

      var url =
          '$baseUrl$encodedPrompt?width=$width&height=$height&nologo=$noLogo&enhance=$enhance&safe=$safe&seed=$seed&model=$model';

      if (model?.toLowerCase() == 'kontext') {
        final token = await _getPollinationToken();
        if (token == null || token.isEmpty) {
          throw Exception('Pollination API key not set.');
        }
        url = '$baseUrl$encodedPrompt?model=kontext&token=$token&nologo=$noLogo';
        if (image != null) {
          url += '&image=$image';
        }
      } else {
        if (image != null) {
          url += '&image=$image';
        }
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
      throw Exception(_getUserFriendlyError(e));
    } on SocketException catch (e) {
      debugPrint('No internet connection. ${e.toString()}');
      throw Exception(_getUserFriendlyError(e));
    } catch (e) {
      throw Exception(_getUserFriendlyError(e));
    }
  }

  String _getUserFriendlyError(dynamic error) {
    if (error is SocketException) {
      return 'No internet connection. Please check your network and try again.';
    } else if (error is DioException) {
      if (error.type == DioExceptionType.receiveTimeout || error.type == DioExceptionType.sendTimeout) {
        return 'Request took too long. Please try again.';
      } else if (error.response?.statusCode == 401) {
        return 'Pollination API key missing or invalid. Please add your key in settings.';
      }
      return 'Request failed: ${error.message}';
    } else if (error is HttpException) {
      return 'Temporary service issue. Please try again in a moment.';
    } else if (error.toString().contains('Pollination API key not set.')) {
      return 'Pollination API key missing. Please add your key in settings.';
    }
    return 'Failed to generate image: $error';
  }
}

// Add custom exception classes
class NetworkException implements Exception {
  final String message;
  NetworkException(this.message);
  @override
  String toString() => message;
}