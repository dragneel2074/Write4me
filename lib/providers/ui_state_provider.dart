import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/saved_chat.dart';

class UIState {
  final bool isImageMode;
  final bool isInternetMode;
  final List<SavedChat> savedChats;

  const UIState({
    this.isImageMode = false,
    this.isInternetMode = false,
    this.savedChats = const [],
  });

  UIState copyWith({
    bool? isImageMode,
    bool? isInternetMode,
    List<SavedChat>? savedChats,
  }) {
    return UIState(
      isImageMode: isImageMode ?? this.isImageMode,
      isInternetMode: isInternetMode ?? this.isInternetMode,
      savedChats: savedChats ?? this.savedChats,
    );
  }
}

class UIStateNotifier extends StateNotifier<UIState> {
  UIStateNotifier() : super(const UIState());

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

  void setSavedChats(List<SavedChat> chats) {
    state = state.copyWith(savedChats: chats);
  }

  void resetModes() {
    state = state.copyWith(
      isImageMode: false,
      isInternetMode: false,
    );
  }
}

final uiStateProvider = StateNotifierProvider<UIStateNotifier, UIState>((ref) {
  return UIStateNotifier();
}); 