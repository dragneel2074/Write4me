import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:write4me/providers/offline_mode_provider.dart';
import 'package:write4me/utils/message_utils.dart';
import 'package:write4me/widgets/model_download_dialog.dart';

class OfflineModelSelector extends ConsumerWidget {
  const OfflineModelSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offlineModeState = ref.watch(offlineModeProvider);
    
    debugPrint('OfflineModelSelector build:');
    debugPrint('- Available models: ${offlineModeState.availableModels.length}');
    debugPrint('- Selected model: ${offlineModeState.selectedModelPath}');

    return Expanded(
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          ...offlineModeState.availableModels.map((model) {
            final modelName = model.path.split('/').last.replaceAll('.gguf', '');
            final isSelected = offlineModeState.useLocalModel && 
                             model.path == offlineModeState.selectedModelPath;
            
            debugPrint('Model chip: $modelName (selected: $isSelected)');
            
            return Padding(
              key: ValueKey(model.path),
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(modelName),
                selected: isSelected,
                onSelected: (selected) {
                  if (selected) {
                    ref.read(offlineModeProvider.notifier)
                      ..setUseLocalModel(true)
                      ..setSelectedModel(model.path);
                  }
                },
              ),
            );
          }),

          // Add model button
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ActionChip(
              avatar: const Icon(Icons.add, size: 18),
              label: const Text('Add Model'),
              onPressed: () => _showModelDownloadDialog(context, ref),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showModelDownloadDialog(BuildContext context, WidgetRef ref) async {
    await showDialog(
      context: context,
      builder: (dialogContext) => ModelDownloadDialog(
        noteMessage: 
          'Note: It is recommended to use Qwen series and start with tiny models like Qwen 0.5 before moving to larger ones. '
          'Please check your memory usage and download only 20% of the free memory. For instance, '
          'if 3.6 GB is used out of 6 GB, free memory is 2.4 GB, so roughly 500 MB should be downloaded. '
          'The app is not liable for any damage to your device.',
        onDownload: (url, onProgress, fileName) async {
          try {
            await ref.read(offlineModeProvider.notifier).downloadModel(
              url,
              onProgress,
              fileName,
            );
            
            if (dialogContext.mounted) {
              MessageUtils.showSuccess(dialogContext, 'Download completed');
              Navigator.pop(dialogContext);
            }
          } catch (e) {
            if (dialogContext.mounted) {
              MessageUtils.showError(
                dialogContext, 
                'Download failed: ${_getErrorReason(e)}'
              );
            }
            rethrow; // Preserve original error for debugging
          }
        },
      ),
    );
  }

  String _getErrorReason(dynamic error) {
    final msg = error.toString().toLowerCase();
    if (msg.contains('connection')) return 'Check your internet connection';
    if (msg.contains('404')) return 'File not found on server';
    if (msg.contains('storage')) return 'Not enough storage space';
    return 'Please try again later';
  }
} 