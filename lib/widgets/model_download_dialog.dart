import 'package:flutter/material.dart';
import '../services/offline_model_service.dart';
import '../utils/message_utils.dart';

class ModelDownloadDialog extends StatefulWidget {
  final Function(String url, void Function(double) onProgress, String fileName) onDownload;

  const ModelDownloadDialog({
    super.key,
    required this.onDownload,
  });

  @override
  State<ModelDownloadDialog> createState() => _ModelDownloadDialogState();
}

class _ModelDownloadDialogState extends State<ModelDownloadDialog> {
  final _urlController = TextEditingController();
  final _fileNameController = TextEditingController();
  bool _isCustomModel = false;
  bool _isDownloading = false;
  double _progress = 0;
  String? _selectedModel;

  @override
  void dispose() {
    _urlController.dispose();
    _fileNameController.dispose();
    super.dispose();
  }

  String _getErrorMessage(dynamic error) {
    // Log the actual error for debugging
    debugPrint('Download error details: $error');
    
    // Return a simple message to the user
    return 'Error downloading the model';
  }

  void _startDownload() async {
    String url;
    String fileName;

    if (_isCustomModel) {
      if (_urlController.text.isEmpty || _fileNameController.text.isEmpty) return;
      url = _urlController.text;
      fileName = _fileNameController.text;
    } else {
      if (_selectedModel == null) return;
      url = OfflineModelService.defaultModels[_selectedModel!]!;
      fileName = '${_selectedModel!.toLowerCase()}.gguf';
    }

    setState(() {
      _isDownloading = true;
      _progress = 0;
    });

    try {
      bool downloadCompleted = false;
      
      await widget.onDownload(
        url,
        (progress) {
          if (mounted) {
            setState(() {
              _progress = progress;
            });
            // Mark as completed only if we reach 100%
            if (progress >= 1.0) {
              downloadCompleted = true;
            }
          }
        },
        fileName,
      );

      // Only show success and close dialog if download actually completed
      if (mounted && downloadCompleted) {
        Navigator.pop(context);
        MessageUtils.showSuccess(context, 'Model downloaded successfully');
      } else if (mounted) {
        setState(() {
          _isDownloading = false;
          _progress = 0;
        });
        MessageUtils.showError(
          context, 
          'Error downloading the model',
          onRetry: _startDownload,
        );
      }
    } catch (e) {
      MessageUtils.logError('Model download failed', e);
      
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _progress = 0;
        });
        
        MessageUtils.showError(
          context, 
          'Error downloading the model',
          onRetry: _startDownload,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Download Model'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Model type selector
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: false,
                  label: Text('Predefined Models'),
                ),
                ButtonSegment(
                  value: true,
                  label: Text('Custom Model'),
                ),
              ],
              selected: {_isCustomModel},
              onSelectionChanged: (value) {
                setState(() {
                  _isCustomModel = value.first;
                });
              },
            ),
            const SizedBox(height: 16),
            
            // Predefined models dropdown or custom model input
            if (_isCustomModel) ...[
              TextField(
                controller: _urlController,
                decoration: const InputDecoration(
                  labelText: 'Model URL',
                  hintText: 'Enter the URL of the GGUF model',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _fileNameController,
                decoration: const InputDecoration(
                  labelText: 'File Name',
                  hintText: 'Enter the name for the model file',
                ),
              ),
            ] else ...[
              DropdownButtonFormField<String>(
                value: _selectedModel,
                decoration: const InputDecoration(
                  labelText: 'Select Model',
                ),
                items: OfflineModelService.defaultModels.keys.map((String model) {
                  return DropdownMenuItem<String>(
                    value: model,
                    child: Text(model),
                  );
                }).toList(),
                onChanged: (String? value) {
                  setState(() {
                    _selectedModel = value;
                  });
                },
              ),
            ],
            
            if (_isDownloading) ...[
              const SizedBox(height: 16),
              LinearProgressIndicator(value: _progress),
              Text('${(_progress * 100).toStringAsFixed(1)}%'),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isDownloading ? null : _startDownload,
          child: const Text('Download'),
        ),
      ],
    );
  }
} 