import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import '../models/chat_message.dart';
import '../services/notification_service.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ImageSaver {
  static Future<String?> saveImage(BuildContext context, Uint8List imageData) async {
    if (Platform.isAndroid && await _needsStoragePermission()) {
    if (!context.mounted) return null;
    final hasPermission =  await _handlePermission(context);
    if (!hasPermission) return null;
    }

    try {
      final directory = await _getOutputDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filePath = '${directory.path}/image_$timestamp.png';
      
      await File(filePath).writeAsBytes(imageData);
      return filePath;
    } catch (e) {
      return null;
    }
  }

  static Future<bool> _needsStoragePermission() async {
    if (await DeviceInfoPlugin().androidInfo.then((info) => info.version.sdkInt >= 33)) {
      return false;
    }
    return true;
  }

  static Future<Directory> _getOutputDirectory() async {
    if (Platform.isAndroid) {
      return Directory('/storage/emulated/0/Download');
    } else if (Platform.isIOS) {
      final directory = await getApplicationDocumentsDirectory();
      final imageDir = Directory('${directory.path}/saved_images');
      if (!await imageDir.exists()) {
        await imageDir.create(recursive: true);
      }
      return imageDir;
    } else {
      throw UnsupportedError('Unsupported platform');
    }
  }

  static Future<bool> _handlePermission(BuildContext context) async {
    final status = await Permission.storage.status;
    
    if (status.isGranted) return true;
    
    if (status.isDenied) {
      final result = await Permission.storage.request();
      return result.isGranted;
    }

    if (status.isPermanentlyDenied) {
      if (!context.mounted) return false;
      final shouldOpenSettings = await _showPermissionDialog(context);
      if (shouldOpenSettings) {
        await openAppSettings();
        return await Permission.storage.status.isGranted;
      }
      return false;
    }
    
    return false;
  }

  static Future<bool> _showPermissionDialog(BuildContext context) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Storage Permission Required'),
        content: const Text(
          'This app needs storage access to save images. Please enable it in settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Open Settings'),
          ),
        ],
      ),
    ) ?? false;
  }
}

class MessageBubble extends ConsumerWidget {
  final ChatMessage message;
  final bool showAvatar;

  const MessageBubble({
    super.key,
    required this.message,
    required this.showAvatar,
  });

  Future<void> _copyToClipboard(BuildContext context, String text) async {
    await Clipboard.setData(ClipboardData(text: text));
      if (!context.mounted) return;

    NotificationService.showTopNotification(
      context,
      message: 'Text copied to clipboard',
    );
  }

  Future<void> _downloadImage(BuildContext context, Uint8List imageData) async {
    final savedPath = await ImageSaver.saveImage(context, imageData);
    if (!context.mounted) return;

    if (savedPath != null) {

      NotificationService.showTopNotification(
        context,
        message: 'Image saved successfully',
      );
    } else {
      NotificationService.showTopNotification(
        context,
        message: 'Failed to save image',
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isUser = message.isUser;
    final hasImage = message.imageData != null;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isUser && showAvatar)
              const CircleAvatar(
                radius: 16,
                child: Icon(Icons.smart_toy, size: 20),
              )
            else if (!isUser)
              const SizedBox(width: 32),
            Flexible(
              child: Card(
                color: isUser 
                    ? Theme.of(context).primaryColor 
                    : Theme.of(context).cardColor,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: hasImage
                      ? Image.memory(message.imageData!)
                      : MarkdownBody(
                          data: message.content,
                          styleSheet: MarkdownStyleSheet(
                            p: TextStyle(
                              color: isUser
                                  ? Theme.of(context).colorScheme.onPrimary
                                  : Theme.of(context).textTheme.bodyLarge?.color,
                            ),
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}