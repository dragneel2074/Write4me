import 'package:langchain/langchain.dart';
import 'package:langchain_openai/langchain_openai.dart';

class VectorStoreService {
  final String openAIApiKey = 'sk-RzGyCXAR4uuK9VzBroQKQHsq9x8O8-5QLvIegWUkQ3T3BlbkFJzNnFl57SG03lAOLPtT2Uja2MfxOODjOBQcz6sbb7MA';

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