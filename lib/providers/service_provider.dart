import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/ai_service.dart';
import '../services/text_generation_service.dart';
import '../services/offline_model_service.dart';
import 'file_processor_provider.dart';
import 'service_providers.dart' show onlineModelServiceProvider; // Import the new provider

// Initialize OfflineModelService first
final offlineModelServiceProvider = Provider<OfflineModelService>((ref) {
  final service = OfflineModelService();
  return service;
});

// Create an initialization provider
final offlineModelInitProvider = FutureProvider<void>((ref) async {
  final service = ref.watch(offlineModelServiceProvider);
  await service.init();
});

// Create the provider for initialized state
final initializedOfflineModelProvider = Provider<OfflineModelService>((ref) {
  // Watch the initialization state
  final initState = ref.watch(offlineModelInitProvider);
  
  return initState.when(
    data: (_) => ref.watch(offlineModelServiceProvider),
    loading: () => throw Exception('OfflineModelService is still initializing'),
    error: (error, _) => throw Exception('Failed to initialize OfflineModelService: $error'),
  );
});

final textGenerationServiceProvider = Provider<TextGenerationService>((ref) {
  return TextGenerationService();
});

final aiServiceProvider = Provider<AIService>((ref) {
  final textGenService = ref.watch(textGenerationServiceProvider);
  final offlineService = ref.watch(offlineModelServiceProvider);
  final fileProcessor = ref.watch(fileProcessorProvider);
  final onlineModelService = ref.watch(onlineModelServiceProvider); // Get onlineModelService
  return AIService(textGenService, offlineService, fileProcessor, onlineModelService); // Pass onlineModelService
});

// final notificationServiceProvider = Provider<NotificationService>((ref) {
//   return NotificationService();
// });

// final reminderServiceProvider = Provider<ReminderService>((ref) {
//   final notificationService = ref.watch(notificationServiceProvider);
//   return ReminderService(notificationService);
// }); 