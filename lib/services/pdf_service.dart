import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'dart:io';
import '../models/pdf_memory.dart';

class PDFService {
  Future<PDFMemory?> pickAndProcessPDF() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
    );

    if (result != null) {
      String pdfName = result.files.first.name;
      String pdfContent = await _extractPDFContent(result);
      return PDFMemory(pdfName, pdfContent, isSelected: true);
    }
    return null;
  }

  Future<String> _extractPDFContent(FilePickerResult result) async {
    if (kIsWeb) {
      return _extractTextFromPDFBytes(result.files.first.bytes!);
    } else {
      String? filePath = result.files.single.path;
      return _extractTextFromPDF(filePath!);
    }
  }

  Future<String> _extractTextFromPDF(String filePath) async {
    final PdfDocument document =
        PdfDocument(inputBytes: File(filePath).readAsBytesSync());
    PdfTextExtractor extractor = PdfTextExtractor(document);
    String text = extractor.extractText();
    document.dispose();
    return text;
  }

  Future<String> _extractTextFromPDFBytes(List<int> bytes) async {
    final PdfDocument document = PdfDocument(inputBytes: bytes);
    PdfTextExtractor extractor = PdfTextExtractor(document);
    String text = extractor.extractText();
    document.dispose();
    return text;
  }
}
