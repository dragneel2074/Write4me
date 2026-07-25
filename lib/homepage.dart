import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';

import 'models/chat_message.dart';
import 'models/image_memory.dart';
import 'models/pdf_memory.dart';
import 'models/saved_chat.dart';
import 'providers/chat_provider.dart';
import 'providers/selected_documents_provider.dart';
import 'providers/service_providers.dart';
import 'providers/theme_provider.dart';
import 'services/online_provider.dart';
import 'services/pollinations_media_service.dart';
import 'services/chat_storage_service.dart';
import 'widgets/model_download_dialog.dart';
import 'widgets/model_settings_dialog.dart';
import 'models/model_parameters.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final _promptController = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();
  final _mediaService = PollinationsMediaService();
  final _chatStorage = ChatStorageService();
  List<SavedChat> _savedChats = const [];
  String? _activeChatId;
  bool _historyReady = false;
  final Map<String, double> _pdfIndexProgress = {};
  _CreateMode _mode = _CreateMode.write;
  bool _isGeneratingMedia = false;
  Uint8List? _mediaBytes;
  bool _mediaIsVideo = false;
  String? _mediaPrompt;

  @override
  void initState() {
    super.initState();
    _promptController.addListener(_onPromptChanged);
    _initializeHistory();
  }

  void _onPromptChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _initializeHistory() async {
    await _chatStorage.init();
    if (!mounted) return;
    setState(() {
      _savedChats = _chatStorage.getAllChats();
      _historyReady = true;
    });
  }

  @override
  void dispose() {
    _promptController.removeListener(_onPromptChanged);
    _promptController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _mediaService.dispose();
    super.dispose();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Future<void> _send() async {
    final prompt = _promptController.text.trim();
    final chat = ref.read(chatProvider);
    final offline = ref.read(offlineModeProvider);
    if (prompt.isEmpty || chat.isGenerating || _isGeneratingMedia) return;

    if (_mode != _CreateMode.write) {
      await _generateMedia(prompt);
      return;
    }

    if (offline.isOfflineMode && offline.selectedModelPath == null) {
      _showMessage('Choose or download a local GGUF model first.');
      await _showEngineSheet();
      return;
    }

    if (!offline.isOfflineMode) {
      final online = ref.read(onlineModelServiceProvider);
      if (!await online.hasApiKey(online.activeProvider)) {
        _showMessage(
            'Add an API key to use ${online.activeProviderConfig.label}.');
        await _showEngineSheet();
        return;
      }
      if (online.selectedOnlineModel == null) {
        _showMessage('Load models and select a text model first.');
        await _showEngineSheet();
        return;
      }
    }

    _promptController.clear();
    final notifier = ref.read(chatProvider.notifier);
    final history = List<ChatMessage>.from(chat.messages);
    final documents = List<PDFMemory>.from(ref.read(selectedDocumentsProvider));
    final images = List<ImageMemory>.from(chat.imageMemories);
    final sentAttachments = <ChatAttachment>[
      ...documents.map(
        (document) => ChatAttachment(name: document.name, type: 'pdf'),
      ),
      ...images.map(
        (image) => ChatAttachment(
          name: image.name,
          type: image.imageFile == null ? 'file' : 'image',
        ),
      ),
    ];
    notifier.addMessage(ChatMessage(
      content: prompt,
      isUser: true,
      attachments: sentAttachments,
    ));
    notifier.addMessage(ChatMessage(content: '', isUser: false));
    notifier.setGenerating(true);
    for (final document in documents) {
      _pdfIndexProgress.remove(document.name);
    }
    ref.read(selectedDocumentsProvider.notifier).state = [];
    notifier.clearImageMemories();
    _scrollToEnd();

    try {
      await ref.read(aiServiceProvider).getStreamingResponse(
        prompt,
        documents,
        images,
        (response, done) {
          if (!mounted) return;
          final current = ref.read(chatProvider).messages;
          if (current.isNotEmpty && !current.last.isUser) {
            notifier.updateLastMessage(response);
          }
          if (done) notifier.setGenerating(false);
          _scrollToEnd();
        },
        history: history,
        useLocalModel: offline.isOfflineMode,
      );
    } catch (_) {
      // AIService already converts provider and model failures to user-facing text.
    } finally {
      if (mounted) {
        notifier.setGenerating(false);
        await _saveCurrentChat();
      }
    }
  }

  Future<void> _saveCurrentChat() async {
    if (!_historyReady) return;
    final messages = ref
        .read(chatProvider)
        .messages
        .where((message) => message.content.trim().isNotEmpty)
        .toList();
    if (!messages.any((message) => message.isUser)) return;
    final saved = await _chatStorage.saveChat(messages, id: _activeChatId);
    if (!mounted || saved == null) return;
    setState(() {
      _activeChatId = saved.id;
      _savedChats = _chatStorage.getAllChats();
    });
  }

  Future<void> _newChat() async {
    await _saveCurrentChat();
    ref.read(chatProvider.notifier).clearMessages();
    ref.read(selectedDocumentsProvider.notifier).state = [];
    setState(() {
      _activeChatId = null;
      _pdfIndexProgress.clear();
      _mediaBytes = null;
      _mediaPrompt = null;
      _mode = _CreateMode.write;
    });
  }

  Future<void> _openChat(SavedChat saved) async {
    await _saveCurrentChat();
    ref.read(chatProvider.notifier).loadMessages(saved.chatMessages);
    ref.read(selectedDocumentsProvider.notifier).state = [];
    setState(() {
      _activeChatId = saved.id;
      _mode = _CreateMode.write;
      _mediaBytes = null;
    });
    _scrollToEnd();
  }

  Future<void> _deleteChat(String id) async {
    await _chatStorage.deleteChat(id);
    if (!mounted) return;
    setState(() {
      _savedChats = _chatStorage.getAllChats();
      if (_activeChatId == id) _activeChatId = null;
    });
  }

  Future<void> _generateMedia(String prompt) async {
    final online = ref.read(onlineModelServiceProvider);
    if (online.activeProvider != OnlineProvider.pollinations) {
      _showMessage('Image and video generation use Pollinations.');
      await _showEngineSheet();
      return;
    }
    final key = await online.getApiKey(OnlineProvider.pollinations);
    if (key == null || key.isEmpty) {
      _showMessage('Add your Pollinations API key first.');
      await _showEngineSheet();
      return;
    }
    final output = _mode == _CreateMode.video ? 'video' : 'image';
    final selected = online.selectedModelForOutput(output);
    if (selected == null || !selected.supportsOutput(output)) {
      _showMessage('Load models and select a $output model first.');
      await _showEngineSheet();
      return;
    }
    _promptController.clear();
    setState(() {
      _isGeneratingMedia = true;
      _mediaBytes = null;
      _mediaPrompt = prompt;
      _mediaIsVideo = output == 'video';
    });
    try {
      final bytes = await _mediaService.generate(
        prompt: prompt,
        model: selected.name,
        apiKey: key,
        video: output == 'video',
      );
      if (mounted) setState(() => _mediaBytes = bytes);
    } catch (error) {
      _showMessage('Generation failed: $error');
    } finally {
      if (mounted) setState(() => _isGeneratingMedia = false);
    }
  }

  Future<void> _shareMedia() async {
    final bytes = _mediaBytes;
    if (bytes == null) return;
    final dir = await getTemporaryDirectory();
    final extension = _mediaIsVideo ? 'mp4' : 'png';
    final file = File(
        '${dir.path}${Platform.pathSeparator}write4me_${DateTime.now().millisecondsSinceEpoch}.$extension');
    await file.writeAsBytes(bytes, flush: true);
    await Share.shareXFiles([XFile(file.path)], text: _mediaPrompt);
  }

  void _stop() {
    if (_isGeneratingMedia) {
      _mediaService.cancel();
      setState(() => _isGeneratingMedia = false);
    }
    ref.read(aiServiceProvider).stopGeneration();
    ref.read(chatProvider.notifier).setGenerating(false);
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _showHistory() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * .72,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 12, 10),
                child: Row(
                  children: [
                    Text('Chat history',
                        style: Theme.of(sheetContext)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.w800)),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        _newChat();
                      },
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('New chat'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: !_historyReady
                    ? const Center(child: CircularProgressIndicator())
                    : _savedChats.isEmpty
                        ? const Center(child: Text('No saved chats yet'))
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                            itemCount: _savedChats.length,
                            itemBuilder: (_, index) {
                              final saved = _savedChats[index];
                              return Card(
                                child: ListTile(
                                  selected: saved.id == _activeChatId,
                                  leading:
                                      const Icon(Icons.chat_bubble_outline),
                                  title: Text(saved.title,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis),
                                  subtitle: Text(
                                    _formatChatDate(saved.timestamp),
                                  ),
                                  trailing: IconButton(
                                    tooltip: 'Delete chat',
                                    icon: const Icon(Icons.delete_outline),
                                    onPressed: () async {
                                      await _deleteChat(saved.id);
                                      if (sheetContext.mounted) {
                                        Navigator.pop(sheetContext);
                                        _showHistory();
                                      }
                                    },
                                  ),
                                  onTap: () {
                                    Navigator.pop(sheetContext);
                                    _openChat(saved);
                                  },
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatChatDate(DateTime value) {
    final local = value.toLocal();
    final now = DateTime.now();
    if (local.year == now.year &&
        local.month == now.month &&
        local.day == now.day) {
      final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
      final minute = local.minute.toString().padLeft(2, '0');
      return 'Today, $hour:$minute ${local.hour >= 12 ? 'PM' : 'AM'}';
    }
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
  }

  ({int used, int? limit, int? remaining}) _contextBudget(
    dynamic offline,
    dynamic online,
    ChatState chat,
    List<PDFMemory> documents,
  ) {
    var characters = _promptController.text.length + 240;
    for (final message in chat.messages) {
      characters += message.content.length + 16;
    }
    // RAG sends only a bounded selection of relevant attachment text, not
    // entire PDFs. Match the 1024-token retrieval allowance used by AIService.
    final attachmentCharacters = documents.fold<int>(
          0,
          (total, document) => total + document.extractedText.length,
        ) +
        chat.imageMemories.fold<int>(
          0,
          (total, image) => total + image.extractedText.length,
        );
    characters += attachmentCharacters.clamp(0, 4096);
    final used = (characters / 4).ceil();
    int? limit;
    if (offline.isOfflineMode) {
      final path = offline.selectedModelPath;
      final parameters = path == null
          ? null
          : offline.modelParameters[path] as ModelParameters?;
      limit = parameters?.contextSize ?? const ModelParameters().contextSize;
    } else {
      limit = online.selectedOnlineModel?.contextWindow as int?;
    }
    final remaining =
        limit == null ? null : (limit - used).clamp(0, limit).toInt();
    return (used: used, limit: limit, remaining: remaining);
  }

  Future<void> _showAttachmentMenu() async {
    if (_mode != _CreateMode.write) {
      _showMessage('Attachments are available in Write mode.');
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.image_outlined),
              title: const Text('Add image'),
              subtitle: const Text('Extract text from a photo'),
              onTap: () {
                Navigator.pop(sheetContext);
                _attachImage();
              },
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_outlined),
              title: const Text('Add PDF'),
              subtitle: const Text('Use the document as writing context'),
              onTap: () {
                Navigator.pop(sheetContext);
                _attachPdf();
              },
            ),
            ListTile(
              leading: const Icon(Icons.description_outlined),
              title: const Text('Add text file'),
              subtitle: const Text('TXT, Markdown, CSV, JSON, YAML, or XML'),
              onTap: () {
                Navigator.pop(sheetContext);
                _attachTextFile();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _attachImage() async {
    try {
      final memory = await ref
          .read(imageServiceProvider)
          .processImageContent(ImageSource.gallery);
      if (memory == null) return;
      ref.read(chatProvider.notifier).addImageMemory(memory);
      _showMessage('${memory.name} attached');
    } catch (error) {
      _showMessage('Could not add image: $error');
    }
  }

  Future<void> _attachPdf() async {
    try {
      final memory = await ref.read(pdfServiceProvider).pickAndProcessPDF(
        onProgress: (fileName, progress) {
          if (!mounted) return;
          final isStillAttached = ref
              .read(selectedDocumentsProvider)
              .any((document) => document.name == fileName);
          if (!isStillAttached && _pdfIndexProgress[fileName] == null) return;
          setState(() => _pdfIndexProgress[fileName] = progress);
        },
      );
      if (memory == null) return;
      setState(() =>
          _pdfIndexProgress[memory.name] = _pdfIndexProgress[memory.name] ?? 0);
      ref.read(selectedDocumentsProvider.notifier).state = [
        ...ref.read(selectedDocumentsProvider),
        memory,
      ];
      _showMessage('${memory.name} attached');
    } catch (error) {
      _showMessage('Could not add PDF: $error');
    }
  }

  Future<void> _attachTextFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const [
          'txt',
          'md',
          'csv',
          'json',
          'yaml',
          'yml',
          'xml'
        ],
        withData: true,
      );
      if (result == null) return;
      final picked = result.files.single;
      if (picked.size > 2 * 1024 * 1024) {
        throw Exception('File size exceeds the 2 MB limit');
      }
      final bytes = picked.bytes ??
          (picked.path == null ? null : await File(picked.path!).readAsBytes());
      if (bytes == null) throw Exception('The selected file could not be read');
      final text = utf8.decode(bytes, allowMalformed: true).trim();
      if (text.isEmpty) throw Exception('The selected file is empty');
      ref.read(chatProvider.notifier).addImageMemory(
            ImageMemory(picked.name, text, isSelected: true),
          );
      _showMessage('${picked.name} attached');
    } catch (error) {
      _showMessage('Could not add file: $error');
    }
  }

  Future<void> _showEngineSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _EngineSheet(mode: _mode),
    );
    if (!mounted) return;
    final offline = ref.read(offlineModeProvider);
    final online = ref.read(onlineModelServiceProvider);
    if (_mode != _CreateMode.write &&
        (offline.isOfflineMode ||
            online.activeProvider != OnlineProvider.pollinations)) {
      setState(() => _mode = _CreateMode.write);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final chat = ref.watch(chatProvider);
    final offline = ref.watch(offlineModeProvider);
    final online = ref.watch(onlineModelServiceProvider);
    final engineName = offline.isOfflineMode
        ? (offline.selectedModelPath?.split(RegExp(r'[/\\]')).last ??
            'Local GGUF')
        : '${online.activeProviderConfig.label} · '
            '${online.selectedOnlineModel?.description ?? 'Choose model'}';
    final canCreateMedia = !offline.isOfflineMode &&
        online.activeProvider == OnlineProvider.pollinations;
    final documents = ref.watch(selectedDocumentsProvider);
    final budget = _contextBudget(offline, online, chat, documents);

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 72,
        titleSpacing: 20,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Write4Me',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            Text('Your focused AI writing studio',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Chat history',
            onPressed: _showHistory,
            icon: const Icon(Icons.history_rounded),
          ),
          IconButton(
            tooltip: 'New document',
            onPressed:
                chat.messages.isEmpty && _mediaBytes == null ? null : _newChat,
            icon: const Icon(Icons.note_add_outlined),
          ),
          IconButton(
            tooltip: theme.brightness == Brightness.dark
                ? 'Use light theme'
                : 'Use dark theme',
            onPressed: () => ref.read(themeProvider.notifier).setThemeMode(
                  theme.brightness == Brightness.dark
                      ? ThemeMode.light
                      : ThemeMode.dark,
                ),
            icon: Icon(theme.brightness == Brightness.dark
                ? Icons.light_mode_outlined
                : Icons.dark_mode_outlined),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: _showEngineSheet,
                child: Ink(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  decoration: BoxDecoration(
                    color: colors.primaryContainer.withValues(alpha: .55),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: colors.outlineVariant),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        offline.isOfflineMode
                            ? Icons.memory_rounded
                            : Icons.cloud_outlined,
                        size: 19,
                        color: colors.primary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          engineName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ),
                      Icon(Icons.tune_rounded,
                          size: 18, color: colors.onSurfaceVariant),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: SegmentedButton<_CreateMode>(
                showSelectedIcon: false,
                segments: [
                  const ButtonSegment(
                      value: _CreateMode.write,
                      icon: Icon(Icons.edit_note_rounded),
                      label: Text('Write')),
                  ButtonSegment(
                      value: _CreateMode.image,
                      enabled: canCreateMedia,
                      icon: const Icon(Icons.image_outlined),
                      label: const Text('Image')),
                  ButtonSegment(
                      value: _CreateMode.video,
                      enabled: canCreateMedia,
                      icon: const Icon(Icons.movie_outlined),
                      label: const Text('Video')),
                ],
                selected: {_mode},
                onSelectionChanged: (value) =>
                    setState(() => _mode = value.first),
              ),
            ),
            Expanded(
              child: _mode != _CreateMode.write
                  ? _MediaWorkspace(
                      mode: _mode,
                      bytes: _mediaBytes,
                      isGenerating: _isGeneratingMedia,
                      prompt: _mediaPrompt,
                      onShare: _shareMedia,
                    )
                  : chat.messages.isEmpty
                      ? _EmptyWritingState(onPrompt: (value) {
                          _promptController.text = value;
                          _focusNode.requestFocus();
                        })
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                          itemCount: chat.messages.length,
                          itemBuilder: (_, index) =>
                              _MessageCard(message: chat.messages[index]),
                        ),
            ),
            if (_mode == _CreateMode.write)
              _AttachmentBar(
                documents: documents,
                images: chat.imageMemories,
                pdfIndexProgress: _pdfIndexProgress,
                onRemoveDocument: (memory) {
                  setState(() => _pdfIndexProgress.remove(memory.name));
                  ref.read(selectedDocumentsProvider.notifier).state = ref
                      .read(selectedDocumentsProvider)
                      .where((item) => item != memory)
                      .toList();
                },
                onRemoveImage: (memory) =>
                    ref.read(chatProvider.notifier).removeImageMemory(memory),
              ),
            if (_mode == _CreateMode.write)
              _ContextBudgetBar(
                used: budget.used,
                limit: budget.limit,
                remaining: budget.remaining,
              ),
            _Composer(
              controller: _promptController,
              focusNode: _focusNode,
              isGenerating: chat.isGenerating || _isGeneratingMedia,
              hintText: switch (_mode) {
                _CreateMode.write => 'Describe what you want to write…',
                _CreateMode.image => 'Describe the image to create…',
                _CreateMode.video => 'Describe the video to create…',
              },
              onSend: _send,
              onStop: _stop,
              onAttach: _showAttachmentMenu,
            ),
          ],
        ),
      ),
    );
  }
}

