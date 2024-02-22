import 'package:write4me/API/requests.dart';

class ChatResponse {
  final String id;
  final String model;
  final int created;
  final String object;
  final List<Choice> choices;
  final Usage usage;

  ChatResponse({
    required this.id,
    required this.model,
    required this.created,
    required this.object,
    required this.choices,
    required this.usage,
  });

  factory ChatResponse.fromJson(Map<String, dynamic> json) => ChatResponse(
        id: json["id"],
        model: json["model"],
        created: json["created"],
        object: json["object"],
        choices: List<Choice>.from(json["choices"].map((x) => Choice.fromJson(x))),
        usage: Usage.fromJson(json["usage"]),
      );
}

class Choice {
  final ChatMessage message;

  Choice({
    required this.message,
  });

  factory Choice.fromJson(Map<String, dynamic> json) => Choice(
        message: ChatMessage(
          role: json["message"]["role"],
          content: json["message"]["content"],
        ),
      );
}

class Usage {
  final int promptTokens;
  final int completionTokens;
  final int totalTokens;

  Usage({
    required this.promptTokens,
    required this.completionTokens,
    required this.totalTokens,
  });

  factory Usage.fromJson(Map<String, dynamic> json) => Usage(
        promptTokens: json["prompt_tokens"],
        completionTokens: json["completion_tokens"],
        totalTokens: json["total_tokens"],
      );
}
