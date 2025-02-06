import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:write4me/providers/offline_mode_provider.dart';

class OfflineFeatureLoader {
  static Future<void> load(WidgetRef ref) async {
    // Initialize the offline mode provider
    await ref.read(offlineModeProvider.notifier).initialize();
  }
  
  static Widget wrapWithProviders(Widget child) {
    return ProviderScope(
      child: child,
    );
  }
} 