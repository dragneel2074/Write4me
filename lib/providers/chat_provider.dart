import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/chat_message.dart';
import '../models/image_memory.dart';

const _sentinel = Object();

// Chat state class to hold all chat-related state
class ChatState {
  final List<ChatMessage> messages;
  final bool isLoading;
  final bool isGenerating;
  final String? error;
  final File? selectedImage;
  final List<ImageMemory> imageMemories;

  ChatState({
    this.messages = const [],
    this.isLoading = false,
    this.isGenerating = false,
    this.error,
    this.selectedImage,
    this.imageMemories = const [],
  });

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isLoading,
    bool? isGenerating,
    Object? error = _sentinel,
    Object? selectedImage = _sentinel,
    List<ImageMemory>? imageMemories,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      isGenerating: isGenerating ?? this.isGenerating,
      error: error == _sentinel ? this.error : error as String?,
      selectedImage: selectedImage == _sentinel
          ? this.selectedImage
          : selectedImage as File?,
      imageMemories: imageMemories ?? this.imageMemories,
    );
  }

  /// Returns meaningful chat history, excluding service check messages
  List<ChatMessage> getMeaningfulHistory() {
    // No messages, return empty list
    if (messages.isEmpty) return [];

    // Find the first user message - everything before that is likely system initialization
    int startIndex = 0;

    for (int i = 0; i < messages.length; i++) {
      if (messages[i].isUser) {
        startIndex = i;
        break;
      }
    }

    // Get messages starting from first user message
    final meaningfulMessages = messages.sublist(startIndex);

    if (kDebugMode) {
      print(
          "Getting meaningful history: ${messages.length} → ${meaningfulMessages.length} messages");
      if (meaningfulMessages.isNotEmpty) {
        print(
            "First meaningful message: '${meaningfulMessages.first.content.substring(0, meaningfulMessages.first.content.length.clamp(0, 30))}...'");
      }
    }

    return meaningfulMessages;
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

  void setSelectedImage(File? image) {
    state = state.copyWith(selectedImage: image);
  }

  void updateLastMessage(String content) {
    try {
      if (state.messages.isEmpty) return;

      final lastMessage = state.messages.last;
      final updatedMessage = ChatMessage(
        content: content,
        isUser: lastMessage.isUser,
        isError: lastMessage.isError,
        imageData: lastMessage.imageData,
        attachments: lastMessage.attachments,
      );

      state = state.copyWith(
        messages: [
          ...state.messages.take(state.messages.length - 1),
          updatedMessage
        ],
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
      selectedImage: null,
      imageMemories: [], // Clear image memories
    );
  }

  void addImageMemory(ImageMemory memory) {
    state = state.copyWith(
      imageMemories: [...state.imageMemories, memory],
    );
  }

  void clearImageMemories() {
    state = state.copyWith(imageMemories: []);
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
    debugPrint('Setting error message: $message');
    final errorMessage = ChatMessage(
      content: message,
      isUser: false,
      isError: true,
      // timestamp: DateTime.now().millisecondsSinceEpoch,
    );
    state = state.copyWith(
      messages: [...state.messages, errorMessage],
      error: message,
      isLoading: false,
      isGenerating: false,
    );
  }

  void clearError() {
    if (state.error != null) {
      state = state.copyWith(
        error: null,
        isLoading: false,
        isGenerating: false,
      );
    }
  }

  void removeMessage(ChatMessage message) {
    state = state.copyWith(
      messages: state.messages.where((m) => m != message).toList(),
    );
  }

  void removeImageMemory(ImageMemory memory) {
    state = state.copyWith(
      imageMemories: state.imageMemories.where((m) => m != memory).toList(),
    );
  }

  void cleanupErrorMessages() {
    if (state.messages.isNotEmpty) {
      final lastMessage = state.messages.last;
      if (!lastMessage.isUser &&
          (lastMessage.content.contains('Error Generating Response') ||
              lastMessage.content.contains('Something went wrong'))) {
        state = state.copyWith(
          messages: state.messages.take(state.messages.length - 1).toList(),
          error: null,
          isLoading: false,
          isGenerating: false,
        );
      }
    }
  }

  void replaceMessage(ChatMessage oldMessage, ChatMessage newMessage) {
    final index = state.messages.indexOf(oldMessage);
    if (index != -1) {
      final newMessages = List<ChatMessage>.from(state.messages);
      newMessages[index] = newMessage;
      state = state.copyWith(
        messages: newMessages,
        error: null,
        isLoading: false,
        isGenerating: false,
      );
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
