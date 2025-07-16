import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:write4me/utils/message_utils.dart';
import 'package:write4me/widgets/model_download_dialog.dart';
import '../providers/theme_provider.dart';
import '../services/model_management_service.dart';
import '../providers/service_providers.dart'; // Import service providers
// Import OnlineModelService
import 'online_model_selection_dialog.dart'; // New import

class SettingsDialog extends ConsumerWidget {
  final bool hasMessages;
  final VoidCallback onSaveChat;
  final VoidCallback onClearChat;
  final VoidCallback onShowInfo;

  const SettingsDialog({
    super.key,
    required this.hasMessages,
    required this.onSaveChat,
    required this.onClearChat,
    required this.onShowInfo,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offlineModeState = ref.watch(offlineModeProvider);
    final themeMode = ref.watch(themeProvider);
    final onlineModelService = ref.watch(onlineModelServiceProvider);

    return AlertDialog(
      title: const Text('Settings'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Theme toggle
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: TextButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('New Chat'),
                    onPressed: () {
                      Navigator.pop(context);
                      onClearChat();
                    },
                  ),
                ),
                Expanded(
                  child: TextButton.icon(
                    icon: const Icon(Icons.save),
                    label: const Text('Save Chat'),
                    onPressed: hasMessages
                        ? () {
                            Navigator.pop(context);
                            onSaveChat();
                          }
                        : null,
                  ),
                ),
              ],
            ),
            const Divider(),
            ListTile(
              leading: Icon(
                themeMode == ThemeMode.dark ? Icons.dark_mode : Icons.light_mode,
              ),
              title: const Text('Dark Mode'),
              trailing: Switch(
                value: themeMode == ThemeMode.dark,
                onChanged: (value) {
                  ref.read(themeProvider.notifier).setThemeMode(
                        value ? ThemeMode.dark : ThemeMode.light,
                      );
                },
              ),
            ),
            // Offline mode section
            const Divider(),
            ListTile(
              leading: const Icon(Icons.cloud_off),
              title: const Text('Offline Mode'),
              trailing: Switch(
                value: offlineModeState.isOfflineMode,
                onChanged: (value) {
                  if (value && offlineModeState.availableModels.isEmpty) {
                    _showDownloadModelPrompt(context, ref);
                  } else {
                    ref.read(offlineModeProvider.notifier).setOfflineMode(value);
                  }
                },
              ),
            ),
            // Online Models List
            if (!offlineModeState.isOfflineMode) ...[
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('Online Text/Image Models', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              ListTile(
                title: Text(
                  onlineModelService.selectedOnlineModel?.name ?? 'No model selected',
                  style: TextStyle(
                    fontWeight: onlineModelService.selectedOnlineModel != null ? FontWeight.bold : null,
                  ),
                ),
                subtitle: onlineModelService.selectedOnlineModel != null
                    ? Text(onlineModelService.selectedOnlineModel!.description)
                    : null,
                trailing: onlineModelService.isLoading
                    ? const CircularProgressIndicator()
                    : (onlineModelService.textErrorMessage != null ||
                            onlineModelService.imageErrorMessage != null)
                        ? Icon(Icons.error,
                            color: Theme.of(context).colorScheme.error)
                        : null,
              ),
              TextButton.icon(
                icon: const Icon(Icons.more_horiz),
                label: const Text('Show More Models'),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => const OnlineModelSelectionDialog(),
                  );
                },
              ),
            ],
            if (offlineModeState.availableModels.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('Local Models', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              ...offlineModeState.availableModels.map((model) => 
                ModelManagementService.buildModelTile(
                  context,
                  model,
                  ref.read(offlineModeProvider.notifier),
                  offlineModeState,
                ),
              ),
              TextButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Add Model'),
                onPressed: () => _showModelDownloadDialog(context, ref),
              ),
            ],
            // Chat actions
            
            // Info
            ListTile(
              leading: const Icon(Icons.info),
              title: const Text('About'),
              onTap: () {
                Navigator.pop(context);
                onShowInfo();
              },
            ),
            
            
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Future<void> _showDownloadModelPrompt(BuildContext context, WidgetRef ref) async {
    final download = await ModelManagementService.showDownloadDialog(context);
    if (download == true) {
      if (context.mounted) {
        await _showModelDownloadDialog(context, ref);
      }
    }
  }

  Future<void> _showModelDownloadDialog(BuildContext context, WidgetRef ref) async {
    showDialog(
      context: context,
      builder: (context) => ModelDownloadDialog(
        noteMessage: 'Note: It is recommended to start with tiny models like Qwen 0.5 before moving to larger ones. '
          'Please check your free memory usage and download only 20% of the free memory. For instance, '
          'if 3.6 GB is used out of 6 GB, free memory is 2.4 GB, so roughly 500 MB should be downloaded. '
          'The app is not liable for any damage to your device.',
        onDownload: (url, onProgress, fileName) async {
          try {
            await ref.read(offlineModeProvider.notifier).downloadModel(
              url,
              onProgress,
              fileName,
            );
            if (context.mounted) {
              Navigator.pop(context);
              MessageUtils.showSuccess(context, 'Model downloaded successfully');
              // ScaffoldMessenger.of(context).showSnackBar(
              //   const SnackBar(content: Text('Model downloaded successfully')),
              // );
            }
          } catch (e) {
            if (context.mounted) {
              MessageUtils.showError(context, 'Error downloading model: $e');
              // ScaffoldMessenger.of(context).showSnackBar(
              //     SnackBar(content: Text('Error downloading model: $e')),
              //   );
            }
          }
        },
      ),
    );
  }
} 