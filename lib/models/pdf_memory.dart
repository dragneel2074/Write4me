class PDFMemory {
  final String fileName;
  final String extractedText;
  bool isSelected;

  PDFMemory({
    required this.fileName,
    required this.extractedText,
    this.isSelected = false,
  });

  PDFMemory copyWith({
    String? fileName,
    String? extractedText,
    bool? isSelected,
  }) {
    return PDFMemory(
      fileName: fileName ?? this.fileName,
      extractedText: extractedText ?? this.extractedText,
      isSelected: isSelected ?? this.isSelected,
    );
  }
}
