class ModelParameters {
  final int maxTokens;
  final int numGpuLayers;
  final double topP;
  final int contextSize;
  final double temperature;
  final double frequencyPenalty;
  final double presencePenalty;
  final double repeatPenalty;
  final int topK;
  final double minP;
  final bool vision;
  final int autoUnloadSeconds;

  const ModelParameters({
    this.maxTokens = 256,
    this.numGpuLayers = 99, // Default from OfflineModelService
    this.topP = 0.9,
    this.contextSize = 2048,
    this.temperature = 0.7,
    this.frequencyPenalty = 0.0,
    this.presencePenalty = 0.0,
    this.repeatPenalty = 1.1,
    this.topK = 40,
    this.minP = 0.05,
    this.vision = false,
    this.autoUnloadSeconds = 300,
  });

  ModelParameters copyWith({
    int? maxTokens,
    int? numGpuLayers,
    double? topP,
    int? contextSize,
    double? temperature,
    double? frequencyPenalty,
    double? presencePenalty,
    double? repeatPenalty,
    int? topK,
    double? minP,
    bool? vision,
    int? autoUnloadSeconds,
  }) {
    return ModelParameters(
      maxTokens: maxTokens ?? this.maxTokens,
      numGpuLayers: numGpuLayers ?? this.numGpuLayers,
      topP: topP ?? this.topP,
      contextSize: contextSize ?? this.contextSize,
      temperature: temperature ?? this.temperature,
      frequencyPenalty: frequencyPenalty ?? this.frequencyPenalty,
      presencePenalty: presencePenalty ?? this.presencePenalty,
      repeatPenalty: repeatPenalty ?? this.repeatPenalty,
      topK: topK ?? this.topK,
      minP: minP ?? this.minP,
      vision: vision ?? this.vision,
      autoUnloadSeconds: autoUnloadSeconds ?? this.autoUnloadSeconds,
    );
  }

  // Convert to JSON for SharedPreferences
  Map<String, dynamic> toJson() => {
        'maxTokens': maxTokens,
        'numGpuLayers': numGpuLayers,
        'topP': topP,
        'contextSize': contextSize,
        'temperature': temperature,
        'frequencyPenalty': frequencyPenalty,
        'presencePenalty': presencePenalty,
        'repeatPenalty': repeatPenalty,
        'topK': topK,
        'minP': minP,
        'vision': vision,
        'autoUnloadSeconds': autoUnloadSeconds,
      };

  // Create from JSON
  factory ModelParameters.fromJson(Map<String, dynamic> json) =>
      ModelParameters(
        maxTokens: (json['maxTokens'] as num?)?.toInt() ?? 256,
        numGpuLayers: (json['numGpuLayers'] as num?)?.toInt() ?? 99,
        topP: (json['topP'] as num?)?.toDouble() ?? 0.9,
        contextSize: (json['contextSize'] as num?)?.toInt() ?? 2048,
        temperature: (json['temperature'] as num?)?.toDouble() ?? 0.7,
        frequencyPenalty: (json['frequencyPenalty'] as num?)?.toDouble() ?? 0.0,
        presencePenalty: (json['presencePenalty'] as num?)?.toDouble() ?? 0.0,
        repeatPenalty: (json['repeatPenalty'] as num?)?.toDouble() ?? 1.1,
        topK: (json['topK'] as num?)?.toInt() ?? 40,
        minP: (json['minP'] as num?)?.toDouble() ?? 0.05,
        vision: json['vision'] as bool? ?? false,
        autoUnloadSeconds: (json['autoUnloadSeconds'] as num?)?.toInt() ?? 300,
      );
}
