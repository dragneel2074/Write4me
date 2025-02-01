import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/offline_model_service.dart';

class ModelDownloadDialog extends StatefulWidget {
  const ModelDownloadDialog({super.key});

  @override
  State<ModelDownloadDialog> createState() => _ModelDownloadDialogState();
}

class _ModelDownloadDialogState extends State<ModelDownloadDialog> {
  String _selectedModel = OfflineModelService.defaultModels.keys.first;
  bool _isDownloading = false;
  double _progress = 0;
  final _urlController = TextEditingController();
  bool _isCustomUrl = false;
  CancelToken? _cancelToken;

  @override
  void dispose() {
    _urlController.dispose();
    _cancelToken?.cancel();
    super.dispose();
  }

  Future<void> _downloadModel() async {
    setState(() => _isDownloading = true);
    _cancelToken = CancelToken();
    
    try {
      final offlineService = context.read<OfflineModelService>();
      
      if (_isCustomUrl) {
        await offlineService.downloadCustomModel(
          _urlController.text.trim(),
          (progress) => setState(() => _progress = progress),
          _cancelToken!,
        );
      } else {
        await offlineService.downloadModel(
          _selectedModel,
          (progress) => setState(() => _progress = progress),
          _cancelToken!,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Model downloaded successfully')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        if (e is CancelException) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Download cancelled')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _progress = 0;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final availableModels = [
      ...OfflineModelService.defaultModels.keys,
      'Custom URL',
    ];

    return AlertDialog(
      title: const Text('Download Model'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select a model to download:',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            DropdownButton<String>(
              value: _selectedModel,
              isExpanded: true,
              items: availableModels.map((name) {
                return DropdownMenuItem(
                  value: name,
                  child: Text(name),
                );
              }).toList(),
              onChanged: _isDownloading ? null : (value) {
                if (value != null) {
                  setState(() {
                    _selectedModel = value;
                    _isCustomUrl = value == 'Custom URL';
                  });
                }
              },
            ),
            if (_isCustomUrl) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _urlController,
                decoration: const InputDecoration(
                  labelText: 'Model URL',
                  hintText: 'Enter GGUF model URL',
                  border: OutlineInputBorder(),
                ),
                enabled: !_isDownloading,
              ),
            ],
            if (_isDownloading) ...[
              const SizedBox(height: 16),
              LinearProgressIndicator(value: _progress),
              const SizedBox(height: 8),
              Text(
                '${(_progress * 100).toStringAsFixed(1)}%',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 16),
            Text(
              'Note: Models are typically 300MB-2GB. Please ensure you have enough storage and a stable connection.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isDownloading 
              ? () {
                  _cancelToken?.cancel();
                  Navigator.pop(context);
                }
              : () => Navigator.pop(context),
          child: Text(_isDownloading ? 'Cancel' : 'Close'),
        ),
        FilledButton(
          onPressed: _isDownloading ? null : _downloadModel,
          child: Text(_isDownloading ? 'Downloading...' : 'Download'),
        ),
      ],
    );
  }
} 