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
import 'package:image_picker/image_picker.dart';
import 'services/web_service.dart';
import 'services/image_service.dart';
import 'services/notification_service.dart';

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
  bool _isInternetMode = false;
  final WebService _webService = WebService();
  final ImageService _imageService = ImageService();

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
        // Get last 6 messages for context
        final recentHistory = _messages.length > 6
            ? _messages.sublist(_messages.length - 6)
            : _messages;

        final response = await _aiService.getResponse(
          userMessage,
          _pdfMemories.where((memory) => memory.isSelected).toList(),
          useInternet: _isInternetMode,
          history: recentHistory,
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
              icon: Icons.web,
              title: 'Web URL',
              onTap: () {
                Navigator.pop(context);
                _processWebContent();
              },
            ),
            _buildOptionTile(
              icon: Icons.file_copy,
              title: 'Files',
              onTap: () {
                Navigator.pop(context);
                _pickPDFAndCreateRAG();
              },
            ),
            _buildOptionTile(
              icon: Icons.image,
              title: 'Image',
              onTap: () {
                Navigator.pop(context);
                _processImageContent();
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

  void _addContent(PDFMemory memory) {
    setState(() {
      _pdfMemories.add(memory);
      // Disable internet mode when content is added
      _isInternetMode = false;
    });
  }

  Future<void> _pickPDFAndCreateRAG() async {
    try {
      PDFMemory? newMemory = await _pdfService.pickAndProcessPDF();
      if (newMemory != null) {
        _addContent(newMemory);
        NotificationService.showTopNotification(
          context,
          message: 'PDF processed: ${newMemory.pdfName}',
        );
      }
    } catch (e) {
      _showErrorSnackBar('Error processing PDF: ${e.toString()}');
    }
  }

  void _showErrorSnackBar(String message) {
    NotificationService.showTopNotification(
      context,
      message: message,
      isError: true,
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

  Future<void> _processWebContent() async {
    final url = await _showURLInputDialog();
    if (url != null) {
      try {
        PDFMemory? webMemory = await _webService.processWebContent(url);
        if (webMemory != null) {
          _addContent(webMemory);
          NotificationService.showTopNotification(
            context,
            message: 'Web content processed: ${webMemory.pdfName}',
          );
        }
      } catch (e) {
        _showErrorSnackBar('Error processing web content: ${e.toString()}');
      }
    }
  }

  Future<String?> _showURLInputDialog() async {
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

  Future<void> _processImageContent() async {
    final source = await _showImageSourceDialog();
    if (source != null) {
      try {
        PDFMemory? imageMemory =
            await _imageService.processImageContent(source);
        if (imageMemory != null) {
          _addContent(imageMemory);
          NotificationService.showTopNotification(
            context,
            message: 'Image content processed: ${imageMemory.pdfName}',
          );
        }
      } catch (e) {
        _showErrorSnackBar('Error processing image: ${e.toString()}');
      }
    }
  }

  Future<ImageSource?> _showImageSourceDialog() async {
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
            padding: const EdgeInsets.all(10),
            child: Column(
              children: [
                if (_pdfMemories.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(1),
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
                TextField(
                  controller: _controller,
                  decoration: InputDecoration(
                    hintText: _isImageMode
                        ? 'Describe the image you want to generate...'
                        : _isInternetMode
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
                      vertical: 10,
                    ),
                    hintStyle: const TextStyle(fontSize: 13),
                  ),
                  style: const TextStyle(fontSize: 13),
                  maxLines: null,
                  minLines: 1,
                  textInputAction: TextInputAction.newline,
                  onSubmitted: (_) => _submitMessage(),
                  onChanged: (text) {
                    // Trigger rebuild when text changes to update button layout
                    setState(() {});
                  },
                ),
                if (_controller.text.split('\n').length > 1)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.add, size: 20),
                          onPressed: _showAddOptions,
                          tooltip: 'Add content',
                        ),
                        IconButton(
                          icon: const Icon(Icons.public, size: 20),
                          onPressed: _pdfMemories.isEmpty
                              ? () {
                                  setState(() {
                                    _isInternetMode = !_isInternetMode;
                                    _isImageMode = false;
                                  });
                                }
                              : null,
                          color: _isInternetMode
                              ? Theme.of(context).colorScheme.primary
                              : null,
                          tooltip: _pdfMemories.isEmpty
                              ? 'Toggle internet search'
                              : 'Internet search disabled when documents are present',
                        ),
                        IconButton(
                          icon: const Icon(Icons.image_outlined, size: 20),
                          onPressed: () {
                            setState(() {
                              _isImageMode = !_isImageMode;
                              _isInternetMode = false;
                            });
                          },
                          color: _isImageMode
                              ? Theme.of(context).colorScheme.primary
                              : null,
                          tooltip: 'Toggle image generation',
                        ),
                        IconButton(
                          icon: const Icon(Icons.send, size: 20),
                          onPressed: _submitMessage,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ],
                    ),
                  )
                else
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.add, size: 20),
                        onPressed: _showAddOptions,
                        tooltip: 'Add content',
                      ),
                      const SizedBox(width: 0),
                      Expanded(
                        child: Container(), // Empty container to take up space
                      ),
                      IconButton(
                        icon: const Icon(Icons.public, size: 20),
                        onPressed: _pdfMemories.isEmpty
                            ? () {
                                setState(() {
                                  _isInternetMode = !_isInternetMode;
                                  _isImageMode = false;
                                });
                              }
                            : null,
                        color: _isInternetMode
                            ? Theme.of(context).colorScheme.primary
                            : null,
                        tooltip: _pdfMemories.isEmpty
                            ? 'Toggle internet search'
                            : 'Internet search disabled when documents are present',
                      ),
                      IconButton(
                        icon: const Icon(Icons.image_outlined, size: 20),
                        onPressed: () {
                          setState(() {
                            _isImageMode = !_isImageMode;
                            _isInternetMode = false;
                          });
                        },
                        color: _isImageMode
                            ? Theme.of(context).colorScheme.primary
                            : null,
                        tooltip: 'Toggle image generation',
                      ),
                      IconButton(
                        icon: const Icon(Icons.send, size: 20),
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
