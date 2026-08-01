import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:dramabox_free/main.dart';
import 'package:dramabox_free/core/di/injection_container.dart' as di;

void main() {
  setUpAll(() async {
    WidgetsFlutterBinding.ensureInitialized();
    final tempDir = await Directory.systemTemp.createTemp('dramabox_hive_');
    Hive.init(tempDir.path);
    await Hive.openBox('settings');
    await di.init();
  });

  tearDownAll(() async {
    await Hive.close();
  });

  testWidgets('UAETooNDrama home screen renders with navigation', (tester) async {
    await tester.pumpWidget(const MyApp());

    // Let the initial bloc events dispatch. Network calls fail fast in the
    // test environment, so no timers are left pending.
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Search'), findsOneWidget);
    expect(find.text('My List'), findsOneWidget);
    expect(find.text('Downloads'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
  });
}