enum _CreateMode { write, image, video }

class _MediaWorkspace extends StatelessWidget {
  final _CreateMode mode;
  final Uint8List? bytes;
  final bool isGenerating;
  final String? prompt;
  final VoidCallback onShare;

  const _MediaWorkspace({
    required this.mode,
    required this.bytes,
    required this.isGenerating,
    required this.prompt,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    if (isGenerating) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 18),
            Text('Creating your ${mode.name}…',
                style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            const Text('Larger models can take a few minutes.'),
          ],
        ),
      );
    }
    if (bytes == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                  mode == _CreateMode.image
                      ? Icons.add_photo_alternate_outlined
                      : Icons.video_camera_back_outlined,
                  size: 58,
                  color: colors.primary),
              const SizedBox(height: 18),
              Text('Create with Pollinations',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(
                'Describe the ${mode.name} you want. Available models are loaded live for your API key.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          if (mode == _CreateMode.image)
            ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Image.memory(bytes!, fit: BoxFit.contain),
            )
          else
            Container(
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                color: colors.surfaceContainer,
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Column(
                children: [
                  Icon(Icons.movie_rounded, size: 60),
                  SizedBox(height: 12),
                  Text('Video is ready',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          if (prompt != null) ...[
            const SizedBox(height: 12),
            Text(prompt!, textAlign: TextAlign.center),
          ],
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: onShare,
            icon: const Icon(Icons.share_outlined),
            label: Text(mode == _CreateMode.video
                ? 'Share or save video'
                : 'Share or save image'),
          ),
        ],
      ),
    );
  }
}

