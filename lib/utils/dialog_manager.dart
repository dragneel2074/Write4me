import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class DialogManager {
  static Future<void> showExtractedText(
    BuildContext context,
    String title,
    String content,
  ) {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(
            child: Text(content),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Close'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }

  static Future<bool?> showClearChatConfirmation(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Chat'),
        content: const Text('Are you sure you want to clear the chat history?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  static Future<String?> showURLInputDialog(BuildContext context) {
    final TextEditingController urlController = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter URL'),
        content: TextField(
          controller: urlController,
          decoration: const InputDecoration(
            hintText: 'https://example.com',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, urlController.text),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  static Future<ImageSource?> showImageSourceDialog(BuildContext context) {
    return showDialog<ImageSource>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Image Source'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Camera'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
  }

  static Future<void> showAddOptionsDialog(
    BuildContext context, {
    required VoidCallback onWebSelected,
    required VoidCallback onFileSelected,
    required VoidCallback onImageSelected,
  }) {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Content'),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildOptionTile(
              context,
              icon: Icons.web,
              title: 'Web URL',
              onTap: () {
                Navigator.pop(context);
                onWebSelected();
              },
            ),
            _buildOptionTile(
              context,
              icon: Icons.file_copy,
              title: 'Files',
              onTap: () {
                Navigator.pop(context);
                onFileSelected();
              },
            ),
            _buildOptionTile(
              context,
              icon: Icons.image,
              title: 'Image',
              onTap: () {
                Navigator.pop(context);
                onImageSelected();
              },
            ),
          ],
        ),
      ),
    );
  }

  static Widget _buildOptionTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(title),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      hoverColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
    );
  }
}
