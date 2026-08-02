import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// The overall app layout/shell style. Classic is the original Dramabox look;
/// QuickPlay is an alternate shell inspired by the QuickPlay app.
enum UiStyle { classic, quickplay }

/// Persists the chosen UI layout style in the `settings` Hive box.
class UiStyleCubit extends Cubit<UiStyle> {
  static const String _boxName = 'settings';
  static const String _key = 'uiStyle';

  UiStyleCubit() : super(UiStyle.classic) {
    _load();
  }

  bool get isQuickplay => state == UiStyle.quickplay;

  void _load() {
    try {
      if (Hive.isBoxOpen(_boxName)) {
        final value =
            Hive.box(_boxName).get(_key, defaultValue: 'classic') as String;
        emit(_fromName(value));
      }
    } catch (e) {
      debugPrint('Error loading UI style: $e');
    }
  }

  Future<void> setStyle(UiStyle style) async {
    if (style == state) return;
    emit(style);
    try {
      final box = await Hive.openBox(_boxName);
      await box.put(_key, style.name);
    } catch (e) {
      debugPrint('Error saving UI style: $e');
    }
  }

  UiStyle _fromName(String name) {
    switch (name) {
      case 'quickplay':
        return UiStyle.quickplay;
      default:
        return UiStyle.classic;
    }
  }
}
