class ChatRequest {
  final String model;
  final int maxTokens;
  final double temperature;
  final List<ChatMessage> messages;

  ChatRequest({
    required this.model,
    required this.maxTokens,
    required this.temperature,
    required this.messages,
  });

  Map<String, dynamic> toJson() => {
        "model": model,
        "max_tokens": maxTokens,
        "temperature": temperature,
        "messages": messages.map((message) => message.toJson()).toList(),
      };
}

class ChatMessage {
  final String role;
  final String content;

  ChatMessage({
    required this.role,
    required this.content,
  });

  Map<String, dynamic> toJson() => {
        "role": role,
        "content": content,
      };
}
