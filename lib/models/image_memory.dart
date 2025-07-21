import 'dart:io';

class ImageMemory {
  final String name;
  final String extractedText;
  final File? imageFile;
  String? imageUrl;
  bool isSelected;

  ImageMemory(this.name, this.extractedText, {this.imageFile, this.imageUrl, this.isSelected = false});

  ImageMemory copyWith({
    String? name,
    String? extractedText,
    File? imageFile,
    String? imageUrl,
    bool? isSelected,
  }) {
    return ImageMemory(
      name ?? this.name,
      extractedText ?? this.extractedText,
      imageFile: imageFile ?? this.imageFile,
      imageUrl: imageUrl ?? this.imageUrl,
      isSelected: isSelected ?? this.isSelected,
    );
  }
}