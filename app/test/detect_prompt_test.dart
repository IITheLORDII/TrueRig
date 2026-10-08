import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:darbogaz/core/devices.dart';
import 'package:darbogaz/core/theme/app_theme.dart';
import 'package:darbogaz/features/detect/detect_prompt.dart';

import 'support.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('detection is a small popup; "Şimdi değil" asks only once', (
    tester,
  ) async {
    final prefs = await prefsWith({});
    await tester.pumpWidget(
      ProviderScope(
        overrides: [prefsProvider.overrideWithValue(prefs)],
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: Consumer(
            builder: (context, ref, _) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => showDetectPrompt(context, ref),
                  child: const Text('aç'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('aç'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Bilgisayarını tanıyalım mı?'), findsOneWidget);
    expect(find.text('Tanı'), findsOneWidget);

    await tester.tap(find.text('Şimdi değil'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(prefs.getBool('detect.asked'), isTrue);
  });
}
