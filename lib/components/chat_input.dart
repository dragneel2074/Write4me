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

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).dividerColor.withOpacity(0.05),
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Text Input Field with Submit Button
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  height: 44,
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.light 
                        ? const Color(0xFFF5F5F5)
                        : Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: TextField(
                    controller: controller,
                    decoration: InputDecoration(
                      hintText: isImageMode 
                          ? 'Describe the image you want to create...'
                          : isInternetMode
                              ? 'Search the internet...'
                              : 'Message Write4Me',
                      hintStyle: TextStyle(
                        color: Theme.of(context).textTheme.bodySmall?.color,
                        fontSize: 15,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    style: const TextStyle(fontSize: 15),
                    onSubmitted: (_) => onSubmit(),
                  ),
                ),
              ),
              _buildActionButton(
                icon: Icons.send,
                onPressed: onSubmit,
                showActive: true,
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Bottom Action Buttons
          Wrap(
            spacing: 4,
            runSpacing: 8,
            children: [
              _buildActionButton(
                icon: Icons.add,
                onPressed: onAddContent,
                label: 'Add Files',
              ),
              _buildActionButton(
                icon: isImageMode ? Icons.image : Icons.image_outlined,
                onPressed: onToggleImage,
                isActive: isImageMode,
                label: 'Generate Image',
              ),
              _buildActionButton(
                icon: isInternetMode ? Icons.language : Icons.language_outlined,
                onPressed: isInternetDisabled ? null : onToggleInternet,
                isActive: isInternetMode,
                label: 'Search Web',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required VoidCallback? onPressed,
    bool isActive = false,
    bool showActive = false,
    String? label,
  }) {
    return Builder(
      builder: (context) => TextButton.icon(
        icon: Icon(
          icon,
          size: 20,
          color: (isActive || showActive)
              ? Theme.of(context).primaryColor
              : Theme.of(context).iconTheme.color?.withOpacity(0.7),
        ),
        label: label != null 
            ? Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  color: (isActive || showActive)
                      ? Theme.of(context).primaryColor
                      : Theme.of(context).iconTheme.color?.withOpacity(0.7),
                ),
              )
            : const SizedBox.shrink(),
        onPressed: onPressed,
        style: TextButton.styleFrom(
          padding: EdgeInsets.symmetric(
            horizontal: label != null ? 8 : 12,
            vertical: 8,
          ),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    );
  }
}
