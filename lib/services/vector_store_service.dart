// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:langchain/langchain.dart';
// import 'package:langchain_openai/langchain_openai.dart';

// class VectorStoreService {
//   Future<String> _getOpenAIApiKey() async {
//     SharedPreferences prefs = await SharedPreferences.getInstance();
//     String? apiKey = prefs.getString('openai_api_key');
//     if (apiKey == null || apiKey.isEmpty) {
//       throw Exception('OpenAI API key is not set in SharedPreferences.');
//     }
//     return apiKey;
//   }

//   Future<MemoryVectorStore> createVectorStore(String content) async {
//     String openAIApiKey = await _getOpenAIApiKey();

//     MemoryVectorStore vectorStore = MemoryVectorStore(
//       embeddings: OpenAIEmbeddings(apiKey: openAIApiKey),
//     );
//     await vectorStore.addDocuments(
//       documents: [Document(pageContent: content)],
//     );
//     return vectorStore;
//   }
// }
