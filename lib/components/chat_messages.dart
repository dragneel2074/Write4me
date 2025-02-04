import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/image_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/chat_provider.dart';
import '../theme/chat_theme.dart';
import 'chat_bubble.dart';

class ChatMessages extends ConsumerWidget {
  final ScrollController scrollController;

  const ChatMessages({
    super.key,
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
    final chatState = ref.watch(chatProvider);
    final theme = Theme.of(context);
    final chatTheme = theme.extension<ChatThemeExtension>()!;
    
    if (chatState.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            chatState.error!,
            style: TextStyle(
              color: theme.colorScheme.error,
              fontSize: 16,
            ),
          ),
        ),
      );
    }
    
    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
      itemCount: chatState.messages.length,
      itemBuilder: (context, index) {
        final message = chatState.messages[index];
        return ChatBubble(
          message: message,
          isLast: index == chatState.messages.length - 1,
          onCopyText: (text) => _copyText(context, text),
          onSaveImage: (imageData) => _saveImage(context, imageData),
        );
      },
    );
  }
}
