import 'package:langchain/langchain.dart';
import 'package:langchain_openai/langchain_openai.dart';
import '../models/pdf_memory.dart';

class AIService {
  final String openAIApiKey = 'sk-RzGyCXAR4uuK9VzBroQKQHsq9x8O8-5QLvIegWUkQ3T3BlbkFJzNnFl57SG03lAOLPtT2Uja2MfxOODjOBQcz6sbb7MA';

  Future<String> getResponse(String question, List<PDFMemory> selectedMemories) async {
    String combinedContext = '';
    if (selectedMemories.isNotEmpty) {
      List<Document> allRelevantDocs = await _getRelevantDocuments(selectedMemories, question);
      combinedContext = allRelevantDocs.map((d) => d.pageContent).join('\n\n');
    }

    final promptTemplate = ChatPromptTemplate.fromTemplates([
      (ChatMessageType.system, combinedContext.isNotEmpty 
        ? 'Answer the question based on the following context from multiple documents:\n{context}'
        : 'Answer the question to the best of your ability:'),
      (ChatMessageType.human, '{question}'),
    ]);

    final model = ChatOpenAI(apiKey: openAIApiKey);
    final chain = promptTemplate.pipe(model);

    final result = await chain.invoke({
      'context': combinedContext,
      'question': question,
    });

    return result.outputAsString;
  }

  Future<List<Document>> _getRelevantDocuments(List<PDFMemory> memories, String question) async {
    List<Document> allRelevantDocs = [];
    for (var memory in memories) {
      final retriever = memory.vectorStore.asRetriever();
      final docs = await retriever.getRelevantDocuments(question);
      allRelevantDocs.addAll(docs);
    }
    return allRelevantDocs;
  }
}