import 'package:flutter/material.dart';

class ChatInput extends StatelessWidget {
  final TextEditingController controller;
  final bool isImageMode;
  final bool isInternetMode;
  final VoidCallback onSubmit;
  final VoidCallback onAddContent;
  final VoidCallback onToggleInternet;
  final VoidCallback onToggleImage;
  final bool isInternetDisabled;

  const ChatInput({
    super.key,
    required this.controller,
    required this.isImageMode,
    required this.isInternetMode,
    required this.onSubmit,
    required this.onAddContent,
    required this.onToggleInternet,
    required this.onToggleImage,
    required this.isInternetDisabled,
  });

  Widget _buildActionButtons(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.public),
          onPressed: isInternetDisabled ? null : onToggleInternet,
          color: isInternetMode ? Theme.of(context).colorScheme.primary : null,
          tooltip: isInternetDisabled
              ? 'Internet search disabled when documents are present'
              : 'Toggle internet search',
        ),
        IconButton(
          icon: const Icon(Icons.image_outlined),
          onPressed: onToggleImage,
          color: isImageMode ? Theme.of(context).colorScheme.primary : null,
          tooltip: 'Toggle image generation',
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.add),
          onPressed: onAddContent,
          tooltip: 'Add content',
        ),
        Expanded(
          child: TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: isImageMode
                  ? 'Describe the image you want to generate...'
                  : isInternetMode
                      ? 'Ask anything to search the internet...'
                      : 'Type your message...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surface,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 14,
              ),
              isDense: false,
              suffixIcon: IconButton(
                icon: const Icon(Icons.send),
                onPressed: onSubmit,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  height: 1.5,
                ),
            maxLines: null,
            minLines: 1,
            textAlignVertical: TextAlignVertical.center,
            textInputAction: TextInputAction.newline,
            onSubmitted: (_) => onSubmit(),
          ),
        ),
        _buildActionButtons(context),
      ],
    );
  }
}
