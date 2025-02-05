import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';

class ImageGenerationService {
  static const String baseUrl = 'https://image.pollinations.ai/prompt/';
  final Dio _dio = Dio();

  Future<Uint8List?> generateImage({
    required String prompt,
    int width = 1024,
    int height = 1024,
    String? model = 'flux',
  }) async {
    try {
      int? seed = 42;
      String noLogo = 'true';
      String enhance = 'true';
      String safe = 'false';
      
      // URL encode the prompt
      final encodedPrompt = Uri.encodeComponent(prompt);

      // Build the URL with parameters
      final url = '$baseUrl$encodedPrompt?width=$width&height=$height&nologo=$noLogo&enhance=$enhance&safe=$safe&seed=$seed';
      
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
