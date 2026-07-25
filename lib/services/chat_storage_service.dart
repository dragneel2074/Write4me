import 'package:hive_flutter/hive_flutter.dart';
import 'package:write4me/models/chat_message.dart';
import '../models/saved_chat.dart';

class ChatStorageService {
  static const String _boxName = 'saved_chats';
  late Box<SavedChat> _box;

  Future<void> init() async {
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(SavedChatAdapter());
    }
    _box = Hive.isBoxOpen(_boxName)
        ? Hive.box<SavedChat>(_boxName)
        : await Hive.openBox<SavedChat>(_boxName);
  }

  Future<SavedChat?> saveChat(List<ChatMessage> messages, {String? id}) async {
    if (messages.isEmpty) return null;

    final savedChat = SavedChat.fromMessages(messages, id: id);
    await _box.put(savedChat.id, savedChat);
    return savedChat;
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
