import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class OnlineModel {
  final String name;
  final String description;
  final String provider;
  final String tier;
  final List<String> inputModalities;
  final List<String> outputModalities;
  final bool tools;
  final bool vision;
  final bool audio;

  OnlineModel({
    required this.name,
    required this.description,
    required this.provider,
    required this.tier,
    required this.inputModalities,
    required this.outputModalities,
    required this.tools,
    required this.vision,
    required this.audio,
  });

  factory OnlineModel.fromJson(Map<String, dynamic> json) {
    return OnlineModel(
      name: json['name'] as String,
      description: json['description'] as String,
      provider: json['provider'] as String,
      tier: json['tier'] as String,
      inputModalities: List<String>.from(json['input_modalities'] as List),
      outputModalities: List<String>.from(json['output_modalities'] as List),
      tools: json['tools'] as bool,
      vision: json['vision'] as bool,
      audio: json['audio'] as bool,
    );
  }
}

class OnlineModelService extends ChangeNotifier {
  static const String _modelsUrl = 'https://text.pollinations.ai/models';

  List<OnlineModel> _availableOnlineModels = [];
  List<OnlineModel> get availableOnlineModels => _availableOnlineModels;

  OnlineModel? _selectedOnlineModel;
  OnlineModel? get selectedOnlineModel => _selectedOnlineModel;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  Future<void> fetchAndFilterModels() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await http.get(Uri.parse(_modelsUrl));

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = json.decode(response.body);
        _availableOnlineModels = jsonList.map((json) => OnlineModel.fromJson(json)).where((model) {
          // Filter out models where input_modalities or output_modalities contain "0 text"
          final hasZeroTextInput = model.inputModalities.contains('0 text');
          final hasZeroTextOutput = model.outputModalities.contains('0 text');
          return !hasZeroTextInput && !hasZeroTextOutput && model.tier == "anonymous";
        }).toList();
        
        // Optionally, set a default selected model if available
        if (_availableOnlineModels.isNotEmpty && _selectedOnlineModel == null) {
          _selectedOnlineModel = _availableOnlineModels.first;
        }

      } else {
        _errorMessage = 'Failed to load models: ${response.statusCode}';
        debugPrint('Failed to load models: ${response.statusCode}');
      }
    } catch (e) {
      _errorMessage = 'Error fetching models: $e';
      debugPrint('Error fetching models: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setSelectedOnlineModel(OnlineModel? model) {
    _selectedOnlineModel = model;
    notifyListeners();
  }
}