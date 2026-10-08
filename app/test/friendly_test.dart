import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:darbogaz/core/theme/app_theme.dart';
import 'package:darbogaz/core/widgets/explain.dart';

import 'support.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('explanations stay closed until their question is tapped', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: const Scaffold(
          body: Explain(
            question: 'Neden bu önerildi?',
            points: ['Oyunlarda ~70 FPS.'],
          ),
        ),
      ),
    );
    expect(find.text('Oyunlarda ~70 FPS.'), findsNothing);
    await tester.tap(find.text('Neden bu önerildi?'));
    await tester.pumpAndSettle();
    expect(find.text('Oyunlarda ~70 FPS.'), findsOneWidget);
  });

  testWidgets('inner pages keep the back arrow and the bottom menu', (
    tester,
  ) async {
    await pumpApp(tester);
    for (final open in [
      () => tapText(tester, 'Bilgisayarı ne için alıyorsun?'),
      () => tap(tester, find.byTooltip('Profil ve ayarlar')),
      () => tapText(tester, 'Hazır bilgisayar / laptop seç'),
    ]) {
      await open();
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byTooltip('Geri'), findsWidgets);
      // The menu leads straight to any section.
      await tap(
        tester,
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Ana Sayfa'),
        ),
      );
      expect(find.text('Cihazların'), findsOneWidget);
    }
  });
}
