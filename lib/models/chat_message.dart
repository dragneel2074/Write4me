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

  Map<String, dynamic> toJson() => {
    'content': content,
    'isUser': isUser,
    'isError': isError,
    'imageData': imageData?.toList(),
  };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    content: json['content'],
    isUser: json['isUser'],
    isError: json['isError'] ?? false,
    imageData: json['imageData'] != null 
        ? Uint8List.fromList(List<int>.from(json['imageData']))
        : null,
  );
}
