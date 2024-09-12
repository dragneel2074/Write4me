import 'package:dio/dio.dart';
import 'package:html/parser.dart' show parse;
import 'package:html/dom.dart' as html;
import '../models/pdf_memory.dart';
import 'vector_store_service.dart';

class WebService {
  final VectorStoreService _vectorStoreService = VectorStoreService();
  final Dio _dio = Dio();

  Future<PDFMemory?> processWebContent(String url) async {
    try {
      print('Fetching content from URL: $url');
      final response = await _dio.get(url);
      print('HTTP status code: ${response.statusCode}');

      if (response.statusCode == 200) {
        print('Successfully fetched content. Extracting text...');
        String extractedText = _extractTextFromHtml(response.data);
        print('Extracted text length: ${extractedText.length}');

        print('Creating vector store...');
        var vectorStore =
            await _vectorStoreService.createVectorStore(extractedText);
        print('Vector store created successfully');

        return PDFMemory('Web: ${Uri.parse(url).host}', vectorStore,extractedText,
            isSelected: true);
      } else {
        throw Exception(
            'Failed to load web content. Status code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error processing web content: $e');
      return null;
    }
  }

  String _extractTextFromHtml(String htmlContent) {
    html.Document document = parse(htmlContent);

    // Remove script and style elements
    document
        .querySelectorAll('script, style')
        .forEach((element) => element.remove());

    // Extract text from body
    String bodyText = document.body?.text ?? '';

    // Basic cleaning
    bodyText = bodyText.replaceAll(RegExp(r'\s+'), ' ').trim();

    return bodyText;
  }
}
