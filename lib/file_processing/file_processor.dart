import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:langchain/langchain.dart';
import 'package:path/path.dart' as path;
import '../vector_store/chroma_vector_store.dart';
import '../embeddings/fonnx_embeddings.dart';

/// Processes files by reading content, chunking, generating embeddings,
/// and adding them to the vector store.
class FileProcessor {
  final ChromaVectorStore _vectorStore = ChromaVectorStore();
  // Optimal chunk size for balancing context and efficiency
  static const int defaultChunkSize = 500;
  // Reasonable overlap to maintain context between chunks
  static const int defaultOverlapSize = 150;
  // Default number of documents to retrieve from similarity search
  static const int defaultSearchResults = 10;

  /// Processes text content directly (from PDFs or other sources)
  Future<void> processText(String content, String fileName, {Function(String)? onTruncation}) async {
    if (content.trim().isEmpty) {
      if (kDebugMode) {
        print("FileProcessor: Warning - empty content provided for $fileName");
      }
      return;
    }
    
    // Clean the text content before processing
    final cleanedContent = _cleanTextForProcessing(content);
    
    if (kDebugMode) {
      print("FileProcessor: Processing text content from: $fileName with ${cleanedContent.length} characters");
      print("FileProcessor: First 100 chars: ${cleanedContent.substring(0, cleanedContent.length < 100 ? cleanedContent.length : 100)}");
      if (cleanedContent.length != content.length) {
        print("FileProcessor: Content was cleaned (original length: ${content.length})");
      }
    }
    
    // Process in batches for large documents
    final List<String> chunks = _chunkText(cleanedContent, defaultChunkSize);
    if (kDebugMode) {
      print("FileProcessor: Split content into ${chunks.length} chunks");
    }

    // Check if truncation is needed and invoke callback
    if (chunks.length * defaultChunkSize > 1500) { // Assuming 1500 is a rough token limit for context
      final originalLength = cleanedContent.length;
      // This is a very rough estimate, a more accurate tokenization would be better
      final truncatedLength = (1500 / (1000 / 700)).round(); // Convert tokens back to characters roughly
      if (onTruncation != null) {
        onTruncation('Content for $fileName was truncated from ${originalLength} characters to approximately ${truncatedLength} characters to fit model context.');
      }
    }
    
    // Process chunks in smaller batches to prevent memory issues
    const int batchSize = 20;
    int processedChunks = 0;
    while (processedChunks < chunks.length) {
      final end = (processedChunks + batchSize < chunks.length) 
          ? processedChunks + batchSize 
          : chunks.length;
      final batch = chunks.sublist(processedChunks, end);
      
      if (kDebugMode) {
        print("FileProcessor: Processing batch ${processedChunks ~/ batchSize + 1} with ${batch.length} chunks");
      }
      
      final fonnxEmbeddings = FonnxEmbeddings();
      final embeddingFutures = batch.map((chunk) => fonnxEmbeddings.embedQuery(chunk)).toList();
      final embeddings = await Future.wait(embeddingFutures);
      
      List<Document> batchDocuments = [];
      for (int i = 0; i < batch.length; i++) {
        final int chunkIndex = processedChunks + i;
        final String docId = "$fileName-$chunkIndex";
        final int startPos = cleanedContent.indexOf(batch[i]);
        final int endPos = startPos + batch[i].length;
        
        batchDocuments.add(Document(
          id: docId,
          pageContent: batch[i],
          metadata: {
            'file': fileName,
            'chunkIndex': chunkIndex,
            'startPos': startPos,
            'endPos': endPos,
            'embedding': embeddings[i],
            'totalChunks': chunks.length
          },
        ));
      }
      
      // Store documents in the vector store immediately after processing each batch
      if (kDebugMode) {
        print("FileProcessor: Storing ${batchDocuments.length} documents in vector store for batch ${processedChunks ~/ batchSize + 1}");
      }
      await _vectorStore.addDocuments(batchDocuments);

      processedChunks = end;
      
      // Report progress
      final progress = processedChunks / chunks.length;
      if (kDebugMode) {
        print("FileProcessor: Progress - ${(progress * 100).toStringAsFixed(1)}% complete");
      }
    }
    
    if (kDebugMode) {
      print("FileProcessor: Successfully indexed all chunks for $fileName");
    }
  }

