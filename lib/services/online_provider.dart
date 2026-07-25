/// Text-only cloud providers supported by Write4Me.
enum OnlineProvider { pollinations, gemini, openrouter }

class OnlineProviderConfig {
  final String label;
  final String description;
  final String baseUrl;
  final String prefsKey;
  final String getKeyUrl;
  final String modelsUrl;

  const OnlineProviderConfig({
    required this.label,
    required this.description,
    required this.baseUrl,
    required this.prefsKey,
    required this.getKeyUrl,
    required this.modelsUrl,
  });

  String get chatUrl => '$baseUrl/chat/completions';
}

const Map<OnlineProvider, OnlineProviderConfig> kOnlineProviders = {
  OnlineProvider.pollinations: OnlineProviderConfig(
    label: 'Pollinations',
    description: 'Text, image, and video',
    baseUrl: 'https://gen.pollinations.ai/v1',
    prefsKey: 'pollination_api_key',
    getKeyUrl: 'https://enter.pollinations.ai',
    modelsUrl: 'https://gen.pollinations.ai/models',
  ),
  OnlineProvider.gemini: OnlineProviderConfig(
    label: 'Gemini',
    description: 'Google AI Studio',
    baseUrl: 'https://generativelanguage.googleapis.com/v1beta/openai',
    prefsKey: 'gemini_api_key',
    getKeyUrl: 'https://aistudio.google.com/apikey',
    modelsUrl: 'https://generativelanguage.googleapis.com/v1beta/openai/models',
  ),
  OnlineProvider.openrouter: OnlineProviderConfig(
    label: 'OpenRouter',
    description: 'One key, many models',
    baseUrl: 'https://openrouter.ai/api/v1',
    prefsKey: 'openrouter_api_key',
    getKeyUrl: 'https://openrouter.ai/keys',
    modelsUrl: 'https://openrouter.ai/api/v1/models?output_modalities=all',
  ),
};

OnlineProvider onlineProviderFromName(String? name) {
  if (name == 'pollinations') return OnlineProvider.pollinations;
  if (name == 'openrouter') return OnlineProvider.openrouter;
  return OnlineProvider.gemini;
}