class _EmptyWritingState extends StatelessWidget {
  final ValueChanged<String> onPrompt;
  const _EmptyWritingState({required this.onPrompt});

  static const prompts = [
    ('Continue writing', 'Continue this text while matching its voice: '),
    ('Rewrite clearly', 'Rewrite this to be clear, natural, and concise: '),
    ('Draft an email', 'Write a polished email about: '),
    ('Brainstorm', 'Give me creative ideas for: '),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Column(
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Icon(Icons.edit_note_rounded,
                    size: 36, color: colors.primary),
              ),
              const SizedBox(height: 22),
              Text('What are we writing?',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800, letterSpacing: -.5)),
              const SizedBox(height: 8),
              Text(
                'Draft, rewrite, summarize, or continue your work with a local GGUF model or your own cloud key.',
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.onSurfaceVariant, height: 1.45),
              ),
              const SizedBox(height: 28),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: prompts
                    .map((item) => ActionChip(
                          avatar:
                              const Icon(Icons.arrow_outward_rounded, size: 16),
                          label: Text(item.$1),
                          onPressed: () => onPrompt(item.$2),
                        ))
                    .toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  final ChatMessage message;
  const _MessageCard({required this.message});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    if (message.content.isEmpty) {
      return const Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 720),
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.fromLTRB(16, 13, 12, 10),
        decoration: BoxDecoration(
          color: message.isError
              ? colors.errorContainer
              : message.isUser
                  ? colors.primaryContainer
                  : colors.surfaceContainer,
          borderRadius: BorderRadius.circular(20).copyWith(
            bottomRight: message.isUser ? const Radius.circular(5) : null,
            bottomLeft: !message.isUser ? const Radius.circular(5) : null,
          ),
          border:
              Border.all(color: colors.outlineVariant.withValues(alpha: .6)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MarkdownBody(
              data: message.content,
              selectable: true,
              styleSheet: MarkdownStyleSheet(
                p: TextStyle(
                    color: message.isError
                        ? colors.onErrorContainer
                        : colors.onSurface,
                    height: 1.5),
              ),
            ),
            if (message.attachments.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: message.attachments
                    .map(
                      (attachment) => Chip(
                        visualDensity: VisualDensity.compact,
                        avatar: Icon(
                          switch (attachment.type) {
                            'image' => Icons.image_outlined,
                            'pdf' => Icons.picture_as_pdf_outlined,
                            _ => Icons.description_outlined,
                          },
                          size: 16,
                        ),
                        label: Text(
                          attachment.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
            if (!message.isUser) ...[
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Copy',
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: message.content));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Copied to clipboard')),
                    );
                  },
                  icon: const Icon(Icons.copy_rounded, size: 17),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AttachmentBar extends StatelessWidget {
  final List<PDFMemory> documents;
  final List<ImageMemory> images;
  final ValueChanged<PDFMemory> onRemoveDocument;
  final ValueChanged<ImageMemory> onRemoveImage;
  final Map<String, double> pdfIndexProgress;

  const _AttachmentBar({
    required this.documents,
    required this.images,
    required this.onRemoveDocument,
    required this.onRemoveImage,
    required this.pdfIndexProgress,
  });

  @override
  Widget build(BuildContext context) {
    if (documents.isEmpty && images.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        children: [
          ...documents.map(
            (memory) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: InputChip(
                avatar: pdfIndexProgress[memory.name] != null &&
                        pdfIndexProgress[memory.name]! < 1
                    ? const SizedBox(
                        width: 17,
                        height: 17,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.picture_as_pdf_outlined, size: 17),
                label: Text(
                  pdfIndexProgress[memory.name] != null &&
                          pdfIndexProgress[memory.name]! < 1
                      ? '${memory.name} · Indexing ${(pdfIndexProgress[memory.name]! * 100).round()}%'
                      : memory.name,
                ),
                onDeleted: () => onRemoveDocument(memory),
              ),
            ),
          ),
          ...images.map(
            (memory) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: InputChip(
                avatar: Icon(
                  memory.imageFile == null
                      ? Icons.description_outlined
                      : Icons.image_outlined,
                  size: 17,
                ),
                label: Text(memory.name),
                onDeleted: () => onRemoveImage(memory),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContextBudgetBar extends StatelessWidget {
  final int used;
  final int? limit;
  final int? remaining;

  const _ContextBudgetBar({
    required this.used,
    required this.limit,
    required this.remaining,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final known = limit != null && remaining != null;
    final fraction =
        known && limit! > 0 ? (used / limit!).clamp(0.0, 1.0) : 0.0;
    final isLow = known && remaining! < limit! * .15;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 2, 18, 2),
      child: Row(
        children: [
          Icon(
            Icons.data_usage_rounded,
            size: 14,
            color: isLow ? colors.error : colors.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              known
                  ? '~${_compact(remaining!)} tokens remaining · ${_compact(used)} used of ${_compact(limit!)}'
                  : '~${_compact(used)} context tokens used · limit not reported by provider',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                color: isLow ? colors.error : colors.onSurfaceVariant,
              ),
            ),
          ),
          if (known)
            SizedBox(
              width: 48,
              child: LinearProgressIndicator(
                value: fraction,
                minHeight: 4,
                color: isLow ? colors.error : colors.primary,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
        ],
      ),
    );
  }

  static String _compact(int value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    }
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
    return value.toString();
  }
}

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isGenerating;
  final VoidCallback onSend;
  final VoidCallback onStop;
  final VoidCallback onAttach;
  final String hintText;

  const _Composer({
    required this.controller,
    required this.focusNode,
    required this.isGenerating,
    required this.onSend,
    required this.onStop,
    required this.onAttach,
    required this.hintText,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 10, 16, 12 + MediaQuery.paddingOf(context).bottom),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.outlineVariant)),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 4, right: 8),
              child: IconButton.outlined(
                tooltip: 'Add image or file',
                onPressed: isGenerating ? null : onAttach,
                icon: const Icon(Icons.add_rounded),
              ),
            ),
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                minLines: 1,
                maxLines: 7,
                textCapitalization: TextCapitalization.sentences,
                onSubmitted: (_) => isGenerating ? onStop() : onSend(),
                decoration: InputDecoration(
                  hintText: hintText,
                  filled: true,
                  fillColor:
                      colors.surfaceContainerHighest.withValues(alpha: .7),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: BorderSide.none,
                  ),
                  suffixIcon: Padding(
                    padding: const EdgeInsets.all(6),
                    child: IconButton.filled(
                      tooltip: isGenerating ? 'Stop' : 'Write',
                      onPressed: isGenerating ? onStop : onSend,
                      icon: Icon(isGenerating
                          ? Icons.stop_rounded
                          : Icons.arrow_upward_rounded),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EngineSheet extends ConsumerStatefulWidget {
  final _CreateMode mode;
  const _EngineSheet({required this.mode});

  @override
  ConsumerState<_EngineSheet> createState() => _EngineSheetState();
}

class _EngineSheetState extends ConsumerState<_EngineSheet> {
  final _keyController = TextEditingController();
  bool _showKey = false;

  @override
  void initState() {
    super.initState();
    _loadKey();
  }

  Future<void> _loadKey() async {
    final service = ref.read(onlineModelServiceProvider);
    _keyController.text = await service.getApiKey(service.activeProvider) ?? '';
  }

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final offline = ref.watch(offlineModeProvider);
    final online = ref.watch(onlineModelServiceProvider);
    final colors = Theme.of(context).colorScheme;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
            20, 0, 20, 16 + MediaQuery.viewInsetsOf(context).bottom),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Writing engine',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text('Choose private on-device writing or a cloud provider.',
                  style: TextStyle(color: colors.onSurfaceVariant)),
              const SizedBox(height: 18),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                      value: false,
                      icon: Icon(Icons.cloud_outlined),
                      label: Text('Cloud')),
                  ButtonSegment(
                      value: true,
                      icon: Icon(Icons.memory_rounded),
                      label: Text('On device')),
                ],
                selected: {offline.isOfflineMode},
                onSelectionChanged: (value) async {
                  final local = value.first;
                  if (local && offline.availableModels.isEmpty) {
                    await _showDownloadDialog();
                    return;
                  }
                  await ref
                      .read(offlineModeProvider.notifier)
                      .setOfflineMode(local);
                },
              ),
              const SizedBox(height: 20),
              if (offline.isOfflineMode)
                _buildLocalModels(offline)
              else
                _buildCloud(online),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCloud(dynamic online) {
    final service = ref.read(onlineModelServiceProvider);
    final config = service.activeProviderConfig;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Provider', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: OnlineProvider.values
              .map((provider) => ChoiceChip(
                    label: Text(kOnlineProviders[provider]!.label),
                    selected: service.activeProvider == provider,
                    onSelected: (_) async {
                      await service.setActiveProvider(provider);
                      await _loadKey();
                      if (mounted) setState(() {});
                    },
                  ))
              .toList(),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _keyController,
          obscureText: !_showKey,
          autocorrect: false,
          enableSuggestions: false,
          decoration: InputDecoration(
            labelText: '${config.label} API key',
            prefixIcon: const Icon(Icons.key_rounded),
            suffixIcon: IconButton(
              onPressed: () => setState(() => _showKey = !_showKey),
              icon: Icon(_showKey
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            TextButton.icon(
              onPressed: () => launchUrl(Uri.parse(config.getKeyUrl),
                  mode: LaunchMode.externalApplication),
              icon: const Icon(Icons.open_in_new_rounded, size: 17),
              label: const Text('Get a key'),
            ),
            const Spacer(),
            OutlinedButton(
              onPressed: () async {
                await service.setApiKey(
                    service.activeProvider, _keyController.text);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${config.label} key saved')),
                  );
                }
              },
              child: const Text('Save key'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: service.isLoading
                ? null
                : () async {
                    await service.fetchModels();
                    if (mounted) setState(() {});
                  },
            icon: const Icon(Icons.cloud_download_outlined),
            label: Text(service.isLoading ? 'Loading…' : 'Load models'),
          ),
        ),
        const SizedBox(height: 14),
        if (service.isLoading)
          const LinearProgressIndicator()
        else if (service.textErrorMessage != null)
          Card(
            child: ListTile(
              leading: const Icon(Icons.cloud_off_outlined),
              title: const Text('Models could not be loaded'),
              subtitle: Text(service.textErrorMessage!),
              trailing: IconButton(
                tooltip: 'Retry',
                onPressed: service.fetchModels,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ),
          )
        else if (!service.hasLoadedModels)
          const Text(
            'Save your API key, then load the provider’s current model catalog.',
          )
        else if (service
            .modelsForOutput(
                widget.mode == _CreateMode.write ? 'text' : widget.mode.name)
            .isEmpty)
          Text(
            'This provider returned no ${widget.mode == _CreateMode.write ? 'text' : widget.mode.name} models.',
          )
        else
          DropdownButtonFormField<String>(
            key: ValueKey(
                '${service.activeProvider.name}-${widget.mode.name}-${service.availableModels.length}'),
            initialValue: service
                .selectedModelForOutput(widget.mode == _CreateMode.write
                    ? 'text'
                    : widget.mode.name)
                ?.name,
            isExpanded: true,
            decoration: const InputDecoration(
                labelText: 'Model',
                prefixIcon: Icon(Icons.auto_awesome_outlined)),
            items: service
                .modelsForOutput(widget.mode == _CreateMode.write
                    ? 'text'
                    : widget.mode.name)
                .map((model) => DropdownMenuItem(
                      value: model.name,
                      child: Text(model.description,
                          overflow: TextOverflow.ellipsis),
                    ))
                .toList(),
            onChanged: (id) {
              if (id == null) return;
              service.setSelectedModelForOutput(
                service.availableModels.firstWhere((m) => m.name == id),
                widget.mode == _CreateMode.write ? 'text' : widget.mode.name,
              );
            },
          ),
        const SizedBox(height: 6),
        const Text(
          'Your key is stored only on this device. Requests go directly to the selected provider.',
          style: TextStyle(fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildLocalModels(dynamic offline) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Downloaded GGUF models',
            style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        ...offline.availableModels.map<Widget>(
          (file) => Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: RadioListTile<String>(
              value: file.path,
              groupValue: offline.selectedModelPath,
              title: Text(
                file.path.split(RegExp(r'[/\\]')).last,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: const Text('On-device GGUF'),
              secondary: IconButton(
                tooltip: 'Tune model',
                icon: const Icon(Icons.tune_rounded),
                onPressed: () => _showModelSettings(
                  file.path,
                  offline.modelParameters[file.path] ?? const ModelParameters(),
                ),
              ),
              onChanged: (path) {
                if (path == null) return;
                ref.read(offlineModeProvider.notifier).setSelectedModel(path);
              },
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: _importModel,
              icon: const Icon(Icons.folder_open_rounded),
              label: const Text('Import from device'),
            ),
            OutlinedButton.icon(
              onPressed: _showDownloadDialog,
              icon: const Icon(Icons.download_rounded),
              label: const Text('Download model'),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _importModel() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );
      final path = result?.files.single.path;
      if (path == null) return;
      if (!path.toLowerCase().endsWith('.gguf')) {
        throw Exception('Please select a .gguf model file');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Importing GGUF model…')),
        );
      }
      await ref.read(offlineModeProvider.notifier).importModel(path);
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(content: Text('Model imported and selected')),
          );
        setState(() {});
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text('Import failed: $error')));
      }
    }
  }

  Future<void> _showModelSettings(
      String modelPath, ModelParameters parameters) async {
    final updated = await showDialog<ModelParameters>(
      context: context,
      builder: (_) => ModelSettingsDialog(
        initialParameters: parameters,
        modelPath: modelPath,
      ),
    );
    if (updated == null) return;
    await ref
        .read(offlineModeProvider.notifier)
        .setModelParameters(modelPath, updated);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Model parameters saved')),
      );
    }
  }

  Future<void> _showDownloadDialog() async {
    await showDialog<void>(
      context: context,
      builder: (_) => ModelDownloadDialog(
        noteMessage:
            'Start with a small instruct-tuned GGUF model. Keep enough free memory for the model context and Android.',
        onDownload: (url, onProgress, fileName) async {
          await ref
              .read(offlineModeProvider.notifier)
              .downloadModel(url, onProgress, fileName);
          if (mounted) Navigator.pop(context);
        },
      ),
    );
  }
}
