import 'package:langchain/langchain.dart';

class PDFMemory {
  final String pdfName;
  final MemoryVectorStore vectorStore;
  bool isSelected;

  PDFMemory(this.pdfName, this.vectorStore, {this.isSelected = false});
}