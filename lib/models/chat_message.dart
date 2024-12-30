import 'dart:typed_data';

class ChatMessage {
  final String content;
  final bool isUser;
  final bool isError;
  final Uint8List? imageData;
  final String role;

  ChatMessage({
    required this.content,
    required this.isUser,
    this.isError = false,
    this.imageData,
  }) : role = isUser ? 'user' : 'assistant';

  Map<String, String> toMap() {
    return {
      'role': role,
      'content': content,
    };
  }
}
