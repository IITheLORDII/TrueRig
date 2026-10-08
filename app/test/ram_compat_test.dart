import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:darbogaz/core/widgets/picker.dart';

import 'support.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('incompatible RAM asks before it is selected', (tester) async {
    await pumpApp(
      tester,
      prefs: await prefsWith({
        'pc.build': ['r5-5600', 'rtx-3060-12'],
      }),
    );
    await openTab(tester, 'Cihazlarım');
    await tapText(tester, 'RAM');
    await search(tester, 'DDR5-6000');
    const ddr5 = 'Genel 32GB (2x16) DDR5-6000';
    expect(find.text(ddr5), findsOneWidget);
    // Flagged in the list with the reason.
    expect(find.textContaining('yalnızca DDR4 destekler'), findsWidgets);

    await tapText(tester, ddr5);
    expect(find.text('Bu parça uyumsuz'), findsOneWidget);
    await tapText(tester, 'Vazgeç');
    expect(find.text('Bu parça uyumsuz'), findsNothing);
    expect(find.text(ddr5), findsOneWidget); // still choosing

    await tapText(tester, ddr5);
    await tapText(tester, 'Yine de seç');
    // Back on Bilgisayarım with the RAM set; Analiz explains the problem.
    expect(find.text('Bu parça uyumsuz'), findsNothing);
    expect(find.text(ddr5), findsWidgets);
    await openTab(tester, 'Analiz');
    final reason = find.textContaining('yalnızca DDR4 destekler');
    await tester.scrollUntilVisible(
      reason,
      400,
      scrollable: find.byType(Scrollable).last,
    );
    expect(reason, findsWidgets);
  });

  testWidgets('RAM rows say whether they are desktop or laptop memory', (
    tester,
  ) async {
    await pumpApp(tester);
    await openTab(tester, 'Cihazlarım');
    await tapText(tester, 'RAM');
    await search(tester, 'SO-DIMM');
    expect(find.textContaining('Dizüstü (SO-DIMM)'), findsWidgets);
    expect(find.byType(PickerTile), findsWidgets);
  });
}
