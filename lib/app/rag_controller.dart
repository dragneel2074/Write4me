import 'package:write4me/providers/selected_documents_provider.dart';

import '../file_processing/file_processor.dart';
import '../services/text_generation_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Controller that ties together file processing, document retrieval, and text generation.
class RAGController {
  final FileProcessor fileProcessor;
  final TextGenerationService textGenerationService;
  final Ref ref;

  RAGController({
    required this.fileProcessor,
    required this.textGenerationService,
    required this.ref,
  });

  /// Given a [query], retrieves relevant file context, augments the prompt,
  /// and calls the cloud text generation API.
  Future<String> generateAnswerForQuery(String query) async {
    print("RAGController: Query received: $query");
    
    // Get selected PDFs
    final selectedFiles = ref.read(selectedDocumentsProvider).map((m) => m.name).toList();
    print("RAGController: Using ${selectedFiles.length} selected documents: $selectedFiles");
    
    // Retrieve relevant documents from the vector store.
    final documents = await fileProcessor.queryFile(query, selectedFiles: selectedFiles);
    print("RAGController: Retrieved ${documents.length} documents from file processor.");

    // Build context as a list of document texts.
    List<String> contextList = documents.map((doc) => 
      "[From ${doc.metadata['file']}, chunk ${doc.metadata['chunkIndex']}]:\n${doc.pageContent}"
    ).toList();
    print("RAGController: Built context list with ${contextList.length} items.");

    // Call the text generation service with the original query and the file context.
    print("RAGController: Sending query and context to Text Generation Service...");
    final generatedText = await textGenerationService.generateText(
      query,
      context: contextList,
      useWebSearch: false,
      history: [],
    );
    print("RAGController: Received generated text: $generatedText");
    return generatedText;
  }
} 