import '../models/pdf_memory.dart';
import '../models/chat_message.dart';
import 'text_generation_service.dart';
import '../utils/text_utils.dart';

class AIService {
  final TextGenerationService _textService = TextGenerationService();

  Future<String> getResponse(
    String question,
    List<PDFMemory> selectedMemories, {
    bool useInternet = false,
    List<ChatMessage> history = const [],
  }) async {
    try {
      List<String> context = [];

      if (selectedMemories.isNotEmpty) {
        for (var memory in selectedMemories) {
          if (memory.isSelected) {
            final trimmedText = TextUtils.trimToWordLimit(memory.extractedText);
            context.add(trimmedText);
          }
        }
      }

      String response = await _textService.generateText(
        question,
        context: context.isNotEmpty ? context : null,
        useInternet: useInternet,
        history: history,
      );

      return response;
    } catch (e) {
      throw Exception('Failed to get response: $e');
    }
  }
}
