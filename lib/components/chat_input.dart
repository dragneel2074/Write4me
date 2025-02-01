import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/providers.dart';
// import 'package:write4me/screens/reminders_screen.dart';

class ChatInput extends ConsumerWidget {
  final TextEditingController controller;
  final bool isImageMode;
  final bool isInternetMode;
  final bool isGenerating;
  final VoidCallback onSubmit;
  final VoidCallback onStop;
  final VoidCallback onAddContent;
  final VoidCallback? onToggleInternet;
  final VoidCallback onToggleImage;
  final bool isInternetDisabled;
  final bool isOfflineMode;

  const ChatInput({
    super.key,
    required this.controller,
    required this.isImageMode,
    required this.isInternetMode,
    required this.isGenerating,
    required this.onSubmit,
    required this.onStop,
    required this.onAddContent,
    required this.onToggleInternet,
    required this.onToggleImage,
    required this.isInternetDisabled,
    required this.isOfflineMode,
  });

  Widget _buildActionButton({
    required IconData icon,
    required VoidCallback onPressed,
    required String label,
    bool isSelected = false,
    bool isDisabled = false,
  }) {
    return Tooltip(
      message: label,
      child: IconButton(
        icon: Icon(
          icon,
          color: isDisabled 
              ? Colors.grey 
              : isSelected 
                  ? Colors.blue 
                  : null,
        ),
        onPressed: isDisabled ? null : onPressed,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).dividerColor.withValues(alpha:0.05),
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Text Input Field with Submit Button
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: onAddContent,
              ),
              Expanded(
                child: TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    hintText: isImageMode 
                        ? 'Describe the image you want...'
                        : 'Type your message...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  maxLines: null,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => onSubmit(),
                  enabled: !isGenerating,
                ),
              ),
              _buildActionButton(
                icon: Icons.language,
                onPressed: onToggleInternet!,
                label: 'Web Search',
                isSelected: isInternetMode,
                isDisabled: isInternetDisabled,
              ),
              _buildActionButton(
                icon: Icons.image,
                onPressed: onToggleImage,
                label: 'Image Generation',
                isSelected: isImageMode,
                isDisabled: isOfflineMode,
              ),
              IconButton(
                icon: Icon(isGenerating ? Icons.stop : Icons.send),
                onPressed: isGenerating ? onStop : onSubmit,
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (isOfflineMode)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Offline Mode - Using Local Model',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.secondary,
                ),
              ),
            ),
          // Bottom Action Buttons
          Wrap(
            spacing: 4,
            runSpacing: 8,
            children: [
              // _buildActionButton(
              //   icon: Icons.add,
              //   onPressed: onAddContent,
              //   label: 'Add Files',
              // ),
              // if (!isOfflineMode) ...[
              //   _buildActionButton(
              //     icon: isImageMode ? Icons.image : Icons.image_outlined,
              //     onPressed: onToggleImage,
              //     label: 'Generate Image',
              //   ),
              //   _buildActionButton(
              //     icon: isInternetMode ? Icons.language : Icons.language_outlined,
              //     onPressed: isInternetDisabled || isOfflineMode ? null : onToggleInternet,
              //     label: 'Search Web',
              //   ),
              // ],
              // _buildActionButton(
              //   icon: Icons.smart_toy_outlined,
              //   onPressed: () {
              //     Navigator.push(
              //       context,
              //       MaterialPageRoute(
              //         builder: (context) => const RemindersScreen(),
              //       ),
              //     );
              //   },
              //   label: 'Agent',
              // ),
            ],
          ),
        ],
      ),
    );
  }
}
