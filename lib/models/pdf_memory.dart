import 'package:langchain/langchain.dart';

class PDFMemory {
  final String pdfName;
  final MemoryVectorStore vectorStore;
  final String extractedText;
  bool isSelected;

  PDFMemory(this.pdfName, this.vectorStore, this.extractedText, {this.isSelected = false});
}