import 'package:flutter/material.dart';

class MessageUtils {
  static void _showSnackBar(
    BuildContext context, {
    required Widget content,
    required Color backgroundColor,
    Duration? duration,
    SnackBarAction? action,
  }) {
    if (!context.mounted) return;
    
    final snackBar = SnackBar(
      content: content,
      backgroundColor: backgroundColor,
      duration: duration ?? const Duration(seconds: 2),
      behavior: SnackBarBehavior.floating,
      action: action,
      margin: const EdgeInsets.symmetric(
        horizontal: 16.0,
        vertical: 16.0,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
    );

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(snackBar);
  }

  static void showSuccess(BuildContext context, String message) {
    _showSnackBar(
      context,
      content: Row(
        children: [
          const Icon(
            Icons.check_circle,
            color: Colors.white,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message),
          ),
        ],
      ),
      backgroundColor: Colors.green,
    );
  }

  static void showError(
    BuildContext context, 
    String message, {
    VoidCallback? onRetry,
  }) {
    _showSnackBar(
      context,
      content: Row(
        children: [
          const Icon(
            Icons.error_outline,
            color: Colors.white,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message),
          ),
        ],
      ),
      backgroundColor: Colors.red,
      duration: const Duration(seconds: 4),
      action: onRetry != null ? SnackBarAction(
        label: 'Retry',
        textColor: Colors.white,
        onPressed: onRetry,
      ) : null,
    );
  }

  static void showWarning(BuildContext context, String message) {
    _showSnackBar(
      context,
      content: Row(
        children: [
          const Icon(
            Icons.warning_amber,
            color: Colors.white,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message),
          ),
        ],
      ),
      backgroundColor: Colors.orange,
      duration: const Duration(seconds: 3),
    );
  }

  static void showInfo(BuildContext context, String message) {
    _showSnackBar(
      context,
      content: Row(
        children: [
          const Icon(
            Icons.info_outline,
            color: Colors.white,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message),
          ),
        ],
      ),
      backgroundColor: Colors.blue,
    );
  }

  // For debug logging
  static void logError(String message, dynamic error) {
    debugPrint('Error - $message: $error');
  }
} 