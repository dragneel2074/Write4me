import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'online_provider.dart';

class OnlineModel {
  final String name;
  final String description;
  final String provider;
  final List<String> inputModalities;
  final List<String> outputModalities;
  final String tier;
  final bool tools;
  final int? contextWindow;

  const OnlineModel({
    required this.name,
    required this.description,
    required this.provider,
    this.inputModalities = const ['text'],
    this.outputModalities = const ['text'],
    this.tier = '',
    this.tools = false,
    this.contextWindow,
  });

  bool supportsOutput(String modality) =>
      outputModalities.any((item) => item.toLowerCase() == modality);
  bool get vision => inputModalities.contains('image');
  bool get audio =>
      inputModalities.contains('audio') || outputModalities.contains('audio');
}

class OnlineModelService extends ChangeNotifier {
  static const _activeProviderKey = 'active_online_provider';
  static const _selectedModelPrefix = 'selected_online_model_';

  OnlineProvider _activeProvider = OnlineProvider.gemini;
  OnlineProvider get activeProvider => _activeProvider;
  OnlineProviderConfig get activeProviderConfig =>
      kOnlineProviders[_activeProvider]!;

  List<OnlineModel> _availableModels = const [];
  List<OnlineModel> get availableModels => _availableModels;
  List<OnlineModel> get availableTextModels => modelsForOutput('text');
  List<OnlineModel> modelsForOutput(String output) =>
      _availableModels.where((model) => model.supportsOutput(output)).toList();

  final Map<String, OnlineModel> _selectedModels = {};
  OnlineModel? get selectedOnlineModel => selectedModelForOutput('text');
  OnlineModel? selectedModelForOutput(String output) => _selectedModels[output];
  bool _isLoading = false;
  bool get isLoading => _isLoading;
  bool _hasLoadedModels = false;
  bool get hasLoadedModels => _hasLoadedModels;
  String? _textErrorMessage;
  String? get textErrorMessage => _textErrorMessage;
  String? get imageErrorMessage => _textErrorMessage;
  List<String> get availableImageModels =>
      modelsForOutput('image').map((model) => model.name).toList();
  String get selectedImageModel => selectedModelForOutput('image')?.name ?? '';

  Future<void> loadActiveProvider() async {
    final prefs = await SharedPreferences.getInstance();
    _activeProvider =
        onlineProviderFromName(prefs.getString(_activeProviderKey));
    notifyListeners();
  }

