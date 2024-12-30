import 'package:dio/dio.dart';
import 'package:html/parser.dart' show parse;
import 'package:html/dom.dart' as html;
import '../models/pdf_memory.dart';

class WebService {
  final Dio _dio = Dio();

  Future<PDFMemory?> processWebContent(String url) async {
    try {
      String newUrl = "https://r.jina.ai/$url";
      print('Fetching content from URL: $newUrl');
      final response = await _dio.get(newUrl);
      print('HTTP status code: ${response.statusCode}');

      if (response.statusCode == 200) {
        print('Successfully fetched content. Extracting text...');
        String extractedText = _extractTextFromHtml(response.data);
        print('Extracted text length: ${extractedText.length}');

        return PDFMemory('Web: ${Uri.parse(url).host}', extractedText,
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
    document
        .querySelectorAll('script, style')
        .forEach((element) => element.remove());
    String bodyText = document.body?.text ?? '';
    return bodyText.replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}
