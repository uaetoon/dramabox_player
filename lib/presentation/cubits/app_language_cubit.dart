import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';

class AppLanguageCubit extends Cubit<Locale> {
  static const String _boxName = 'settings';
  static const String _localeKey = 'locale';

  AppLanguageCubit() : super(const Locale('en')) {
    _load();
  }

  void _load() {
    try {
      if (Hive.isBoxOpen(_boxName)) {
        final box = Hive.box(_boxName);
        final code = box.get(_localeKey, defaultValue: 'en') as String;
        emit(Locale(code));
      }
    } catch (e) {
      debugPrint('Error loading language: $e');
    }
  }

  Future<void> setLanguage(Locale locale) async {
    if (locale == state) return;
    emit(locale);
    try {
      final box = await Hive.openBox(_boxName);
      await box.put(_localeKey, locale.languageCode);
    } catch (e) {
      debugPrint('Error saving language: $e');
    }
  }
}
