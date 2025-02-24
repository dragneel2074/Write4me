import 'package:langchain/langchain.dart';
import '../embeddings/fonnx_embeddings.dart';

/// Wrapper for in-memory vector storage
class ChromaVectorStore {
  final MemoryVectorStore _vectorStore;

  ChromaVectorStore() : _vectorStore = MemoryVectorStore(
    embeddings: FonnxEmbeddings(),
  );

  Future<void> addDocuments(List<Document> documents) async {
    await _vectorStore.addDocuments(documents: documents);
  }

  Future<List<Document>> similaritySearch(
    String query, {
    int k = 2,
    double scoreThreshold = 0.4,
    Map<String, dynamic>? where,
  }) async {
    return await _vectorStore.similaritySearch(
      query: query,
      config: VectorStoreSimilaritySearch(
        k: k,
        scoreThreshold: scoreThreshold,
        filter: where,
      ),
    );
  }

  Future<void> clearStore() async {
    final docs = await _vectorStore.similaritySearch( query: '');
    await _vectorStore.delete(ids: docs.map((d) => d.id!).toList());
    print("Vector store cleared");
  }
} 