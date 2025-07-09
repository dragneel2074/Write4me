import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/service_providers.dart';
import '../services/online_model_service.dart';

class OnlineModelSelectionDialog extends ConsumerWidget {
  const OnlineModelSelectionDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onlineModelService = ref.watch(onlineModelServiceProvider);

    return AlertDialog(
      title: const Text('Select Online Model'),
      content: onlineModelService.isLoading
          ? const Center(child: CircularProgressIndicator())
          : onlineModelService.errorMessage != null
              ? Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    'Error: ${onlineModelService.errorMessage}',
                    style: const TextStyle(color: Colors.red),
                  ),
                )
              : onlineModelService.availableOnlineModels.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Text('No online models available.'),
                    )
                  : SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: onlineModelService.availableOnlineModels.map((model) {
                          final isSelected = onlineModelService.selectedOnlineModel?.name == model.name;
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            color: isSelected 
                                ? Theme.of(context).colorScheme.primaryContainer 
                                : null,
                            child: InkWell(
                              onTap: () {
                                onlineModelService.setSelectedOnlineModel(model);
                                Navigator.pop(context); // Close dialog after selection
                              },
                              child: ListTile(
                                title: Text(model.name),
                                subtitle: Text(model.description),
                                trailing: isSelected ? const Icon(Icons.check_circle) : null,
                              ),
                            ),
                          );
                        }).toList(),
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