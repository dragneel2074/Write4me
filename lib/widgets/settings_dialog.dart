import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:write4me/widgets/model_download_dialog.dart';
import '../providers/theme_provider.dart';
import '../providers/offline_mode_provider.dart';
import '../services/model_management_service.dart';

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

    return AlertDialog(
      title: const Text('Settings'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Theme toggle
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
            if (!offlineModeState.isOfflineMode && offlineModeState.availableModels.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.memory),
                title: const Text('Use Local Model'),
                trailing: Switch(
                  value: offlineModeState.useLocalModel,
                  onChanged: (value) {
                    ref.read(offlineModeProvider.notifier).setUseLocalModel(value);
                  },
                ),
              ),
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
                ),
              ),
              TextButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Add Model'),
                onPressed: () => _showModelDownloadDialog(context, ref),
              ),
            ],
            // Chat actions
            if (hasMessages) ...[
              ListTile(
                leading: const Icon(Icons.save),
                title: const Text('Save Chat'),
                onTap: () {
                  Navigator.pop(context);
                  onSaveChat();
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete),
                title: const Text('Clear Chat'),
                onTap: () {
                  Navigator.pop(context);
                  onClearChat();
                },
              ),
            ],
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
      await _showModelDownloadDialog(context, ref);
    }
  }

  Future<void> _showModelDownloadDialog(BuildContext context, WidgetRef ref) async {
    showDialog(
      context: context,
      builder: (context) => ModelDownloadDialog(
        onDownload: (url, onProgress, fileName) async {
          try {
            await ref.read(offlineModeProvider.notifier).downloadModel(
              url,
              onProgress,
              fileName,
            );
            if (context.mounted) {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Model downloaded successfully')),
              );
            }
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error downloading model: $e')),
              );
            }
          }
        },
      ),
    );
  }
} 