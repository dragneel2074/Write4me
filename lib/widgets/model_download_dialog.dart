import 'package:flutter/material.dart';
import '../services/offline_model_service.dart';
import '../utils/message_utils.dart';
import 'package:disk_space_2/disk_space_2.dart';

// Use HTTP Here DON"T USE DIO. FASTER DOWNLAOD WITH HTTP and OUT OF MEMORY ERRORS WITH DIO
class ModelDownloadDialog extends StatefulWidget {
  final Function(String url, void Function(double) onProgress, String fileName) onDownload;
  final String noteMessage;

  const ModelDownloadDialog({
    super.key,
    required this.onDownload, required this.noteMessage,
  });

  @override
  State<ModelDownloadDialog> createState() => _ModelDownloadDialogState();
}

class _ModelDownloadDialogState extends State<ModelDownloadDialog> {
  final _urlController = TextEditingController();
  final _diskSpacePlugin = DiskSpace();
  bool _isCustomModel = false;
  bool _isDownloading = false;
  double _progress = 0;
  String? _selectedModel;

  // Model sizes in MB
  final Map<String, double> modelSizes = {
    'Qwen-R1 (1.8 GB)': 1800,
    'Qwen-2.5-0.5 (650 MB)': 650,
  };

  @override
  void initState() {
    super.initState();
    _initDiskSpace();
  }

  Future<void> _initDiskSpace() async {
    try {
      await _diskSpacePlugin.getPlatformVersion();
    } catch (e) {
      debugPrint('Error initializing disk space plugin: $e');
    }
  }

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

  Future<bool> _checkStorageSpace(double requiredSpaceMB) async {
    try {
      // Initialize disk space values
      final freeDiskSpace = await DiskSpace.getFreeDiskSpace;
      final totalDiskSpace = await DiskSpace.getTotalDiskSpace;

      if (freeDiskSpace == null || totalDiskSpace == null) {
        debugPrint('Could not get disk space information');
        return true; // Allow download if we can't check space
      }
      
      // Convert MB to GB for display
      final freeSpaceGB = freeDiskSpace / 1024;
      final totalSpaceGB = totalDiskSpace / 1024;
      final requiredSpaceGB = requiredSpaceMB / 1024;
      
      debugPrint('Storage check:');
      debugPrint('- Free space: ${freeSpaceGB.toStringAsFixed(2)} GB');
      debugPrint('- Total space: ${totalSpaceGB.toStringAsFixed(2)} GB');
      debugPrint('- Required space: ${requiredSpaceGB.toStringAsFixed(2)} GB');

      if (freeDiskSpace < requiredSpaceMB) {
        if (!mounted) return false;
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Insufficient Storage'),
            content: Text(
              'This model requires ${requiredSpaceGB.toStringAsFixed(1)} GB of free space.\n\n'
              'Available space: ${freeSpaceGB.toStringAsFixed(1)} GB\n'
              'Total space: ${totalSpaceGB.toStringAsFixed(1)} GB\n\n'
              'Please free up some space before downloading.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        return false;
      }

      // Warn if free space is less than 2x the model size
      if (freeDiskSpace < requiredSpaceMB * 2) {
        if (!mounted) return false;
        final shouldContinue = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Low Storage Warning'),
            content: Text(
              'You have ${freeSpaceGB.toStringAsFixed(1)} GB free space, which is less than '
              'recommended for this ${requiredSpaceGB.toStringAsFixed(1)} GB model.\n\n'
              'It\'s recommended to have at least ${(requiredSpaceGB * 2).toStringAsFixed(1)} GB '
              'free space for optimal performance.\n\n'
              'Do you want to continue?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Continue Anyway'),
              ),
            ],
          ),
        );
        return shouldContinue ?? false;
      }

      return true;
    } catch (e) {
      debugPrint('Error checking storage space: $e');
      // If we can't check space, allow the download but log the error
      return true;
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

    final modelSize = modelSizes[_selectedModel] ?? 0;
    if (!await _checkStorageSpace(modelSize)) return;

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
            Text(widget.noteMessage),
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