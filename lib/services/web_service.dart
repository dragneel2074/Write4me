import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;
import '../models/pdf_memory.dart';

class WebService {
  Future<PDFMemory?> processWebContent(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) return null;

      final document = parser.parse(response.body);
      final text = document.body?.text ?? '';
      
      if (text.trim().isEmpty) return null;

      final title = document.querySelector('title')?.text ?? url;
      
      return PDFMemory(
        fileName: 'Web: $title',
        extractedText: text,
      );
    } catch (e) {
      debugPrint('Error processing web content: $e');
      return null;
    }
  }
}
