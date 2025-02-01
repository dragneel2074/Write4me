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
    
    // Show initial placeholder
    onResponse('Generating Response...', false);
    
    // Build context from selected memories
    List<String> context = [];
    if (selectedMemories.isNotEmpty) {
      for (var memory in selectedMemories) {
        if (memory.isSelected) {
          final trimmedText = TextUtils.trimToWordLimit(memory.extractedText);
          context.add(trimmedText);
        }
      }
    }

    // Prevent web URL processing in offline mode
    if (_offlineService.isOfflineMode && useInternet) {
      onResponse('Web search is not available in offline mode.', true);
      return;
    }

    if (_offlineService.isOfflineMode || 
        (!useInternet && _offlineService.useLocalModel)) {
      final contextPrompt = context.isNotEmpty 
          ? '''
Context from documents:
${context.join('\n\n')}

Based on the above context, please answer:
$question'''
          : question;

      bool firstResponse = true;
      await _offlineService.generateStreamingResponse(
        contextPrompt,
        (response, done) {
          if (_isCancelled) {
            done = true;
          }
          // Replace placeholder with first real response
          if (firstResponse && response.trim().isNotEmpty) {
            firstResponse = false;
          }
          onResponse(response, done);
        },
        history: history,
      );
    } else {
      try {
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

    await getStreamingResponse(
      question,
      selectedMemories,
      (response, done) {
        if (done) completer.complete(response);
      },
      useInternet: useInternet,
      history: history,
    );

    return completer.future;
  }
}
