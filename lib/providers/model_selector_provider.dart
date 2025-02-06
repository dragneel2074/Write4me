import 'package:flutter_riverpod/flutter_riverpod.dart';

class ModelSelectorState {
  final bool useLocalModel;
  
  ModelSelectorState({this.useLocalModel = false});
  
  ModelSelectorState copyWith({bool? useLocalModel}) {
    return ModelSelectorState(
      useLocalModel: useLocalModel ?? this.useLocalModel,
    );
  }
}

class ModelSelectorNotifier extends StateNotifier<ModelSelectorState> {
  ModelSelectorNotifier() : super(ModelSelectorState());
  
  void setUseLocalModel(bool value) {
    state = state.copyWith(useLocalModel: value);
  }
}

final modelSelectorProvider = StateNotifierProvider<ModelSelectorNotifier, ModelSelectorState>((ref) {
  return ModelSelectorNotifier();
}); 