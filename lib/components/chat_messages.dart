import 'package:flutter/material.dart';
import '../models/chat_message.dart';
import 'message_bubble.dart';

class ChatMessages extends StatelessWidget {
  final List<ChatMessage> messages;
  final bool isLoading;
  final ScrollController scrollController;

  const ChatMessages({
    super.key,
    required this.messages,
    required this.isLoading,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: ListView.builder(
        controller: scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: messages.length + (isLoading ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == messages.length) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(8.0),
                child: CircularProgressIndicator(),
              ),
            );
          }
          return MessageBubble(message: messages[index]);
        },
      ),
    );
  }
}
