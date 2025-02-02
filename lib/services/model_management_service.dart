import 'package:flutter/material.dart';
import 'dart:io';
import 'package:url_launcher/url_launcher.dart';
import '../providers/offline_mode_provider.dart';

class ModelManagementService {
  static Future<void> launchJinaWebsite(BuildContext context) async {
    final Uri url = Uri.parse('https://jina.ai/#apiform');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open website')),
      );
    }
  }

  static Future<bool?> showDownloadDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Download Required'),
        content: const Text(
          'Offline mode requires downloading a model (300MB+). Download now?'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Download'),
          ),
        ],
      ),
    );
  }

  static Future<void> showDeleteModelDialog(
    BuildContext context, 
    File model, 
    OfflineModeNotifier notifier,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Model'),
        content: Text(
          'Are you sure you want to delete ${model.path.split('/').last}?'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await notifier.deleteModel(model.path);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Model deleted successfully')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting model: $e')),
          );
        }
      }
    }
  }

  static Widget buildModelTile(
    BuildContext context, 
    File model, 
    OfflineModeNotifier notifier,
  ) {
    final modelName = model.path.split('/').last.replaceAll('.gguf', '');
    final isSelected = model.path == notifier.state.selectedModelPath;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isSelected 
          ? Theme.of(context).colorScheme.primaryContainer 
          : null,
      child: ListTile(
        title: Text(
          modelName,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : null,
          ),
        ),
        leading: Radio<String>(
          value: model.path,
          groupValue: notifier.state.selectedModelPath,
          onChanged: (value) {
            if (value != null) notifier.setSelectedModel(value);
          },
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline),
          onPressed: () => showDeleteModelDialog(context, model, notifier),
        ),
      ),
    );
  }
} 