  Future<void> fetchModels() async {
    final key = (await getApiKey(_activeProvider))?.trim() ?? '';
    if (key.isEmpty) {
      _textErrorMessage =
          'Enter and save a ${activeProviderConfig.label} API key first.';
      _availableModels = const [];
      _selectedModels.clear();
      _hasLoadedModels = false;
      notifyListeners();
      return;
    }
    _isLoading = true;
    _textErrorMessage = null;
    notifyListeners();
    try {
      final config = activeProviderConfig;
      final headers = <String, String>{'Accept': 'application/json'};
      final uri = Uri.parse(config.modelsUrl);
      headers['Authorization'] = 'Bearer $key';
      final response = await http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 30));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('Model API returned ${response.statusCode}');
      }
      final decoded = jsonDecode(response.body);
      _availableModels = switch (_activeProvider) {
        OnlineProvider.gemini => _parseGemini(decoded),
        OnlineProvider.openrouter => _parseOpenRouter(decoded),
        OnlineProvider.pollinations => _parsePollinations(decoded),
      };
      _hasLoadedModels = true;
      final prefs = await SharedPreferences.getInstance();
      _selectedModels.clear();
      for (final output in const ['text', 'image', 'video']) {
        final candidates = modelsForOutput(output);
        if (candidates.isEmpty) continue;
        final saved = prefs
            .getString('$_selectedModelPrefix${_activeProvider.name}_$output');
        final savedModels =
            candidates.where((model) => model.name == saved).toList();
        if (savedModels.isNotEmpty) {
          _selectedModels[output] = savedModels.first;
        }
      }
    } catch (error) {
      _textErrorMessage = 'Could not load models: $error';
      _availableModels = const [];
      _selectedModels.clear();
      _hasLoadedModels = false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  List<OnlineModel> _parseGemini(dynamic json) {
    final list = json is Map ? (json['data'] ?? json['models']) : null;
    if (list is! List) return const [];
    return list
        .whereType<Map>()
        .map((item) {
          final raw = (item['id'] ?? item['baseModelId'] ?? item['name'] ?? '')
              .toString();
          final id = raw.replaceFirst('models/', '');
          return OnlineModel(
            name: id,
            description: (item['display_name'] ??
                    item['displayName'] ??
                    item['name'] ??
                    id)
                .toString(),
            provider: 'gemini',
            inputModalities: const ['text'],
            outputModalities: const ['text'],
            contextWindow:
                _integer(item['inputTokenLimit'] ?? item['context_length']),
          );
        })
        .where((model) => model.name.isNotEmpty)
        .toList();
  }

  List<OnlineModel> _parseOpenRouter(dynamic json) {
    final list = json is Map ? json['data'] : null;
    if (list is! List) return const [];
    return list
        .whereType<Map>()
        .map((item) {
          final architecture = item['architecture'];
          final arch = architecture is Map ? architecture : const {};
          return OnlineModel(
            name: (item['id'] ?? '').toString(),
            description: (item['name'] ?? item['id'] ?? '').toString(),
            provider: 'openrouter',
            inputModalities:
                _strings(arch['input_modalities'] ?? arch['inputModalities']),
            outputModalities:
                _strings(arch['output_modalities'] ?? arch['outputModalities']),
            contextWindow:
                _integer(item['context_length'] ?? item['contextWindow']),
          );
        })
        .where((model) => model.name.isNotEmpty)
        .toList();
  }

  List<OnlineModel> _parsePollinations(dynamic json) {
    final dynamic rawList = json is List
        ? json
        : (json is Map ? (json['data'] ?? json['models']) : null);
    if (rawList is! List) return const [];
    return rawList
        .map((raw) {
          if (raw is String) {
            return OnlineModel(
              name: raw,
              description: raw,
              provider: 'pollinations',
            );
          }
          if (raw is! Map) return null;
          final id =
              (raw['id'] ?? raw['name'] ?? raw['model'] ?? '').toString();
          var outputs = _strings(raw['outputModalities'] ??
              raw['output_modalities'] ??
              raw['outputs']);
          final type =
              (raw['type'] ?? raw['category'] ?? '').toString().toLowerCase();
          if (outputs.isEmpty) {
            outputs = [
              if (type.contains('video'))
                'video'
              else if (type.contains('image'))
                'image'
              else
                'text'
            ];
          }
          return OnlineModel(
            name: id,
            description:
                (raw['title'] ?? raw['displayName'] ?? raw['description'] ?? id)
                    .toString(),
            provider: 'pollinations',
            inputModalities: _strings(raw['inputModalities'] ??
                raw['input_modalities'] ??
                raw['inputs']),
            outputModalities: outputs,
            tier: raw['paid_only'] == true ? 'paid' : 'standard',
            tools: raw['tools'] == true,
            contextWindow: _integer(raw['context_length'] ??
                raw['contextWindow'] ??
                raw['inputTokenLimit']),
          );
        })
        .whereType<OnlineModel>()
        .where((model) => model.name.isNotEmpty)
        .toList();
  }

  static List<String> _strings(dynamic value) {
    if (value is List) {
      return value.map((item) => item.toString().toLowerCase()).toList();
    }
    if (value is String && value.isNotEmpty) return [value.toLowerCase()];
    return const [];
  }

  static int? _integer(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  Future<void> setActiveProvider(OnlineProvider provider) async {
    if (_activeProvider == provider) return;
    _activeProvider = provider;
    _availableModels = const [];
    _selectedModels.clear();
    _hasLoadedModels = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activeProviderKey, provider.name);
    notifyListeners();
  }

  Future<String?> getApiKey(OnlineProvider provider) async {
    final prefs = await SharedPreferences.getInstance();
    if (provider == OnlineProvider.gemini) {
      return prefs.getString(kOnlineProviders[provider]!.prefsKey) ??
          prefs.getString('google_api_key');
    }
    return prefs.getString(kOnlineProviders[provider]!.prefsKey);
  }

  Future<bool> hasApiKey(OnlineProvider provider) async =>
      (await getApiKey(provider))?.trim().isNotEmpty == true;

  Future<bool> hasPollinationApiKey() => hasApiKey(OnlineProvider.pollinations);

  Future<void> setApiKey(OnlineProvider provider, String key) async {
    final prefs = await SharedPreferences.getInstance();
    final value = key.trim();
    if (value.isEmpty) {
      await prefs.remove(kOnlineProviders[provider]!.prefsKey);
    } else {
      await prefs.setString(kOnlineProviders[provider]!.prefsKey, value);
    }
    _availableModels = const [];
    _selectedModels.clear();
    _hasLoadedModels = false;
    _textErrorMessage = null;
    notifyListeners();
  }

  Future<void> setPollinationApiKey(String key) =>
      setApiKey(OnlineProvider.pollinations, key);

  void setSelectedImageModel(String modelName) {
    final candidates = modelsForOutput('image');
    final match = candidates.where((model) => model.name == modelName);
    if (match.isNotEmpty) setSelectedModelForOutput(match.first, 'image');
  }

  Future<void> setSelectedOnlineModel(OnlineModel model) async {
    final output = model.outputModalities.firstWhere(
      (item) => const ['text', 'image', 'video'].contains(item),
      orElse: () => 'text',
    );
    await setSelectedModelForOutput(model, output);
  }

  Future<void> setSelectedModelForOutput(
      OnlineModel model, String output) async {
    _selectedModels[output] = model;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        '$_selectedModelPrefix${_activeProvider.name}_$output', model.name);
    notifyListeners();
  }
}
