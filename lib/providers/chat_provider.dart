import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../models/chat_message.dart';
import '../models/pdf_memory.dart';
import 'providers.dart';

part 'chat_provider.g.dart';

@Riverpod(keepAlive: true)
class ChatNotifier extends _$ChatNotifier {
  @override
  ChatState build() {
    return ChatState(
      messages: [],
      pdfMemories: [],
      isGenerating: false,
      isImageMode: false,
      isInternetMode: false,
    );
  }

  void addMessage(ChatMessage message) {
    state = state.copyWith(
      messages: [...state.messages, message],
    );
  }

  void updateLastMessage(ChatMessage message) {
    if (state.messages.isEmpty) return;
    final messages = [...state.messages];
    messages[messages.length - 1] = message;
    state = state.copyWith(messages: messages);
  }

  void clearMessages() {
    state = state.copyWith(messages: []);
  }

  void setGenerating(bool isGenerating) {
    state = state.copyWith(isGenerating: isGenerating);
  }

  void toggleImageMode() {
    state = state.copyWith(
      isImageMode: !state.isImageMode,
      isInternetMode: false,
    );
  }

  void toggleInternetMode() {
    state = state.copyWith(
      isInternetMode: !state.isInternetMode,
      isImageMode: false,
    );
  }

  void addPDFMemory(PDFMemory memory) {
    state = state.copyWith(
      pdfMemories: [...state.pdfMemories, memory],
    );
  }

  void removePDFMemory(PDFMemory memory) {
    state = state.copyWith(
      pdfMemories: state.pdfMemories.where((m) => m != memory).toList(),
    );
  }

  void togglePDFMemorySelection(PDFMemory memory) {
    final index = state.pdfMemories.indexOf(memory);
    if (index == -1) return;

    final updatedMemories = [...state.pdfMemories];
    updatedMemories[index] = memory.copyWith(
      isSelected: !memory.isSelected,
    );

    state = state.copyWith(pdfMemories: updatedMemories);
  }

  Future<void> handleImageGeneration(String prompt) async {
    setGenerating(true);
    addMessage(ChatMessage(
      content: prompt,
      isUser: true,
    ));
    addMessage(ChatMessage(
      content: "Generating image... Please wait.",
      isUser: false,
    ));

    try {
      final imageGenService = ref.read(imageGenerationServiceProvider);
      final imageData = await imageGenService.generateImage(prompt);

      if (imageData != null) {
        updateLastMessage(ChatMessage(
          content: prompt,
          isUser: false,
          imageData: imageData,
        ));
      } else {
        updateLastMessage(ChatMessage(
          content: "Failed to generate image.",
          isUser: false,
          isError: true,
        ));
      }
    } catch (e) {
      updateLastMessage(ChatMessage(
        content: "Error generating image: $e",
        isUser: false,
        isError: true,
      ));
    } finally {
      setGenerating(false);
      toggleImageMode();
    }
  }
}

class ChatState {
  final List<ChatMessage> messages;
  final List<PDFMemory> pdfMemories;
  final bool isGenerating;
  final bool isImageMode;
  final bool isInternetMode;

  ChatState({
    required this.messages,
    required this.pdfMemories,
    required this.isGenerating,
    required this.isImageMode,
    required this.isInternetMode,
  });

  ChatState copyWith({
    List<ChatMessage>? messages,
    List<PDFMemory>? pdfMemories,
    bool? isGenerating,
    bool? isImageMode,
    bool? isInternetMode,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      pdfMemories: pdfMemories ?? this.pdfMemories,
      isGenerating: isGenerating ?? this.isGenerating,
      isImageMode: isImageMode ?? this.isImageMode,
      isInternetMode: isInternetMode ?? this.isInternetMode,
    );
  }
} 