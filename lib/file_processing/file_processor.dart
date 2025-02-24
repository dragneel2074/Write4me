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

  /// Simple text chunking by splitting into segments of maximum [maxChunkSize] characters.
  List<String> _chunkText(String text, int maxChunkSize) {
    List<String> chunks = [];
    int start = 0;
    while (start < text.length) {
      int end = start + maxChunkSize;
      if (end > text.length) end = text.length;
      chunks.add(text.substring(start, end));
      start = end;
    }
    return chunks;
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