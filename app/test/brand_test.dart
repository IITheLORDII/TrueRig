import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:darbogaz/app.dart';
import 'package:darbogaz/core/brand/truerig_logo.dart';
import 'package:darbogaz/features/detect/self_device.dart';

import 'support.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('splash shows the brand, then opens Cihazlarım', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [selfDeviceIdProvider.overrideWith((ref) async => null)],
        child: const DarbogazApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 900));
    expect(find.text(kAppTagline), findsOneWidget);
    expect(find.byType(TrueRigMark), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.text(kAppTagline), findsNothing);
    expect(find.text('PC ekle'), findsOneWidget);
  });

  testWidgets('every tab shows the logo, name and profile button', (
    tester,
  ) async {
    await pumpApp(tester);
    for (final tab in ['Cihazlarım', 'Analiz', 'Karşılaştır', 'Fiyat']) {
      await openTab(tester, tab);
      final bar = find.byType(AppBar);
      expect(
        find.descendant(of: bar, matching: find.byType(TrueRigMark)),
        findsOneWidget,
        reason: tab,
      );
      expect(
        find.descendant(of: bar, matching: find.text('True')),
        findsOneWidget,
        reason: tab,
      );
      expect(find.byTooltip('Profil ve ayarlar'), findsOneWidget, reason: tab);
    }
  });

  testWidgets('home and Analiz survive large text (accessibility)', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpApp(tester);
    expect(tester.takeException(), isNull);
    await openTab(tester, 'Analiz');
    expect(tester.takeException(), isNull);
  });
}
