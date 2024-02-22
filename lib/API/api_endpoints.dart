import 'package:flutter_dotenv/flutter_dotenv.dart';

final Uri completionsEndpoint = Uri.parse('https://openrouter.ai/api/v1/chat/completions');
final openAIApiKey = dotenv.env['OPENAI_API_KEY'];
 final Map<String, String> headers = {
  'Content-Type': 'application/json',
  'Authorization': 'Bearer $openAIApiKey',
};