import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'support.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  bool onHome(WidgetTester tester) =>
      find.text('Ne öğrenmek istersin?'.toUpperCase()).evaluate().isNotEmpty ||
      find.textContaining('RENMEK').evaluate().isNotEmpty;

  testWidgets('tab pages have a back button; Ana Sayfa has none', (
    tester,
  ) async {
    await pumpApp(tester);
    expect(find.byTooltip('Geri'), findsNothing);
    await openTab(tester, 'Analiz');
    await openTab(tester, 'Karşılaştır');
    expect(find.byTooltip('Geri'), findsOneWidget);

    // Back goes to the previous tab, then to Ana Sayfa.
    await tap(tester, find.byTooltip('Geri'));
    expect(find.text('Özet'), findsOneWidget); // Analiz
    await tap(tester, find.byTooltip('Geri'));
    expect(onHome(tester), isTrue);
  });

  testWidgets('Android back key steps back through tabs', (tester) async {
    await pumpApp(tester);
    await openTab(tester, 'Parça Ara');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(onHome(tester), isTrue);
  });

  testWidgets('swipe from the left edge goes back (iOS style)', (tester) async {
    await pumpApp(tester);
    await openTab(tester, 'Cihazlarım');
    await tester.dragFrom(const Offset(4, 600), const Offset(220, 0));
    await tester.pumpAndSettle();
    expect(onHome(tester), isTrue);
  });

  testWidgets('pushed pages keep the system back arrow', (tester) async {
    await pumpApp(tester);
    await tap(tester, find.byTooltip('Profil ve ayarlar'));
    expect(find.byType(BackButton), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(onHome(tester), isTrue);
  });
}