  /// Processes a file at [filePath], splitting it into chunks, and indexing each chunk.
  Future<void> processFile(String filePath) async {
    if (kDebugMode) {
      print("FileProcessor: Starting to process file: $filePath");
    }
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception("File does not exist: $filePath");
    }

    // Check file size
    final fileSize = await file.length();
    if (fileSize > 2 * 1024 * 1024) { // 2MB limit
      throw Exception("File size exceeds the 2MB limit: $filePath");
    }
    
    final content = await file.readAsString();
    if (kDebugMode) {
      print("FileProcessor: Read file content of length: ${content.length}");
    }
    
    await processText(content, path.basename(filePath));
  }

  /// Improved text chunking that respects semantic boundaries and adds overlaps
  List<String> _chunkText(String text, int maxChunkSize) {
    List<String> chunks = [];
    
    // Split by paragraphs
    List<String> paragraphs = text.split(RegExp(r'\n\s*\n'));
    
    String currentChunk = '';
    String previousChunk = '';
    const int overlapSize = defaultOverlapSize;
    
    for (String paragraph in paragraphs) {
      paragraph = paragraph.trim();
      if (paragraph.isEmpty) continue;
      
      // If adding this paragraph exceeds the chunk size and we already have content
      if ((currentChunk.length + paragraph.length > maxChunkSize) && currentChunk.isNotEmpty) {
        chunks.add(currentChunk);
        previousChunk = currentChunk;
        currentChunk = '';
        
        // Add overlap from previous chunk if available
        if (previousChunk.isNotEmpty) {
          final String overlapText = _getOverlapText(previousChunk, overlapSize);
          if (overlapText.isNotEmpty) {
            currentChunk = "$overlapText\n";
          }
        }
      }
      
      // If the paragraph itself is longer than max size, split it by sentences
      if (paragraph.length > maxChunkSize) {
        List<String> sentences = paragraph.split(RegExp(r'(?<=[.!?])\s+'));
        
        for (String sentence in sentences) {
          if (currentChunk.length + sentence.length <= maxChunkSize) {
            currentChunk += (currentChunk.isEmpty ? '' : ' ') + sentence;
          } else {
            if (currentChunk.isNotEmpty) {
              chunks.add(currentChunk);
            }
            
            // Handle extremely long sentences
            if (sentence.length > maxChunkSize) {
              int start = 0;
              while (start < sentence.length) {
                int end = start + maxChunkSize;
                if (end > sentence.length) end = sentence.length;
                chunks.add(sentence.substring(start, end));
                start = end;
              }
            } else {
              currentChunk = sentence;
            }
          }
        }
      } else {
        currentChunk += (currentChunk.isEmpty ? '' : '\n\n') + paragraph;
      }
    }
    
    if (currentChunk.isNotEmpty) {
      chunks.add(currentChunk);
    }
    
    return chunks;
  }

  /// Gets the last portion of text to use as overlap
  String _getOverlapText(String text, int overlapSize) {
    if (text.length <= overlapSize) return text;
    
    // Try to find a sentence boundary for cleaner overlap
    final int startPos = text.length - overlapSize;
    final match = RegExp(r'[.!?]\s+').firstMatch(text.substring(startPos));
    
    if (match != null) {
      // Found a sentence boundary, start from there
      return text.substring(startPos + match.end);
    } else {
      // No sentence boundary, just take the last overlapSize characters
      return text.substring(text.length - overlapSize);
    }
  }

  /// Query a file for content matching the given query.
  /// Returns a list of documents that match the query.
  Future<List<Document>> queryFile(String query, {
    List<String>? selectedFiles,
    int limit = defaultSearchResults,
  }) async {
    if (query.trim().isEmpty) {
      return [];
    }

    if (kDebugMode) {
      print('FileProcessor: Querying with: "$query"');
      if (selectedFiles != null && selectedFiles.isNotEmpty) {
        print('FileProcessor: Selected files: $selectedFiles');
      }
      print('FileProcessor: Result limit: $limit');
    }
    
    try {
      // First try to get vector store stats
      final stats = await getVectorStoreStats();
      if (kDebugMode) {
        print('FileProcessor: Vector store stats: $stats');
      }
      
      // Create filter from selected files
      Map<String, dynamic>? filter;
      if (selectedFiles != null && selectedFiles.isNotEmpty) {
        filter = {'file': selectedFiles};
      }
      
      // Try vector similarity search first
      List<Document> results = [];
      
      try {
        results = await _vectorStore.similaritySearch(
          query,
          k: limit,
          filter: filter,
        );
        
        if (kDebugMode) {
          print('FileProcessor: Vector search returned ${results.length} results');
        }
      } catch (e) {
        if (kDebugMode) {
          print('FileProcessor: Error in vector search: $e');
        }
      }
      
      // If no results or error, try fallback
      if (results.isEmpty) {
        if (kDebugMode) {
          print('FileProcessor: No vector results, trying fallback search');
        }
        
        results = await _fallbackTextSearch(
          query,
          k: limit,
          filter: filter,
        );
      }
      
      return results;
    } catch (e) {
      if (kDebugMode) {
        print('FileProcessor: Error querying file: $e');
      }
      rethrow;
    }
  }
  
  /// Perform a fallback text-based search when vector search fails
  Future<List<Document>> _fallbackTextSearch(String query, {
    int k = 4,
    Map<String, dynamic>? filter,
  }) async {
    if (query.trim().isEmpty) {
      if (kDebugMode) {
        print("FileProcessor: Empty query in fallback search");
      }
      return [];
    }
    
    if (kDebugMode) {
      print("FileProcessor: Performing fallback text search for: '$query'");
    }
    
    try {
      // Get all documents
      final allDocs = await _vectorStore.getAllDocuments();
      
      if (kDebugMode) {
        print("FileProcessor: Searching through ${allDocs.length} documents");
      }
      
      // Filter by selected files if needed
      List<Document> candidates = allDocs;
      if (filter != null && filter.isNotEmpty) {
        candidates = _filterDocuments(candidates, filter);
        
        if (kDebugMode) {
          print("FileProcessor: After filtering, candidate count: ${candidates.length}");
        }
      }
      
      // Extract relevant keywords from text for search
      final keywords = _extractKeywords(query);
      
      if (kDebugMode) {
        print("FileProcessor: Using keywords: $keywords");
      }
      
      // Normalize the query for better matching
      final normalizedQuery = _normalizeText(query);
      
      // Score documents based on term frequency and content similarity
      final scoredDocs = candidates.map((doc) {
        // Normalize document text (this helps with case-insensitive matching and punctuation)
        final normalizedContent = _normalizeText(doc.pageContent);
        int score = 0;
        
        // Exact query match is highest score
        if (normalizedContent.contains(normalizedQuery)) {
          score += 10 * normalizedQuery.length; // Weighted by query length
        }
        
        // Keyword-based scoring
        for (final term in keywords) {
          if (normalizedContent.contains(term)) {
            // Count occurrences
            final matches = RegExp(term, caseSensitive: false).allMatches(normalizedContent).length;
            // Score based on keyword frequency and length
            score += matches * term.length;
          }
        }
        
        return {
          'document': doc,
          'score': score,
        };
      }).where((item) => (item['score'] as int) > 0).toList();
      
      // Sort by score (descending)
      scoredDocs.sort((a, b) => (b['score'] as int).compareTo(a['score'] as int));
      
      // Return top k results
      final results = scoredDocs.take(k).map((item) => item['document'] as Document).toList();
      
      if (kDebugMode) {
        print("FileProcessor: Fallback search found ${results.length} results");
        if (results.isNotEmpty) {
          print("FileProcessor: Top result score: ${scoredDocs.first['score']}");
        }
      }
      
      return results;
    } catch (e) {
      if (kDebugMode) {
        print("FileProcessor: Error in fallback search: $e");
      }
      return [];
    }
  }
  
  /// Normalize text for improved search matching
  String _normalizeText(String text) {
    if (text.isEmpty) return text;
    
    // Convert to lowercase
    String normalized = text.toLowerCase();
    
    // Replace all whitespace with single space
    normalized = normalized.replaceAll(RegExp(r'\s+'), ' ');
    
    // Remove common punctuation that might interfere with matching
    normalized = normalized.replaceAll(RegExp(r'[.,;:!?()[\]{}]'), ' ');
    
    // Collapse multiple spaces again
    normalized = normalized.replaceAll(RegExp(r'\s+'), ' ');
    
    // Trim 
    normalized = normalized.trim();
    
    return normalized;
  }
  
  /// Extract relevant keywords from text for search
  List<String> _extractKeywords(String text, {int minLength = 4, int maxKeywords = 10}) {
    if (text.isEmpty) return [];
    
    // Convert to lowercase and remove punctuation
    final cleanText = text.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), ' ');
    
    // Split into words
    final words = cleanText.split(RegExp(r'\s+'))
      .where((word) => word.length >= minLength)  // Only consider words of minimum length
      .where((word) => !_stopWords.contains(word)) // Filter out stop words
      .toList();
    
    // Count word frequency
    final wordFreq = <String, int>{};
    for (final word in words) {
      wordFreq[word] = (wordFreq[word] ?? 0) + 1;
    }
    
    // Sort by frequency
    final sortedWords = wordFreq.keys.toList()
      ..sort((a, b) => wordFreq[b]!.compareTo(wordFreq[a]!));
    
    // Return top keywords
    return sortedWords.take(maxKeywords).toList();
  }
  
  // Common English stop words to exclude from keyword extraction
  final _stopWords = <String>{
    'the', 'and', 'that', 'have', 'for', 'not', 'with', 'you',
    'this', 'but', 'his', 'from', 'they', 'say', 'her', 'she',
    'will', 'one', 'all', 'would', 'there', 'their', 'what',
    'out', 'about', 'who', 'get', 'which', 'when', 'make',
    'can', 'like', 'time', 'just', 'him', 'know', 'take',
    'person', 'into', 'year', 'your', 'good', 'some', 'could',
    'them', 'see', 'other', 'than', 'then', 'now', 'look',
    'only', 'come', 'its', 'over', 'think', 'also', 'back',
    'after', 'use', 'two', 'how', 'our', 'work', 'first',
    'well', 'way', 'even', 'new', 'want', 'because', 'any',
    'these', 'give', 'day', 'most', 'should'
  };

  /// Filter documents based on metadata criteria
  List<Document> _filterDocuments(List<Document> docs, Map<String, dynamic> filter) {
    return docs.where((doc) {
      // Check if all filter conditions match
      for (final entry in filter.entries) {
        final key = entry.key;
        final value = entry.value;
        
        // Skip null values in the filter
        if (value == null) continue;
        
        // Check if the document has the metadata field
        if (!doc.metadata.containsKey(key)) {
          return false;
        }
        
        final docValue = doc.metadata[key];
        
        // Handle list of values (OR condition)
        if (value is List) {
          if (value.isEmpty) continue; // Skip empty lists
          
          // Check if any value in the list matches
          if (!value.contains(docValue)) {
            return false;
          }
        } 
        // Handle single value
        else if (docValue != value) {
          return false;
        }
      }
      
      return true;
    }).toList();
  }
  
  /// Retrieve diagnostic information about the vector store
  Future<Map<String, dynamic>> getVectorStoreStats() async {
    try {
      final collectionInfo = await _vectorStore.getCollectionInfo();
      final docCount = await _vectorStore.getDocumentCount();
      
      if (kDebugMode) {
        print("FileProcessor: Getting vector store stats - Document count: $docCount");
      }
      
      return {
        'documentCount': docCount,
        'collections': collectionInfo['collections'] ?? [],
        'lastUpdated': collectionInfo['lastUpdated'] ?? 'unknown',
        'status': 'ok',
      };
    } catch (e) {
      if (kDebugMode) {
        print("FileProcessor: Error getting vector store stats: $e");
      }
      return {
        'status': 'error',
        'error': e.toString(),
      };
    }
  }
  
  /// Test the vector store with a simple document and search
  Future<Map<String, dynamic>> runDiagnosticTest(String testQuery) async {
    if (kDebugMode) {
      print("FileProcessor: Running comprehensive diagnostic test");
      print("FileProcessor: Test query: '$testQuery'");
    }
    
    try {
      // 1. Check if vector store has documents
      final currentStats = await getVectorStoreStats();
      final initialDocCount = currentStats['documentCount'] as int;
      
      if (kDebugMode) {
        print("FileProcessor: Current document count: $initialDocCount");
      }
      
      // 2. Add a test document with unique content
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final uniqueMarker = "diagnostic_test_$timestamp";
      final testContent = """
This is a diagnostic test document for the vector store.
It contains unique marker $uniqueMarker to ensure we can find it.
It's used to test the vector similarity search functionality.
The document should be retrievable using related queries about diagnostic tests.
      """.trim();
      
      if (kDebugMode) {
        print("FileProcessor: Adding test document with unique marker: $uniqueMarker");
      }
      
      // 3. Create test document
      await processText(testContent, "diagnostic_test.txt");
      
      // 4. Verify document was added
      final updatedStats = await getVectorStoreStats();
      final newDocCount = updatedStats['documentCount'] as int;
      final docsAdded = newDocCount > initialDocCount;
      
      if (kDebugMode) {
        print("FileProcessor: After adding test document, count: $newDocCount (${docsAdded ? 'increased' : 'unchanged'})");
      }
      
      // 5. Test vector similarity search
      if (kDebugMode) {
        print("FileProcessor: Testing vector search with query: '$testQuery'");
      }
      
      final vectorResults = await _vectorStore.similaritySearch(
        testQuery,
        k: 5,
      );
      
      final vectorSearchSuccess = vectorResults.isNotEmpty;
      
      if (kDebugMode) {
        print("FileProcessor: Vector search returned ${vectorResults.length} results");
        if (vectorResults.isNotEmpty) {
          print("FileProcessor: First result: ${vectorResults[0].pageContent.substring(0, 50)}...");
        }
      }
      
      // 6. Test direct marker search
      if (kDebugMode) {
        print("FileProcessor: Testing direct marker search with: '$uniqueMarker'");
      }
      
      final markerResults = await _vectorStore.similaritySearch(
        uniqueMarker,
        k: 1,
      );
      
      final markerSearchSuccess = markerResults.isNotEmpty && 
                                 markerResults[0].pageContent.contains(uniqueMarker);
      
      if (kDebugMode) {
        print("FileProcessor: Marker search ${markerSearchSuccess ? 'succeeded' : 'failed'}");
        if (markerResults.isNotEmpty) {
          print("FileProcessor: Found document containing marker: ${markerResults[0].pageContent.contains(uniqueMarker)}");
        }
      }
      
      // 7. Test fallback text search
      if (kDebugMode) {
        print("FileProcessor: Testing fallback text search");
      }
      
      final fallbackResults = await _fallbackTextSearch(uniqueMarker);
      final fallbackSuccess = fallbackResults.isNotEmpty && 
                            fallbackResults[0].pageContent.contains(uniqueMarker);
      
      if (kDebugMode) {
        print("FileProcessor: Fallback search ${fallbackSuccess ? 'succeeded' : 'failed'}");
      }
      
      return {
        'success': vectorSearchSuccess || markerSearchSuccess || fallbackSuccess,
        'documentAdded': docsAdded,
        'vectorSearchSuccess': vectorSearchSuccess,
        'markerSearchSuccess': markerSearchSuccess,
        'fallbackSearchSuccess': fallbackSuccess,
        'vectorResultsCount': vectorResults.length,
        'markerResultsCount': markerResults.length,
        'fallbackResultsCount': fallbackResults.length,
        'docCountBefore': initialDocCount,
        'docCountAfter': newDocCount,
        'uniqueMarker': uniqueMarker,
        'testSummary': vectorSearchSuccess 
            ? "Vector search working properly" 
            : (markerSearchSuccess 
                ? "Vector search works with exact terms" 
                : (fallbackSuccess 
                    ? "Vector search failed but fallback search works" 
                    : "All search methods failed")),
      };
    } catch (e) {
      if (kDebugMode) {
        print("FileProcessor: Error in diagnostic test: $e");
      }
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Clean text content before processing
  String _cleanTextForProcessing(String content) {
    if (content.isEmpty) return content;
    
    // Remove extra whitespace
    String cleanedContent = content.trim();
    
    // Replace multiple consecutive newlines with a single newline
    cleanedContent = cleanedContent.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    
    // Replace tabs with spaces
    cleanedContent = cleanedContent.replaceAll('\t', ' ');
    
    // Replace multiple spaces with a single space
    cleanedContent = cleanedContent.replaceAll(RegExp(r' {2,}'), ' ');
    
    // Remove weird Unicode control characters
    cleanedContent = cleanedContent.replaceAll(RegExp(r'[\x00-\x09\x0B\x0C\x0E-\x1F\x7F]'), '');
    
    // ADDITION: Remove special character sequences that cause issues in API requests
    // This removes the problematic $1 and $2 sequences that appear in PDFs
    cleanedContent = cleanedContent.replaceAll(RegExp(r'\$\d+'), '');
    
    // ADDITION: Remove other common problematic characters from PDFs
    cleanedContent = cleanedContent.replaceAll(RegExp(r'[\u2028\u2029]'), '\n'); // Line/paragraph separators
    cleanedContent = cleanedContent.replaceAll(RegExp(r'[^\x20-\x7E\n\r]'), ''); // Keep only ASCII printable and newlines
    
    return cleanedContent;
  }

  /// Addition: Clean text specifically for API submission
  /// This should be called on text before sending to external APIs
  static String cleanTextForApiSubmission(String text) {
    if (text.isEmpty) return text;
    
    if (kDebugMode) {
      print("FileProcessor: Cleaning text for API submission (length: ${text.length})");
      
      // Check for problematic patterns
      final dollarDigitCount = RegExp(r'\$\d+').allMatches(text).length;
      final nonAsciiCount = RegExp(r'[^\x20-\x7E\n\r]').allMatches(text).length;
      
      if (dollarDigitCount > 0 || nonAsciiCount > 0) {
        print("FileProcessor: Found potential issues: $dollarDigitCount \$digit sequences, $nonAsciiCount non-ASCII characters");
      }
    }
    
    // Remove problematic sequences
    String cleaned = text.replaceAll(RegExp(r'\$\d+'), '');
    
    // Replace extended Unicode with standard ASCII where possible
    cleaned = cleaned.replaceAll(RegExp(r'[\u2018\u2019]'), "'"); // Smart quotes
    cleaned = cleaned.replaceAll(RegExp(r'[\u201C\u201D]'), '"'); // Smart double quotes
    cleaned = cleaned.replaceAll(RegExp(r'[\u2013\u2014]'), '-'); // En/em dashes
    
    // Strip non-printable ASCII and control characters
    cleaned = cleaned.replaceAll(RegExp(r'[^\x20-\x7E\n\r]'), '');
    
    // Normalize whitespace
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
    
    if (kDebugMode && text.length != cleaned.length) {
      if (kDebugMode) {
        print("FileProcessor: Text length changed: ${text.length} → ${cleaned.length} (${text.length - cleaned.length} chars removed)");
      }
    }
    
    return cleaned;
  }
} 