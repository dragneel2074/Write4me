import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/ai_service.dart';
import '../services/pdf_service.dart';
import 'file_processor_provider.dart';
import '../services/online_model_service.dart'; // Import the new service

// Import all providers from service_provider.dart
import 'service_provider.dart' as legacy_providers;
// Import offline_mode_provider.dart to re-export its provider

// Re-export providers from service_provider to make migration easier
export 'service_provider.dart' show offlineModelServiceProvider, offlineModelInitProvider, initializedOfflineModelProvider;
// Re-export offlineModeProvider
export 'offline_mode_provider.dart' show offlineModeProvider;

/// Provider for TextGenerationService
final textGenerationServiceProvider = legacy_providers.textGenerationServiceProvider;

/// Provider for AIService that depends on TextGenerationService and OfflineModelService
final aiServiceProvider = ChangeNotifierProvider<AIService>((ref) {
  final textGenService = ref.read(legacy_providers.textGenerationServiceProvider);
  // Important: Use the same offlineModelService instance that's used by offlineModeProvider
  final offlineModelService = ref.read(legacy_providers.offlineModelServiceProvider);
  final fileProcessor = ref.read(fileProcessorProvider);
  final onlineModelService = ref.read(onlineModelServiceProvider);
  
  return AIService(textGenService, offlineModelService, fileProcessor, onlineModelService);
});

/// Provider for PDFService that depends on FileProcessor
final pdfServiceProvider = Provider<PDFService>((ref) {
  final fileProcessor = ref.read(fileProcessorProvider);
  final offlineModelService = ref.read(legacy_providers.offlineModelServiceProvider);
  return PDFService(fileProcessor, offlineModelService);
});

/// Provider for OnlineModelService
final onlineModelServiceProvider = ChangeNotifierProvider<OnlineModelService>((ref) {
  final service = OnlineModelService();
  // Fetch models when the service is initialized
  service.fetchModels();
  return service;
}); 