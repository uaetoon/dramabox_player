import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// User-configurable playback defaults.
class PlaybackSettings {
  /// Auto-advance to the next episode when the current one finishes.
  final bool autoPlayNext;

  /// Default playback speed (e.g. 1.0, 1.5).
  final double defaultSpeed;

  const PlaybackSettings({
    this.autoPlayNext = true,
    this.defaultSpeed = 1.0,
  });

  PlaybackSettings copyWith({bool? autoPlayNext, double? defaultSpeed}) {
    return PlaybackSettings(
      autoPlayNext: autoPlayNext ?? this.autoPlayNext,
      defaultSpeed: defaultSpeed ?? this.defaultSpeed,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is PlaybackSettings &&
      other.autoPlayNext == autoPlayNext &&
      other.defaultSpeed == defaultSpeed;

  @override
  int get hashCode => Object.hash(autoPlayNext, defaultSpeed);
}

/// Persists playback defaults (auto-next, default speed) in the `settings`
/// Hive box.
class PlaybackSettingsCubit extends Cubit<PlaybackSettings> {
  static const String _boxName = 'settings';
  static const String _autoNextKey = 'autoPlayNext';
  static const String _speedKey = 'defaultSpeed';

  PlaybackSettingsCubit() : super(const PlaybackSettings()) {
    _load();
  }

  void _load() {
    try {
      if (Hive.isBoxOpen(_boxName)) {
        final box = Hive.box(_boxName);
        final autoNext =
            box.get(_autoNextKey, defaultValue: true) as bool;
        final speed =
            (box.get(_speedKey, defaultValue: 1.0) as num).toDouble();
        emit(PlaybackSettings(autoPlayNext: autoNext, defaultSpeed: speed));
      }
    } catch (e) {
      debugPrint('Error loading playback settings: $e');
    }
  }

  Future<void> setAutoPlayNext(bool value) async {
    emit(state.copyWith(autoPlayNext: value));
    try {
      final box = await Hive.openBox(_boxName);
      await box.put(_autoNextKey, value);
    } catch (e) {
      debugPrint('Error saving autoPlayNext: $e');
    }
  }

  Future<void> setDefaultSpeed(double value) async {
    emit(state.copyWith(defaultSpeed: value));
    try {
      final box = await Hive.openBox(_boxName);
      await box.put(_speedKey, value);
    } catch (e) {
      debugPrint('Error saving defaultSpeed: $e');
    }
  }
}
