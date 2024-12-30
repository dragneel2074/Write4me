import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../models/pdf_memory.dart';

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
      print('Error processing image: $e');
      return null;
    } finally {
      textRecognizer.close();
    }
  }
}
