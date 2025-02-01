import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'providers.dart';

part 'service_status_provider.g.dart';

class ServiceStatus {
  final bool isTextServiceOnline;
  final bool isImageServiceOnline;

  ServiceStatus({
    required this.isTextServiceOnline,
    required this.isImageServiceOnline,
  });
}

@riverpod
class ServiceStatusNotifier extends _$ServiceStatusNotifier {
  @override
  Future<ServiceStatus> build() async {
    bool isTextServiceOnline = false;
    bool isImageServiceOnline = false;

    try {
      final textGenService = ref.read(textGenerationServiceProvider);
      final response = await textGenService.generateCloudResponse('say hi');
      isTextServiceOnline = response.isNotEmpty;
    } catch (e) {
      isTextServiceOnline = false;
    }

    try {
      final imageGenService = ref.read(imageGenerationServiceProvider);
      final imageBytes = await imageGenService.generateImage('test image');
      isImageServiceOnline = imageBytes != null;
    } catch (e) {
      isImageServiceOnline = false;
    }

    return ServiceStatus(
      isTextServiceOnline: isTextServiceOnline,
      isImageServiceOnline: isImageServiceOnline,
    );
  }

  Future<void> checkStatus() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => build());
  }
} 