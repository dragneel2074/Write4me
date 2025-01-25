import 'package:flutter/material.dart';

class IntroDrawer extends StatelessWidget {
  const IntroDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context);
    final availableHeight = screenSize.size.height - 
                          screenSize.padding.bottom - 
                          screenSize.padding.top -
                          90;

    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        width: screenSize.size.width * 0.9,
        height: availableHeight,
        margin: EdgeInsets.only(
          top: screenSize.padding.top,
          right: 0,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            bottomLeft: Radius.circular(20),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(-2, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Expanded(
                    child: Text(
                      'Welcome to Write4Me! 👋',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        decoration: TextDecoration.none,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSection(
                      icon: Icons.chat_bubble_outline,
                      title: 'Chat with AI',
                      description: 'Ask questions, get help with writing, brainstorm ideas, or just have a friendly conversation!',
                    ),
                    const SizedBox(height: 20),
                    _buildSection(
                      icon: Icons.image_outlined,
                      title: 'Generate Images',
                      description: 'Create unique images by describing what you want to see. From artwork to illustrations, bring your ideas to life!',
                    ),
                    const SizedBox(height: 20),
                    _buildSection(
                      icon: Icons.upload_file_outlined,
                      title: 'Upload Documents',
                      description: 'Add Urls or PDFs or Images with text, and I\'ll help you understand them. Ask questions about the content or get summaries.',
                    ),
                    const SizedBox(height: 20),
                    _buildSection(
                      icon: Icons.language_outlined,
                      title: 'Web Search',
                      description: 'Get information from the internet to answer your questions with up-to-date knowledge.',
                    ),
                    const SizedBox(height: 32),
                    Text(
                      'Quick Start Guide:',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        decoration: TextDecoration.none,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '1. Type your message in the chat box and press send\n'
                      '2. Use the + button to add documents or images\n'
                      '3. Toggle image mode to create images\n'
                      '4. Toggle web mode to search the internet',
                      style: TextStyle(
                        fontSize: 16, 
                        height: 1.5,
                        decoration: TextDecoration.none,
                      ),
                    ),
                    const SizedBox(height: 32),
                    Align(
                      alignment: Alignment.center,
                      child: Text(
                        'Note: Write4Me doesn\'t store your chats or files.\nData may be processed by Third Party services we use.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).textTheme.bodySmall?.color,
                          decoration: TextDecoration.none,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 28),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  decoration: TextDecoration.none,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 16,
                  decoration: TextDecoration.none,
                ),
                overflow: TextOverflow.visible,
              ),
            ],
          ),
        ),
      ],
    );
  }
} 