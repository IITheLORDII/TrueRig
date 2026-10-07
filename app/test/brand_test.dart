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

  testWidgets('splash shows the brand, then opens Ana Sayfa', (tester) async {
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
    // First launch: the welcome tour, skippable at any time.
    expect(find.text('TrueRig ne yapar?'), findsOneWidget);
    await tester.tap(find.text('Atla'));
    await tester.pumpAndSettle();
    expect(find.text('Cihazların'), findsOneWidget);
  });

  testWidgets('tour: choosing a device opens its add sheet', (tester) async {
    await pumpApp(tester, prefs: await prefsWith({'onboarding.done': false}));
    expect(find.text('TrueRig ne yapar?'), findsOneWidget);
    await tapText(tester, 'Devam');
    expect(find.text('Darboğaz nedir?'), findsOneWidget);
    await tapText(tester, 'Devam');
    await tapText(tester, 'Telefonum');
    expect(find.text('Telefonunu nasıl ekleyelim?'), findsOneWidget);
  });

  testWidgets('every tab shows the logo, name and profile button', (
    tester,
  ) async {
    await pumpApp(tester);
    for (final tab in [
      'Ana Sayfa',
      'Cihazlarım',
      'Analiz',
      'Karşılaştır',
      'Parça Ara',
    ]) {
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

  testWidgets('main screens survive large text (accessibility)', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpApp(tester);
    expect(tester.takeException(), isNull);
    for (final tab in ['Analiz', 'Karşılaştır', 'Parça Ara', 'Cihazlarım']) {
      await openTab(tester, tab);
      expect(tester.takeException(), isNull, reason: tab);
    }
  });

  testWidgets('welcome tour survives large text', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpApp(tester, prefs: await prefsWith({'onboarding.done': false}));
    for (var i = 0; i < 2; i++) {
      expect(tester.takeException(), isNull);
      await tapText(tester, 'Devam');
    }
    expect(tester.takeException(), isNull);
  });
}
