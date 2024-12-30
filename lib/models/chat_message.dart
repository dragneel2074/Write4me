import 'dart:typed_data';

class ChatMessage {
  final String content;
  final bool isUser;
  final bool isError;
  final Uint8List? imageData;

  ChatMessage({
    required this.content,
    required this.isUser,
    this.isError = false,
    this.imageData,
  });
}
