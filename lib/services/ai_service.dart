import 'package:flutter/foundation.dart';
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

  Future<String> getResponse(
    String prompt,
    List<PDFMemory> selectedMemories, {
    bool useInternet = false,
    List<ChatMessage>? history,
  }) async {
    final completer = Completer<String>();

    await getStreamingResponse(
      prompt,
      selectedMemories,
      (response, done) {
        if (done) completer.complete(response);
      },
      useInternet: useInternet,
      history: history,
    );

    return completer.future;
  }

  Future<void> getStreamingResponse(
    String prompt,
    List<PDFMemory> selectedMemories,
    void Function(String, bool) onResponse, {
    bool useInternet = false,
    List<ChatMessage>? history,
  }) async {
    _isCancelled = false;
    
    // Show initial placeholder
    onResponse('Generating Response...', false);
    
    // Build context from selected memories
    final selectedDocs = selectedMemories.where((m) => m.isSelected).toList();
    String context = '';
    
    if (selectedDocs.isNotEmpty) {
      context = selectedDocs.map((doc) => doc.extractedText).join('\n\n');
    }

    if (_offlineService.isOfflineMode || 
        (!useInternet && _offlineService.useLocalModel)) {
      final contextPrompt = context.isNotEmpty 
          ? '''
Context:
$context

Based on the above context, ${prompt.trim()}'''
          : prompt;

      await _textGenService.generateStreamingResponse(
        contextPrompt,
        (response, done) {
          if (_isCancelled) {
            onResponse('Generation cancelled', true);
            return;
          }
          onResponse(response, done);
        },
      );
    } else {
      // Handle cloud generation
      try {
        final response = await _textGenService.generateCloudResponse(
          prompt,
          context: context,
          history: history,
        );
        onResponse(response, true);
      } catch (e) {
        debugPrint('Error in cloud generation: $e');
        onResponse('Error: $e', true);
      }
    }
  }
}
