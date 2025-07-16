import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/service_providers.dart';

class OnlineModelSelectionDialog extends ConsumerWidget {
  const OnlineModelSelectionDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onlineModelService = ref.watch(onlineModelServiceProvider);

    return AlertDialog(
      title: const Text('Select Online Text/Image Model'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () async {
                  await onlineModelService.fetchModels();
                },
              ),
            ],
          ),
          Expanded(
            child: onlineModelService.isLoading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Text Models',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        if (onlineModelService.textErrorMessage != null)
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              '${onlineModelService.textErrorMessage}',
                              style: const TextStyle(color: Colors.red),
                            ),
                          ),
                        ...onlineModelService.availableTextModels.map((model) {
                          final isSelected =
                              onlineModelService.selectedOnlineModel?.name ==
                                  model.name;
                          return Card(
                            margin: const EdgeInsets.only(top: 8, bottom: 8),
                            color: isSelected
                                ? Theme.of(context).colorScheme.primaryContainer
                                : null,
                            child: InkWell(
                              onTap: () {
                                onlineModelService.setSelectedOnlineModel(model);
                                Navigator.pop(
                                    context); // Close dialog after selection
                              },
                              child: ListTile(
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Flexible(
                                            child: Text(
                                              model.name,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if (model.tier == 'seed') ...[
                                            const SizedBox(width: 4),
                                            const Icon(Icons.vpn_key, size: 16),
                                          ],
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    if (model.inputModalities.contains('text'))
                                      const Icon(Icons.text_fields, size: 16),
                                    if (model.inputModalities.contains('image')) ...[
                                      const SizedBox(width: 4),
                                      const Icon(Icons.image, size: 16),
                                    ]
                                  ],
                                ),
                                subtitle: Text(model.description),
                                trailing:
                                    isSelected ? const Icon(Icons.check_circle) : null,
                              ),
                            ),
                          );
                        }),
                        const SizedBox(height: 16),
                        const Text('Image Models',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        if (onlineModelService.imageErrorMessage != null)
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              '${onlineModelService.imageErrorMessage}',
                              style: const TextStyle(color: Colors.red),
                            ),
                          ),
                        ...onlineModelService.availableImageModels.map((modelName) {
                          final isSelected =
                              onlineModelService.selectedImageModel == modelName;
                          final isGptImage = modelName.toLowerCase() == 'gptimage';
                          return Card(
                            margin: const EdgeInsets.only(top: 8, bottom: 8),
                            color: isSelected
                                ? Theme.of(context).colorScheme.primaryContainer
                                : isGptImage
                                    ? Theme.of(context).disabledColor
                                    : null,
                            child: ListTile(
                              title: Text(modelName),
                              trailing:
                                  isSelected ? const Icon(Icons.check_circle) : null,
                              onTap: isGptImage
                                  ? null
                                  : () {
                                      onlineModelService
                                          .setSelectedImageModel(modelName);
                                      Navigator.pop(
                                          context); // Close dialog after selection
                                    },
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}