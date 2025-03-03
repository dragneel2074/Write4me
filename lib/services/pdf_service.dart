import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'dart:io';
import '../models/pdf_memory.dart';
import '../file_processing/file_processor.dart';

class PDFService {
  final FileProcessor fileProcessor;

  PDFService(this.fileProcessor);

  Future<PDFMemory?> pickAndProcessPDF() async {
    if (kDebugMode) {
      print("PDFService: Starting PDF pick and process");
    }
    
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
    );

    if (result != null) {
      String pdfName = result.files.first.name;
      if (kDebugMode) {
        print("PDFService: PDF selected: $pdfName");
      }
      
      String pdfContent = await _extractPDFContent(result);
      
      if (kDebugMode) {
        print("PDFService: Extracted ${pdfContent.length} characters from $pdfName");
        print("PDFService: First 100 chars: ${pdfContent.substring(0, pdfContent.length < 100 ? pdfContent.length : 100)}");
      }
      
      // Process for embeddings immediately
      try {
        if (kDebugMode) {
          print("PDFService: Processing $pdfName for vector embeddings");
        }
        await fileProcessor.processText(pdfContent, pdfName);

        if (kDebugMode) {
          print("PDFService: Successfully processed $pdfName for vector search");
          // Get document count to verify processing
          final stats = await fileProcessor.getVectorStoreStats();
          print("PDFService: Vector store now has ${stats['documentCount']} documents");
          
          // Verify search capability with a test query from the document
          // Take a short fragment from the beginning of the document to ensure it exists
          if (pdfContent.length > 20) {
            final testFragment = pdfContent.substring(0, 20).trim();
            print("PDFService: Testing search with fragment: '$testFragment'");
            
            final results = await fileProcessor.queryFile(testFragment, selectedFiles: [pdfName], limit: 1);
            print("PDFService: Verification search returned ${results.length} results");
            
            if (results.isEmpty) {
              print("PDFService: WARNING - Verification search failed, document may not be retrievable");
            } else {
              print("PDFService: Document verified successfully");
            }
          }
        }
      } catch (e) {
        if (kDebugMode) {
          print("PDFService: Error processing document for vector search: $e");
          print("PDFService: Stack trace: ${StackTrace.current}");
        }
        // Continue even if processing fails, as we can still use the raw text
      }
      
      return PDFMemory(pdfName, pdfContent, isSelected: true);
    } else {
      if (kDebugMode) {
        print("PDFService: No PDF selected");
      }
      return null;
    }
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
    cleaned = cleaned.replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), '');
    
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
        print('PDFService: Text cleaning changed length from ${text.length} to ${cleaned.length}');
      }
    }
    
    return cleaned;
  }
}
