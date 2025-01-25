import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../models/pdf_memory.dart';
import 'package:gal/gal.dart'; // Import the gal package

class ImageService {
  final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

  Future<PDFMemory?> processImageContent(ImageSource source) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: source);

      if (image != null) {
        final inputImage = InputImage.fromFilePath(image.path);
        final recognizedText = await textRecognizer.processImage(inputImage);

        if (recognizedText.text.isNotEmpty) {
          return PDFMemory('Image: ${image.name}', recognizedText.text,
              isSelected: true);
        } else {
          throw Exception('No text recognized in the image');
        }
      } else {
        throw Exception('No image selected');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error processing image: $e');
      }
      return null;
    } finally {
      textRecognizer.close();
    }
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