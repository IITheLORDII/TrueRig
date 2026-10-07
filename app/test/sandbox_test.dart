import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'support.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('home has "Analiz yap" between status and features', (
    tester,
  ) async {
    await pumpApp(tester);
    expect(find.text('Analiz yap'), findsOneWidget);
    final status = tester.getTopLeft(find.text('Durumun')).dy;
    final quick = tester.getTopLeft(find.text('Analiz yap')).dy;
    final features = tester
        .getTopLeft(find.textContaining(RegExp('yapmak', caseSensitive: false)))
        .dy;
    expect(quick, greaterThan(status));
    expect(quick, lessThan(features));
  });

  testWidgets('PC topla: hand-picked parts show the bottleneck, nothing '
      'is saved', (tester) async {
    final prefs = await prefsWith({});
    await pumpApp(tester, prefs: prefs);
    await tapText(tester, 'PC topla');
    expect(find.text('Bilgisayar topla'), findsOneWidget);

    await tapText(tester, 'İşlemci');
    await search(tester, '5600');
    await tapText(tester, 'AMD Ryzen 5 5600');
    await tapText(tester, 'Ekran Kartı');
    await search(tester, 'RTX 4090');
    await tapText(tester, 'NVIDIA GeForce RTX 4090');

    expect(find.text('Genel darboğaz'), findsOneWidget);
    expect(find.text('Çözünürlüğe göre'), findsOneWidget);
    // Scratch area never touches the user's own devices.
    expect(prefs.getStringList('pc.build'), isNull);
    expect(prefs.getString('devices.saved') ?? '', isNot(contains('r5-5600')));
  });

  testWidgets('compare two phones in the scratch area', (tester) async {
    await pumpApp(tester);
    await tap(tester, find.widgetWithText(OutlinedButton, 'Karşılaştır'));
    await tapText(tester, 'Telefon');
    await tap(tester, find.text('Seç').first);
    await search(tester, 'iPhone 15');
    await tapText(tester, 'Apple iPhone 15');
    await tap(tester, find.text('Seç').first);
    await search(tester, 'Pixel 8');
    await tapText(tester, 'Google Pixel 8');
    expect(find.text('Kim önde?'), findsOneWidget);
    expect(find.text('Genel puan'), findsOneWidget);
    expect(find.byType(Switch), findsOneWidget);
  });
}
