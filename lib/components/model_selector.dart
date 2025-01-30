import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/offline_model_service.dart';
import '../widgets/model_download_dialog.dart';

class ModelSelector extends StatelessWidget {
  final bool isOfflineMode;
  
  const ModelSelector({
    super.key,
    required this.isOfflineMode,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<OfflineModelService>(
      builder: (context, offlineService, child) {
        return Container(
          height: 40,
          margin: const EdgeInsets.only(bottom: 8),
          child: Wrap(
            spacing: 8,
            children: [
              // Cloud model chip (only in online mode)
              if (!isOfflineMode)
                ChoiceChip(
                  label: const Text('Cloud'),
                  selected: !offlineService.useLocalModel,
                  onSelected: (selected) {
                    if (selected) {
                      offlineService.setUseLocalModel(false);
                    }
                  },
                ),
              // Local model chips
              ...offlineService.availableModels.map((model) {
                final modelName = model.path.split('/').last.replaceAll('.gguf', '');
                return ChoiceChip(
                  label: Text(modelName),
                  selected: (isOfflineMode || offlineService.useLocalModel) && 
                           model.path == offlineService.selectedModelPath,
                  onSelected: (selected) {
                    if (selected) {
                      if (!isOfflineMode) {
                        offlineService.setUseLocalModel(true);
                      }
                      offlineService.setSelectedModel(model.path);
                    }
                  },
                );
              }),
              // Add model button
              ActionChip(
                avatar: const Icon(Icons.add, size: 18),
                label: const Text('Add Local'),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => const ModelDownloadDialog(),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
} 