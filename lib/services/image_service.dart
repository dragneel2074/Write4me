import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../models/pdf_memory.dart';
import 'package:gal/gal.dart'; // Import the gal package
import 'package:flutter/material.dart';
import '../utils/dialog_manager.dart';

class ImageService {
  final _textRecognizer = TextRecognizer();
  final _imagePicker = ImagePicker();

  Future<PDFMemory?> pickAndProcessImage() async {
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1800,
        maxHeight: 1800,
      );
      
      if (pickedFile == null) return null;

      final inputImage = InputImage.fromFilePath(pickedFile.path);
      final recognizedText = await _textRecognizer.processImage(inputImage);

      if (recognizedText.text.trim().isEmpty) return null;

      return PDFMemory(
        fileName: 'Image: ${DateTime.now().toString()}',
        extractedText: recognizedText.text,
      );
    } catch (e) {
      debugPrint('Error processing image: $e');
      return null;
    }
  }

  void dispose() {
    _textRecognizer.close();
  }

  Future<void> saveImage(Uint8List imageData) async {
    try {
      // Use the gal package to save the image
      await Gal.putImageBytes(
        imageData,
        name: "Write4Me_${DateTime.now().millisecondsSinceEpoch}",
      );
      debugPrint('Image saved successfully');
    } on GalException catch (e) {
      debugPrint('Error saving image: ${e.type.message}');
      rethrow;
    } catch (e) {
      debugPrint('Unexpected error saving image: $e');
      rethrow;
    }
  }
}