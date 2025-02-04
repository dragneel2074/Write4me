import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'components/chat_input.dart';
import 'components/chat_messages.dart';
import 'components/document_list_container.dart';
import 'models/chat_message.dart';
import 'models/pdf_memory.dart';
import 'services/image_generation_service.dart';
import 'services/image_service.dart';
import 'services/notification_service.dart';
import 'services/pdf_service.dart';
import 'services/web_service.dart';
import 'utils/dialog_manager.dart';
import 'widgets/intro_drawer.dart';
import 'services/chat_storage_service.dart';
import 'models/saved_chat.dart';
import 'widgets/saved_chats_drawer.dart';
import 'widgets/settings_dialog.dart';
import 'components/model_selector.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/chat_provider.dart';
import '../providers/service_provider.dart';
import '../providers/ui_state_provider.dart';
import '../providers/offline_mode_provider.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage>
    with SingleTickerProviderStateMixin {
  final List<PDFMemory> _pdfMemories = [];
  final TextEditingController _controller = TextEditingController();
  late final ScrollController _scrollController;
  
  // Move these to a new StateNotifier
  bool _isImageMode = false;
  bool _isInternetMode = false;

  // Services that don't need state management
  final PDFService _pdfService = PDFService();
  final ImageGenerationService _imageGenService = ImageGenerationService();
  final WebService _webService = WebService();
  final ImageService _imageService = ImageService();
  final ChatStorageService _chatStorage = ChatStorageService();

  // Move this to a StateNotifier
  final List<SavedChat> _savedChats = [];

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    await _chatStorage.init();
    _loadSavedChats();
    
    // Only check service status after offline service is initialized
    ref.read(offlineModelInitProvider.future).then((_) {
      _checkServiceStatus();
    });
  }

  void _loadSavedChats() {
    final chats = _chatStorage.getAllChats();
    ref.read(uiStateProvider.notifier).setSavedChats(chats);
  }

  void _loadSavedChat(SavedChat chat) {
    ref.read(chatProvider.notifier).loadMessages(chat.chatMessages);
  }


  Future<void> _checkServiceStatus() async {
    final chatNotifier = ref.read(chatProvider.notifier);
    final textGenService = ref.read(textGenerationServiceProvider);
    
    chatNotifier.addMessage(
      ChatMessage(
        content: "Checking if services are online...",
        isUser: false,
      ),
    );

    bool isTextServiceOnline = false;
    bool isImageServiceOnline = false;

    try {
      final textResponse = await textGenService.generateText("say hi");
      isTextServiceOnline = textResponse.isNotEmpty;
    } catch (e) {
      isTextServiceOnline = false;
    }

    try {
      final imageBytes = await _imageGenService.generateImage(prompt: "boy in yellow hat");
      isImageServiceOnline = imageBytes!.isNotEmpty;
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

    // Update status message
    chatNotifier.loadMessages([
      ChatMessage(
        content: statusMessage,
        isUser: false,
        isError: !isTextServiceOnline || !isImageServiceOnline,
      ),
    ]);
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
    final offlineModeState = ref.read(offlineModeProvider);
    final isOffline = offlineModeState.isOfflineMode;
    
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.picture_as_pdf),
              title: const Text('Add PDF'),
              onTap: () {
                Navigator.pop(context);
                _pickPDFAndCreateRAG();
              },
            ),
            ListTile(
              leading: const Icon(Icons.image),
              title: const Text('Add Image'),
              onTap: () {
                Navigator.pop(context);
                _processImageContent();
              },
            ),
            // Only show web URL option in online mode
            if (!isOffline)
              ListTile(
                leading: const Icon(Icons.link),
                title: const Text('Add Web URL'),
                onTap: () {
                  Navigator.pop(context);
                  _processWebContent();
                },
              ),
          ],
        ),
      ),
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
            message: 'PDF processed: ${newMemory.name}',
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
            message: 'Web content processed: ${webMemory.name}',
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
            message: 'Image content processed: ${imageMemory.name}',
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
      memory.name,
      memory.extractedText,
    );
  }

  Future<void> _clearChat() async {
    final aiService = ref.read(aiServiceProvider);
    aiService.stopGeneration();
    
    final chatNotifier = ref.read(chatProvider.notifier);
    chatNotifier.clearMessages();
    
    ref.read(uiStateProvider.notifier).resetModes();
    _controller.clear();
    setState(() {
      _pdfMemories.clear();
    });

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
    final aiService = ref.read(aiServiceProvider);
    aiService.stopGeneration();
    ref.read(chatProvider.notifier).setGenerating(false);
  }

  Future<void> _submitMessage() async {
    final message = _controller.text.trim();
    if (message.isEmpty) return;

    final chatNotifier = ref.read(chatProvider.notifier);
    final chatState = ref.read(chatProvider);
    final aiService = ref.read(aiServiceProvider);
    final uiState = ref.read(uiStateProvider);
    final offlineModeState = ref.read(offlineModeProvider);
    
    // Add user message
    final userMessage = ChatMessage(content: message, isUser: true);
    chatNotifier.addMessage(userMessage);
    
    // Set loading state
    chatNotifier.startLoading();
    chatNotifier.setGenerating(true);
    _controller.clear();
    _scrollToBottom();

    try {
      if (uiState.isImageMode) {
        chatNotifier.addMessage(
          ChatMessage(
            content: "Generating image... Please wait.",
            isUser: false,
          )
        );

        final imageData = await _imageGenService.generateImage(prompt: message);

        if (imageData != null) {
          chatNotifier.addMessage(
            ChatMessage(
              content: message,
              isUser: false,
              imageData: imageData,
            )
          );
        } else {
          chatNotifier.setError("Failed to generate image.");
        }
        setState(() => _isImageMode = false);
      } else {
        // Add initial AI message
        chatNotifier.addMessage(
          ChatMessage(content: '', isUser: false)
        );
        
        // Don't allow internet mode in offline mode
        final useInternet = !offlineModeState.isOfflineMode && uiState.isInternetMode;
        
        await aiService.getStreamingResponse(
          message,
          _pdfMemories,
          (response, done) {
            if (mounted) {
              chatNotifier.updateLastMessage(response);
              if (done) chatNotifier.setGenerating(false);
              _scrollToBottom();
            }
          },
          useInternet: useInternet,
          history: chatState.messages,
        );
      }
    } catch (e) {
      chatNotifier.setError("Something went wrong! Try again later.");
    } finally {
      if (mounted) {
        chatNotifier.stopLoading();
        chatNotifier.setGenerating(false);
        _scrollToBottom();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch the initialization state
    final initState = ref.watch(offlineModelInitProvider);
    
    return initState.when(
      data: (_) {
        final offlineModeState = ref.watch(offlineModeProvider);
        final chatState = ref.watch(chatProvider);
        final uiState = ref.watch(uiStateProvider);
        final aiService = ref.watch(aiServiceProvider);

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
                // if (offlineModeState.isOfflineMode && offlineModeState.availableModels.length > 1)
                //   PopupMenuButton<String>(
                //     tooltip: 'Switch Model',
                //     icon: const Icon(Icons.swap_horiz),
                //     itemBuilder: (context) => [
                //       for (final model in offlineModeState.availableModels)
                //         PopupMenuItem(
                //           value: model.path,
                //           child: Row(
                //             children: [
                //               Icon(
                //                 model.path == offlineModeState.selectedModelPath
                //                     ? Icons.check_circle
                //                     : Icons.circle_outlined,
                //                 size: 18,
                //                 color: Theme.of(context).primaryColor,
                //               ),
                //               const SizedBox(width: 8),
                //               Text(model.path.split('/').last.replaceAll('.gguf', '')),
                //             ],
                //           ),
                //         ),
                //     ],
                //     onSelected: (modelPath) {
                //       ref.read(offlineModeProvider.notifier).setSelectedModel(modelPath);
                //     },
                //   ),
                IconButton(
                  icon: const Icon(Icons.settings),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => SettingsDialog(
                        hasMessages: chatState.messages.isNotEmpty,
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
            chats: uiState.savedChats,
            onChatSelected: _loadSavedChat,
            onChatDeleted: _deleteChat,
          ),
          body: Column(
            children: [
              if (chatState.messages.isEmpty)
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
                  scrollController: _scrollController,
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 4,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(10),
                child: Column(
                  children: [
                    ModelSelector(
                      isOfflineMode: offlineModeState.isOfflineMode,
                    ),
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
                      isImageMode: uiState.isImageMode,
                      isInternetMode: uiState.isInternetMode,
                      isGenerating: chatState.isGenerating,
                      onSubmit: _submitMessage,
                      onStop: _stopGeneration,
                      onAddContent: _showAddOptions,
                      onToggleInternet: offlineModeState.isOfflineMode 
                          ? null
                          : () => ref.read(uiStateProvider.notifier).toggleInternetMode(),
                      onToggleImage: () => ref.read(uiStateProvider.notifier).toggleImageMode(),
                      isInternetDisabled: _pdfMemories.isNotEmpty || offlineModeState.isOfflineMode,
                      isOfflineMode: offlineModeState.isOfflineMode,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      ),
      error: (error, _) => Scaffold(
        body: Center(
          child: Text('Error initializing: $error'),
        ),
      ),
    );
  }

  Future<void> _saveCurrentChat() async {
    final chatState = ref.read(chatProvider);
    if (chatState.messages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No messages to save')),
      );
      return;
    }

    await _chatStorage.saveChat(chatState.messages);
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
}
