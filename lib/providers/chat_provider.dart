import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/chat_message.dart';
import 'package:flutter/foundation.dart';

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
    try {
      final List<ChatMessage> updatedMessages = List.from(state.messages);
      updatedMessages.add(message);
      
      state = state.copyWith(
        messages: updatedMessages,
        error: null,
        isLoading: false,
        isGenerating: false,
      );
    } catch (e) {
      debugPrint('Error adding message: $e');
      state = state.copyWith(
        error: 'Failed to add message',
        isLoading: false,
        isGenerating: false,
      );
    }
  }

  void updateLastMessage(String content) {
    try {
      if (state.messages.isEmpty) return;
      
      final lastMessage = state.messages.last;
      final updatedMessage = ChatMessage(
        content: content,
        isUser: lastMessage.isUser,
        imageData: lastMessage.imageData,
      );
      
      state = state.copyWith(
        messages: [...state.messages.take(state.messages.length - 1), updatedMessage],
        error: null,
      );
    } catch (e) {
      debugPrint('Error updating last message: $e');
      state = state.copyWith(
        error: 'Failed to update message',
        isLoading: false,
        isGenerating: false,
      );
    }
  }

  void loadMessages(List<ChatMessage> messages) {
    try {
      state = state.copyWith(
        messages: messages,
        error: null,
        isLoading: false,
        isGenerating: false,
      );
    } catch (e) {
      debugPrint('Error loading messages: $e');
      state = state.copyWith(
        error: 'Failed to load messages',
        isLoading: false,
        isGenerating: false,
      );
    }
  }

  void clearMessages() {
    state = state.copyWith(
      messages: [],
      error: null,
      isLoading: false,
      isGenerating: false,
    );
  }

  void startLoading() {
    state = state.copyWith(
      isLoading: true,
      error: null,
      isGenerating: false,
    );
  }

  void stopLoading() {
    state = state.copyWith(
      isLoading: false,
      isGenerating: false,
    );
  }

  void setGenerating(bool value) {
    state = state.copyWith(
      isGenerating: value,
      error: value ? null : state.error,
    );
  }

  void setError(String message) {
    debugPrint('Setting error: $message');
    state = state.copyWith(
      error: message,
      isLoading: false,
      isGenerating: false,
    );
  }

  void clearError() {
    state = state.copyWith(error: null);
  }

  void cleanupErrorMessages() {
    if (state.messages.isNotEmpty) {
      final lastMessage = state.messages.last;
      if (!lastMessage.isUser && 
          lastMessage.content.contains('Error Generating Response')) {
        state = state.copyWith(
          messages: state.messages.take(state.messages.length - 1).toList(),
          error: null,
        );
      }
    }
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