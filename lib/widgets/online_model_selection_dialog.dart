import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/service_providers.dart';
import '../services/online_provider.dart';
import '../services/online_model_service.dart';

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
                        _ProviderKeysSection(service: onlineModelService),
                        const Divider(),
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
                                onlineModelService
                                    .setSelectedOnlineModel(model);
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
                                    if (model.inputModalities
                                        .contains('image')) ...[
                                      const SizedBox(width: 4),
                                      const Icon(Icons.image, size: 16),
                                    ]
                                  ],
                                ),
                                subtitle: Text(model.description),
                                trailing: isSelected
                                    ? const Icon(Icons.check_circle)
                                    : null,
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
                        ...onlineModelService.availableImageModels
                            .map((modelName) {
                          final isSelected =
                              onlineModelService.selectedImageModel ==
                                  modelName;
                          final isGptImage =
                              modelName.toLowerCase() == 'gptimage';
                          return Card(
                            margin: const EdgeInsets.only(top: 8, bottom: 8),
                            color: isSelected
                                ? Theme.of(context).colorScheme.primaryContainer
                                : isGptImage
                                    ? Theme.of(context).disabledColor
                                    : null,
                            child: ListTile(
                              title: Text(modelName),
                              trailing: isSelected
                                  ? const Icon(Icons.check_circle)
                                  : null,
                              onTap: isGptImage
                                  ? null
                                  : () async {
                                      if (modelName.toLowerCase() ==
                                          'kontext') {
                                        final hasKey = await onlineModelService
                                            .hasPollinationApiKey();
                                        if (!hasKey) {
                                          // Show dialog to prompt for API key
                                          final TextEditingController
                                              apiKeyController =
                                              TextEditingController();
                                          // ignore: use_build_context_synchronously
                                          await showDialog(
                                            context: context,
                                            builder:
                                                (BuildContext dialogContext) {
                                              return AlertDialog(
                                                title: const Text(
                                                    'Enter Pollination API Key'),
                                                content: TextField(
                                                  controller: apiKeyController,
                                                  decoration:
                                                      const InputDecoration(
                                                    hintText: 'API Key',
                                                  ),
                                                ),
                                                actions: <Widget>[
                                                  TextButton(
                                                    child: const Text('Cancel'),
                                                    onPressed: () {
                                                      Navigator.of(
                                                              dialogContext)
                                                          .pop();
                                                    },
                                                  ),
                                                  TextButton(
                                                    child: const Text('Save'),
                                                    onPressed: () async {
                                                      if (apiKeyController
                                                          .text.isNotEmpty) {
                                                        await onlineModelService
                                                            .setPollinationApiKey(
                                                                apiKeyController
                                                                    .text);
                                                        // ignore: use_build_context_synchronously
                                                        Navigator.of(
                                                                dialogContext)
                                                            .pop();
                                                        onlineModelService
                                                            .setSelectedImageModel(
                                                                modelName);
                                                        // ignore: use_build_context_synchronously
                                                        Navigator.pop(
                                                            context); // Close main dialog
                                                      }
                                                    },
                                                  ),
                                                ],
                                              );
                                            },
                                          );
                                        } else {
                                          onlineModelService
                                              .setSelectedImageModel(modelName);
                                          Navigator.pop(
                                              context); // Close dialog after selection
                                        }
                                      } else {
                                        onlineModelService
                                            .setSelectedImageModel(modelName);
                                        Navigator.pop(
                                            context); // Close dialog after selection
                                      }
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

/// Lets the user pick the active online provider and enter its API key.
/// Pollinations' free/keyless API is gone — every provider now needs a key.
class _ProviderKeysSection extends StatefulWidget {
  final OnlineModelService service;
  const _ProviderKeysSection({required this.service});

  @override
  State<_ProviderKeysSection> createState() => _ProviderKeysSectionState();
}

class _ProviderKeysSectionState extends State<_ProviderKeysSection> {
  final _keyController = TextEditingController();
  OnlineProvider? _provider;

  @override
  void initState() {
    super.initState();
    _provider = widget.service.activeProvider;
    _loadKey();
  }

  Future<void> _loadKey() async {
    final key = await widget.service.getApiKey(_provider!);
    if (mounted) _keyController.text = key ?? '';
  }

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = kOnlineProviders[_provider]!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Provider & API Key',
            style: TextStyle(fontWeight: FontWeight.bold)),
        ...OnlineProvider.values.map((p) {
          return RadioListTile<OnlineProvider>(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(kOnlineProviders[p]!.label),
            value: p,
            groupValue: _provider,
            onChanged: (value) async {
              if (value == null) return;
              await widget.service.setActiveProvider(value);
              setState(() => _provider = value);
              await _loadKey();
            },
          );
        }),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _keyController,
                obscureText: true,
                decoration: InputDecoration(
                  hintText: '${config.label} API key',
                  isDense: true,
                ),
              ),
            ),
            TextButton(
              onPressed: () async {
                await widget.service.setApiKey(_provider!, _keyController.text);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${config.label} key saved')),
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: () => launchUrl(
              Uri.parse(config.getKeyUrl),
              mode: LaunchMode.externalApplication,
            ),
            child: Text('Get a ${config.label} key'),
          ),
        ),
      ],
    );
  }
}
