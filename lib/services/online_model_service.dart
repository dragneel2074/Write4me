import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:collection/collection.dart'; // For firstWhereOrNull

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
      tools: json['tools'] as bool? ?? false,
      vision: json['input_modalities'].contains('image'),
      audio: json['audio'] as bool? ?? false,
    );
  }
}

class OnlineModelService extends ChangeNotifier {
  static const String _textModelsUrl = 'https://text.pollinations.ai/models';
  static const String _imageModelsUrl = 'https://image.pollinations.ai/models';

  List<OnlineModel> _availableTextModels = [];
  List<OnlineModel> get availableTextModels => _availableTextModels;

  List<String> _availableImageModels = [];
  List<String> get availableImageModels => _availableImageModels;

  OnlineModel? _selectedOnlineModel;
  OnlineModel? get selectedOnlineModel => _selectedOnlineModel;

  String _selectedImageModel = 'flux';
  String get selectedImageModel => _selectedImageModel;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _textErrorMessage;
  String? get textErrorMessage => _textErrorMessage;

  String? _imageErrorMessage;
  String? get imageErrorMessage => _imageErrorMessage;

  Future<String?> _getPollinationToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('pollination_api_key');
  }

  Future<void> fetchModels() async {
    _isLoading = true;
    _textErrorMessage = null;
    _imageErrorMessage = null;
    notifyListeners();

    try {
      await _fetchTextModels();
    } catch (e) {
      _textErrorMessage = 'Error fetching text models: $e';
      debugPrint('Error fetching text models: $e');
    }

    try {
      await _fetchImageModels();
    } catch (e) {
      _imageErrorMessage = 'Error fetching image models: $e';
      debugPrint('Error fetching image models: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _fetchTextModels() async {
    final response = await http.get(Uri.parse(_textModelsUrl));

    if (response.statusCode == 200) {
      final token = await _getPollinationToken();
      final bool hasToken = token != null && token.isNotEmpty;

      final List<dynamic> jsonList = json.decode(response.body);
      _availableTextModels = jsonList.map((json) => OnlineModel.fromJson(json)).where((model) {
        final hasZeroTextInput = model.inputModalities.contains('0 text');
        final hasZeroTextOutput = model.outputModalities.contains('0 text');
        final isAllowedTier = model.tier == "anonymous" || (hasToken && model.tier == "seed");
        return !hasZeroTextInput && !hasZeroTextOutput && isAllowedTier;
      }).toList();
      
      if (_availableTextModels.isNotEmpty && _selectedOnlineModel == null) {
        final gpt4oMini = _availableTextModels.firstWhereOrNull(
          (model) => model.name == 'openai',
        );
        if (gpt4oMini != null) {
          _selectedOnlineModel = gpt4oMini;
        } else {
          _selectedOnlineModel = _availableTextModels.first;
        }
      }
    } else {
      throw Exception('Failed to load text models: ${response.statusCode}');
    }
  }

  Future<void> _fetchImageModels() async {
    final response = await http.get(Uri.parse(_imageModelsUrl));

    if (response.statusCode == 200) {
      final List<dynamic> jsonList = json.decode(response.body);
      _availableImageModels = List<String>.from(jsonList);
    } else {
      throw Exception('Failed to load image models: ${response.statusCode}');
    }
  }

  void setSelectedOnlineModel(OnlineModel? model) {
    _selectedOnlineModel = model;
    notifyListeners();
  }

  void setSelectedImageModel(String modelName) {
    _selectedImageModel = modelName;
    notifyListeners();
  }
}