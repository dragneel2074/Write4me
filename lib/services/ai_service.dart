import 'dart:io';

import '../models/pdf_memory.dart';
import '../models/chat_message.dart';
import 'text_generation_service.dart';
import '../utils/text_utils.dart';
import 'offline_model_service.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import '../file_processing/file_processor.dart';

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
    
    final fullPrompt = StringBuffer();
    
    fullPrompt.writeln('You are a helpful assistant answering questions based on specific information.');
    
    if (searchResults != null) {
      fullPrompt.writeln('\nWEB SEARCH RESULTS:');
      fullPrompt.writeln(searchResults);
    }
    
    if (context.isNotEmpty) {
      fullPrompt.writeln('\nDOCUMENT CONTEXT:');
      for (int i = 0; i < context.length; i++) {
        fullPrompt.writeln('---');
        fullPrompt.writeln(context[i]);
      }
      fullPrompt.writeln('---');
    }
    
    fullPrompt.writeln('\nQUESTION: $prompt');
    fullPrompt.writeln('\nINSTRUCTIONS:');
    fullPrompt.writeln('1. Answer based ONLY on the provided context above');
    fullPrompt.writeln('2. If the answer is not in the context, say "I don\'t have enough information"');
    fullPrompt.writeln('3. Include references to the source documents in your answer');
    fullPrompt.writeln('\nANSWER:');

    debugPrint('Generated full prompt for local model:');
    debugPrint('----------------------------------------');
    debugPrint(fullPrompt.toString());
    debugPrint('----------------------------------------');

    await _offlineService.generateStreamingResponse(
      fullPrompt.toString(),
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
      // Build context from selected memories using vector similarity search
      List<String> context = [];
      if (pdfMemories.isNotEmpty) {
        // Get list of selected file names
        List<String> selectedFiles = pdfMemories
            .where((memory) => memory.isSelected)
            .map((memory) => memory.name)
            .toList();
        
        if (selectedFiles.isNotEmpty) {
          // Use the FileProcessor to perform vector similarity search
          final fileProcessor = FileProcessor();
          try {
            // This performs semantic search to find relevant chunks
            final relevantDocs = await fileProcessor.queryFile(
              prompt,
              selectedFiles: selectedFiles,
            );
            
            debugPrint('Retrieved ${relevantDocs.length} relevant chunks via vector search');
            
            // Format the retrieved chunks with source information
            for (var doc in relevantDocs) {
              final source = doc.metadata!['file'] ?? 'Unknown';
              final chunkIndex = doc.metadata!['chunkIndex'] ?? '';
              context.add("From: $source (chunk $chunkIndex)\n${doc.pageContent}");
            }
          } catch (e) {
            debugPrint('Error in vector similarity search: $e');
            // Fallback to the old method if vector search fails
            for (var memory in pdfMemories) {
              if (memory.isSelected) {
                final trimmedText = TextUtils.trimToWordLimit(memory.extractedText);
                context.add("From: ${memory.name}\n$trimmedText");
              }
            }
          }
        }
      }
      
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
      onResponse(_getUserFriendlyError(e), true);
    } finally {
      debugPrint('Generation completed, cleaning up');
      _isGenerating = false;
      notifyListeners();
    }
  }

  String _getUserFriendlyError(dynamic error) {
    if (error is SocketException) {
      return 'No internet connection. Please check your network and try again.';
    } else if (error is TimeoutException) {
      return 'Request took too long. Please try again.';
    } else if (error is HttpException) {
      return 'Temporary service issue. Please try again in a moment.';
    } else if (error.toString().contains('API key')) {
      return 'API key missing. Please add your API key in settings.';
    } else if (error.toString().contains('local model')) {
      return 'Local model error. Please check the model file.';
    }
    return 'Oops! Something went wrong. Please try again.';
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