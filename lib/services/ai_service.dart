import '../models/pdf_memory.dart';
import '../models/chat_message.dart';
import 'text_generation_service.dart';
import '../utils/text_utils.dart';
import 'offline_model_service.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';

class AIService extends ChangeNotifier {
  final TextGenerationService _textGenService;
  final OfflineModelService _offlineService;
  bool _isGenerating = false;

  AIService(this._textGenService, this._offlineService) {
    // Listen to offline service changes
    _offlineService.addListener(_onOfflineServiceChanged);
  }

  @override
  void dispose() {
    _offlineService.removeListener(_onOfflineServiceChanged);
    super.dispose();
  }

  void _onOfflineServiceChanged() {
    // Notify listeners when offline service changes
    notifyListeners();
  }

  bool get isGenerating => _isGenerating;

  Future<void> getStreamingResponse(
    String prompt,
    List<PDFMemory> pdfMemories,
    void Function(String, bool) onResponse, {
    bool useWebSearch = false,
    List<ChatMessage> history = const [],
  }) async {
    if (_isGenerating) return;

    _isGenerating = true;
    notifyListeners();

    try {
      // Build context from selected memories
      List<String> context = [];
      if (pdfMemories.isNotEmpty) {
        for (var memory in pdfMemories) {
          if (memory.isSelected) {
            final trimmedText = TextUtils.trimToWordLimit(memory.extractedText);
            context.add(trimmedText);
          }
        }
      }

      // Prevent web URL processing in offline mode
      if (_offlineService.isOfflineMode && useWebSearch) {
        onResponse('Web search is not available in offline mode.', true);
        return;
      }

      if (_offlineService.isOfflineMode || _offlineService.useLocalModel) {
        // Use offline model with context
        final contextPrompt = context.isNotEmpty 
            ? '''
Context from documents:
${context.join('\n\n')}

Based on the above context, please answer:
$prompt'''
            : prompt;

        await _offlineService.generateStreamingResponse(
          contextPrompt,
          onResponse,
          history: history,
        );
      } else {
        // Use online service
        await _textGenService.generateStreamingResponse(
          prompt,
          pdfMemories,
          onResponse,
          useWebSearch: useWebSearch,
          history: history,
        );
      }
    } finally {
      _isGenerating = false;
      notifyListeners();
    }
  }

  void stopGeneration() {
    _isGenerating = false;
    notifyListeners();
  }

  Future<String> getResponse(
    String question,
    List<PDFMemory> selectedMemories, {
    bool useWebSearch = false,
    List<ChatMessage> history = const [],
  }) async {
    final completer = Completer<String>();

    await getStreamingResponse(
      question,
      selectedMemories,
      (response, done) {
        if (done) completer.complete(response);
      },
      useWebSearch: useWebSearch,
      history: history,
    );

    return completer.future;
  }
}
