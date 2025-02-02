class PDFMemory {
  final String name;
  final String extractedText;
  bool isSelected;

  PDFMemory(this.name, this.extractedText, {this.isSelected = false});
}
