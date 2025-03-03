import 'package:flutter/foundation.dart';
import 'package:langchain/langchain.dart';
import '../embeddings/fonnx_embeddings.dart';
import 'dart:math' show sqrt;

/// Wrapper for in-memory vector storage
class ChromaVectorStore {
  final MemoryVectorStore _vectorStore;
  final FonnxEmbeddings _embeddings;
  final List<Document> _documents = [];
  final Map<String, dynamic> _collectionInfo = {
    'count': 0,
    'collections': ['default'],
    'lastUpdated': DateTime.now().toIso8601String(),
  };

  ChromaVectorStore() : 
    _embeddings = FonnxEmbeddings(),
    _vectorStore = MemoryVectorStore(
      embeddings: FonnxEmbeddings(),
    );

  Future<void> addDocuments(List<Document> documents) async {
    if (documents.isEmpty) {
      if (kDebugMode) {
        print("ChromaVectorStore: Warning - tried to add empty document list");
      }
      return;
    }
    
    _documents.addAll(documents);
    _collectionInfo['count'] = _documents.length;
    _collectionInfo['lastUpdated'] = DateTime.now().toIso8601String();
    
    if (kDebugMode) {
      print("ChromaVectorStore: Adding ${documents.length} documents. Total count: ${_documents.length}");
      print("ChromaVectorStore: First document snippet: ${documents[0].pageContent.substring(0, documents[0].pageContent.length < 50 ? documents[0].pageContent.length : 50)}...");
    }
    
    try {
      await _vectorStore.addDocuments(documents: documents);
      if (kDebugMode) {
        print("ChromaVectorStore: Successfully added documents to vector store");
      }
    } catch (e) {
      if (kDebugMode) {
        print("ChromaVectorStore: Error adding documents to vector store: $e");
      }
      rethrow;
    }
  }

  /// Get the number of documents in the store
  Future<int> getDocumentCount() async {
    return _documents.length;
  }

  /// Check if a document with pageContent exists in the store
  Future<bool> hasDocument(String content) async {
    final found = _documents.any((doc) => doc.pageContent.contains(content));
    return found;
  }

  /// Return full collection information for diagnostics
  Future<Map<String, dynamic>> getCollectionInfo() async {
    if (kDebugMode) {
      print("ChromaVectorStore: Getting collection info: $_collectionInfo");
    }
    return _collectionInfo;
  }

  /// Perform a similarity search against the vector store.
  /// [query] is the text to search for.
  /// [k] is the number of results to return (default: 4).
  /// [filter] is an optional filter to apply to the search.
  /// [scoreThreshold] is an optional minimum similarity score (0.0-1.0)
  Future<List<Document>> similaritySearch(
    String query, {
    int k = 4,
    Map<String, dynamic>? filter,
    double? scoreThreshold,
  }) async {
    if (query.trim().isEmpty) {
      if (kDebugMode) {
        print("ChromaVectorStore: Empty query, returning empty results");
      }
      return [];
    }

    try {
      if (kDebugMode) {
        print("ChromaVectorStore: Running similarity search for query: '$query'");
        print("ChromaVectorStore: Document count in store: ${_documents.length}");
        if (filter != null) {
          print("ChromaVectorStore: Using filter: $filter");
        }
      }

      // 1. Filter documents if needed
      List<Document> candidates = _documents;
      
      if (filter != null && filter.isNotEmpty) {
        candidates = _filterDocuments(candidates, filter);
        if (kDebugMode) {
          print("ChromaVectorStore: After filtering, candidate count: ${candidates.length}");
        }
        
        // Early return if no candidates match the filter
        if (candidates.isEmpty) {
          if (kDebugMode) {
            print("ChromaVectorStore: No documents match the filter criteria");
          }
          return [];
        }
      }

      // 2. Generate embedding for the query
      if (kDebugMode) {
        print("ChromaVectorStore: Generating embedding for query");
      }
      final queryEmbedding = await _embeddings.embedQuery(query);
      
      if (queryEmbedding.isEmpty) {
        if (kDebugMode) {
          print("ChromaVectorStore: Failed to generate embedding for query");
        }
        return [];
      }

      // 3. Calculate similarity scores for all candidates
      if (kDebugMode) {
        print("ChromaVectorStore: Calculating similarity scores for ${candidates.length} candidates");
      }
      
      final List<Map<String, dynamic>> scoredDocs = [];
      
      for (final doc in candidates) {
        final embedding = _getDocumentEmbedding(doc);
        
        if (embedding == null || embedding.isEmpty) {
          if (kDebugMode) {
            print("ChromaVectorStore: Document missing embedding: ${doc.metadata['source']}");
          }
          continue;
        }
        
        // Calculate cosine similarity
        final score = _calculateCosineSimilarity(queryEmbedding, embedding);
        
        // Add to results if it meets the threshold
        if (scoreThreshold == null || score >= scoreThreshold) {
          scoredDocs.add({
            'document': doc,
            'score': score,
          });
        }
      }

      // 4. Sort by score and return top k
      scoredDocs.sort((a, b) => (b['score'] as double).compareTo(a['score'] as double));
      
      final results = scoredDocs.take(k).map((item) => item['document'] as Document).toList();
      
      if (kDebugMode) {
        print("ChromaVectorStore: Returning ${results.length} results");
        if (results.isNotEmpty) {
          print("ChromaVectorStore: Top result score: ${scoredDocs.first['score']}");
        }
      }
      
      return results;
    } catch (e) {
      if (kDebugMode) {
        print("ChromaVectorStore: Error in similarity search: $e");
      }
      return [];
    }
  }

