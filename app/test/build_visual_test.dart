import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:perf_engine/perf_engine.dart';

import 'package:darbogaz/core/brand/truerig_logo.dart';
import 'package:darbogaz/core/theme/app_theme.dart';
import 'package:darbogaz/features/builder/build_visual.dart';
import 'package:darbogaz/features/builder/pc_case_painter.dart';
import 'package:darbogaz/features/builder/pc_case_shape.dart';

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

  group('the chosen case changes the picture', () {
    PcBuild withCase(String id, {String? cooler}) {
      var b = PcBuild(cpu: cpu, gpu: gpu).withPart(c.byId(id)!);
      if (cooler != null) b = b.withPart(c.byId(cooler)!);
      return b;
    }

    test('fans, style and size follow the case', () {
      final air = BuildShape.of(withCase('montech-air100'));
      expect(air.fans.total, 4);
      expect(air.rgbFans, isTrue);
      expect(air.style, CaseStyle.airflow);
      final o11 = BuildShape.of(withCase('lianli-o11-evo'));
      expect(o11.style, CaseStyle.aquarium);
      expect(o11.fans.total, 0);
      final terra = BuildShape.of(withCase('fractal-terra'));
      expect(terra.style, CaseStyle.compact);
      expect(terra.h, lessThan(o11.h)); // small case drawn smaller
    });

    test('every case draws exactly the fans it ships with', () {
      for (final pc in c.byCategory(PartCategory.pcCase).cast<PcCase>()) {
        final s = BuildShape.of(PcBuild(cpu: cpu).withPart(pc));
        final slots = s.fanSlots;
        final m = pc.mounts;
        expect(slots.length, m.total - m.side, reason: pc.id);
        expect(
          slots.where((f) => f.filled).length,
          pc.fans.total - pc.fans.side,
          reason: pc.id,
        );
        for (final f in slots) {
          expect(f.r, greaterThan(0.05), reason: '${pc.id} fan too small');
          final (along, lo, hi) = switch (f.place) {
            FanPlace.front || FanPlace.rear => (f.y, 0.0, s.h),
            FanPlace.top => (f.z, 0.0, s.d),
            FanPlace.bottom => (f.z, 0.0, s.psuFrontZ),
          };
          expect(along - f.r, greaterThanOrEqualTo(lo), reason: pc.id);
          expect(along + f.r, lessThanOrEqualTo(hi), reason: pc.id);
        }
      }
      final air = BuildShape.of(withCase('montech-air100')).fanSlots;
      int filled(FanPlace p) =>
          air.where((f) => f.place == p && f.filled).length;
      expect(filled(FanPlace.front), 3);
      expect(filled(FanPlace.rear), 1);
      expect(filled(FanPlace.top), 0);
      expect(air.where((f) => f.place == FanPlace.top).length, 2);
    });

    test('cases keep their real size relative to the reference', () {
      final ref = BuildShape.of(withCase('corsair-4000d'));
      expect(ref.d, closeTo(1.1, 1e-9)); // the 4000D sets the scale
      for (final pc in c.byCategory(PartCategory.pcCase).cast<PcCase>()) {
        final s = BuildShape.of(PcBuild(cpu: cpu).withPart(pc));
        expect(s.w / ref.w, closeTo(pc.widthMm / 230, 1e-9), reason: pc.id);
        expect(s.h / ref.h, closeTo(pc.heightMm / 466, 1e-9), reason: pc.id);
        expect(s.d / ref.d, closeTo(pc.depthMm / 453, 1e-9), reason: pc.id);
      }
      // No case chosen: drawn as the reference.
      expect(BuildShape.of(PcBuild(cpu: cpu)).h, ref.h);
    });

    test('a liquid cooler gets a radiator with one fan per 120 mm', () {
      final s = BuildShape.of(
        withCase('lianli-o11-evo', cooler: 'cooler-aio-360'),
      );
      expect(s.liquid, isTrue);
      expect(s.radiatorFans, 3);
    });

    test('parts too big for the case are flagged', () {
      final s = BuildShape.of(
        withCase('fractal-terra', cooler: 'cooler-tower-120'),
      );
      expect(s.coolerTooTall, isTrue);
      expect(s.gpuTooLong, gpu.lengthMm > 322);
    });

    test('built-in graphics draws no card', () {
      final igpu = c
          .byCategory(PartCategory.gpu)
          .cast<Gpu>()
          .firstWhere(isIntegratedGpu);
      expect(BuildShape.of(PcBuild(gpu: igpu)).gpuIntegrated, isTrue);
    });

    testWidgets('caption tells the fans and what does not fit', (tester) async {
      await tester.pumpWidget(
        _host(
          SingleChildScrollView(
            child: BuildVisual(
              build: withCase('fractal-terra', cooler: 'cooler-tower-120'),
              isLaptop: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Terra fansız geliyor'), findsOneWidget);
      expect(find.textContaining('1 fan takılabilir: 1 alt'), findsOneWidget);
      expect(find.textContaining('153 × 218 × 343 mm'), findsOneWidget);
      expect(
        find.textContaining('Soğutucu bu kasaya sığmıyor'),
        findsOneWidget,
      );
      expect(_painter(tester).shape.coolerTooTall, isTrue);
    });
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
