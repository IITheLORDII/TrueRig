import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:darbogaz/core/theme/app_theme.dart';
import 'package:darbogaz/core/widgets/score_scale.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('zone bands are actually drawn (non-zero height)', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          body: Builder(
            builder: (context) => Padding(
              padding: const EdgeInsets.all(16),
              child: ScoreScale.bottleneck(context, 15),
            ),
          ),
        ),
      ),
    );
    final bands = find.descendant(
      of: find.byType(ScoreScale),
      matching: find.byType(ColoredBox),
    );
    expect(bands, findsNWidgets(3));
    for (final e in bands.evaluate()) {
      final size = tester.getSize(find.byWidget(e.widget));
      expect(size.height, greaterThan(0));
      expect(size.width, greaterThan(0));
    }
    expect(
      find.textContaining('%15 · Orta', findRichText: true),
      findsOneWidget,
    );
  });
}
