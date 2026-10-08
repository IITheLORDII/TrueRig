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

  testWidgets('a question button is read on its own by screen readers', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: const Scaffold(
          body: Card(
            child: Column(
              children: [
                Text('En uygun'),
                Explain(question: 'Neden bu önerildi?', answer: 'Hızlı.'),
              ],
            ),
          ),
        ),
      ),
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel('Neden bu önerildi?')),
      matchesSemantics(
        label: 'Neden bu önerildi?',
        isButton: true,
        hasExpandedState: true,
        hasTapAction: true,
      ),
    );
    handle.dispose();
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
