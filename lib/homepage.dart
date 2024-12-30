import 'package:flutter/material.dart';
import 'components/pdf_list.dart';
import 'components/message_bubble.dart';
import 'models/pdf_memory.dart';
import 'services/ai_service.dart';
import 'services/pdf_service.dart';
import 'models/chat_message.dart';
import 'package:provider/provider.dart';
import 'theme/theme_provider.dart';
import 'services/image_generation_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final List<PDFMemory> _pdfMemories = [];
  final TextEditingController _controller = TextEditingController();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;
  final PDFService _pdfService = PDFService();
  final AIService _aiService = AIService();
  final ScrollController _scrollController = ScrollController();
  final ImageGenerationService _imageGenService = ImageGenerationService();
  bool _isImageMode = false;

  @override
  void dispose() {
    _scrollController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _submitMessage() async {
    if (_controller.text.trim().isEmpty) return;

    final userMessage = _controller.text;
    setState(() {
      _messages.add(ChatMessage(
        content: userMessage,
        isUser: true,
      ));
      _isLoading = true;
      _controller.clear();
    });
    _scrollToBottom();

    try {
      if (_isImageMode) {
        // Handle image generation
        setState(() {
          _messages.add(ChatMessage(
            content: "Generating image... Please wait.",
            isUser: false,
          ));
        });

        final imageData =
            await _imageGenService.generateImage(prompt: userMessage);

        if (imageData != null) {
          setState(() {
            _messages.add(ChatMessage(
              content: userMessage,
              isUser: false,
              imageData: imageData,
            ));
          });
        } else {
          setState(() {
            _messages.add(ChatMessage(
              content: "Failed to generate image.",
              isUser: false,
              isError: true,
            ));
          });
        }
        // Reset image mode after generation
        setState(() {
          _isImageMode = false;
        });
      } else {
        // Handle text generation
        final response = await _aiService.getResponse(
          userMessage,
          _pdfMemories.where((memory) => memory.isSelected).toList(),
        );

        setState(() {
          _messages.add(ChatMessage(
            content: response,
            isUser: false,
          ));
        });
      }
    } catch (e) {
      setState(() {
        _messages.add(ChatMessage(
          content: "Error: $e",
          isUser: false,
          isError: true,
        ));
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
      _scrollToBottom();
    }
  }

  Future<void> _showAddOptions() async {
    await showDialog(
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
              icon: Icons.file_copy,
              title: 'Files',
              onTap: () {
                Navigator.pop(context);
                _pickPDFAndCreateRAG();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionTile({
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

  Future<void> _pickPDFAndCreateRAG() async {
    try {
      PDFMemory? newMemory = await _pdfService.pickAndProcessPDF();
      if (newMemory != null) {
        setState(() {
          _pdfMemories.add(newMemory);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF processed: ${newMemory.pdfName}')),
        );
      }
    } catch (e) {
      _showErrorSnackBar('Error processing PDF: ${e.toString()}');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _showExtractedText(PDFMemory memory) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Extracted Text from ${memory.pdfName}'),
          content: SingleChildScrollView(
            child: Text(memory.extractedText),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Close'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _clearChat() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Chat'),
        content: const Text('Are you sure you want to clear the chat history?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _messages.clear();
              });
              Navigator.pop(context);
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  void _removeDocument(PDFMemory document) {
    setState(() {
      _pdfMemories.remove(document);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Write4Me'),
        centerTitle: true,
        elevation: 1,
        actions: [
          if (_messages.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.cleaning_services),
              onPressed: _clearChat,
              tooltip: 'Clear chat',
            ),
          IconButton(
            icon: Icon(
              Theme.of(context).brightness == Brightness.light
                  ? Icons.dark_mode
                  : Icons.light_mode,
            ),
            onPressed: () {
              final themeProvider = Provider.of<ThemeProvider>(
                context,
                listen: false,
              );
              themeProvider.toggleTheme();
            },
            tooltip: 'Toggle theme',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              color: Theme.of(context).colorScheme.surface,
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: _messages.length + (_isLoading ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == _messages.length) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(8.0),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }
                  return MessageBubble(message: _messages[index]);
                },
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  offset: const Offset(0, -2),
                  blurRadius: 5,
                ),
              ],
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                if (_pdfMemories.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Theme.of(context).dividerColor,
                      ),
                    ),
                    child: PDFList(
                      pdfMemories: _pdfMemories,
                      onSelectionChanged: () => setState(() {}),
                      onLongPress: _showExtractedText,
                      onRemove: _removeDocument,
                    ),
                  ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: _showAddOptions,
                      tooltip: 'Add content',
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        decoration: InputDecoration(
                          hintText: _isImageMode
                              ? 'Describe the image you want to generate...'
                              : 'Type your message...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Theme.of(context).colorScheme.surface,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                        ),
                        maxLines: null,
                        textInputAction: TextInputAction.newline,
                        onSubmitted: (_) => _submitMessage(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.image_outlined),
                      onPressed: () {
                        setState(() {
                          _isImageMode = !_isImageMode;
                        });
                      },
                      color: _isImageMode
                          ? Theme.of(context).colorScheme.primary
                          : null,
                      tooltip: 'Toggle image generation',
                    ),
                    IconButton(
                      icon: const Icon(Icons.send),
                      onPressed: _submitMessage,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
