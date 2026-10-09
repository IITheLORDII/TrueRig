import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:perf_engine/perf_engine.dart';

import 'package:darbogaz/core/brand/truerig_logo.dart';
import 'package:darbogaz/core/theme/app_theme.dart';
import 'package:darbogaz/features/builder/build_visual.dart';
import 'package:darbogaz/features/builder/pc_case_painter.dart';

Widget _host(Widget child, {bool reduceMotion = false}) => MaterialApp(
  theme: AppTheme.dark(),
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: reduceMotion),
    child: Scaffold(
      body: Padding(padding: const EdgeInsets.all(16), child: child),
    ),
  ),
);

PcCasePainter _painter(WidgetTester tester) => tester
    .widgetList<CustomPaint>(find.byType(CustomPaint))
    .map((w) => w.painter)
    .whereType<PcCasePainter>()
    .single;

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
    // Every inside part is missing, so each gets a dashed outline.
    expect(_painter(tester).present, isEmpty);
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
    // Mid-move the parts are on their way, then settle in place.
    await tester.pump(const Duration(milliseconds: 150));
    final mid = _painter(tester).progressOf(PartCategory.cpu);
    expect(mid, greaterThan(0));
    expect(mid, lessThan(1));
    await tester.pumpAndSettle();
    expect(find.text('4 ana parçadan 2 tanesi takılı'), findsOneWidget);
    expect(_painter(tester).progressOf(PartCategory.gpu), 1);
    expect(_painter(tester).progressOf(PartCategory.ram), 0);
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
    expect(_painter(tester).progressOf(PartCategory.cpu), 1);
    expect(tester.takeException(), isNull);
  });
}
