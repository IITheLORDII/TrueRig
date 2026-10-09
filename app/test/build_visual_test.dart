import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:perf_engine/perf_engine.dart';

import 'package:darbogaz/core/brand/truerig_logo.dart';
import 'package:darbogaz/core/theme/app_theme.dart';
import 'package:darbogaz/features/builder/build_visual.dart';

Widget _host(Widget child, {bool reduceMotion = false}) => MaterialApp(
  theme: AppTheme.dark(),
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: reduceMotion),
    child: Scaffold(
      body: Padding(padding: const EdgeInsets.all(16), child: child),
    ),
  ),
);

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  final c = PartCatalog.seed();
  final cpu = c.byId('r5-5600')! as Cpu;
  final gpu = c.byId('rtx-4090')! as Gpu;

  testWidgets('empty case says what is missing', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _host(const BuildVisual(build: PcBuild(), isLaptop: false)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Parça seçtikçe kasana yerleşecek'), findsOneWidget);
    // Empty slots are drawn at full size (not collapsed to nothing).
    final slots = find.descendant(
      of: find.byType(BuildVisual),
      matching: find.byType(CustomPaint),
    );
    final drawn = slots.evaluate().where((e) {
      final size = e.size;
      return size != null && size.width > 10 && size.height > 10;
    });
    expect(drawn.length, greaterThanOrEqualTo(6)); // case + 5 slots
    expect(
      find.bySemanticsLabel('Masaüstü kasa: henüz parça yok'),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('a picked part drops into the case', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _host(const BuildVisual(build: PcBuild(), isLaptop: false)),
    );
    await tester.pumpWidget(
      _host(
        BuildVisual(
          build: PcBuild(cpu: cpu, gpu: gpu),
          isLaptop: false,
        ),
      ),
    );
    // Mid-fall the part is above its slot.
    await tester.pump(const Duration(milliseconds: 100));
    final midFall = tester.widget<Transform>(
      find
          .descendant(
            of: find.byType(BuildVisual),
            matching: find.byType(Transform),
          )
          .first,
    );
    expect(midFall.transform.getTranslation().y, lessThan(0));
    await tester.pumpAndSettle();
    expect(find.text('4 ana parçadan 2 tanesi takılı'), findsOneWidget);
    expect(
      find.bySemanticsLabel(
        'Masaüstü kasa: işlemci, ekran kartı takılı; anakart, RAM eksik',
      ),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('a laptop opens on the TrueRig mark', (tester) async {
    await tester.pumpWidget(
      _host(
        BuildVisual(
          build: PcBuild(cpu: cpu, gpu: gpu),
          isLaptop: true,
          systemName: 'Casper Excalibur G770',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(TrueRigMark), findsOneWidget);
    expect(find.text('Casper Excalibur G770'), findsOneWidget);
    expect(find.textContaining('kasa'), findsNothing);
  });

  testWidgets('reduced motion shows the final picture at once', (tester) async {
    await tester.pumpWidget(
      _host(
        BuildVisual(
          build: PcBuild(cpu: cpu, gpu: gpu),
          isLaptop: false,
        ),
        reduceMotion: true,
      ),
    );
    await tester.pump();
    expect(tester.hasRunningAnimations, isFalse);
    expect(tester.takeException(), isNull);
  });
}
