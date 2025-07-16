import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/saved_chat.dart';

class UIState {
  final bool isImageMode;
  final bool isWebSearch;
  final List<SavedChat> savedChats;

  const UIState({
    this.isImageMode = false,
    this.isWebSearch = false,
    this.savedChats = const [],
  });

  UIState copyWith({
    bool? isImageMode,
    bool? isWebSearch,
    List<SavedChat>? savedChats,
  }) {
    return UIState(
      isImageMode: isImageMode ?? this.isImageMode,
      isWebSearch: isWebSearch ?? this.isWebSearch,
      savedChats: savedChats ?? this.savedChats,
    );
  }
}

class UIStateNotifier extends StateNotifier<UIState> {
  UIStateNotifier() : super(const UIState());

  void setImageMode(bool value) {
    state = state.copyWith(
      isImageMode: value,
      isWebSearch: value ? false : state.isWebSearch,
    );
  }

  void toggleImageMode() {
    state = state.copyWith(
      isImageMode: !state.isImageMode,
      isWebSearch: false,
    );
  }

  void toggleWebSearch() {
    state = state.copyWith(
      isWebSearch: !state.isWebSearch,
      isImageMode: false,
    );
  }

  void setSavedChats(List<SavedChat> chats) {
    state = state.copyWith(savedChats: chats);
  }

  void resetModes() {
    state = state.copyWith(
      isImageMode: false,
      isWebSearch: false,
    );
  }
}

final uiStateProvider = StateNotifierProvider<UIStateNotifier, UIState>((ref) {
  return UIStateNotifier();
}); 