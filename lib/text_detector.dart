import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'utils/image_utils.dart';

class TextDetectorPage extends StatefulWidget {
  @override
  _TextDetectorPageState createState() => _TextDetectorPageState();
}

class _TextDetectorPageState extends State<TextDetectorPage> {
  XFile? _image;
  String _recognizedText = '';
  final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

  Future<void> _getImage(ImageSource source) async {
    final pickedFile = await ImagePicker().pickImage(source: source);
    if (pickedFile != null) {
      setState(() {
        _image = pickedFile;
      });
      await _processImage();
    }
  }

  Future<void> _processImage() async {
    if (_image == null) return;
    final inputImage = InputImage.fromFilePath(_image!.path);
    try {
      print('Processing image: ${_image!.path}');
      final recognizedText = await textRecognizer.processImage(inputImage);
      setState(() {
        _recognizedText = recognizedText.text;
      });
      print('Text recognition completed. Text length: ${_recognizedText.length}');
    } catch (e) {
      print('Error processing image: $e');
      setState(() {
        _recognizedText = 'Error processing image: $e';
      });
    }
  }

  @override
  void dispose() {
    textRecognizer.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Text Detector'),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            if (_image != null)
              ImageUtils.imageFromXFile(_image!)
            else
              Placeholder(fallbackHeight: 200),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => _getImage(ImageSource.gallery),
              child: Text('Pick Image from Gallery'),
            ),
            ElevatedButton(
              onPressed: () => _getImage(ImageSource.camera),
              child: Text('Take Picture'),
            ),
            SizedBox(height: 20),
            Text('Recognized Text:'),
            Padding(
              padding: EdgeInsets.all(16),
              child: Text(_recognizedText),
            ),
          ],
        ),
      ),
    );
  }
}