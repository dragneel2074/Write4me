class PDFMemory {
  final String name;
  final String extractedText;
  bool isSelected;
  final DateTime addedTime;

  PDFMemory(this.name, this.extractedText, {this.isSelected = false, DateTime? addedTime})
    : addedTime = addedTime ?? DateTime.now();
}
