import 'package:flutter/material.dart';
import '../models/chat_message.dart';

class ChatBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isLast;

  const ChatBubble({
    super.key,
    required this.message,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        margin: EdgeInsets.only(
          left: message.isUser ? 48 : 8,
          right: message.isUser ? 8 : 48,
          bottom: 8,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: message.isUser 
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message.imageData != null) ...[
              Image.memory(
                message.imageData!,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 8),
            ],
            Text(
              message.content,
              style: TextStyle(
                color: message.isUser 
                    ? Colors.white
                    : Theme.of(context).textTheme.bodyLarge?.color,
                fontSize: 16,
              ),
            ),
            if (message.isError) ...[
              const SizedBox(height: 4),
              Text(
                'Error',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
} 