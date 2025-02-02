import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/chat_message.dart';

// Chat state class to hold all chat-related state
class ChatState {
  final List<ChatMessage> messages;
  final bool isLoading;
  final bool isGenerating;
  final String? error;

  ChatState({
    this.messages = const [],
    this.isLoading = false,
    this.isGenerating = false,
    this.error,
  });

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isLoading,
    bool? isGenerating,
    String? error,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      isGenerating: isGenerating ?? this.isGenerating,
      error: error ?? this.error,
    );
  }
}

class ChatNotifier extends StateNotifier<ChatState> {
  ChatNotifier() : super(ChatState());

  void addMessage(ChatMessage message) {
    final List<ChatMessage> updatedMessages = List.from(state.messages);
    updatedMessages.add(message);
    
    state = state.copyWith(
      messages: updatedMessages,
      error: null,
    );
  }

  void updateLastMessage(String content) {
    if (state.messages.isEmpty) return;
    
    final lastMessage = state.messages.last;
    final updatedMessage = ChatMessage(
      content: content,
      isUser: lastMessage.isUser,
      imageData: lastMessage.imageData,
    );
    
    state = state.copyWith(
      messages: [...state.messages.take(state.messages.length - 1), updatedMessage],
    );
  }

  void loadMessages(List<ChatMessage> messages) {
    state = state.copyWith(messages: messages);
  }

  void clearMessages() {
    state = state.copyWith(messages: []);
  }

  void startLoading() {
    state = state.copyWith(isLoading: true, error: null);
  }

  void stopLoading() {
    state = state.copyWith(isLoading: false);
  }

  void setGenerating(bool value) {
    state = state.copyWith(isGenerating: value);
  }

  void setError(String message) {
    state = state.copyWith(
      error: message,
      isLoading: false,
      isGenerating: false,
    );
  }
}

// Providers
final chatProvider = StateNotifierProvider<ChatNotifier, ChatState>((ref) {
  return ChatNotifier();
});

// Convenience providers for individual states
final chatMessagesProvider = Provider<List<ChatMessage>>((ref) {
  return ref.watch(chatProvider).messages;
});

final chatLoadingProvider = Provider<bool>((ref) {
  return ref.watch(chatProvider).isLoading;
});

final chatGeneratingProvider = Provider<bool>((ref) {
  return ref.watch(chatProvider).isGenerating;
});

final chatErrorProvider = Provider<String?>((ref) {
  return ref.watch(chatProvider).error;
}); 