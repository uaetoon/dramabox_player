import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Gates the "18+" pseudo-provider behind a numeric code.
///
/// The unlocked state persists in the `settings` Hive box so it survives app
/// restarts. Locked by default.
class AdultLockCubit extends Cubit<bool> {
  static const String _boxName = 'settings';
  static const String _unlockedKey = 'adultUnlocked';

  /// The code required to unlock adult content.
  static const String correctCode = '666';

  AdultLockCubit() : super(false) {
    _load();
  }

  bool get isUnlocked => state;

  void _load() {
    try {
      if (Hive.isBoxOpen(_boxName)) {
        final box = Hive.box(_boxName);
        final value = box.get(_unlockedKey, defaultValue: false) as bool;
        emit(value);
      }
    } catch (e) {
      debugPrint('Error loading adult lock: $e');
    }
  }

  /// Unlocks adult content if [code] matches. Returns whether the code was
  /// correct and the state changed.
  Future<bool> unlock(String code) async {
    if (code.trim() != correctCode) return false;
    emit(true);
    try {
      final box = await Hive.openBox(_boxName);
      await box.put(_unlockedKey, true);
    } catch (e) {
      debugPrint('Error saving adult lock: $e');
    }
    return true;
  }

  /// Re-locks adult content.
  Future<void> lock() async {
    emit(false);
    try {
      final box = await Hive.openBox(_boxName);
      await box.put(_unlockedKey, false);
    } catch (e) {
      debugPrint('Error saving adult lock: $e');
    }
  }
}
