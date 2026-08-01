import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Toggles the "Similar on other platforms" row shown on drama detail pages.
///
/// The setting persists in the `settings` Hive box so it survives app
/// restarts. Enabled by default.
class SimilarSectionCubit extends Cubit<bool> {
  static const String _boxName = 'settings';
  static const String _enabledKey = 'similarEnabled';

  SimilarSectionCubit() : super(true) {
    _load();
  }

  bool get isEnabled => state;

  void _load() {
    try {
      if (Hive.isBoxOpen(_boxName)) {
        final box = Hive.box(_boxName);
        final value = box.get(_enabledKey, defaultValue: true) as bool;
        emit(value);
      }
    } catch (e) {
      debugPrint('Error loading similar section setting: $e');
    }
  }

  Future<void> setEnabled(bool enabled) async {
    emit(enabled);
    try {
      final box = await Hive.openBox(_boxName);
      await box.put(_enabledKey, enabled);
    } catch (e) {
      debugPrint('Error saving similar section setting: $e');
    }
  }
}
