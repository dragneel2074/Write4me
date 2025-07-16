import 'dart:io';

class ImageMemory {
  final String name;
  final String extractedText;
  final File? imageFile;
  String? imageUrl;
  bool isSelected;

  ImageMemory(this.name, this.extractedText, {this.imageFile, this.imageUrl, this.isSelected = false});
}