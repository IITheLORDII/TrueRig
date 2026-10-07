import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:darbogaz/app.dart';
import 'package:darbogaz/core/devices.dart';
import 'package:darbogaz/core/providers.dart';
import 'package:darbogaz/features/detect/self_device.dart';

Future<SharedPreferences> prefsWith(Map<String, Object> values) async {
  SharedPreferences.setMockInitialValues(values);
  return SharedPreferences.getInstance();
}

/// Pumps the whole app (through the splash) on a tall phone-like screen so
/// lists are built without scrolling.
Future<void> pumpApp(
  WidgetTester tester, {
  SharedPreferences? prefs,
  String? selfId,
  BuildController Function()? build,
}) async {
  tester.view.physicalSize = const Size(430, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        selfDeviceIdProvider.overrideWith((ref) async => selfId),
        prefsProvider.overrideWithValue(prefs ?? await prefsWith({})),
        if (build != null) buildProvider.overrideWith(build),
      ],
      child: const DarbogazApp(),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f.first);
  await tester.tap(f.first);
  await tester.pumpAndSettle();
}

Future<void> tapText(WidgetTester tester, String text) =>
    tap(tester, find.text(text));

/// Bottom navigation tab by label.
Future<void> openTab(WidgetTester tester, String label) => tap(
  tester,
  find.descendant(of: find.byType(NavigationBar), matching: find.text(label)),
);

Future<void> search(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField).first, text);
  await tester.pumpAndSettle();
}
