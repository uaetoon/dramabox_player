import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';

class ProviderVisibilityCubit extends Cubit<Set<String>> {
  static const String _boxName = 'settings';
  static const String _hiddenKey = 'hidden_providers';

  ProviderVisibilityCubit() : super(const {}) {
    _load();
  }

  void _load() {
    try {
      if (Hive.isBoxOpen(_boxName)) {
        final box = Hive.box(_boxName);
        final raw = box.get(_hiddenKey, defaultValue: <String>[]) as List;
        emit(raw.whereType<String>().toSet());
      }
    } catch (e) {
      debugPrint('Error loading provider visibility: $e');
    }
  }

  bool isVisible(String providerKey) => !state.contains(providerKey);

  Future<void> setVisible(String providerKey, bool visible) async {
    final hidden = Set<String>.from(state);
    if (visible) {
      hidden.remove(providerKey);
    } else {
      hidden.add(providerKey);
    }
    emit(hidden);
    try {
      final box = await Hive.openBox(_boxName);
      await box.put(_hiddenKey, hidden.toList());
    } catch (e) {
      debugPrint('Error saving provider visibility: $e');
    }
  }
}
