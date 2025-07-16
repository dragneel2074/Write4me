import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FileUploadService {
  final Dio _dio = Dio();
  static const String _uploadUrl = 'https://0x0.st';
  static const String _tokenKey = 'pollinations_api_token';

  Future<String?> uploadImage(Uint8List imageBytes, String fileName) async {
    try {
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(imageBytes, filename: fileName),
      });
      final response = await _dio.post(_uploadUrl, data: formData);
      if (response.statusCode == 200) {
        return response.data.toString().trim();
      } else {
        throw Exception('Failed to upload image: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error uploading image: $e');
    }
  }

  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }
}
