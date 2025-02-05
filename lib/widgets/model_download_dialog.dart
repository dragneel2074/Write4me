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
  bool _isCustomModel = false;
  bool _isDownloading = false;
  double _progress = 0;
  String? _selectedModel;

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  String _extractModelNameFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final pathSegments = uri.pathSegments;

      // Extract the file name from the URL
      final fileName = pathSegments.last.replaceAll('.gguf', '');

      // Split the file name by '-' and take the first two parts
      final parts = fileName.split('-');
      if (parts.length >= 2) {
        // Check if the second part contains 'b' (e.g., 1.1b, 2-9b)
        if (parts[1].toLowerCase().contains('b')) {
          return '${parts[0]}-${parts[1]}';
        } else {
          return '${parts[0]}-${parts[1]}';
        }
      } else {
        // If the file name doesn't follow the expected pattern, return the file name as is
        return fileName;
      }
    } catch (e) {
      debugPrint('Error extracting model name: $e');
      return 'model';
    }
  }

  bool _validateUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.host == 'huggingface.co' && uri.path.endsWith('.gguf');
    } catch (e) {
      return false;
    }
  }

  void _startDownload() async {
    String url;
    String fileName;

    if (_isCustomModel) {
      if (_urlController.text.isEmpty) return;
      url = _urlController.text;

      if (!_validateUrl(url)) {
        MessageUtils.showError(context, 'Invalid URL. Must be a Hugging Face GGUF file.');
        return;
      }

      fileName = _extractModelNameFromUrl(url);
      if (!fileName.toLowerCase().endsWith('.gguf')) {
        fileName = '$fileName.gguf';
      }

      debugPrint('Starting custom model download:');
      debugPrint('URL: $url');
      debugPrint('Filename: $fileName');
    } else {
      if (_selectedModel == null) return;
      url = OfflineModelService.defaultModels[_selectedModel!]!;
      fileName = '${_selectedModel!.toLowerCase()}.gguf';
      debugPrint('Starting default model download:');
      debugPrint('Model: $_selectedModel');
      debugPrint('URL: $url');
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
            if (progress >= 1.0) {
              downloadCompleted = true;
            }
          }
        },
        fileName,
      );

      debugPrint('Download process finished. Completed: $downloadCompleted');

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
      debugPrint('Error in download process: $e');

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