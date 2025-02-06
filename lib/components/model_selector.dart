import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:write4me/utils/message_utils.dart';
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
      final modelSelectorContext = this.context;
    await showDialog(
      context: context,
      barrierDismissible: false, // Prevent dismissing during download
      builder: (context) => ModelDownloadDialog(
        // Pass our note message to the dialog
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
            if (!mounted) return;
            
            MessageUtils.showSuccess(modelSelectorContext, 'Model downloaded successfully');
            // Navigator.of(context).pop();
          } catch (e) {
            MessageUtils.showError(modelSelectorContext, 'Error downloading model: $e');
          }
        },
      ),
    );
  }
}
