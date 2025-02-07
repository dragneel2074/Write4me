import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:write4me/providers/offline_mode_provider.dart';
import 'package:write4me/utils/message_utils.dart';
import 'package:write4me/widgets/model_download_dialog.dart';

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
  void initState() {
    super.initState();
    _initializeState();
  }

  Future<void> _initializeState() async {
    final offlineModeState = ref.read(offlineModeProvider);
    if (widget.isOfflineMode && offlineModeState.availableModels.isEmpty) {
      await ref.read(offlineModeProvider.notifier).initialize();
    }
  }

  Future<void> _showModelDownloadDialog(BuildContext context) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
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
            
            if (!dialogContext.mounted) return;
            MessageUtils.showSuccess(dialogContext, 'Model downloaded successfully');
            Navigator.of(dialogContext).pop();
          } catch (e) {
            if (!dialogContext.mounted) return;
            MessageUtils.showError(dialogContext, _getDownloadError(e));
            rethrow; // Keep the error visible in logs
          }
        },
      ),
    );
  }

  String _getDownloadError(dynamic error) {
    if (error is SocketException) {
      return 'Download failed. Check your internet connection';
    } else if (error is HttpException) {
      return 'Server error. Please try again later';
    } else if (error.toString().contains('host lookup')) {
      return 'Connection failed. Check your network';
    }
    return 'Failed to download model. Please try again';
  }

  @override
  Widget build(BuildContext context) {
    final offlineModeState = ref.watch(offlineModeProvider);
    
    debugPrint('ModelSelector rebuild:');
    debugPrint('- Offline mode: ${widget.isOfflineMode}');
    debugPrint('- Use local model: ${offlineModeState.useLocalModel}');
    debugPrint('- Available models: ${offlineModeState.availableModels.length}');
    debugPrint('- Selected model: ${offlineModeState.selectedModelPath}');

    return Container(
      height: 40,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          // Cloud model option
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

          // Show offline models if available
          if (offlineModeState.availableModels.isNotEmpty)
            ...offlineModeState.availableModels.map((model) {
              final modelName = model.path.split('/').last.replaceAll('.gguf', '');
              final isSelected = offlineModeState.useLocalModel && 
                               model.path == offlineModeState.selectedModelPath;
              
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

          // Show download button if in offline mode and no models available
          if (widget.isOfflineMode && offlineModeState.availableModels.isEmpty)
            TextButton.icon(
              icon: const Icon(Icons.download),
              label: const Text('Download Model'),
              onPressed: () => _showModelDownloadDialog(context),
            ),

          // Show add model button if in offline mode and models exist
          if (widget.isOfflineMode && offlineModeState.availableModels.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ActionChip(
                avatar: const Icon(Icons.add, size: 18),
                label: const Text('Add Model'),
                onPressed: () => _showModelDownloadDialog(context),
              ),
            ),
        ],
      ),
    );
  }
}