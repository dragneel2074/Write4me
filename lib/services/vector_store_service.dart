import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:langchain/langchain.dart';
import 'package:langchain_openai/langchain_openai.dart';

class VectorStoreService {
  final String openAIApiKey = dotenv.env['OPENAI_API_KEY'] ?? '';

  Future<MemoryVectorStore> createVectorStore(String content) async {
    MemoryVectorStore vectorStore = MemoryVectorStore(
      embeddings: OpenAIEmbeddings(apiKey: openAIApiKey),
    );
    await vectorStore.addDocuments(
      documents: [Document(pageContent: content)],
    );
    return vectorStore;
  }
}