import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../models/chat_message.dart';
import 'package:flutter/services.dart';
import '../services/image_service.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'message_bubble.dart';

class ChatMessages extends ConsumerWidget {
  final List<ChatMessage> messages;
  final bool isLoading;
  final ScrollController scrollController;

  const ChatMessages({
    super.key,
    required this.messages,
    required this.isLoading,
    required this.scrollController,
  });

  Future<void> _saveImage(BuildContext context, Uint8List imageData) async {
    try {
      await ImageService().saveImage(imageData);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Image saved to gallery'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save image'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _copyText(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Text copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (messages.isEmpty) {
      return const Center(
        child: Text('Start a conversation...'),
      );
    }

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: MessageBubble(
            message: message,
            showAvatar: index == 0 || messages[index - 1].isUser != message.isUser,
          ),
        );
      },
    );
  }
}
