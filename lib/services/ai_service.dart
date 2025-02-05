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

  Future<String?> _performWebSearch(
    String prompt,
    void Function(String, bool) onResponse,
  ) async {
    debugPrint('_performWebSearch called with prompt: $prompt');
    try {
      onResponse('Searching the web...', false);
      final results = await _textGenService.searchWithJina(prompt);
      debugPrint('Raw search results received: $results');
      
      if (results.isNotEmpty) {
        onResponse('Search results found. Generating response...', false);
        return results;
      }
      debugPrint('Search results were empty');
      return null;
    } catch (e) {
      if (e.toString().contains('API key')) {
        debugPrint('API key error detected');
        onResponse('Web search failed: Please set your Jina API key first.', true);
        _isGenerating = false;
        notifyListeners();
        return null;
      }
      debugPrint('Web search error: $e');
      onResponse('Web search failed. Generating response without search...', false);
      return null;
    }
  }

  Future<void> _generateLocalResponse(
    String prompt,
    String? searchResults,
    List<String> context,
    void Function(String, bool) onResponse,
    List<ChatMessage> history,
  ) async {
    debugPrint('_generateLocalResponse called with:');
    debugPrint('- prompt: $prompt');
    debugPrint('- searchResults: ${searchResults?.substring(0, searchResults.length.clamp(0, 100))}...');
    debugPrint('- context length: ${context.length}');
    
    final fullPrompt = '''
${searchResults != null ? 'Search Results:\n$searchResults\n\n' : ''}
${context.isNotEmpty ? 'Context from documents:\n${context.join('\n\n')}\n\n' : ''}
${searchResults != null ? 'Based on the search results' : ''}
${context.isNotEmpty ? '${searchResults != null ? ' and' : 'Based on'} the context' : ''}
${searchResults == null && context.isEmpty ? 'Please answer' : ', please answer'}:
$prompt'''.trim();

    debugPrint('Generated full prompt for local model:');
    debugPrint('----------------------------------------');
    debugPrint(fullPrompt);
    debugPrint('----------------------------------------');

    await _offlineService.generateStreamingResponse(
      fullPrompt,
      onResponse,
      history: history,
    );
  }

  Future<void> getStreamingResponse(
    String prompt,
    List<PDFMemory> pdfMemories,
    void Function(String, bool) onResponse, {
    bool useWebSearch = false,
    List<ChatMessage> history = const [],
  }) async {
    debugPrint('\ngetStreamingResponse called with:');
    debugPrint('- prompt: $prompt');
    debugPrint('- useWebSearch: $useWebSearch');
    debugPrint('- isLocalModel: ${_offlineService.useLocalModel}');

    if (_isGenerating) {
      debugPrint('Already generating, returning early');
      return;
    }

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
      debugPrint('Context built with ${context.length} memories');

      // Step 1: Perform web search if enabled
      String? searchResults;
      if (useWebSearch) {
        debugPrint('Starting web search process...');
        searchResults = await _performWebSearch(prompt, onResponse);
        debugPrint('Search completed. Results: ${searchResults != null ? 'found' : 'not found'}');
        
        if (searchResults == null) {
          debugPrint('Search results null, checking _isGenerating: $_isGenerating');
          if (!_isGenerating) {
            debugPrint('Generation was cancelled, returning early');
            return;
          }
        }
      } else {
        debugPrint('Web search not requested');
      }

      // Step 2: Generate response based on model selection
      if (_offlineService.useLocalModel) {
        debugPrint('Using local model for generation');
        debugPrint('Search results available: ${searchResults != null}');
        await _generateLocalResponse(
          prompt,
          searchResults,
          context,
          onResponse,
          // Disable history when web search is enabled
          useWebSearch ? [] : history,
        );
      } else {
        debugPrint('Using online service for generation');
        await _textGenService.generateStreamingResponse(
          prompt,
          pdfMemories,
          onResponse,
          useWebSearch: useWebSearch,
          // Disable history when web search is enabled
          history: useWebSearch ? [] : history,
        );
      }
    } catch (e) {
      debugPrint('Error in getStreamingResponse: $e');
      debugPrint(e.toString());
      onResponse('Error: ${e.toString()}', true);
    } finally {
      debugPrint('Generation completed, cleaning up');
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