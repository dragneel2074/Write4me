import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FileUploadService {
  final Dio _dio = Dio();
  static const String _uploadUrl = 'https://uguu.se/upload';
  static const String _tokenKey = 'pollinations_api_token';

  Future<String?> uploadImage(Uint8List imageBytes, String fileName) async {
    try {
      final formData = FormData.fromMap({
        'files[]': MultipartFile.fromBytes(imageBytes, filename: fileName),
      });
      final response = await _dio.post(_uploadUrl, data: formData);
      debugPrint("Image Upoading Response is ${response.statusCode}");
      if (response.statusCode == 200) {
        final responseData = response.data;
        if (responseData is Map<String, dynamic> &&
            responseData['files'] != null &&
            responseData['files'].isNotEmpty) {
          return responseData['files'][0]['url'];
        } else if (responseData is String) {
          final decoded = jsonDecode(responseData);
          return decoded['files'][0]['url'];
        } else {
          throw Exception('Failed to parse upload response');
        }
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
