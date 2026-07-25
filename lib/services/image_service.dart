import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../models/image_memory.dart';
import 'package:gal/gal.dart'; // Import the gal package
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';

import '../file_processing/file_processor.dart';

class ImageService {
  final _textRecognizer = TextRecognizer();
  final _picker = ImagePicker();
  final FileProcessor _fileProcessor;
  bool _isRequestingPermission = false;

  ImageService(this._fileProcessor);

  Future<bool> _requestPermission(Permission permission) async {
    if (_isRequestingPermission) return false;

    try {
      _isRequestingPermission = true;
      final status = await permission.request();
      return status.isGranted;
    } finally {
      _isRequestingPermission = false;
    }
  }

  Future<bool> _requestStoragePermission() async {
    if (_isRequestingPermission) return false;

    try {
      _isRequestingPermission = true;

      // Check Android version
      final deviceInfo = await DeviceInfoPlugin().androidInfo;
      final sdkInt = deviceInfo.version.sdkInt;

      if (sdkInt >= 33) {
        // Android 13 and above
        final photos = await Permission.photos.request();
        return photos.isGranted;
      } else {
        final storage = await Permission.storage.request();
        return storage.isGranted;
      }
    } finally {
      _isRequestingPermission = false;
    }
  }

  Future<ImageMemory?> processImageContent(ImageSource source) async {
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
          maxWidth: 1024, // Reduced max width
          maxHeight: 1024, // Reduced max height
          imageQuality: 70, // Reduced image quality
        );
      } catch (e) {
        debugPrint('Error picking image with constraints: $e');
        // If picking with constraints fails, inform the user and return null
        throw Exception(
            'Failed to pick image with optimal size. Try a smaller image or different source.');
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

      await _fileProcessor.processText(
          recognizedText.text, 'Image: ${pickedFile.name}');

      return ImageMemory(
        'Image: ${pickedFile.name}',
        recognizedText.text,
        imageFile: file,
        isSelected: true,
      );
    } catch (e) {
      debugPrint('Error processing image: $e');
      rethrow;
    }
  }

  Future<void> saveImage(Uint8List imageData) async {
    try {
      final permissionGranted = await _requestStoragePermission();
      if (!permissionGranted) {
        throw Exception('Storage permission denied');
      }

      // Use gal package to save the image with error handling
      try {
        await Gal.putImageBytes(
          imageData,
          name: "Write4Me_${DateTime.now().millisecondsSinceEpoch}.png",
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
