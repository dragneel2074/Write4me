import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/image_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/chat_provider.dart';
import '../providers/offline_mode_provider.dart';
// import '../theme/chat_theme.dart';
import 'chat_bubble.dart';
import '../utils/message_utils.dart';

class ChatMessages extends ConsumerWidget {
  final ScrollController scrollController;

  const ChatMessages({
    super.key,
    required this.scrollController,
  });

  // Check internet connectivity
  // Future<bool> _checkInternetConnection() async {
  //   try {
  //     final result = await InternetAddress.lookup('google.com');
  //     return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
  //   } on SocketException catch (_) {
  //     return false;
  //   }
  // }

  Future<void> _saveImage(BuildContext context, Uint8List imageData) async {
    try {
      await ImageService().saveImage(imageData);
      if (context.mounted) {
        MessageUtils.showSuccess(context, 'Image saved to gallery');
      }
    } catch (e) {
      MessageUtils.logError('Failed to save image', e);
      if (context.mounted) {
        MessageUtils.showError(context, 'Failed to save image');
      }
    }
  }

  void _copyText(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    MessageUtils.showSuccess(context, 'Text copied to clipboard');
  }

  // Widget _buildErrorWidget(
  //   BuildContext context,
  //   WidgetRef ref,
  //   String error,
  //   bool isOffline,
  // ) {
  //   final offlineModeState = ref.watch(offlineModeProvider);
  //   final hasLocalModels = offlineModeState.availableModels.isNotEmpty;

  //   // If offline mode is active and we have local models, don't show the error
  //   if (offlineModeState.isOfflineMode && hasLocalModels) {
  //     return const SizedBox.shrink();
  //   }

  //   if (isOffline) {
  //     return Center(
  //       child: SingleChildScrollView(
  //         padding: const EdgeInsets.all(24.0),
  //         child: Column(
  //           mainAxisSize: MainAxisSize.min,
  //           children: [
  //             const Icon(
  //               Icons.cloud_off,
  //               size: 48,
  //               color: Colors.grey,
  //             ),
  //             const SizedBox(height: 16),
  //             const Text(
  //               'No Internet Connection',
  //               style: TextStyle(
  //                 fontSize: 20,
  //                 fontWeight: FontWeight.bold,
  //               ),
  //               textAlign: TextAlign.center,
  //             ),
  //             const SizedBox(height: 8),
  //             if (hasLocalModels) ...[
  //               const Text(
  //                 'Would you like to switch to offline mode?',
  //                 textAlign: TextAlign.center,
  //               ),
  //               const SizedBox(height: 16),
  //               ElevatedButton.icon(
  //                 icon: const Icon(Icons.offline_bolt),
  //                 label: const Text('Switch to Offline Mode'),
  //                 onPressed: () {
  //                   ref.read(offlineModeProvider.notifier).setOfflineMode(true);
  //                   ref.read(chatProvider.notifier).clearError();
  //                 },
  //               ),
  //             ] else ...[
  //               const Text(
  //                 'No offline models available.\nPlease download a model when you\'re back online.',
  //                 textAlign: TextAlign.center,
  //               ),
  //               const SizedBox(height: 16),
  //               OutlinedButton.icon(
  //                 icon: const Icon(Icons.refresh),
  //                 label: const Text('Check Connection'),
  //                 onPressed: () async {
  //                   final isOnline = await _checkInternetConnection();
  //                   if (isOnline) {
  //                     ref.read(offlineModeProvider.notifier).setOfflineMode(false);
  //                     ref.read(chatProvider.notifier).clearError();
  //                   }
  //                 },
  //               ),
  //             ],
  //           ],
  //         ),
  //       ),
  //     );
  //   }

  //   // For other errors
  //   return Center(
  //     child: SingleChildScrollView(
  //       padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
  //       child: Column(
  //         mainAxisSize: MainAxisSize.min,
  //         children: [
  //           Text(
  //             error,
  //             style: TextStyle(
  //               color: Theme.of(context).colorScheme.error,
  //               fontSize: 16,
  //             ),
  //             textAlign: TextAlign.center,
  //           ),
  //           const SizedBox(height: 16),
  //           ElevatedButton(
  //             onPressed: () {
  //               ref.read(chatProvider.notifier).clearError();
  //             },
  //             child: const Text('Try Again'),
  //           ),
  //         ],
  //       ),
  //     ),
  //   );
  // }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chatState = ref.watch(chatProvider);
    final offlineModeState = ref.watch(offlineModeProvider);
    // final theme = Theme.of(context);
    // final chatTheme = theme.extension<ChatThemeExtension>()!;
    
    // Show messages if we're in offline mode with local models
    if (offlineModeState.isOfflineMode && offlineModeState.availableModels.isNotEmpty) {
      if (chatState.messages.isEmpty) {
        return const Center(
          child: Text('No messages yet'),
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
    
    // Handle error states
    // if (chatState.error != null) {
    //   return FutureBuilder<bool>(
    //     future: _checkInternetConnection(),
    //     builder: (context, snapshot) {
    //       final isOffline = snapshot.hasData && !snapshot.data!;
    //       return _buildErrorWidget(
    //         context,
    //         ref,
    //         chatState.error!,
    //         isOffline,
    //       );
    //     },
    //   );
    // }

    if (chatState.messages.isEmpty) {
      return const Center(
        child: Text('No messages yet'),
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
