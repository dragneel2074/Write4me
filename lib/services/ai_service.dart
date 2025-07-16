import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import '../file_processing/file_processor.dart';

import '../models/pdf_memory.dart';
import '../models/image_memory.dart';
import '../models/chat_message.dart';
import 'text_generation_service.dart';
import '../utils/text_utils.dart';
import 'offline_model_service.dart';
import 'online_model_service.dart'; // New import

class AIService extends ChangeNotifier {
  final TextGenerationService _textGenService;
  final OfflineModelService _offlineService;
  final FileProcessor _fileProcessor;
  final OnlineModelService _onlineModelService; // New field
  bool _isGenerating = false;

  AIService(this._textGenService, this._offlineService, this._fileProcessor, this._onlineModelService) {
    // Listen to offline service changes
    _offlineService.addListener(_onOfflineServiceChanged);
    _onlineModelService.addListener(_onOnlineServiceChanged); // New listener
  }

  @override
  void dispose() {
    _offlineService.removeListener(_onOfflineServiceChanged);
    _onlineModelService.removeListener(_onOnlineServiceChanged); // New listener
    super.dispose();
  }

  void _onOfflineServiceChanged() {
    // Notify listeners when offline service changes
    notifyListeners();
  }

  void _onOnlineServiceChanged() {
    // Notify listeners when online service changes
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

  /// Filters out service check messages from chat history
  List<ChatMessage> _filterServiceCheckMessages(List<ChatMessage> history) {
    // Skip the first system messages that are service checks
    if (history.isEmpty) return history;
    
    // Define patterns that identify service check messages
    final serviceCheckPatterns = [
      'Checking if services are online',
      'Service is Online',
      'Service is Offline',
      'Chat Service is Online',
      'Image Service is Online',
      'Chat Service is currently Offline',
      'Image Service is Offline',
      'Checking service status',
      'Services are',
      'Hey!',
      'Ask Me Anything'
    ];
    
    final filtered = history.where((message) {
      // Keep all user messages
      if (message.isUser) return true;
      
      // Filter out system messages that match service check patterns
      for (final pattern in serviceCheckPatterns) {
        if (message.content.contains(pattern)) {
          return false;
        }
      }
      
      return true;
    }).toList();
    
    // Debug print to show filtering effect
    if (kDebugMode) {
      print("Filtered chat history: ${history.length} → ${filtered.length} messages");
    }
    
    return filtered;
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
    
    // Limit context size for faster inference
    final limitedContext = _limitContextSize(context);
    debugPrint('- limited context length: ${limitedContext.length}');
    
    

    // Start timing the generation
    final stopwatch = Stopwatch()..start();
    
    await _offlineService.generateStreamingResponse(
          prompt,
          onResponse,
          history: history,
          context: limitedContext, // Pass the limited context
        );
    
    // Print performance statistics
    stopwatch.stop();
    final elapsedSeconds = stopwatch.elapsedMilliseconds / 1000;
    debugPrint('Response generation took ${elapsedSeconds.toStringAsFixed(2)} seconds');
  }
  
  
  
  /// Limits context size to optimize inference speed
  List<String> _limitContextSize(List<String> context, {int maxTokens = 1024}) {
    if (context.isEmpty) return context;
    
    // Simple heuristic: ~4 chars per token
    int totalChars = 0;
    final reducedContext = <String>[];
    
    // Take most relevant chunks first (assumed to be ordered by relevance)
    for (final chunk in context) {
      totalChars += chunk.length;
      if (totalChars > maxTokens * 4) break;
      reducedContext.add(chunk);
    }
    
    if (kDebugMode) {
      print("Reduced context from ${context.length} to ${reducedContext.length} chunks");
      print("Approximate tokens: ~${(totalChars / 4).round()} (limit: $maxTokens)");
    }
    
    return reducedContext;
  }

  Future<void> getStreamingResponse(
    String prompt,
    List<PDFMemory> pdfMemories,
    List<ImageMemory> imageMemories,
    void Function(String, bool) onResponse, {
    bool useWebSearch = false,
    List<ChatMessage> history = const [],
    required bool useLocalModel,
    Map<String, dynamic>? visionMessage,
  }) async {
    debugPrint('\ngetStreamingResponse called with:');
    debugPrint('- prompt: $prompt');
    debugPrint('- useWebSearch: $useWebSearch');
    debugPrint('- useLocalModel: $useLocalModel');
    debugPrint('- isOfflineMode: ${_offlineService.isOfflineMode}');
    debugPrint('- history length: ${history.length}');

    if (_isGenerating) {
      debugPrint('Already generating, returning early');
      return;
    }

    _isGenerating = true;
    notifyListeners();

    try {
      // If in offline mode, force local model and disable web search
      final bool isOfflineMode = _offlineService.isOfflineMode;
      
      // When in offline mode, we must use local model and cannot use web search
      if (isOfflineMode) {
        if (!_offlineService.isLocalModelActive) {
          debugPrint('In offline mode but local model not active - forcing local model');
          await _offlineService.setIsLocalModelActive(true);
        }
        // Override web search setting when in offline mode
        if (useWebSearch) {
          debugPrint('Web search requested but in offline mode - disabling web search');
          useWebSearch = false;
        }
      }
      
      // Filter out service check messages from history
      final filteredHistory = _filterServiceCheckMessages(history);
      debugPrint('- filtered history length: ${filteredHistory.length}');
      
      // Build context from selected memories using vector similarity search
      List<String> context = [];
      if (pdfMemories.isNotEmpty) {
        // Get list of selected file names
        List<String> selectedFiles = pdfMemories
            .where((memory) => memory.isSelected)
            .map((memory) => memory.name)
            .toList();
        
        if (selectedFiles.isNotEmpty) {
          // Use the injected FileProcessor to perform vector similarity search
          try {
            // This performs semantic search to find relevant chunks
            debugPrint('Performing vector similarity search with ${selectedFiles.length} selected files');
            
            // Retrieve more results for better coverage
            final relevantDocs = await _fileProcessor.queryFile(
              prompt,
              selectedFiles: selectedFiles,
              limit: 10, // Increased for better RAG context
            );
            
            debugPrint('Retrieved \${relevantDocs.length} relevant chunks via vector search');
            debugPrint('Passing \${relevantDocs.length} chunks to the model.');
            
            // DEBUG: Print document chunks content for debugging
            if (kDebugMode) {
              print('\n==================== VECTOR SEARCH RESULTS ====================');
              print('Query: "$prompt"');
              print('Number of chunks found: ${relevantDocs.length}');
              
              for (int i = 0; i < relevantDocs.length; i++) {
                final doc = relevantDocs[i];
                final source = doc.metadata['file'] as String? ?? 'Unknown';
                final score = doc.metadata['score'] != null ? 
                    (doc.metadata['score'] as double).toStringAsFixed(4) : 'N/A';
                
                print('\n--- CHUNK ${i+1}/${relevantDocs.length} (Source: $source, Score: $score) ---');
                print('First 200 chars: ${doc.pageContent.length > 200 ? "${doc.pageContent.substring(0, 200)}..." : doc.pageContent}');
                
                // Log full content length to verify complete chunks are being used
                print('Full content length: ${doc.pageContent.length} characters');
                
                // Check for problematic sequences
                final problematicSeqCount = '\$1'.allMatches(doc.pageContent).length;
                if (problematicSeqCount > 0) {
                  print('WARNING: Contains $problematicSeqCount "\$1" sequences that may cause API issues');
                }
              }
              print('================================================================\n');
            }
            
            // Check if we have enough context from across the document
            final Map<String, int> fileChunkCounts = {};
            for (var doc in relevantDocs) {
              final file = doc.metadata['file'] as String;
              fileChunkCounts[file] = (fileChunkCounts[file] ?? 0) + 1;
            }
            
            debugPrint('File distribution in results: $fileChunkCounts');
            
            // Format the retrieved chunks with source information
            for (var doc in relevantDocs) {
              final source = doc.metadata['file'] ?? 'Unknown';
              final chunkIndex = doc.metadata['chunkIndex'] ?? '';
              final totalChunks = doc.metadata['totalChunks'] ?? '';
              context.add("From: $source (chunk $chunkIndex of $totalChunks)\n${doc.pageContent}");
            }
            
            // Clean the context text before sending to API
            for (int i = 0; i < context.length; i++) {
              if (kDebugMode) {
                print('\n----------- CLEANING CONTEXT CHUNK ${i+1}/${context.length} -----------');
                print('Before cleaning (first 100 chars): ${context[i].length > 100 ? "${context[i].substring(0, 100)}..." : context[i]}');
                
                // Look for problematic patterns before cleaning
                final dollarDigitCount = RegExp(r'\$\d+').allMatches(context[i]).length;
                final nonAsciiCount = RegExp(r'[^\x20-\x7E\n\r]').allMatches(context[i]).length;
                
                if (dollarDigitCount > 0 || nonAsciiCount > 0) {
                  print('Found: $dollarDigitCount \$digit sequences, $nonAsciiCount non-ASCII characters');
                }
              }
              
              final originalLength = context[i].length;
              context[i] = FileProcessor.cleanTextForApiSubmission(context[i]);
              
              if (kDebugMode) {
                final newLength = context[i].length;
                final lengthDiff = originalLength - newLength;
                print('After cleaning (first 100 chars): ${context[i].length > 100 ? "${context[i].substring(0, 100)}..." : context[i]}');
                print('Length change: $originalLength → $newLength (${lengthDiff > 0 ? "-$lengthDiff" : "+${-lengthDiff}"} chars)');
                print('----------------------------------------------------------\n');
              }
            }
            
            // Diagnostic output about vector store
            final stats = await _fileProcessor.getVectorStoreStats();
            debugPrint('Vector store stats: $stats');
          } catch (e) {
            debugPrint('Error in vector similarity search: $e');
            // Fallback to the old method if vector search fails
            for (var memory in pdfMemories) {
              if (memory.isSelected) {
                final trimmedText = TextUtils.trimToWordLimit(memory.extractedText);
                context.add("From: ${memory.name}\n$trimmedText");
                debugPrint('Using fallback method for ${memory.name}');
              }
            }
          }
        }
      }

      // Add image context directly      
      if (imageMemories.isNotEmpty) {       
         for (var memory in imageMemories) {         
           if (memory.isSelected) {            
            context.add("From: ${memory.name}\n${memory.extractedText}");
         }      
           }    
             }
      
      // Step 1: Perform web search if enabled and not in offline mode
      String? searchResults;
      if (useWebSearch && !isOfflineMode) {
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
        debugPrint('Web search not requested or offline mode enabled');
      }

      // Step 2: Generate response based on model selection
      if (isOfflineMode || useLocalModel) {
        // If in offline mode OR local model is explicitly selected, use local model
        debugPrint('Using local model for generation (Offline Mode: $isOfflineMode, Local Model Selected: $useLocalModel)');
        debugPrint('Search results available: ${searchResults != null}');
        await _generateLocalResponse(
          prompt,
          searchResults,
          context,
          onResponse,
          // Use filtered history when web search is not enabled
          useWebSearch ? [] : filteredHistory,
        );
      } else if (_onlineModelService.selectedOnlineModel != null) {
        // If not in offline mode and a specific online model is selected
        debugPrint('Using selected online model for generation: ${_onlineModelService.selectedOnlineModel!.name}');
        await _textGenService.generateStreamingResponse(
          prompt,
          context, // Pass the context
          onResponse,
          useWebSearch: useWebSearch,
          history: useWebSearch ? [] : filteredHistory,
          model: _onlineModelService.selectedOnlineModel!.name, // Pass the selected online model name
          visionMessage: visionMessage,
        );
      } else {
        // If not in offline mode and no specific online model is selected, use default online service
        debugPrint('Using default online service for generation');
        await _textGenService.generateStreamingResponse(
          prompt,
          context, // Pass the context
          onResponse,
          useWebSearch: useWebSearch,
          // Use filtered history when web search is not enabled
          history: useWebSearch ? [] : filteredHistory,
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
    List<PDFMemory> selectedMemories,
    List<ImageMemory> imageMemories,
    {
    bool useWebSearch = false,
    List<ChatMessage> history = const [],
    required bool useLocalModel,
  }) async {
    final completer = Completer<String>();

    await getStreamingResponse(
      question,
      selectedMemories,
      imageMemories,
      (response, done) {
        if (done) completer.complete(response);
      },
      useWebSearch: useWebSearch,
      history: history,
      useLocalModel: useLocalModel,
    );

    return completer.future;
  }
}