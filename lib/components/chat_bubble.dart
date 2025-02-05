import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../models/chat_message.dart';
import '../theme/chat_theme.dart';
// import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';

class ChatBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isLast;
  final Function(String)? onCopyText;
  final Function(Uint8List)? onSaveImage;

  const ChatBubble({
    super.key,
    required this.message,
    required this.isLast,
    this.onCopyText,
    this.onSaveImage,
  });

  String _sanitizeText(String text) {
    try {
      // Try to handle UTF-16 surrogate pairs
      final List<int> bytes = [];
      for (int i = 0; i < text.length; i++) {
        try {
          final codeUnit = text.codeUnitAt(i);
          if (codeUnit < 0xD800 || codeUnit > 0xDFFF) {
            // Regular UTF-16 character
            bytes.addAll(utf8.encode(text[i]));
          } else if (codeUnit >= 0xD800 && codeUnit <= 0xDBFF && i + 1 < text.length) {
            // High surrogate followed by low surrogate
            final nextCodeUnit = text.codeUnitAt(i + 1);
            if (nextCodeUnit >= 0xDC00 && nextCodeUnit <= 0xDFFF) {
              bytes.addAll(utf8.encode(text.substring(i, i + 2)));
              i++; // Skip the next code unit as we've already processed it
            } else {
              bytes.add(0x20); // Replace invalid surrogate with space
            }
          } else {
            bytes.add(0x20); // Replace invalid surrogate with space
          }
        } catch (e) {
          bytes.add(0x20); // Replace any problematic character with space
        }
      }

      // Try to decode the bytes back to a string
      try {
        return utf8.decode(bytes, allowMalformed: true);
      } catch (e) {
        // If UTF-8 decode fails, try to create a clean ASCII string
        return String.fromCharCodes(
          bytes.map((b) => b < 128 ? b : 0x20) // Replace non-ASCII with space
        );
      }
    } catch (e) {
      debugPrint('Error in text sanitization: $e');
      return 'Error displaying content';
    }
  }

  String _cleanMarkdown(String text) {
    try {
      // Remove or fix problematic markdown sequences
      return text
          .replaceAll(RegExp(r'\\[^\s]'), '') // Remove escaped characters
          .replaceAll(RegExp(r'\u0000'), '') // Remove null characters
          .replaceAll(RegExp(r'[^\S\r\n]+'), ' ') // Normalize whitespace
          .replaceAll(RegExp(r'\n{3,}'), '\n\n') // Normalize multiple newlines
          .trim();
    } catch (e) {
      debugPrint('Error cleaning markdown: $e');
      return text;
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatTheme = Theme.of(context).extension<ChatThemeExtension>()!;
    
    // Double sanitization: first clean the text, then clean markdown
    final sanitizedContent = _cleanMarkdown(_sanitizeText(message.content));
    
    return GestureDetector(
      onLongPress: () {
        if (message.content.isNotEmpty && onCopyText != null) {
          onCopyText!(message.content);
        }
      },
      child: Align(
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
                ? chatTheme.userBubbleColor
                : chatTheme.botBubbleColor,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha:0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (message.imageData != null) ...[
                Stack(
                  children: [
                    Image.memory(
                      message.imageData!,
                      fit: BoxFit.contain,
                    ),
                    Positioned(
                      right: 8,
                      top: 8,
                      child: IconButton(
                        icon: const Icon(Icons.save_alt),
                        onPressed: () {
                          if (onSaveImage != null) {
                            onSaveImage!(message.imageData!);
                          }
                        },
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black54,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              Builder(
                builder: (context) {
                  if (sanitizedContent.isEmpty) {
                    return const Text('Generating response...');
                  }
                  
                  try {
                    return MarkdownBody(
                      data: sanitizedContent,
                      styleSheet: MarkdownStyleSheet(
                        p: TextStyle(
                          color: message.isUser 
                              ? chatTheme.userTextColor
                              : chatTheme.botTextColor,
                          fontSize: 16,
                        ),
                        code: TextStyle(
                          backgroundColor: message.isUser 
                              ? chatTheme.userBubbleColor.withValues(alpha:0.7)
                              : chatTheme.botBubbleColor.withValues(alpha:0.7),
                          color: message.isUser 
                              ? chatTheme.userTextColor
                              : chatTheme.botTextColor,
                          fontSize: 14,
                        ),
                        codeblockDecoration: BoxDecoration(
                          color: message.isUser 
                              ? chatTheme.userBubbleColor.withValues(alpha:0.7)
                              : chatTheme.botBubbleColor.withValues(alpha:0.7),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        blockquote: TextStyle(
                          color: message.isUser 
                              ? chatTheme.userTextColor.withValues(alpha:0.9)
                              : chatTheme.botTextColor.withValues(alpha:0.9),
                          fontSize: 16,
                          fontStyle: FontStyle.italic,
                        ),
                        h1: TextStyle(
                          color: message.isUser 
                              ? chatTheme.userTextColor
                              : chatTheme.botTextColor,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        h2: TextStyle(
                          color: message.isUser 
                              ? chatTheme.userTextColor
                              : chatTheme.botTextColor,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        h3: TextStyle(
                          color: message.isUser 
                              ? chatTheme.userTextColor
                              : chatTheme.botTextColor,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        em: TextStyle(
                          color: message.isUser 
                              ? chatTheme.userTextColor
                              : chatTheme.botTextColor,
                          fontStyle: FontStyle.italic,
                        ),
                        strong: TextStyle(
                          color: message.isUser 
                              ? chatTheme.userTextColor
                              : chatTheme.botTextColor,
                          fontWeight: FontWeight.bold,
                        ),
                        a: TextStyle(
                          color: message.isUser 
                              ? chatTheme.userTextColor
                              : Theme.of(context).primaryColor,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                      onTapLink: (text, href, title) {
                        if (href != null) {
                          // launchUrl(Uri.parse(href));
                        }
                      },
                      selectable: true,
                    );
                  } catch (e) {
                    debugPrint('Error rendering markdown: $e');
                    // Fallback to plain text with additional error handling
                    return SelectableText(
                      sanitizedContent.characters.toList().join(''),
                      style: TextStyle(
                        color: message.isUser 
                            ? chatTheme.userTextColor
                            : chatTheme.botTextColor,
                        fontSize: 16,
                      ),
                    );
                  }
                },
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
      ),
    );
  }
} 