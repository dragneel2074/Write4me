import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'components/chat_input.dart';
import 'components/chat_messages.dart';
import 'components/document_list_container.dart';
import 'components/model_selector.dart';
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
import 'providers/providers.dart';
import 'providers/chat_provider.dart';
import 'providers/service_status_provider.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
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
    _loadSavedChats();
    _checkServiceStatus();
  }

  Future<void> _initializeServices() async {
    final offlineService = ref.read(offlineModelNotifierProvider);
    _aiService = AIService(_textGenService, offlineService);
    await _chatStorage.init();
    _loadSavedChats();
    _checkServiceStatus();
  }

  void _loadSavedChats() {
    final chatStorage = ref.read(chatStorageNotifierProvider);
    setState(() {
      _savedChats = chatStorage.getAllChats();
    });
  }

  Future<void> _saveCurrentChat() async {
    final chatState = ref.read(chatNotifierProvider);
    if (chatState.messages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No messages to save')),
      );
      return;
    }

    final chatStorage = ref.read(chatStorageNotifierProvider);
    await chatStorage.saveChat(chatState.messages);
    _loadSavedChats();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chat saved successfully')),
      );
    }
  }

  Future<void> _deleteChat(String id) async {
    final chatStorage = ref.read(chatStorageNotifierProvider);
    await chatStorage.deleteChat(id);
    _loadSavedChats();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chat deleted')),
      );
    }
  }

  void _loadSavedChat(SavedChat chat) {
    final chatNotifier = ref.read(chatNotifierProvider.notifier);
    chatNotifier.clearMessages();
    for (final message in chat.chatMessages) {
      chatNotifier.addMessage(message);
    }
  }

  Future<void> _checkServiceStatus() async {
    final chatNotifier = ref.read(chatNotifierProvider.notifier);
    
    // Add initial checking message
    chatNotifier.addMessage(ChatMessage(
      content: "Checking if services are online...",
      isUser: false,
    ));

    final statusNotifier = ref.read(serviceStatusNotifierProvider.notifier);
    await statusNotifier.checkStatus();
    
    final status = await ref.read(serviceStatusNotifierProvider.future);
    
    String statusMessage = "Hey! \n\n";
    statusMessage += status.isTextServiceOnline
        ? "Chat Service is Online. Ask Me Anything.\n\n"
        : "Chat Service is currently Offline :( Try Again Later.\n";

    statusMessage += status.isImageServiceOnline
        ? "Image Service is Online. Generate Amazing Images"
        : "Image Service is Offline. Try Again Later";

    // Remove the checking message and add the status message
    chatNotifier.clearMessages();
    chatNotifier.addMessage(ChatMessage(
      content: statusMessage,
      isUser: false,
      isError: !status.isTextServiceOnline || !status.isImageServiceOnline,
    ));
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
    final offlineService = ref.read(offlineModelNotifierProvider);
    final isOffline = offlineService.isOfflineMode;

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
    final pdfService = ref.read(pdfServiceProvider);
    final chatNotifier = ref.read(chatNotifierProvider.notifier);
    
    try {
      final memory = await pdfService.pickAndProcessPDF();
      if (memory != null) {
        chatNotifier.addPDFMemory(memory);
        if (mounted) {
          NotificationService.showTopNotification(
            context,
            message: 'PDF processed: ${memory.fileName}',
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

  Future<void> _processWebContent() async {
    final webService = ref.read(webServiceProvider);
    final chatNotifier = ref.read(chatNotifierProvider.notifier);
    
    final url = await DialogManager.showURLInputDialog(context);
    if (url == null || url.isEmpty) return;

    try {
      final memory = await webService.processWebContent(url);
      if (memory != null) {
        chatNotifier.addPDFMemory(memory);
        if (!mounted) return;
        NotificationService.showTopNotification(
          context,
          message: 'Web content processed: ${memory.fileName}',
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

  Future<void> _processImageContent() async {
    final imageService = ref.read(imageServiceProvider);
    final chatNotifier = ref.read(chatNotifierProvider.notifier);
    
    try {
      final memory = await imageService.pickAndProcessImage();
      if (memory != null) {
        chatNotifier.addPDFMemory(memory);
        if (!mounted) return;

        NotificationService.showTopNotification(
          context,
          message: 'Image content processed: ${memory.fileName}',
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

  void _showExtractedText(PDFMemory memory) {
    DialogManager.showExtractedText(
      context,
      memory.fileName,
      memory.extractedText,
    );
  }

  void _clearChat() {
    ref.read(chatNotifierProvider.notifier).clearMessages();
  }

  Future<void> _stopGeneration() async {
    _aiService.stopGeneration();
    setState(() {
      _isGenerating = false;
    });
  }

  Future<void> _submitMessage() async {
    if (_controller.text.trim().isEmpty) return;

    final chatNotifier = ref.read(chatNotifierProvider.notifier);
    final chatState = ref.read(chatNotifierProvider);
    final question = _controller.text;
    _controller.clear();

    if (chatState.isImageMode) {
      await chatNotifier.handleImageGeneration(question);
      return;
    }

    chatNotifier.addMessage(ChatMessage(
      content: question,
      isUser: true,
    ));
    chatNotifier.setGenerating(true);

    try {
      final aiService = ref.read(aiServiceProvider);
      await aiService.getStreamingResponse(
        question,
        chatState.pdfMemories,
        (response, done) {
          if (chatNotifier.state.messages.last.isUser) {
            chatNotifier.addMessage(ChatMessage(
              content: response,
              isUser: false,
            ));
          } else {
            chatNotifier.updateLastMessage(ChatMessage(
              content: response,
              isUser: false,
            ));
          }
          chatNotifier.setGenerating(!done);
          _scrollToBottom();
        },
        useInternet: chatState.isInternetMode,
        history: chatState.messages,
      );
    } catch (e) {
      chatNotifier.addMessage(ChatMessage(
        content: 'Error: $e',
        isUser: false,
        isError: true,
      ));
      chatNotifier.setGenerating(false);
    }
  }

  void _showInfo() {
    showDialog(
      context: context,
      builder: (context) => const IntroDrawer(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final offlineService = ref.watch(offlineModelNotifierProvider);
    final chatState = ref.watch(chatNotifierProvider);

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
            if (offlineService.isOfflineMode && offlineService.availableModels.length > 1)
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
                    hasMessages: chatState.messages.isNotEmpty,
                    onSaveChat: _saveCurrentChat,
                    onClearChat: _clearChat,
                    onShowInfo: _showInfo,
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
              messages: chatState.messages,
              isLoading: _isLoading,
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
                ModelSelector(isOfflineMode: offlineService.isOfflineMode),
                DocumentListContainer(
                  documents: chatState.pdfMemories,
                  onSelectionChanged: () => setState(() {}),
                  onLongPress: _showExtractedText,
                  onRemove: (memory) {
                    ref.read(chatNotifierProvider.notifier).removePDFMemory(memory);
                  },
                ),
                ChatInput(
                  controller: _controller,
                  isImageMode: chatState.isImageMode,
                  isInternetMode: chatState.isInternetMode,
                  isGenerating: chatState.isGenerating,
                  onSubmit: _submitMessage,
                  onStop: _stopGeneration,
                  onAddContent: _showAddOptions,
                  onToggleInternet: offlineService.isOfflineMode 
                      ? null 
                      : () => ref.read(chatNotifierProvider.notifier).toggleInternetMode(),
                  onToggleImage: () => ref.read(chatNotifierProvider.notifier).toggleImageMode(),
                  isInternetDisabled: chatState.pdfMemories.isNotEmpty || offlineService.isOfflineMode,
                  isOfflineMode: offlineService.isOfflineMode,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
