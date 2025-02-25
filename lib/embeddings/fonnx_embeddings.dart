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
    print("FonnxEmbeddings: Generating embeddings for ${documents.length} documents");
    for (final doc in documents) {
      print("FonnxEmbeddings: Processing document ${doc.id}");
      embeddings.add(await embedQuery(doc.pageContent));
    }
    print("FonnxEmbeddings: Generated ${embeddings.length} embeddings");
    return embeddings;
  }
} 