import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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
import 'services/text_generation_service.dart';
import 'services/web_service.dart';
import 'utils/dialog_manager.dart';
import 'widgets/intro_drawer.dart';
import 'services/chat_storage_service.dart';
import 'models/saved_chat.dart';
import 'widgets/saved_chats_drawer.dart';
import 'widgets/settings_dialog.dart';
import 'services/offline_model_service.dart';
import 'package:provider/provider.dart';
import 'components/model_selector.dart';

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
  bool _isGenerating = false;

  // Services
  late final AIService _aiService;
  final PDFService _pdfService = PDFService();
  final ImageGenerationService _imageGenService = ImageGenerationService();
  final TextGenerationService _textGenService = TextGenerationService();
  final WebService _webService = WebService();
  final ImageService _imageService = ImageService();
  final ChatStorageService _chatStorage = ChatStorageService();
  List<SavedChat> _savedChats = [];

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    final offlineService = context.read<OfflineModelService>();
    _aiService = AIService(_textGenService, offlineService);
    await _chatStorage.init();
    _loadSavedChats();
    _checkServiceStatus();
  }

  void _loadSavedChats() {
    setState(() {
      _savedChats = _chatStorage.getAllChats();
    });
  }

  Future<void> _saveCurrentChat() async {
    if (_messages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No messages to save')),
      );
      return;
    }

    await _chatStorage.saveChat(_messages);
    _loadSavedChats();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chat saved successfully')),
      );
    }
  }

  Future<void> _deleteChat(String id) async {
    await _chatStorage.deleteChat(id);
    _loadSavedChats();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chat deleted')),
      );
    }
  }

  void _loadSavedChat(SavedChat chat) {
    setState(() {
      _messages.clear();
      _messages.addAll(chat.chatMessages);
    });
  }

  Future<void> _checkServiceStatus() async {
    // Add initial checking message
    setState(() {
      _messages.add(ChatMessage(
        content: "Checking if services are online...",
        isUser: false,
      ));
    });

    bool isTextServiceOnline = false;
    bool isImageServiceOnline = false;

    try {
      final textResponse = await _textGenService.generateText("say hi");
      isTextServiceOnline = textResponse.isNotEmpty;
    } catch (e) {
      isTextServiceOnline = false;
      if (kDebugMode) {
        print("Error checking text service status: $e");
      }
    }

    try {
      final imageBytes =
          await _imageGenService.generateImage(prompt: "boy in yellow hat");
      isImageServiceOnline = imageBytes != null;
    } catch (e) {
      isImageServiceOnline = false;
      if (kDebugMode) {
        print("Error checking image service status: $e");
      }
    }

    String statusMessage = "Hey! \n\n";
    statusMessage += isTextServiceOnline
        ? "Chat Service is Online. Ask Me Anything.\n\n"
        : "Chat Service is currently Offline :( Try Again Later.\n";

    statusMessage += isImageServiceOnline
        ? " Image Service is Online. Generate Amazing Images"
        : " Image Service is Offline. Try Again Later";

    setState(() {
      // Remove the checking message
      _messages.removeAt(0);
      // Add the status message
      _messages.add(ChatMessage(
        content: statusMessage,
        isUser: false,
        isError: !isTextServiceOnline || !isImageServiceOnline,
      ));
    });
    _scrollToBottom();
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
        if (mounted) {
          NotificationService.showTopNotification(
            context,
            message: 'PDF processed: ${newMemory.pdfName}',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        NotificationService.showTopNotification(
          context,
          message: 'Error processing PDF: ${e.toString()}',
          isError: true,
        );
      }
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
          if (!mounted) return;
          NotificationService.showTopNotification(
            context,
            message: 'Web content processed: ${webMemory.pdfName}',
          );
        }
      } catch (e) {
                  if (!mounted) return;

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
                    if (!mounted) return;

          NotificationService.showTopNotification(
            context,
            message: 'Image content processed: ${imageMemory.pdfName}',
          );
        }
      } catch (e) {
                  if (!mounted) return;

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
    // Stop any ongoing generation
    _aiService.stopGeneration();
    
    setState(() {
      _messages.clear();
      _isLoading = false;
      _isGenerating = false;
      _isImageMode = false;
      _isInternetMode = false;
      _controller.clear();
      _pdfMemories.clear();
    });

    // Show a brief confirmation
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Started new chat'),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  Future<void> _stopGeneration() async {
    _aiService.stopGeneration();
    setState(() {
      _isGenerating = false;
    });
  }

  Future<void> _submitMessage() async {
    final message = _controller.text.trim();
    if (message.isEmpty) return;

    setState(() {
      _messages.add(ChatMessage(content: message, isUser: true));
      _isLoading = true;
      _isGenerating = true;
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
            await _imageGenService.generateImage(prompt: message);

        if (imageData != null) {
          setState(() {
            _messages.add(ChatMessage(
              content: message,
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
        };
        setState(() {
          _isImageMode = false;
        });
      } else {
        await _aiService.getStreamingResponse(
          message,
          _pdfMemories,
          (response, done) {
            if (mounted) {
              setState(() {
                if (_messages.last.isUser) {
                  _messages.add(ChatMessage(
                    content: response,
                    isUser: false,
                  ));
                } else {
                  _messages.last = ChatMessage(
                    content: response,
                    isUser: false,
                  );
                }
                if (done) _isGenerating = false;
              });
              _scrollToBottom();
            }
          },
          useInternet: _isInternetMode,
          history: _messages,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add(ChatMessage(
            content: "Something went wrong! Try again later.",
            isUser: false,
            isError: true,
          ));
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isGenerating = false;
        });
        _scrollToBottom();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final offlineService = context.watch<OfflineModelService>();
    final isOffline = offlineService.isOfflineMode;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            const Expanded(
              child: Text(
                'Write4Me',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (isOffline && offlineService.availableModels.length > 1)
              PopupMenuButton<String>(
                tooltip: 'Switch Model',
                icon: const Icon(Icons.swap_horiz),
                itemBuilder: (context) => [
                  for (final model in offlineService.availableModels)
                    PopupMenuItem(
                      value: model.path,
                      child: Row(
                        children: [
                          Icon(
                            model.path == offlineService.selectedModelPath
                                ? Icons.check_circle
                                : Icons.circle_outlined,
                            size: 18,
                            color: Theme.of(context).primaryColor,
                          ),
                          const SizedBox(width: 8),
                          Text(model.path.split('/').last.replaceAll('.gguf', '')),
                        ],
                      ),
                    ),
                ],
                onSelected: (modelPath) {
                  offlineService.setSelectedModel(modelPath);
                },
              ),
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => SettingsDialog(
                    hasMessages: _messages.isNotEmpty,
                    onSaveChat: _saveCurrentChat,
                    onClearChat: _clearChat,
                    onShowInfo: () {
                      showDialog(
                        context: context,
                        barrierDismissible: true,
                        builder: (BuildContext context) => const IntroDrawer(),
                        useSafeArea: true,
                      );
                    },
                  ),
                );
              },
              tooltip: 'Settings',
            ),
          ],
        ),
      ),
      drawer: SavedChatsDrawer(
        chats: _savedChats,
        onChatSelected: _loadSavedChat,
        onChatDeleted: _deleteChat,
      ),
      body: Column(
        children: [
          if (_messages.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                children: [
                  const Text(
                    'Ask anything,\nget instant answers.',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      height: 1.2,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    height: 2,
                    width: 120,
                    decoration: BoxDecoration(
                      color:
                          Theme.of(context).primaryColor.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: ChatMessages(
              messages: _messages,
              isLoading: _isLoading,
              scrollController: _scrollController,
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            padding: const EdgeInsets.all(10),
            child: Column(
              children: [
                ModelSelector(isOfflineMode: isOffline),
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
                  isGenerating: _isGenerating,
                  onSubmit: _submitMessage,
                  onStop: _stopGeneration,
                  onAddContent: _showAddOptions,
                  onToggleInternet: isOffline 
                      ? null  // Now type-safe
                      : () {
                          setState(() {
                            _isInternetMode = !_isInternetMode;
                            _isImageMode = false;
                          });
                        },
                  onToggleImage: isOffline
                      ? null  // Now type-safe
                      : () {
                          setState(() {
                            _isImageMode = !_isImageMode;
                            _isInternetMode = false;
                          });
                        },
                  isInternetDisabled: _pdfMemories.isNotEmpty || isOffline,
                  isOfflineMode: isOffline,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