  /// Helper method to extract document embedding
  List<double>? _getDocumentEmbedding(Document doc) {
    try {
      if (doc.metadata.containsKey('embedding')) {
        final embedding = doc.metadata['embedding'];
        if (embedding is List<double>) {
          return embedding;
        } else if (embedding is List) {
          return embedding.cast<double>();
        }
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print("ChromaVectorStore: Error extracting embedding: $e");
      }
      return null;
    }
  }
  
  /// Calculate cosine similarity between two vectors
  double _calculateCosineSimilarity(List<double> vec1, List<double> vec2) {
    if (vec1.length != vec2.length) {
      throw ArgumentError('Vectors must be of the same dimension');
    }
    
    double dotProduct = 0.0;
    double norm1 = 0.0;
    double norm2 = 0.0;
    
    for (int i = 0; i < vec1.length; i++) {
      dotProduct += vec1[i] * vec2[i];
      norm1 += vec1[i] * vec1[i];
      norm2 += vec2[i] * vec2[i];
    }
    
    // Handle edge cases to avoid division by zero
    if (norm1 == 0 || norm2 == 0) return 0;
    
    return dotProduct / (sqrt(norm1) * sqrt(norm2));
  }

  /// Filter documents based on metadata criteria
  List<Document> _filterDocuments(List<Document> docs, Map<String, dynamic> filter) {
    if (kDebugMode) {
      print("ChromaVectorStore: Filtering ${docs.length} documents with filter: $filter");
    }
    
    return docs.where((doc) {
      // Check if all filter conditions match
      for (final entry in filter.entries) {
        final key = entry.key;
        final value = entry.value;
        
        // Skip null values in the filter
        if (value == null) continue;
        
        // Check if the document has the metadata field
        if (!doc.metadata.containsKey(key)) {
          if (kDebugMode) {
            print("ChromaVectorStore: Document missing filter key: $key");
          }
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

  Future<void> clearStore() async {
    final docs = await _vectorStore.similaritySearch( query: '');
    await _vectorStore.delete(ids: docs.map((d) => d.id!).toList());
    if (kDebugMode) {
      print("Vector store cleared");
    }
  }

  /// Gets the embeddings implementation (as required by the VectorStore interface)
  Future<Embeddings> getEmbeddings() async {
    // This will be provided by the caller in practice
    throw UnimplementedError('Not used directly in this implementation');
  }

  /// Get all documents stored in the vector store
  Future<List<Document>> getAllDocuments() async {
    return _documents;
  }
} 