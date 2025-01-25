import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../models/chat_message.dart';
import 'package:flutter/services.dart';
import '../services/image_service.dart';

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

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: messages.length + (isLoading ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == messages.length) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Theme.of(context).primaryColor,
                ),
              ),
            ),
          );
        }
        final message = messages[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: message.isUser 
                ? CrossAxisAlignment.end 
                : CrossAxisAlignment.start,
            children: [
              if (!message.isUser)
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 4),
                  child: Row(
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.auto_awesome,
                          size: 12,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Write4Me',
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context).textTheme.bodySmall?.color,
                        ),
                      ),
                    ],
                  ),
                ),
              Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.75,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: message.isUser 
                      ? Theme.of(context).primaryColor
                      : Theme.of(context).brightness == Brightness.light
                          ? const Color(0xFFF5F5F5)
                          : Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(16).copyWith(
                    bottomRight: message.isUser ? const Radius.circular(4) : null,
                    bottomLeft: !message.isUser ? const Radius.circular(4) : null,
                  ),
                ),
                child: message.imageData != null
                    ? Stack(
                        alignment: Alignment.topRight,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.memory(message.imageData!),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: IconButton(
                              icon: const Icon(
                                Icons.download,
                                color: Colors.white,
                              ),
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.black54,
                                padding: const EdgeInsets.all(8),
                              ),
                              onPressed: () => _saveImage(context, message.imageData!),
                              tooltip: 'Save image',
                            ),
                          ),
                        ],
                      )
                    : MarkdownBody(
                        data: message.content,
                        styleSheet: MarkdownStyleSheet(
                          p: TextStyle(
                            color: message.isUser 
                                ? Colors.white
                                : Theme.of(context).textTheme.bodyLarge?.color,
                            height: 1.4,
                            fontSize: 15,
                          ),
                          code: TextStyle(
                            color: message.isUser 
                                ? Colors.white.withOpacity(0.9)
                                : Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.9),
                            backgroundColor: message.isUser 
                                ? Colors.white.withOpacity(0.1)
                                : Theme.of(context).brightness == Brightness.light
                                    ? Colors.black.withOpacity(0.05)
                                    : Colors.white.withOpacity(0.1),
                            fontSize: 14,
                          ),
                          codeblockDecoration: BoxDecoration(
                            color: message.isUser 
                                ? Colors.white.withOpacity(0.1)
                                : Theme.of(context).brightness == Brightness.light
                                    ? Colors.black.withOpacity(0.05)
                                    : Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          blockquote: TextStyle(
                            color: message.isUser 
                                ? Colors.white.withOpacity(0.9)
                                : Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.9),
                            fontSize: 15,
                            height: 1.4,
                          ),
                          h1: TextStyle(
                            color: message.isUser 
                                ? Colors.white
                                : Theme.of(context).textTheme.bodyLarge?.color,
                            height: 1.4,
                          ),
                          h2: TextStyle(
                            color: message.isUser 
                                ? Colors.white
                                : Theme.of(context).textTheme.bodyLarge?.color,
                            height: 1.4,
                          ),
                          h3: TextStyle(
                            color: message.isUser 
                                ? Colors.white
                                : Theme.of(context).textTheme.bodyLarge?.color,
                            height: 1.4,
                          ),
                        ),
                        selectable: true,
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
