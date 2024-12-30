import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'components/chat_input.dart';
import 'components/chat_messages.dart';
import 'components/document_list_container.dart';
import 'models/chat_message.dart';
import 'models/pdf_memory.dart';
import 'services/ai_service.dart';
import 'services/image_generation_service.dart';
import 'services/image_service.dart';
import 'services/notification_service.dart';
import 'services/pdf_service.dart';
import 'services/web_service.dart';
import 'theme/theme_provider.dart';
import 'utils/dialog_manager.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  final List<PDFMemory> _pdfMemories = [];
  final TextEditingController _controller = TextEditingController();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;
  late final ScrollController _scrollController;
  bool _isImageMode = false;
  bool _isInternetMode = false;

  // Services
  final PDFService _pdfService = PDFService();
  final AIService _aiService = AIService();
  final ImageGenerationService _imageGenService = ImageGenerationService();
  final WebService _webService = WebService();
  final ImageService _imageService = ImageService();

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

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

  Future<void> _showAddOptions() async {
    await DialogManager.showAddOptionsDialog(
      context,
      onWebSelected: _processWebContent,
      onFileSelected: _pickPDFAndCreateRAG,
      onImageSelected: _processImageContent,
    );
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
      NotificationService.showTopNotification(
        context,
        message: 'Error processing PDF: ${e.toString()}',
        isError: true,
      );
    }
  }

  void _addContent(PDFMemory memory) {
    setState(() {
      _pdfMemories.add(memory);
      _isInternetMode = false;
    });
  }

  Future<void> _processWebContent() async {
    final url = await DialogManager.showURLInputDialog(context);
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
        NotificationService.showTopNotification(
          context,
          message: 'Error processing web content: ${e.toString()}',
          isError: true,
        );
      }
    }
  }

  Future<void> _processImageContent() async {
    final source = await DialogManager.showImageSourceDialog(context);
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
        NotificationService.showTopNotification(
          context,
          message: 'Error processing image: ${e.toString()}',
          isError: true,
        );
      }
    }
  }

  void _showExtractedText(PDFMemory memory) {
    DialogManager.showExtractedText(
      context,
      memory.pdfName,
      memory.extractedText,
    );
  }

  Future<void> _clearChat() async {
    final shouldClear = await DialogManager.showClearChatConfirmation(context);
    if (shouldClear ?? false) {
      setState(() {
        _messages.clear();
      });
    }
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
            child: ChatMessages(
              messages: _messages,
              isLoading: _isLoading,
              scrollController: _scrollController,
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
                DocumentListContainer(
                  documents: _pdfMemories,
                  onSelectionChanged: () => setState(() {}),
                  onLongPress: _showExtractedText,
                  onRemove: (memory) {
                    setState(() {
                      _pdfMemories.remove(memory);
                    });
                  },
                ),
                ChatInput(
                  controller: _controller,
                  isImageMode: _isImageMode,
                  isInternetMode: _isInternetMode,
                  onSubmit: _submitMessage,
                  onAddContent: _showAddOptions,
                  onToggleInternet: () {
                    setState(() {
                      _isInternetMode = !_isInternetMode;
                      _isImageMode = false;
                    });
                  },
                  onToggleImage: () {
                    setState(() {
                      _isImageMode = !_isImageMode;
                      _isInternetMode = false;
                    });
                  },
                  isInternetDisabled: _pdfMemories.isNotEmpty,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
