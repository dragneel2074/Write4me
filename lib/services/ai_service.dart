import '../models/pdf_memory.dart';
import '../models/chat_message.dart';
import 'text_generation_service.dart';
import '../utils/text_utils.dart';
import 'offline_model_service.dart';
import 'dart:async';

class AIService {
  final TextGenerationService _textGenService;
  final OfflineModelService _offlineService;
  bool _isCancelled = false;

  AIService(this._textGenService, this._offlineService);

  void stopGeneration() {
    _isCancelled = true;
  }

  Future<void> getStreamingResponse(
    String question,
    List<PDFMemory> selectedMemories,
    void Function(String, bool) onResponse, {
    bool useInternet = false,
    List<ChatMessage> history = const [],
  }) async {
    _isCancelled = false;
    
    if (_offlineService.isOfflineMode || 
        (!useInternet && _offlineService.useLocalModel)) {
      await _offlineService.generateStreamingResponse(
        question,
        (response, done) {
          if (_isCancelled) {
            done = true;
          }
          onResponse(response, done);
        },
        history: history,
      );
    } else {
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

        final response = await _textGenService.generateText(
          question,
          context: context.isNotEmpty ? context : null,
          useInternet: useInternet,
          history: history,
        );

        if (_isCancelled) {
          onResponse(response, true);
          return;
        }
        onResponse(response, true);
      } catch (e) {
        throw Exception('Failed to get response: $e');
      }
    }
  }

  Future<String> getResponse(
    String question,
    List<PDFMemory> selectedMemories, {
    bool useInternet = false,
    List<ChatMessage> history = const [],
  }) async {
    final completer = Completer<String>();
    String fullResponse = '';

    await getStreamingResponse(
      question,
      selectedMemories,
      (response, done) {
        fullResponse = response;
        if (done) completer.complete(response);
      },
      useInternet: useInternet,
      history: history,
    );

    return completer.future;
  }
}
