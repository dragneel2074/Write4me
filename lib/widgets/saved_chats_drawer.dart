import 'package:flutter/material.dart';
import '../models/saved_chat.dart';
import '../services/chat_storage_service.dart';
import 'package:timeago/timeago.dart' as timeago;

class SavedChatsDrawer extends StatelessWidget {
  final List<SavedChat> chats;
  final Function(SavedChat) onChatSelected;
  final Function(String) onChatDeleted;

  const SavedChatsDrawer({
    super.key,
    required this.chats,
    required this.onChatSelected,
    required this.onChatDeleted,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.chat_bubble_outline,
                  size: 48,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Saved Chats',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: chats.isEmpty
                ? Center(
                    child: Text(
                      'No saved chats yet',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  )
                : ListView.builder(
                    itemCount: chats.length,
                    itemBuilder: (context, index) {
                      final chat = chats[index];
                      return ListTile(
                        title: Text(
                          chat.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          timeago.format(chat.timestamp),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        leading: const Icon(Icons.chat_bubble_outline),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => onChatDeleted(chat.id),
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          onChatSelected(chat);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
} 