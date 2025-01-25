import 'package:hive/hive.dart';
import 'chat_message.dart';

part 'saved_chat.g.dart';

@HiveType(typeId: 1)
class SavedChat extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String title;

  @HiveField(2)
  final DateTime timestamp;

  @HiveField(3)
  final List<Map<String, dynamic>> messages;

  SavedChat({
    required this.id,
    required this.title,
    required this.timestamp,
    required this.messages,
  });

  factory SavedChat.fromMessages(List<ChatMessage> messages) {
    final title = _generateTitle(messages);
    return SavedChat(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      timestamp: DateTime.now(),
      messages: messages.map((msg) => msg.toJson()).toList(),
    );
  }

  static String _generateTitle(List<ChatMessage> messages) {
    // Get first user message or use default title
    final firstUserMessage = messages.firstWhere(
      (msg) => msg.isUser,
      orElse: () => ChatMessage(content: 'New Chat', isUser: true),
    );
    
    // Truncate to reasonable length
    String title = firstUserMessage.content;
    if (title.length > 50) {
      title = '${title.substring(0, 47)}...';
    }
    return title;
  }

  List<ChatMessage> get chatMessages {
    return messages.map((json) => ChatMessage.fromJson(json)).toList();
  }
} 