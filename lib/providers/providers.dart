import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../services/offline_model_service.dart';
import '../services/ai_service.dart';
import '../services/text_generation_service.dart';
import '../services/image_service.dart';
import '../services/chat_storage_service.dart';
import '../services/web_service.dart';
import '../services/pdf_service.dart';
import '../services/image_generation_service.dart';
import '../services/notification_service.dart';
import '../services/reminder_service.dart';

part 'providers.g.dart';

@Riverpod(keepAlive: true)
class OfflineModelNotifier extends _$OfflineModelNotifier {
  @override
  OfflineModelService build() {
    final service = OfflineModelService();
    service.init();
    return service;
  }
}

@Riverpod(keepAlive: true)
class NotificationNotifier extends _$NotificationNotifier {
  @override
  NotificationService build() {
    final service = NotificationService();
    service.init();
    return service;
  }
}

@Riverpod(keepAlive: true)
class ReminderNotifier extends _$ReminderNotifier {
  @override
  ReminderService build() {
    final notificationService = ref.watch(notificationNotifierProvider);
    final service = ReminderService(notificationService);
    service.init();
    return service;
  }
}

@Riverpod(keepAlive: true)
class ChatStorageNotifier extends _$ChatStorageNotifier {
  @override
  ChatStorageService build() {
    final service = ChatStorageService();
    service.init();
    return service;
  }
}

@riverpod
AIService aiService(AiServiceRef ref) {
  final offlineService = ref.watch(offlineModelNotifierProvider);
  final textGenService = ref.watch(textGenerationServiceProvider);
  return AIService(textGenService, offlineService);
}

@riverpod
TextGenerationService textGenerationService(TextGenerationServiceRef ref) {
  return TextGenerationService();
}

@riverpod
ImageService imageService(ImageServiceRef ref) {
  final service = ImageService();
  ref.onDispose(() {
    service.dispose();
  });
  return service;
}

@riverpod
WebService webService(WebServiceRef ref) {
  return WebService();
}

@riverpod
PDFService pdfService(PdfServiceRef ref) {
  return PDFService();
}

@riverpod
ImageGenerationService imageGenerationService(ImageGenerationServiceRef ref) {
  return ImageGenerationService();
}

@riverpod
ReminderService reminderService(ReminderServiceRef ref) {
  final notificationService = ref.watch(notificationNotifierProvider);
  final service = ReminderService(notificationService);
  ref.onDispose(() {
    // Clean up if needed
  });
  return service;
} 