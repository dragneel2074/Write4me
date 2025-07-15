class ModelParameters {
  final int maxTokens;
  final int numGpuLayers;
  final double topP;
  final int contextSize;
  final double temperature;
  final double frequencyPenalty;
  final double presencePenalty;
  final bool vision;

  const ModelParameters({
    this.maxTokens = 512,
    this.numGpuLayers = 99, // Default from OfflineModelService
    this.topP = 1.0,
    this.contextSize = 1024,
    this.temperature = 0.5,
    this.frequencyPenalty = 0.5,
    this.presencePenalty = 0.7,
    this.vision = false,
  });

  ModelParameters copyWith({
    int? maxTokens,
    int? numGpuLayers,
    double? topP,
    int? contextSize,
    double? temperature,
    double? frequencyPenalty,
    double? presencePenalty,
    bool? vision,
  }) {
    return ModelParameters(
      maxTokens: maxTokens ?? this.maxTokens,
      numGpuLayers: numGpuLayers ?? this.numGpuLayers,
      topP: topP ?? this.topP,
      contextSize: contextSize ?? this.contextSize,
      temperature: temperature ?? this.temperature,
      frequencyPenalty: frequencyPenalty ?? this.frequencyPenalty,
      presencePenalty: presencePenalty ?? this.presencePenalty,
      vision: vision ?? this.vision,
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
        'vision': vision,
      };

  // Create from JSON
  factory ModelParameters.fromJson(Map<String, dynamic> json) => ModelParameters(
        maxTokens: json['maxTokens'] as int,
        numGpuLayers: json['numGpuLayers'] as int,
        topP: json['topP'] as double,
        contextSize: json['contextSize'] as int,
        temperature: json['temperature'] as double,
        frequencyPenalty: json['frequencyPenalty'] as double,
        presencePenalty: json['presencePenalty'] as double,
        vision: json['vision'] as bool? ?? false,
      );
}
