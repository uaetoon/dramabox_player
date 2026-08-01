import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';

class AppThemeCubit extends Cubit<ThemeMode> {
  static const String _boxName = 'settings';
  static const String _themeKey = 'themeMode';

  AppThemeCubit() : super(ThemeMode.dark) {
    _load();
  }

  void _load() {
    try {
      if (Hive.isBoxOpen(_boxName)) {
        final box = Hive.box(_boxName);
        final value = box.get(_themeKey, defaultValue: 'dark') as String;
        emit(_fromName(value));
      }
    } catch (e) {
      debugPrint('Error loading theme: $e');
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (mode == state) return;
    emit(mode);
    try {
      final box = await Hive.openBox(_boxName);
      await box.put(_themeKey, mode.name);
    } catch (e) {
      debugPrint('Error saving theme: $e');
    }
  }

  ThemeMode _fromName(String name) {
    switch (name) {
      case 'light':
        return ThemeMode.light;
      case 'system':
        return ThemeMode.system;
      default:
        return ThemeMode.dark;
    }
  }
}
