import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:darbogaz/core/theme/app_theme.dart';
import 'package:darbogaz/core/widgets/app_controls.dart';

/// The app has one design: these controls must render identically on iOS and
/// Android.
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Future<void> pumpOn(
    WidgetTester tester,
    TargetPlatform platform,
    Widget child,
  ) async {
    debugDefaultTargetPlatformOverride = platform;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(body: child),
      ),
    );
    await tester.pumpAndSettle();
  }

  tearDown(() => debugDefaultTargetPlatformOverride = null);

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets('same segmented control on ${platform.name}', (tester) async {
      var picked = '';
      await pumpOn(
        tester,
        platform,
        AppSegmented<String>(
          values: const ['1080p', '1440p', '4K'],
          selected: '1080p',
          labelOf: (v) => v,
          onChanged: (v) => picked = v,
        ),
      );
      expect(
        find.byType(CupertinoSlidingSegmentedControl<String>),
        findsOneWidget,
      );
      expect(find.byType(SegmentedButton<String>), findsNothing);
      await tester.tap(find.text('4K'));
      await tester.pumpAndSettle();
      expect(picked, '4K');
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('same bottom bar on ${platform.name}', (tester) async {
      await pumpOn(
        tester,
        platform,
        AppBottomBar(
          tabs: const [
            AppTab('Cihaz', Icons.devices_outlined, Icons.devices_rounded),
            AppTab('Performans', Icons.speed_outlined, Icons.speed_rounded),
          ],
          currentIndex: 0,
          onTap: (_) {},
        ),
      );
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(CupertinoTabBar), findsNothing);
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('same option sheet on ${platform.name}', (tester) async {
      String? result;
      await pumpOn(
        tester,
        platform,
        Builder(
          builder: (context) => TextButton(
            onPressed: () async => result = await showOptionSheet<String>(
              context: context,
              title: 'Oyun seç',
              options: const ['CS2', 'RDR2'],
              labelOf: (v) => v,
              selected: 'CS2',
            ),
            child: const Text('aç'),
          ),
        ),
      );
      await tester.tap(find.text('aç'));
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoActionSheet), findsNothing);
      await tester.tap(find.text('RDR2'));
      await tester.pumpAndSettle();
      expect(result, 'RDR2');
      debugDefaultTargetPlatformOverride = null;
    });
  }

  test('theme uses one page transition for every platform', () {
    final builders = AppTheme.dark().pageTransitionsTheme.builders;
    expect(
      builders[TargetPlatform.android].runtimeType,
      builders[TargetPlatform.iOS].runtimeType,
    );
    expect(AppTheme.dark().appBarTheme.centerTitle, isTrue);
  });
}
