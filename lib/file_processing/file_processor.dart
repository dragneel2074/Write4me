import 'dart:io';
import 'package:langchain/langchain.dart';
import 'package:path/path.dart' as path;
import '../vector_store/chroma_vector_store.dart';

/// Processes files by reading content, chunking, generating embeddings,
/// and adding them to the vector store.
class FileProcessor {
  final ChromaVectorStore _vectorStore = ChromaVectorStore();

  /// Processes text content directly (from PDFs or other sources)
  Future<void> processText(String content, String fileName) async {
    print("FileProcessor: Processing text content from: $fileName");
    final List<String> chunks = _chunkText(content, 1000);
    print("FileProcessor: Split content into ${chunks.length} chunks");

    List<Document> documents = [];
    for (int i = 0; i < chunks.length; i++) {
      String docId = "$fileName-$i";
      documents.add(Document(
        id: docId,
        pageContent: chunks[i],
        metadata: {'file': fileName, 'chunkIndex': i},
      ));
      print("FileProcessor: Created document for $fileName chunk $i");
    }

    await _vectorStore.addDocuments(documents);
    print("FileProcessor: Added ${documents.length} documents from $fileName");
  }

  /// Processes a file at [filePath], splitting it into chunks, and indexing each chunk.
  Future<void> processFile(String filePath) async {
    print("FileProcessor: Starting to process file: $filePath");
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception("File does not exist: $filePath");
    }
    
    final content = await file.readAsString();
    print("FileProcessor: Read file content of length: ${content.length}");
    final List<String> chunks = _chunkText(content, 1000); // Chunk size can be adjusted.
    print("FileProcessor: Splitted content into ${chunks.length} chunks");
    
    List<Document> documents = [];
    for (int i = 0; i < chunks.length; i++) {
      String docId = "${path.basename(filePath)}-$i";
      documents.add(Document(
        id: docId,
        pageContent: chunks[i],
        metadata: {'file': path.basename(filePath), 'chunkIndex': i},
      ));
      print("FileProcessor: Created document with id: $docId");
    }
    
    await _vectorStore.addDocuments(documents);
    print("FileProcessor: Added ${documents.length} documents to the vector store.");
  }

  /// Improved text chunking that respects semantic boundaries and adds overlaps
  List<String> _chunkText(String text, int maxChunkSize) {
    List<String> chunks = [];
    
    // Split by paragraphs
    List<String> paragraphs = text.split(RegExp(r'\n\s*\n'));
    
    String currentChunk = '';
    String previousChunk = '';
    final int overlapSize = 150; // Characters to overlap between chunks
    
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

  /// Queries the vector store and returns relevant documents based on the [query].
  Future<List<Document>> queryFile(String query, {List<String>? selectedFiles}) async {
    print("FileProcessor: Running similarity search for query: $query");
    final results = await _vectorStore.similaritySearch(
      query,
      where: selectedFiles != null ? {'file': {'\$in': selectedFiles}} : null,
    );
    print("FileProcessor: Retrieved ${results.length} documents from similarity search.");
    return results;
  }
} 