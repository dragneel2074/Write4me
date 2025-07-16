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
      content: onlineModelService.isLoading
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
                                child: Text(
                                  model.name,
                                  overflow: TextOverflow.ellipsis,
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
                    return Card(
                      margin: const EdgeInsets.only(top: 8, bottom: 8),
                      child: ListTile(
                        title: Text(modelName),
                      ),
                    );
                  }),
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
}