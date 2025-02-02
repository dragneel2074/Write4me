import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/offline_mode_provider.dart';
import '../widgets/model_download_dialog.dart';

class ModelSelector extends ConsumerWidget {
  final bool isOfflineMode;
  
  const ModelSelector({
    super.key,
    required this.isOfflineMode,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offlineModeState = ref.watch(offlineModeProvider);

    return Container(
      height: 40,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          // Cloud model option (only in online mode)
          if (!isOfflineMode)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: const Text('Cloud'),
                selected: !offlineModeState.useLocalModel,
                onSelected: (selected) {
                  if (selected) {
                    ref.read(offlineModeProvider.notifier).setUseLocalModel(false);
                  }
                },
              ),
            ),

          // Local models
          ...offlineModeState.availableModels.map((model) {
            final modelName = model.path.split('/').last.replaceAll('.gguf', '');
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(modelName),
                selected: (isOfflineMode || offlineModeState.useLocalModel) && 
                         model.path == offlineModeState.selectedModelPath,
                onSelected: (selected) {
                  if (selected) {
                    if (!isOfflineMode) {
                      ref.read(offlineModeProvider.notifier).setUseLocalModel(true);
                    }
                    ref.read(offlineModeProvider.notifier).setSelectedModel(model.path);
                  }
                },
              ),
            );
          }),

          // Add model button
          if (offlineModeState.availableModels.isEmpty && isOfflineMode)
            TextButton.icon(
              icon: const Icon(Icons.download),
              label: const Text('Download Model'),
              onPressed: () => _showModelDownloadDialog(context, ref),
            )
          else
            ActionChip(
              avatar: const Icon(Icons.add, size: 18),
              label: const Text('Add Model'),
              onPressed: () => _showModelDownloadDialog(context, ref),
            ),
        ],
      ),
    );
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