import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../models/chat_message.dart';
import '../services/notification_service.dart';

class MessageBubble extends StatelessWidget {
  final ChatMessage message;

  const MessageBubble({
    super.key,
    required this.message,
  });

  Future<void> _copyToClipboard(BuildContext context, String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    NotificationService.showTopNotification(
      context,
      message: 'Text copied to clipboard',
    );
  }

  Future<void> _downloadImage(BuildContext context, Uint8List imageData) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      if (directory == null) throw Exception('Directory not found');

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filePath = '${directory.path}/image_$timestamp.png';

      final file = File(filePath);
      await file.writeAsBytes(imageData);

      NotificationService.showTopNotification(
        context,
        message: 'Image saved to: $filePath',
      );
    } catch (e) {
      NotificationService.showTopNotification(
        context,
        message: 'Failed to save image: $e',
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment:
            message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!message.isUser)
            CircleAvatar(
              backgroundColor:
                  Theme.of(context).colorScheme.primary.withOpacity(0.1),
              child: const Icon(
                Icons.smart_toy,
                size: 20,
              ),
            ),
          if (!message.isUser) const SizedBox(width: 8),
          Flexible(
            child: GestureDetector(
              onLongPress: message.imageData == null
                  ? () => _copyToClipboard(context, message.content)
                  : null,
              child: Container(
                constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: message.isUser
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: !message.isUser
                      ? Border.all(
                          color: Theme.of(context).dividerColor,
                        )
                      : null,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (message.imageData != null) ...[
                      Stack(
                        alignment: Alignment.topRight,
                        children: [
                          Image.memory(
                            message.imageData!,
                            fit: BoxFit.cover,
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.download,
                              color: Colors.white,
                            ),
                            onPressed: () => _downloadImage(
                              context,
                              message.imageData!,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                    MarkdownBody(
                      data: message.content,
                      styleSheet: MarkdownStyleSheet(
                        p: TextStyle(
                          color: message.isUser ? Colors.white : null,
                        ),
                      ),
                    ),
                    if (!message.isUser && message.imageData == null)
                      Align(
                        alignment: Alignment.centerRight,
                        child: IconButton(
                          icon: const Icon(Icons.copy, size: 16),
                          onPressed: () =>
                              _copyToClipboard(context, message.content),
                          tooltip: 'Copy text',
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          if (message.isUser) const SizedBox(width: 8),
          if (message.isUser)
            CircleAvatar(
              backgroundColor:
                  Theme.of(context).colorScheme.primary.withOpacity(0.1),
              child: const Icon(
                Icons.person,
                size: 20,
              ),
            ),
        ],
      ),
    );
  }
}