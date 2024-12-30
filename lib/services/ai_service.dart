import '../models/pdf_memory.dart';
import 'text_generation_service.dart';
import '../utils/text_utils.dart';

class AIService {
  final TextGenerationService _textService = TextGenerationService();

  Future<String> getResponse(
      String question, List<PDFMemory> selectedMemories) async {
    try {
      List<String> context = [];

      if (selectedMemories.isNotEmpty) {
        for (var memory in selectedMemories) {
          if (memory.isSelected) {
            // Trim each document's text to the word limit
            final trimmedText = TextUtils.trimToWordLimit(memory.extractedText);
            context.add(trimmedText);
          }
        }
      }

      String response = await _textService.generateText(
        question,
        context: context.isNotEmpty ? context : null,
      );

      return response;
    } catch (e) {
      throw Exception('Failed to get response: $e');
    }
  }
}
