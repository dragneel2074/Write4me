import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:write4me/widgets/model_download_dialog.dart';
import '../theme/theme_provider.dart';
import 'package:http/http.dart' as http;
import '../services/offline_model_service.dart';
import 'dart:io';

class SettingsDialog extends StatefulWidget {
  final VoidCallback onSaveChat;
  final VoidCallback onClearChat;
  final VoidCallback onShowInfo;
  final bool hasMessages;

  const SettingsDialog({
    super.key,
    required this.onSaveChat,
    required this.onClearChat,
    required this.onShowInfo,
    required this.hasMessages,
  });

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  final TextEditingController _apiKeyController = TextEditingController();
  bool _isApiKeyVisible = false;
  bool _isValidating = false;
  bool _hasChanges = false;
  bool _isOfflineMode = false;
  String _selectedModel = '';

  @override
  void initState() {
    super.initState();
    _loadApiKey();
    _loadSettings();
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<void> _loadApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    final apiKey = prefs.getString('jina_api_key') ?? '';
    _apiKeyController.text = apiKey;
  }

  Future<bool> _validateJinaApiKey(String apiKey) async {
    try {
      final response = await http.get(
        Uri.parse('https://s.jina.ai/When%20was%20Jina%20AI%20founded?count=3'),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'X-Retain-Images': 'none',
          'X-Return-Format': 'text',
        },
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error validating API key: $e');
      return false;
    }
  }

  Future<void> _saveApiKey() async {
    if (!_hasChanges) return;

    setState(() => _isValidating = true);
    
    final isValid = await _validateJinaApiKey(_apiKeyController.text);
    
    if (!mounted) return;

    if (isValid) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('jina_api_key', _apiKeyController.text);
      if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('API key validated and saved successfully')),
      );
      }
      setState(() => _hasChanges = false);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid API key. Please check and try again'),
          backgroundColor: Colors.red,
        ),
      );
    }
    
    setState(() => _isValidating = false);
  }

  Future<void> _launchJinaWebsite() async {
    final Uri url = Uri.parse('https://jina.ai/#apiform');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open website')),
        );
      }
    }
  }

  Future<void> _loadSettings() async {
    final offlineService = context.read<OfflineModelService>();
    setState(() {
      _isOfflineMode = offlineService.isOfflineMode;
      _selectedModel = offlineService.selectedModelPath;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<OfflineModelService>(
      builder: (context, offlineService, child) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.settings,
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Settings',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                // Content
                Flexible(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Chat Section
                          _buildSectionHeader(context, 'Chat'),
                          Card(
                            child: Column(
                              children: [
                                ListTile(
                                  leading: const Icon(Icons.save),
                                  title: const Text('Save Current Chat'),
                                  enabled: widget.hasMessages,
                                  onTap: widget.onSaveChat,
                                ),
                                const Divider(height: 1),
                                ListTile(
                                  leading: const Icon(Icons.add_circle_outline),
                                  title: const Text('New Chat'),
                                  enabled: widget.hasMessages,
                                  onTap: () {
                                    Navigator.pop(context);
                                    widget.onClearChat();
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Model Settings Section
                          _buildSectionHeader(context, 'Model Settings'),
                          Card(
                            child: Column(
                              children: [
                                // Theme Switch
                                Consumer<ThemeProvider>(
                                  builder: (context, themeProvider, child) {
                                    return SwitchListTile(
                                      title: const Text('Dark Theme'),
                                      secondary: const Icon(Icons.dark_mode),
                                      value: themeProvider.isDarkMode,
                                      onChanged: (value) {
                                        themeProvider.toggleTheme();
                                      },
                                    );
                                  },
                                ),
                                const Divider(height: 1),
                                // Offline Mode Switch
                                SwitchListTile(
                                  title: const Text('Offline Mode'),
                                  subtitle: Text(
                                    offlineService.isOfflineMode
                                      ? 'Using: ${offlineService.currentModelName}'
                                      : 'No data leaves your device.'
                                  ),
                                  secondary: const Icon(Icons.offline_bolt),
                                  value: offlineService.isOfflineMode,
                                  onChanged: (value) async {
                                    if (value && offlineService.availableModels.isEmpty) {
                                      final download = await _showDownloadDialog(context);
                                      if (download == true && context.mounted) {
                                        await showDialog(
                                          context: context,
                                          barrierDismissible: false,
                                          builder: (context) => const ModelDownloadDialog(),
                                        );
                                      }
                                    }
                                    await offlineService.setOfflineMode(value);
                                  },
                                ),
                                if (offlineService.isOfflineMode || offlineService.useLocalModel) ...[
                                  const Divider(height: 1),
                                  Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Available Models',
                                          style: Theme.of(context).textTheme.titleSmall,
                                        ),
                                        const SizedBox(height: 8),
                                        ...offlineService.availableModels.map((model) => 
                                          _buildModelTile(context, model, offlineService),
                                        ),
                                        const SizedBox(height: 16),
                                        SizedBox(
                                          width: double.infinity,
                                          child: FilledButton.icon(
                                            icon: const Icon(Icons.download),
                                            label: const Text('Download Additional Model'),
                                            onPressed: () => showDialog(
                                              context: context,
                                              builder: (_) => const ModelDownloadDialog(),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // Footer
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildModelTile(BuildContext context, File model, OfflineModelService service) {
    final modelName = model.path.split('/').last.replaceAll('.gguf', '');
    final isSelected = model.path == service.selectedModelPath;

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
          groupValue: service.selectedModelPath,
          onChanged: (value) {
            if (value != null) service.setSelectedModel(value);
          },
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline),
          onPressed: () => _showDeleteDialog(context, model, service),
        ),
      ),
    );
  }

  Future<bool?> _showDownloadDialog(BuildContext context) {
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

  Future<void> _showDeleteDialog(
    BuildContext context, 
    File model, 
    OfflineModelService service,
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

    if (confirm == true && context.mounted) {
      try {
        await service.deleteModel(model.path);
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
} 