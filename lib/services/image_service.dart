import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../models/pdf_memory.dart';
import 'package:gal/gal.dart'; // Import the gal package
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';

class ImageService {
  final _textRecognizer = TextRecognizer();
  final _picker = ImagePicker();
  bool _isRequestingPermission = false;

  Future<bool> _requestPermission(Permission permission) async {
    if (_isRequestingPermission) {
      return false;
    }

    try {
      _isRequestingPermission = true;
      final status = await permission.request();
      return status.isGranted;
    } finally {
      _isRequestingPermission = false;
    }
  }

  Future<PDFMemory?> processImageContent(ImageSource source) async {
    try {
      // Request permissions first
      bool permissionGranted = false;
      if (source == ImageSource.camera) {
        permissionGranted = await _requestPermission(Permission.camera);
        if (!permissionGranted) {
          throw Exception('Camera permission denied');
        }
      } else {
        permissionGranted = await _requestPermission(Permission.photos);
        if (!permissionGranted) {
          throw Exception('Photos permission denied');
        }
      }

      // Pick image with error handling
      XFile? pickedFile;
      try {
        pickedFile = await _picker.pickImage(
          source: source,
          maxWidth: 1800,
          maxHeight: 1800,
          imageQuality: 85,
        );
      } catch (e) {
        debugPrint('Error picking image: $e');
        // If first attempt fails, try again without image constraints
        pickedFile = await _picker.pickImage(
          source: source,
        );
      }

      if (pickedFile == null) return null;

      // Verify file exists and is readable
      final file = File(pickedFile.path);
      if (!await file.exists()) {
        throw Exception('Selected file does not exist');
      }

      // Process image
      final inputImage = InputImage.fromFile(file);
      final recognizedText = await _textRecognizer.processImage(inputImage);

      if (recognizedText.text.isEmpty) {
        throw Exception('No text found in image');
      }

      return PDFMemory(
        'Image: ${pickedFile.name}',
        recognizedText.text,
        isSelected: true,
      );
    } catch (e) {
      debugPrint('Error processing image: $e');
      rethrow;
    }
  }

  Future<void> saveImage(Uint8List imageData) async {
    try {
      final permissionGranted = await _requestPermission(Permission.storage);
      if (!permissionGranted) {
        throw Exception('Storage permission denied');
      }

      // Use gal package to save the image with error handling
      try {
        await Gal.putImageBytes(
          imageData,
          name: "Write4Me_${DateTime.now().millisecondsSinceEpoch}",
        );
      } on GalException catch (e) {
        debugPrint('Gal error: ${e.type}');
        rethrow;
      }
    } catch (e) {
      debugPrint('Error saving image: $e');
      rethrow;
    }
  }

  void dispose() {
    _textRecognizer.close();
  }
}