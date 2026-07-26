import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'dart:async';
import 'dart:io';
import '../models/pdf_memory.dart';
import '../file_processing/file_processor.dart';

import 'offline_model_service.dart';

class PDFService {
  final FileProcessor fileProcessor;
  final OfflineModelService _offlineModelService;

  PDFService(this.fileProcessor, this._offlineModelService);

  Future<PDFMemory?> pickAndProcessPDF({
    void Function(String fileName, double progress)? onProgress,
  }) async {
    if (kDebugMode) {
      print("PDFService: Starting PDF pick and process");
    }

    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
    );

    if (result != null) {
      final file = result.files.first;
      final fileSize = file.size;

      if (fileSize > 2 * 1024 * 1024) {
        // 2MB limit
        throw Exception("File size exceeds the 2MB limit.");
      }

      String pdfName = file.name;
      if (kDebugMode) {
        print("PDFService: PDF selected: $pdfName");
      }

      String pdfContent = await _extractPDFContent(result);

      if (kDebugMode) {
        print(
            "PDFService: Extracted ${pdfContent.length} characters from $pdfName");
        print("PDFService: Extraction completed");
      }

      // Make the document available to the UI immediately. Indexing a large
      // PDF can take minutes on-device, so it continues in the background.
      unawaited(_indexPdfInBackground(
        pdfContent,
        pdfName,
        onProgress: onProgress,
      ));
      return PDFMemory(pdfName, pdfContent, isSelected: true);
    } else {
      if (kDebugMode) {
        print("PDFService: No PDF selected");
      }
      return null;
    }
  }

  Future<void> _indexPdfInBackground(
    String pdfContent,
    String pdfName, {
    void Function(String fileName, double progress)? onProgress,
  }) async {
    try {
      if (kDebugMode) {
        print("PDFService: Background indexing started for $pdfName");
      }
      await fileProcessor.processText(
        pdfContent,
        pdfName,
        onTruncation: _offlineModelService.setTruncationMessage,
        onProgress: (progress) => onProgress?.call(pdfName, progress),
      );
      onProgress?.call(pdfName, 1);
      if (kDebugMode) {
        print("PDFService: Background indexing complete for $pdfName");
      }
    } catch (error, stackTrace) {
      if (kDebugMode) {
        print("PDFService: Background indexing failed for $pdfName: $error");
        print(stackTrace);
      }
    }
  }

  Future<String> _extractPDFContent(FilePickerResult result) async {
    // Prefer in-memory bytes when available to avoid SAF/file path issues on Android release
    final pickedFile = result.files.first;
    final bytes = pickedFile.bytes;
    if (bytes != null && bytes.isNotEmpty) {
      if (kDebugMode) {
        print(
            "PDFService: Using in-memory bytes for PDF extraction (size: ${bytes.length})");
      }
      return _extractTextFromPDFBytes(bytes);
    }

    // Fallback to file path when bytes are not provided
    final String? filePath = pickedFile.path;
    if (filePath == null || filePath.isEmpty) {
      throw Exception(
          "PDFService: No bytes or valid file path returned by FilePicker");
    }
    if (kDebugMode) {
      print("PDFService: Using file path for PDF extraction: $filePath");
    }
    return _extractTextFromPDF(filePath);
  }

  Future<String> _extractTextFromPDF(String filePath) async {
    final PdfDocument document =
        PdfDocument(inputBytes: File(filePath).readAsBytesSync());
    PdfTextExtractor extractor = PdfTextExtractor(document);
    String text = extractor.extractText();
    document.dispose();
    return _cleanPdfText(text);
  }

  Future<String> _extractTextFromPDFBytes(List<int> bytes) async {
    final PdfDocument document = PdfDocument(inputBytes: bytes);
    PdfTextExtractor extractor = PdfTextExtractor(document);
    String text = extractor.extractText();
    document.dispose();
    return _cleanPdfText(text);
  }

  /// Clean PDF text to improve quality
  String _cleanPdfText(String text) {
    if (text.isEmpty) return text;

    // Remove form feed characters
    String cleaned = text.replaceAll('\f', '\n');

    // Fix broken words (words split by newlines with hyphens)
    cleaned = cleaned.replaceAll(RegExp(r'(\w+)-\n(\w+)'), r'$1$2');

    // Replace multiple consecutive spaces with a single space
    cleaned = cleaned.replaceAll(RegExp(r' {2,}'), ' ');

    // Fix excessive newlines (more than 2 consecutive newlines)
    cleaned = cleaned.replaceAll(RegExp(r'\n{3,}'), '\n\n');

    // Remove header/footer page numbers (common in PDFs)
    cleaned = cleaned.replaceAll(RegExp(r'\n\s*\d+\s*\n'), '\n\n');

    // Remove non-printable characters
    cleaned =
        cleaned.replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), '');

    // Remove isolated numbers that might be page numbers
    cleaned = cleaned.replaceAll(RegExp(r'\n\s*\d+\s*\n'), '\n\n');

    // Fix spacing after punctuation
    cleaned = cleaned.replaceAll(RegExp(r'([.,;:!?])\s*'), r'$1 ');

    // Normalize whitespace around parentheses
    cleaned = cleaned.replaceAll(RegExp(r'\s*\(\s*'), ' (');
    cleaned = cleaned.replaceAll(RegExp(r'\s*\)\s*'), ') ');

    // Trim leading/trailing whitespace
    cleaned = cleaned.trim();

    if (kDebugMode && cleaned.length != text.length) {
      if (kDebugMode) {
        print(
            'PDFService: Text cleaning changed length from ${text.length} to ${cleaned.length}');
      }
    }

    return cleaned;
  }
}
