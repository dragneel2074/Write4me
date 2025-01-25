import 'package:hive_flutter/hive_flutter.dart';
import 'package:write4me/models/chat_message.dart';
import '../models/saved_chat.dart';

class ChatStorageService {
  static const String _boxName = 'saved_chats';
  late Box<SavedChat> _box;

  Future<void> init() async {
    await Hive.initFlutter();
    Hive.registerAdapter(SavedChatAdapter());
    _box = await Hive.openBox<SavedChat>(_boxName);
  }

  Future<void> saveChat(List<ChatMessage> messages) async {
    if (messages.isEmpty) return;
    
    final savedChat = SavedChat.fromMessages(messages);
    await _box.put(savedChat.id, savedChat);
  }

  List<SavedChat> getAllChats() {
    return _box.values.toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  Future<void> deleteChat(String id) async {
    await _box.delete(id);
  }

  SavedChat? getChat(String id) {
    return _box.get(id);
  }
} 