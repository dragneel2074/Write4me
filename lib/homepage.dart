import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:write4me/utils/message_utils.dart';
import 'components/chat_input.dart';
import 'components/chat_messages.dart';
import 'components/document_list_container.dart';
import 'models/chat_message.dart';
import 'models/pdf_memory.dart';
import 'services/image_generation_service.dart';
import 'services/image_service.dart';
import 'services/notification_service.dart';
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
import '../providers/ui_state_provider.dart';
import 'providers/service_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/selected_documents_provider.dart';

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
  // final bool _isImageMode = false;

  // Services are now accessed through providers
  final ImageGenerationService _imageGenService = ImageGenerationService();
  final WebService _webService = WebService();
  final ImageService _imageService = ImageService();
  final ChatStorageService _chatStorage = ChatStorageService();

  // Move this to a StateNotifier
  // final List<SavedChat> _savedChats = [];

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    await _chatStorage.init();
    _loadSavedChats();

    // Initialize offline mode first
    try {
      final offlineModeNotifier = ref.read(offlineModeProvider.notifier);
      await offlineModeNotifier.initialize();
      debugPrint('Offline mode initialized');
    } catch (e) {
      debugPrint('Error initializing offline mode: $e');
    }

    // Then check service status
    _checkServiceStatus();
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
      final imageBytes =
          await _imageGenService.generateImage(prompt: "boy in yellow hat")
          .catchError((e) {
        debugPrint("Image Service check failed: $e");
        return null;
      });
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
    debugPrint("[RAG] Starting PDF processing workflow");
    
    // Use the PDFService through the provider
    final pdfService = ref.read(pdfServiceProvider);
    final pdfMemory = await pdfService.pickAndProcessPDF();
    
    if (pdfMemory != null) {
      debugPrint("[RAG] PDF picked: ${pdfMemory.name}");
      _addContent(pdfMemory);
      
      // Add to selectedDocumentsProvider to ensure RAG uses it
      final currentDocs = ref.read(selectedDocumentsProvider);
      ref.read(selectedDocumentsProvider.notifier).state = [...currentDocs, pdfMemory];
      debugPrint("[RAG] Added PDF to selectedDocumentsProvider: ${currentDocs.length + 1} documents");
      
      if (mounted) {
        NotificationService.showTopNotification(
          context,
          message: 'PDF processed: ${pdfMemory.name}',
        );
      }
      
      // The PDF has already been processed by the PDFService
      // which has the FileProcessor injected into it
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PDF processed successfully!'))
      );
    } else {
      if (mounted) {
      }
    }
  }

  void _addContent(PDFMemory memory) {
    setState(() {
      _pdfMemories.add(memory);
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
        MessageUtils.showInfo(context, 'Started new chat');
      // ScaffoldMessenger.of(context).showSnackBar(
      //   const SnackBar(
      //     content: Text('Started new chat'),
      //     duration: Duration(seconds: 1),
      //   ),
      // );
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
    final uiState = ref.read(uiStateProvider);
    final offlineModeState = ref.read(offlineModeProvider);
    final aiService = ref.read(aiServiceProvider);
    final textGenService = ref.read(textGenerationServiceProvider);

    _controller.clear();
    chatNotifier.startLoading();

    try {
      // Check for API key if web search is enabled
      if (uiState.isWebSearch) {
        final apiKey = await textGenService.getJinaApiKey();
        if (apiKey.isEmpty) {
          chatNotifier.stopLoading();
          if (context.mounted) {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('API Key Required'),
                content: const Text(
                  'Please set your Jina API key to use web search. You can set it by clicking the key icon in the top bar.'
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _showApiKeyDialog(context);
                    },
                    child: const Text('Set API Key'),
                  ),
                ],
              ),
            );
          }
          return;
        }
      }

      // Add user message
      chatNotifier.addMessage(ChatMessage(
        content: message,
        isUser: true,
      ));

      if (uiState.isImageMode) {
        // Add placeholder message
        final placeholderMessage = ChatMessage(
          content: "Generating image... Please wait.",
          isUser: false,
          // timestamp: DateTime.now().millisecondsSinceEpoch,
        );
        chatNotifier.addMessage(placeholderMessage);

        final imageData = await _imageGenService.generateImage(prompt: message)
          .catchError((e) {
            final userMessage = _getImageError(e);
            // Replace placeholder with error message
            chatNotifier.replaceMessage(
              placeholderMessage,
              ChatMessage(
                content: userMessage,
                isUser: false,
                isError: true,
                // timestamp: DateTime.now().millisecondsSinceEpoch,
              ),
            );
            return null;
          });

        if (imageData != null) {
          // Replace placeholder with actual image
          chatNotifier.replaceMessage(
            placeholderMessage,
            ChatMessage(
              content: message,
              isUser: false,
              imageData: imageData,
              // timestamp: DateTime.now().millisecondsSinceEpoch,
            ),
          );
        }
      } else {
        // Add initial placeholder message
        final placeholderMessage = ChatMessage(
          content: 'Generating response...',
          isUser: false,
        );
        chatNotifier.addMessage(placeholderMessage);

        // Determine if web search should be used
        final useWebSearch = uiState.isWebSearch;

        debugPrint('Submitting message with:');
        debugPrint('- isWebSearch: ${uiState.isWebSearch}');
        debugPrint('- isOfflineMode: ${offlineModeState.isOfflineMode}');
        debugPrint('- useLocalModel: ${offlineModeState.useLocalModel}');
        debugPrint('- useWebSearch: $useWebSearch');

        try {
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
            useWebSearch: useWebSearch,
            history: chatState.messages,
          );
        } catch (e) {
          chatNotifier.replaceMessage(
            placeholderMessage,
            ChatMessage(
              content: _getUserFriendlyError(e),
              isUser: false,
              isError: true,
            ),
          );
        }
      }
    } catch (e) {
      final errorMessage = uiState.isImageMode ? _getImageError(e) : _getUserFriendlyError(e);
      chatNotifier.addMessage(ChatMessage(
        content: errorMessage,
        isUser: false,
        isError: true,
      ));
    } finally {
      if (mounted) {
        chatNotifier.stopLoading();
        chatNotifier.setGenerating(false);
        _scrollToBottom();
      }
    }
  }

  String _getImageError(dynamic error) {
    if (error is NetworkException) {
      return 'Image generation failed: No internet connection. Please check your network.';
    } else if (error is TimeoutException) {
      return 'Image generation took too long. Please try again.';
    } else if (error is HttpException) {
      return 'Temporary image service issue. Please try again later.';
    }
    return 'Image generation failed. Please try again.';
  }

  String _getUserFriendlyError(dynamic error) {
    if (error is SocketException) {
      return 'No internet connection. Please check your network and try again.';
    } else if (error is TimeoutException) {
      return 'Request took too long. Please try again.';
    } else if (error is HttpException) {
      return 'Temporary service issue. Please try again in a moment.';
    }
    return 'Something went wrong. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    final offlineModeState = ref.watch(offlineModeProvider);
    
    // Add debug prints
    debugPrint('HomePage build - isOfflineMode: ${offlineModeState.isOfflineMode}');
    debugPrint('HomePage build - useLocalModel: ${offlineModeState.useLocalModel}');
    debugPrint('HomePage build - availableModels: ${offlineModeState.availableModels.length}');

    return ref.watch(offlineModelInitProvider).when(
      data: (_) {
        final chatState = ref.watch(chatProvider);
        final uiState = ref.watch(uiStateProvider);

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
                // Only show key icon when not in offline mode
                if (!offlineModeState.isOfflineMode) 
                  IconButton(
                    icon: const Icon(Icons.key),
                    onPressed: () => _showApiKeyDialog(context),
                  ),
                IconButton(
                  icon: const Icon(Icons.settings),
                  onPressed: () => _showSettingsDialog(context),
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
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
                          color: Theme.of(context)
                              .primaryColor
                              .withValues(alpha: 0.5),
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
                      isWebSearch: uiState.isWebSearch,
                      isGenerating: chatState.isGenerating,
                      onSubmit: _submitMessage,
                      onStop: _stopGeneration,
                      onAddContent: _showAddOptions,
                      onToggleWebSearch: offlineModeState.isOfflineMode
                          ? null
                          : () => ref
                              .read(uiStateProvider.notifier)
                              .toggleWebSearch(),
                      onToggleImage: () =>
                          ref.read(uiStateProvider.notifier).toggleImageMode(),
                      isWebSearchDisabled: _pdfMemories.isNotEmpty ||
                          offlineModeState.isOfflineMode,
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
      // ScaffoldMessenger.of(context).showSnackBar(
      //   const SnackBar(content: Text('No messages to save')),
      // );
        MessageUtils.showInfo(context, 'No messages to save');
      return;
    }

    await _chatStorage.saveChat(chatState.messages);
    _loadSavedChats();

    if (mounted) {
      // ScaffoldMessenger.of(context).showSnackBar(
      //   const SnackBar(content: Text('Chat saved successfully')),
      // );
        MessageUtils.showInfo(context, 'Started new chat');
    }
  }

  Future<void> _deleteChat(String id) async {
    await _chatStorage.deleteChat(id);
    _loadSavedChats();

    if (mounted) {
          // ScaffoldMessenger.of(context).showSnackBar(
          //   const SnackBar(content: Text('Chat deleted')),
          // );
          MessageUtils.showSuccess(context, 'Chat deleted');
    }
  }

  Future<void> _showApiKeyDialog(BuildContext context) async {
    final textGenService = ref.read(textGenerationServiceProvider);
    final currentKey = await textGenService.getJinaApiKey();
    
    final controller = TextEditingController(text: currentKey);
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Jina API Key'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter your Jina API key for web search:'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'Enter API key',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
            GestureDetector(
  onTap: () async {
    final Uri url = Uri.parse('https://jina.ai/#apiform');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      throw 'Could not launch $url';
    }
  },
  child: const Text(
    'Get a free API key by going to Jina.ai',
    style: TextStyle(
      color: Colors.blue,
      decoration: TextDecoration.underline,
    ),
  ),)

          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('jina_api_key', controller.text.trim());
              if (context.mounted) {
                Navigator.pop(context);
                // ScaffoldMessenger.of(context).showSnackBar(
                //   const SnackBar(content: Text('API key saved')),
                // );
                MessageUtils.showSuccess(context, 'API key saved');
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _showSettingsDialog(BuildContext context) {
    return showDialog(
      context: context,
      builder: (context) => SettingsDialog(
        hasMessages: ref.read(chatProvider).messages.isNotEmpty,
        onSaveChat: _saveCurrentChat,
        onClearChat: _clearChat,
        onShowInfo: () {
          showDialog(
            context: context,
            barrierDismissible: true,
            builder: (BuildContext context) =>
                const IntroDrawer(),
            useSafeArea: true,
          );
        },
      ),
    );
  }
}
