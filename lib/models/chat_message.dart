import 'dart:typed_data';

class ChatAttachment {
  final String name;
  final String type;

  const ChatAttachment({required this.name, required this.type});

  Map<String, dynamic> toJson() => {'name': name, 'type': type};

  factory ChatAttachment.fromJson(Map<String, dynamic> json) => ChatAttachment(
        name: json['name']?.toString() ?? 'Attachment',
        type: json['type']?.toString() ?? 'file',
      );
}

class ChatMessage {
  final String content;
  final bool isUser;
  final bool isError;
  final Uint8List? imageData;
  final String role;
  final List<ChatAttachment> attachments;

  ChatMessage({
    required this.content,
    required this.isUser,
    this.isError = false,
    this.imageData,
    this.attachments = const [],
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
        'attachments': attachments.map((item) => item.toJson()).toList(),
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        content: json['content'],
        isUser: json['isUser'],
        isError: json['isError'] ?? false,
        imageData: json['imageData'] != null
            ? Uint8List.fromList(List<int>.from(json['imageData']))
            : null,
        attachments: (json['attachments'] as List<dynamic>? ?? const [])
            .whereType<Map>()
            .map((item) =>
                ChatAttachment.fromJson(Map<String, dynamic>.from(item)))
            .toList(),
      );
}
