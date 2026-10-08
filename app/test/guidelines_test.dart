import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:darbogaz/core/widgets/buttons.dart';

import 'support.dart';

/// Design rules every main screen must keep: at most one primary button,
/// tap targets of at least 48 px, and no overflow with large text.
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  const tabs = [
    'Ana Sayfa',
    'Cihazlarım',
    'Analiz',
    'Karşılaştır',
    'Parça Ara',
  ];

  testWidgets('each tab has at most one primary button', (tester) async {
    await pumpApp(tester);
    for (final t in tabs) {
      await openTab(tester, t);
      expect(
        find.byType(PrimaryButton, skipOffstage: true).evaluate().length,
        lessThanOrEqualTo(1),
        reason: t,
      );
    }
  });

  testWidgets('each tab meets the tap target guideline', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpApp(tester);
    for (final t in tabs) {
      await openTab(tester, t);
      await expectLater(
        tester,
        meetsGuideline(androidTapTargetGuideline),
        reason: t,
      );
    }
    handle.dispose();
  });

  testWidgets('tabs and the advisor do not overflow at 1.5× text', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpApp(tester);
    tester.view.physicalSize = const Size(375, 2000);
    await tester.pumpAndSettle();
    for (final t in tabs) {
      await openTab(tester, t);
      expect(tester.takeException(), isNull, reason: t);
    }
    await openTab(tester, 'Ana Sayfa');
    await tapText(tester, 'Bilgisayarı ne için alıyorsun?');
    await tapText(tester, 'Oyun');
    await tapText(tester, 'Devam');
    expect(tester.takeException(), isNull);
  });
}
