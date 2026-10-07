import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:darbogaz/app.dart';
import 'package:darbogaz/core/brand/truerig_logo.dart';
import 'package:darbogaz/features/detect/self_device.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('splash shows the brand, then opens the device tab', (
    tester,
  ) async {
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
    expect(find.text('Cihazım'), findsOneWidget);
  });

  testWidgets('every tab shows the logo and name in the app bar', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [selfDeviceIdProvider.overrideWith((ref) async => null)],
        child: const DarbogazApp(),
      ),
    );
    await tester.pumpAndSettle();
    for (final tab in ['Cihaz', 'Performans', 'Fiyat', 'Profil']) {
      await tester.tap(find.text(tab).last);
      await tester.pumpAndSettle();
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
    }
  });
}
