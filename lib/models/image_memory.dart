import 'dart:io';

class ImageMemory {
  final String name;
  final String extractedText;
  final File? imageFile;
  bool isSelected;

  ImageMemory(this.name, this.extractedText, {this.imageFile, this.isSelected = false});
}