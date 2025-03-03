import 'package:flutter/foundation.dart';
import 'package:langchain/langchain.dart';
import '../embedding_generator.dart';

/// Custom embeddings class that uses fonnx-generated embeddings.
class FonnxEmbeddings implements Embeddings {
  @override
  Future<List<double>> embedQuery(String text) async {
    // Clean the text before embedding
    final cleanedText = _cleanText(text);
    
    if (kDebugMode) {
      print("FonnxEmbeddings: Embedding query text: '${cleanedText.length > 50 ? cleanedText.substring(0, 50) + '...' : cleanedText}'");
      print("FonnxEmbeddings: Query text length: ${cleanedText.length} characters");
      if (cleanedText != text) {
        print("FonnxEmbeddings: Text was cleaned (original length: ${text.length})");
      }
    }
    
    final embedding = await EmbeddingGenerator.generateEmbedding(cleanedText);
    
    if (kDebugMode) {
      print("FonnxEmbeddings: Generated query embedding with length: ${embedding.length}");
      if (embedding.isNotEmpty) {
        print("FonnxEmbeddings: First few values: [${embedding.take(3).map((e) => e.toStringAsFixed(4)).join(', ')}...]");
      }
    }
    
    return embedding;
  }

  @override
  Future<List<List<double>>> embedDocuments(List<Document> documents) async {
    List<List<double>> embeddings = [];
    if (kDebugMode) {
      print("FonnxEmbeddings: Generating embeddings for ${documents.length} documents");
    }
    for (final doc in documents) {
      // Clean the document content before embedding
      final cleanedContent = _cleanText(doc.pageContent);
      
      if (kDebugMode) {
        print("FonnxEmbeddings: Processing document ${doc.id ?? 'unknown-id'}, content length: ${cleanedContent.length}");
        if (cleanedContent != doc.pageContent) {
          print("FonnxEmbeddings: Document was cleaned (original length: ${doc.pageContent.length})");
        }
      }
      embeddings.add(await embedQuery(cleanedContent));
    }
    if (kDebugMode) {
      print("FonnxEmbeddings: Generated ${embeddings.length} embeddings");
    }
    return embeddings;
  }
  
  /// Clean text before embedding to improve quality
  String _cleanText(String text) {
    if (text.isEmpty) return text;
    
    // Trim leading/trailing whitespace
    String cleaned = text.trim();
    
    // Replace tabs and multiple spaces with a single space
    cleaned = cleaned.replaceAll(RegExp(r'\t+'), ' ');
    cleaned = cleaned.replaceAll(RegExp(r' {2,}'), ' ');
    
    // Replace multiple newlines with a single newline
    cleaned = cleaned.replaceAll(RegExp(r'\n{2,}'), '\n');
    
    // Remove non-alphanumeric characters except important punctuation
    cleaned = cleaned.replaceAll(RegExp(r'[^\w\s.,!?;:]'), ' ');
    
    // Normalize whitespace after cleaning
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
    
    if (kDebugMode && cleaned.length != text.length) {
      print('FonnxEmbeddings: Text cleaning changed length from ${text.length} to ${cleaned.length}');
    }
    
    return cleaned;
  }
} 