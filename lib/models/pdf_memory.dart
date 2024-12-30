
class PDFMemory {
  final String pdfName;
  final String extractedText;
  bool isSelected;

  PDFMemory(
    this.pdfName,
    this.extractedText, {
    this.isSelected = false,
  });
}
