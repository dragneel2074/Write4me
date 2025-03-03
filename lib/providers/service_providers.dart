import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/ai_service.dart';
import '../services/text_generation_service.dart';
import '../services/offline_model_service.dart';
import '../services/pdf_service.dart';
import 'file_processor_provider.dart';

/// Provider for TextGenerationService
final textGenerationServiceProvider = Provider<TextGenerationService>((ref) {
  return TextGenerationService();
});

/// Provider for OfflineModelService
final offlineModelServiceProvider = Provider<OfflineModelService>((ref) {
  return OfflineModelService();
});

/// Provider for AIService that depends on TextGenerationService and OfflineModelService
final aiServiceProvider = ChangeNotifierProvider<AIService>((ref) {
  final textGenService = ref.read(textGenerationServiceProvider);
  final offlineModelService = ref.read(offlineModelServiceProvider);
  final fileProcessor = ref.read(fileProcessorProvider);
  
  return AIService(textGenService, offlineModelService, fileProcessor);
});

/// Provider for PDFService that depends on FileProcessor
final pdfServiceProvider = Provider<PDFService>((ref) {
  final fileProcessor = ref.read(fileProcessorProvider);
  return PDFService(fileProcessor);
}); 