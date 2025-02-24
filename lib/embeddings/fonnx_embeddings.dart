import 'package:langchain/langchain.dart';
import '../embedding_generator.dart';

/// Custom embeddings class that uses fonnx-generated embeddings.
class FonnxEmbeddings implements Embeddings {
  @override
  Future<List<double>> embedQuery(String text) async {
    return await EmbeddingGenerator.generateEmbedding(text);
  }

  @override
  Future<List<List<double>>> embedDocuments(List<Document> documents) async {
    List<List<double>> embeddings = [];
    for (final doc in documents) {
      embeddings.add(await embedQuery(doc.pageContent));
    }
    return embeddings;
  }
} 