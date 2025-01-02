import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import '../models/chat_message.dart';
import '../services/notification_service.dart';
import 'package:device_info_plus/device_info_plus.dart';

class ImageSaver {
  static Future<String?> saveImage(BuildContext context, Uint8List imageData) async {
    if (Platform.isAndroid && await _needsStoragePermission()) {
      final hasPermission = await _handlePermission(context);
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
    final savedPath = await ImageSaver.saveImage(context, imageData);
    
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

  Widget _buildMessageContent(BuildContext context) {
    return Column(
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
                onPressed: () => _downloadImage(context, message.imageData!),
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
              onPressed: () => _copyToClipboard(context, message.content),
              tooltip: 'Copy text',
            ),
          ),
      ],
    );
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
          if (!message.isUser) ...[
            CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              child: const Icon(Icons.smart_toy, size: 20),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: GestureDetector(
              onLongPress: message.imageData == null
                  ? () => _copyToClipboard(context, message.content)
                  : null,
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.7,
                ),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: message.isUser
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: !message.isUser
                      ? Border.all(color: Theme.of(context).dividerColor)
                      : null,
                ),
                child: _buildMessageContent(context),
              ),
            ),
          ),
          if (message.isUser) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              child: const Icon(Icons.person, size: 20),
            ),
          ],
        ],
      ),
    );
  }
}