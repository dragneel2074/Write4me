import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/offline_mode_provider.dart';
import '../widgets/model_download_dialog.dart';

class ModelSelector extends ConsumerStatefulWidget {
  final bool isOfflineMode;
  
  const ModelSelector({
    super.key,
    required this.isOfflineMode,
  });

  @override
  ConsumerState<ModelSelector> createState() => _ModelSelectorState();
}

class _ModelSelectorState extends ConsumerState<ModelSelector> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final offlineModeState = ref.read(offlineModeProvider);
    debugPrint('ModelSelector dependencies changed - Available models: ${offlineModeState.availableModels.length}');
  }

  @override
  Widget build(BuildContext context) {
    final offlineModeState = ref.watch(offlineModeProvider);
    debugPrint('ModelSelector rebuild - Available models: ${offlineModeState.availableModels.length}');

    return Container(
      height: 40,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          // Cloud model option (only in online mode)
          if (!widget.isOfflineMode)
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

          // Local models with key for forcing rebuild
          ...offlineModeState.availableModels.map((model) {
            final modelName = model.path.split('/').last.replaceAll('.gguf', '');
            return Padding(
              key: ValueKey(model.path),
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(modelName),
                selected: (widget.isOfflineMode || offlineModeState.useLocalModel) && 
                         model.path == offlineModeState.selectedModelPath,
                onSelected: (selected) {
                  if (selected) {
                    if (!widget.isOfflineMode) {
                      ref.read(offlineModeProvider.notifier).setUseLocalModel(true);
                    }
                    ref.read(offlineModeProvider.notifier).setSelectedModel(model.path);
                  }
                },
              ),
            );
          }),

          // Add model button
          if (offlineModeState.availableModels.isEmpty && widget.isOfflineMode)
            TextButton.icon(
              icon: const Icon(Icons.download),
              label: const Text('Download Model'),
              onPressed: () => _showModelDownloadDialog(context),
            )
          else
            ActionChip(
              avatar: const Icon(Icons.add, size: 18),
              label: const Text('Add Model'),
              onPressed: () => _showModelDownloadDialog(context),
            ),
        ],
      ),
    );
  }

  Future<void> _showModelDownloadDialog(BuildContext context) async {
    if (!mounted) return;
    
    await showDialog(
      context: context,
      barrierDismissible: false, // Prevent dismissing during download
      builder: (context) => ModelDownloadDialog(
        onDownload: (url, onProgress, fileName) async {
          try {
            await ref.read(offlineModeProvider.notifier).downloadModel(
              url,
              onProgress,
              fileName,
            );
            if (mounted) {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Model downloaded successfully'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error downloading model: $e'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          }
        },
      ),
    );
  }
} 