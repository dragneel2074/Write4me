import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:write4me/theme/theme_provider.dart';
import 'model_download_dialog.dart';
import '../providers/providers.dart';

class SettingsDialog extends ConsumerWidget {
  final VoidCallback onSaveChat;
  final VoidCallback onClearChat;
  final VoidCallback onShowInfo;
  final bool hasMessages;

  const SettingsDialog({
    super.key,
    required this.onSaveChat,
    required this.onClearChat,
    required this.onShowInfo,
    required this.hasMessages,
  });

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offlineService = ref.watch(offlineModelNotifierProvider);
    final models = offlineService.availableModels;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.settings,
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Settings',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                ],
              ),
            ),
            // Content
            Flexible(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Chat Section
                      _buildSectionHeader(context, 'Chat'),
                      Card(
                        child: Column(
                          children: [
                            if (hasMessages) ...[
                              ListTile(
                                leading: const Icon(Icons.save),
                                title: const Text('Save Current Chat'),
                                onTap: () {
                                  Navigator.pop(context);
                                  onSaveChat();
                                },
                              ),
                              const Divider(height: 1),
                              ListTile(
                                leading: const Icon(Icons.delete),
                                title: const Text('Clear Chat'),
                                onTap: () {
                                  Navigator.pop(context);
                                  onClearChat();
                                },
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Model Settings
                      _buildSectionHeader(context, 'Model Settings'),
                      Card(
                        child: Column(
                          children: [
                            // Theme Switch
                            Consumer(
                              builder: (context, ref, child) {
                                final themeNotifier = ref.watch(themeNotifierProvider.notifier);
                                return SwitchListTile(
                                  title: const Text('Dark Theme'),
                                  secondary: const Icon(Icons.dark_mode),
                                  value: themeNotifier.isDarkMode,
                                  onChanged: (_) => themeNotifier.toggleTheme(),
                                );
                              },
                            ),
                            const Divider(height: 1),
                            // Offline Mode Switch
                            SwitchListTile(
                              title: const Text('Offline Mode'),
                              subtitle: Text(models.isEmpty 
                                  ? 'No models available' 
                                  : '${models.length} model(s) available'),
                              secondary: const Icon(Icons.offline_bolt),
                              value: offlineService.isOfflineMode,
                              onChanged: models.isEmpty ? null : (value) async {
                                await offlineService.setOfflineMode(value);
                              },
                            ),
                            if (models.isNotEmpty) ...[
                              const Divider(),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: Text(
                                  'Selected Model: ${offlineService.currentModelName}',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Footer
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
} 