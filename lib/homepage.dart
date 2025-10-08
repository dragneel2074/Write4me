import 'dart:convert';
import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:write4me/services/offline_model_service.dart';
import 'package:write4me/utils/message_utils.dart';
import 'components/chat_input.dart';
import 'components/chat_messages.dart';
import 'components/document_list_container.dart';
import 'models/chat_message.dart';
import 'models/pdf_memory.dart';
import 'embedding_generator.dart';
import 'models/image_memory.dart';
import 'services/image_generation_service.dart';

import 'services/notification_service.dart';

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
import 'package:write4me/services/file_upload_service.dart';
import 'package:collection/collection.dart'; // For firstWhereOrNull


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
  bool _isProcessingRAG = false; // New state variable
  

  // Move these to a new StateNotifier
  // final bool _isImageMode = false;

  // Services are now accessed through providers
  final ImageGenerationService _imageGenService = ImageGenerationService();
  final FileUploadService _fileUploadService = FileUploadService();
  
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
    final onlineModel = ref.read(onlineModelServiceProvider).selectedOnlineModel;
    final hasVision = onlineModel?.vision ?? false;
    final isKontext = ref.read(onlineModelServiceProvider).selectedImageModel.toLowerCase() == 'kontext';
    final isImageMode = ref.read(uiStateProvider).isImageMode;

    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isImageMode && isKontext)
              ListTile(
                leading: const Icon(Icons.add_photo_alternate_outlined),
                title: const Text('Select Image to Edit'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImageForKontext();
                },
              )
            else ...[
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
                title: const Text('Add Image (OCR)'),
                onTap: () {
                  Navigator.pop(context);
                  _processImageContent();
                },
              ),
              if (!isOffline && hasVision)
                ListTile(
                  leading: const Icon(Icons.image_search),
                  title: const Text('Add Image (Vision)'),
                  onTap: () {
                    Navigator.pop(context);
                    _processImageVision();
                  },
                ),
            ]
          ],
        ),
      ),
    );
  }

  Future<void> _pickImageForKontext() async {
    ref.read(uiStateProvider.notifier).setImageMode(true);
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      final imageFile = File(pickedFile.path);
      // Remove previous kontext image if any
      final chatNotifier = ref.read(chatProvider.notifier);
      final chatState = ref.read(chatProvider);

      final existingKontextImage = chatState.imageMemories.firstWhereOrNull(
        (m) => m.extractedText == 'Image for kontext',
      );
      if (existingKontextImage != null) {
        chatNotifier.removeImageMemory(existingKontextImage);
      }

      // Create the memory object first
      final imageMemory = ImageMemory(
        pickedFile.path.split('/').last,
        'Image for kontext', // Special marker
        imageFile: imageFile,
      );
      chatNotifier.addImageMemory(imageMemory);

      // Show notification that we are uploading
      if (mounted) {
        NotificationService.showTopNotification(
          context,
          message: 'Uploading image...',
        );
      }

      try {
        // Upload the image
        final imageBytes = await imageFile.readAsBytes();
        final imageUrl = await _fileUploadService.uploadImage(
            imageBytes, imageMemory.name);
        
        if (imageUrl != null) {
          // Update the memory object with the URL
          // Find the memory in the chat state and update it
          final updatedImageMemory = imageMemory.copyWith(imageUrl: imageUrl);
          chatNotifier.removeImageMemory(imageMemory);
          chatNotifier.addImageMemory(updatedImageMemory);

          debugPrint('Uploaded image URL: $imageUrl');
          if (mounted) {
            NotificationService.showTopNotification(
              context,
              message: 'Image ready for editing.',
              isError: false,
            );
          }
        } else {
          throw Exception('Image upload returned null URL');
        }
      } catch (e) {
        debugPrint('Error uploading image: $e');
        if (mounted) {
          NotificationService.showTopNotification(
            context,
            message: 'Image upload failed. Please try again.',
            isError: true,
          );
        }
        // Remove the memory object if upload fails
        chatNotifier.removeImageMemory(imageMemory);
      }

    } else {
      // Only turn off image mode if no image is selected and no other images are present for vision.
      final chatState = ref.read(chatProvider);
      final hasVisionImage = chatState.imageMemories.any((m) => m.extractedText == 'Image for vision model');
      if (!hasVisionImage) {
        ref.read(uiStateProvider.notifier).setImageMode(false);
      }
    }
  }

   Future<void> _pickPDFAndCreateRAG() async {
    final chatNotifier = ref.read(chatProvider.notifier);
    chatNotifier.setGenerating(true); // Set generating to true
    setState(() { _isProcessingRAG = true; }); // Set RAG processing to true
    debugPrint("[RAG] Starting PDF processing workflow");
    
    try {
      // Use the PDFService through the provider
      final pdfService = ref.read(pdfServiceProvider);
      final pdfMemory = await pdfService.pickAndProcessPDF();
      
      if (pdfMemory != null) {
        debugPrint("[RAG] PDF picked: ${pdfMemory.name}");
        _addPdfContent(pdfMemory);
        
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
        
        // ScaffoldMessenger.of(context).showSnackBar(
        //   const SnackBar(content: Text('PDF processed successfully!'))
        // );
      } else {
        if (mounted) {
        }
      }
    } catch (e) {
        if (!mounted) return;

        NotificationService.showTopNotification(
          context,
          message: 'Error processing PDF: ${e.toString().replaceFirst("Exception: ", "")}',
          isError: true,
        );
    } finally {
      chatNotifier.setGenerating(false); // Set generating to false
      setState(() { _isProcessingRAG = false; }); // Set RAG processing to false
    }
  }

  void _addPdfContent(PDFMemory memory) {
    setState(() {
      _pdfMemories.add(memory);
    });
  }

  Future<void> _processImageContent() async {
    final chatNotifier = ref.read(chatProvider.notifier);
    chatNotifier.setGenerating(true); // Set generating to true
    setState(() { _isProcessingRAG = true; }); // Set RAG processing to true
    final source = await DialogManager.showImageSourceDialog(context);
    if (source != null) {
      try {
        final imageService = ref.read(imageServiceProvider);
        ImageMemory? imageMemory =
            await imageService.processImageContent(source);
        if (imageMemory != null) {
          chatNotifier.addImageMemory(imageMemory); // Use chatNotifier

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
      } finally { // Added finally block
        chatNotifier.setGenerating(false); // Set generating to false
        setState(() { _isProcessingRAG = false; }); // Set RAG processing to false
      }
    } else { // Added else block for when source is null
      chatNotifier.setGenerating(false); // Set generating to false if no source selected
      setState(() { _isProcessingRAG = false; }); // Set RAG processing to false
    }
  }

  Future<void> _processImageVision() async {
    final chatNotifier = ref.read(chatProvider.notifier);
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      final imageFile = File(pickedFile.path);
      chatNotifier.setSelectedImage(imageFile);

      final imageMemory = ImageMemory(
        pickedFile.path.split('/').last,
        'Image for vision model',
        imageFile: imageFile,
      );
      chatNotifier.addImageMemory(imageMemory);

      if (mounted) {
        NotificationService.showTopNotification(
          context,
          message: 'Image selected for vision model',
        );
      }
    }
  }

  void _showPreview(dynamic memory) {
    if (memory is ImageMemory && memory.imageFile != null) {
      DialogManager.showImagePreview(context, memory.name, memory.imageFile!);
    } else {
      DialogManager.showExtractedText(
        context,
        memory.name,
        memory.extractedText,
      );
    }
  }

  Future<void> _clearChat() async {
    final aiService = ref.read(aiServiceProvider);
    aiService.stopGeneration();

    final chatNotifier = ref.read(chatProvider.notifier);
    chatNotifier.clearMessages();
    chatNotifier.clearImageMemories();
    chatNotifier.setSelectedImage(null);

    ref.read(uiStateProvider.notifier).resetModes();
    _controller.clear();
    setState(() {
      _pdfMemories.clear();
    });
    
    // Clean up ONNX model cache to free memory
    EmbeddingGenerator.dispose();

    if (mounted) {
        MessageUtils.showInfo(context, 'Chat cleared and memory freed');
      // ScaffoldMessenger.of(context).showSnackBar(
      //   const SnackBar(content: Text('No messages to save')),
      // );
    }
  }

  Future<void> _stopGeneration() async {
    final aiService = ref.read(aiServiceProvider);
    aiService.stopGeneration();
    ref.read(chatProvider.notifier).setGenerating(false);
  }

  Future<void> _submitMessage() async {
    debugPrint("1. _submitMessage called.");
    final message = _controller.text.trim();
    if (message.isEmpty) {
      debugPrint("2. Message is empty, returning.");
      return;
    }

    final chatNotifier = ref.read(chatProvider.notifier);
    final chatState = ref.read(chatProvider);
    final uiState = ref.read(uiStateProvider);
    final offlineModeState = ref.read(offlineModeProvider);
    final aiService = ref.read(aiServiceProvider);
    final textGenService = ref.read(textGenerationServiceProvider);
    final onlineModelService = ref.read(onlineModelServiceProvider);

    _controller.clear();
    chatNotifier.startLoading();
    debugPrint("3. Loading started.");

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
                      _showApiKeysDialog(context);
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
      debugPrint("4. User message added to chat.");

      if (uiState.isImageMode) {
        debugPrint("5. In isImageMode block.");
        final isKontext =
            onlineModelService.selectedImageModel.toLowerCase() == 'kontext';
        debugPrint("6. isKontext: $isKontext");
        ImageMemory? kontextImageMemory;
        for (final m in chatState.imageMemories) {
          if (m.extractedText == 'Image for kontext') {
            kontextImageMemory = m;
            break;
          }
        }
        debugPrint("7. Found kontextImageMemory: ${kontextImageMemory != null}");

        if (isKontext && kontextImageMemory == null) {
          debugPrint("8. No kontext image found, showing error.");
          chatNotifier.stopLoading();
          MessageUtils.showError(context, 'Please select an image to edit.');
          return;
        }

        // Add placeholder message
        final placeholderMessage = ChatMessage(
          content: "Generating image... Please wait.",
          isUser: false,
          // timestamp: DateTime.now().millisecondsSinceEpoch,
        );
        chatNotifier.addMessage(placeholderMessage);
        debugPrint("9. Placeholder message added.");

        String? imageUrl;
        if (isKontext) {
          debugPrint("10. Using pre-uploaded image for kontext...");
          imageUrl = kontextImageMemory?.imageUrl;
          if (imageUrl == null) {
            debugPrint("11. Image URL is null, showing error.");
            MessageUtils.showError(context, 'Image has not been uploaded yet. Please wait or try re-selecting the image.');
            chatNotifier.stopLoading();
            return;
          }
          debugPrint('Using image URL: $imageUrl');
        }

        final imageData = await _imageGenService.generateImage(
          prompt: message,
          model: onlineModelService.selectedImageModel,
          image: imageUrl,
        )
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
        if (isKontext) {
          ref.read(chatProvider.notifier).removeImageMemory(kontextImageMemory!); // Use chatNotifier
        }
      } else {
        debugPrint("Not in image mode.");
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
        debugPrint('- isLocalModelActive: ${offlineModeState.isLocalModelActive}');
        debugPrint('- isLocalModelSelected: ${offlineModeState.isLocalModelSelected}');
        debugPrint('- useWebSearch: $useWebSearch');
        
        // DEBUG: Show history before filtering service messages
        if (kDebugMode) {
          print('Chat history before filtering:');
          for (int i = 0; i < chatState.messages.length; i++) {
            final msg = chatState.messages[i];
            print('[$i] ${msg.isUser ? "USER" : "AI"}: ${msg.content.substring(0, msg.content.length.clamp(0, 50))}...');
          }
        }

        Map<String, dynamic>? visionMessage;
        if (chatState.selectedImage != null && (onlineModelService.selectedOnlineModel?.vision ?? false)) {
          final imageBytes = await chatState.selectedImage!.readAsBytes();
          final base64Image = base64Encode(imageBytes);
          visionMessage = {
            'model': onlineModelService.selectedOnlineModel!.name,
            'messages': [
              {
                'role': 'user',
                'content': [
                  {'type': 'text', 'text': message},
                  {
                    'type': 'image_url',
                    'image_url': {'url': 'data:image/jpeg;base64,$base64Image'}
                  }
                ]
              }
            ],
            'max_tokens': 300
          };
        }

        try {
          await aiService.getStreamingResponse(
            message,
            _pdfMemories,
            chatState.imageMemories, // Pass imageMemories from chatState
            (response, done) {
              if (mounted) {
                chatNotifier.updateLastMessage(response);
                if (done) chatNotifier.setGenerating(false);
                _scrollToBottom();
              }
            },
            useWebSearch: useWebSearch,
            // Use getMeaningfulHistory() instead of all messages to exclude service check messages
            history: chatState.getMeaningfulHistory(),
            useLocalModel: offlineModeState.isLocalModelSelected,
            visionMessage: visionMessage,
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
        if (visionMessage != null) {
          chatNotifier.setSelectedImage(null);
          final visionImageMemory = chatState.imageMemories.firstWhereOrNull((memory) => memory.extractedText == 'Image for vision model');
          if (visionImageMemory != null) {
            chatNotifier.removeImageMemory(visionImageMemory);
          }
        }
      }
    } catch (e) {
      debugPrint("Error in _submitMessage: $e");
      final errorMessage = uiState.isImageMode ? _getImageError(e) : _getUserFriendlyError(e);
      chatNotifier.addMessage(ChatMessage(
        content: errorMessage,
        isUser: false,
        isError: true,
      ));
    } finally {
      debugPrint("Finally block in _submitMessage.");
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
    debugPrint('HomePage build - isLocalModelActive: ${offlineModeState.isLocalModelActive}');
    debugPrint('HomePage build - isLocalModelSelected: ${offlineModeState.isLocalModelSelected}');
    debugPrint('HomePage build - availableModels: ${offlineModeState.availableModels.length}');

    return ref.watch(offlineModelInitProvider).when(
      data: (_) {
        final chatState = ref.watch(chatProvider);
        final uiState = ref.watch(uiStateProvider);

        ref.listen<OfflineModelService>(offlineModelServiceProvider, (previous, next) {
          if (next.truncationMessage != null && next.truncationMessage != previous?.truncationMessage) {
            // Message is now displayed directly in the UI, no need for SnackBar
            // Clear the message after it's displayed (or when a new message is submitted)
            // For now, we rely on OfflineModelService to clear it.
          }
        });

        final String? truncationMessage = ref.watch(offlineModelServiceProvider).truncationMessage;

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
                    onPressed: () => _showApiKeysDialog(context),
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
          body: Stack( // Wrap with Stack
            children: [
              Column(
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
                          documents: [..._pdfMemories, ...chatState.imageMemories],
                          onSelectionChanged: () => setState(() {}),
                          onLongPress: _showPreview,
                          onRemove: (memory) {
                            final offlineModelService = ref.read(offlineModelServiceProvider);
                            offlineModelService.clearTruncationMessage();
                            if (memory is PDFMemory) {
                              setState(() {
                                _pdfMemories.remove(memory);
                              });
                            } else if (memory is ImageMemory) {
                              ref.read(chatProvider.notifier).removeImageMemory(memory);
                            }
                          },
                        ),
                        ChatInput( // Moved ChatInput here
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
                          onAddImageForKontext: _pickImageForKontext,
                          isWebSearchDisabled: _pdfMemories.isNotEmpty ||
                              chatState.imageMemories.isNotEmpty ||
                              offlineModeState.isOfflineMode,
                          isOfflineMode: offlineModeState.isOfflineMode,
                        ),
                        if (truncationMessage != null) // New truncation message display
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                            child: Text(
                              truncationMessage,
                              style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12),
                              textAlign: TextAlign.center,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              if (_isProcessingRAG) // Conditionally show overlay
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.5), // Semi-transparent background
                    child: const Center(
                      child: CircularProgressIndicator(),
                    ),
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
        MessageUtils.showInfo(context, 'No messages to save');
      return;
    }

    await _chatStorage.saveChat(chatState.messages);
    _loadSavedChats();

    if (mounted) {
        MessageUtils.showInfo(context, 'Started new chat');
    }
    
    // Clear the chat after saving
    await _clearChat();
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

  Future<void> _showApiKeysDialog(BuildContext context) async {
    final textGenService = ref.read(textGenerationServiceProvider);
    final jinaController = TextEditingController(text: await textGenService.getJinaApiKey());
    final pollinationController = TextEditingController(text: await textGenService.getPollinationApiKey());

    if (!mounted) return;

    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('API Keys'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter your API keys for the following services:'),
            const SizedBox(height: 16),
            TextField(
              controller: jinaController,
              decoration: const InputDecoration(
                labelText: 'Jina API Key (Web Search)',
                hintText: 'Enter Jina API key',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: pollinationController,
              decoration: const InputDecoration(
                labelText: 'Pollination API Key (Advanced LLMs & Image Edit)',
                hintText: 'Enter Pollination API key',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () async {
                final Uri url = Uri.parse('https://jina.ai/#apiform');
                if (await canLaunchUrl(url)) {
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                }
              },
              child: const Text(
                'Get Jina API Key',
                style: TextStyle(
                  color: Colors.blue,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () async {
                // Add the URL for getting a Pollination API key
              },
              child: const Text(
                'Get Pollination API Key',
                style: TextStyle(
                  color: Colors.blue,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
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
              await prefs.setString('jina_api_key', jinaController.text.trim());
              await prefs.setString('pollination_api_key', pollinationController.text.trim());
              
              // Refresh models after saving the key
              await ref.read(onlineModelServiceProvider).fetchModels();

              if (context.mounted) {
                Navigator.pop(context);
                MessageUtils.showSuccess(context, 'API keys saved');
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
