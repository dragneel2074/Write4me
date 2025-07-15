import 'package:flutter/material.dart';
// import 'package:write4me/screens/reminders_screen.dart';

class ChatInput extends StatelessWidget {
  final TextEditingController controller;
  final bool isImageMode;
  final bool isWebSearch;
  final bool isGenerating;
  final VoidCallback onSubmit;
  final VoidCallback onStop;
  final VoidCallback onAddContent;
  final VoidCallback? onToggleWebSearch;
  final VoidCallback onToggleImage;
  final bool isWebSearchDisabled;
  final bool isOfflineMode;

  const ChatInput({
    super.key,
    required this.controller,
    required this.isImageMode,
    required this.isWebSearch,
    required this.isGenerating,
    required this.onSubmit,
    required this.onStop,
    required this.onAddContent,
    required this.onToggleWebSearch,
    required this.onToggleImage,
    required this.isWebSearchDisabled,
    required this.isOfflineMode,
  });

  @override
  Widget build(BuildContext context) {
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
              _buildActionButton(
                icon: Icons.add,
                onPressed: onAddContent,
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              ),
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
                    enabled: !isGenerating,
                    decoration: InputDecoration(
                      hintText: isGenerating 
                          ? 'Generating...'
                          : isImageMode 
                              ? 'Describe the image...'
                              : isWebSearch
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
                icon: isGenerating ? Icons.stop : Icons.send,
                onPressed: isGenerating ? onStop : onSubmit,
                showActive: true,
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
              if (!isOfflineMode) ...[
                _buildActionButton(
                  icon: isImageMode ? Icons.image : Icons.image_outlined,
                  onPressed: onToggleImage,
                  isActive: isImageMode,
                  label: 'Generate Image',
                ),
                _buildActionButton(
                  icon: isWebSearch ? Icons.language : Icons.language_outlined,
                  onPressed: isWebSearchDisabled || isOfflineMode 
                      ? null 
                      : onToggleWebSearch,
                  isActive: isWebSearch,
                  label: 'Search Web',
                ),
              ],
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

  Widget _buildActionButton({
    required IconData icon,
    VoidCallback? onPressed,
    bool isActive = false,
    bool showActive = false,
    String? label,
    EdgeInsetsGeometry? padding,
  }) {
    return Builder(
      builder: (context) => TextButton.icon(
        icon: Icon(
          icon,
          size: 20,
          color: (isActive || showActive)
              ? Theme.of(context).primaryColor
              : Theme.of(context).iconTheme.color?.withValues(alpha:0.7),
        ),
        label: label != null 
            ? Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  color: (isActive || showActive)
                      ? Theme.of(context).primaryColor
                      : Theme.of(context).iconTheme.color?.withValues(alpha:0.7),
                ),
              )
            : const SizedBox.shrink(),
        onPressed: onPressed,
        style: TextButton.styleFrom(
          padding: padding ?? EdgeInsets.symmetric(
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
