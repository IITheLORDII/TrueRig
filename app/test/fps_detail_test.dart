import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:perf_engine/perf_engine.dart';

import 'package:darbogaz/core/providers.dart';

import 'support.dart';

/// Ryzen 5 5600 + RTX 4090: clearly limited by the processor.
class _CpuBoundBuild extends BuildController {
  _CpuBoundBuild([this.ramId = 'corsair-ddr5-6000-32']);

  final String ramId;

  @override
  PcBuild build() {
    final c = PartCatalog.seed();
    return PcBuild(
      cpu: c.byId('r5-5600')! as Cpu,
      gpu: c.byId('rtx-4090')! as Gpu,
      ram: c.byId(ramId)! as Ram,
    );
  }
}

class _SingleStickBuild extends _CpuBoundBuild {
  _SingleStickBuild() : super('kingston-ddr5-5600-16x1');
}

const _open = 'Detaylı incele: parça parça FPS';

/// Text of the big "~N" result number.
String _result(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((t) => t.data ?? '')
    .firstWhere((s) => RegExp(r'^~\d+$').hasMatch(s));

void main() {
  testWidgets('Analiz opens each part\'s own FPS, with back and menu', (
    tester,
  ) async {
    await pumpApp(tester, build: _CpuBoundBuild.new);
    await openTab(tester, 'Analiz');
    await tapText(tester, _open);
    expect(find.text('Parça parça FPS'), findsOneWidget);
    for (final t in ['İşlemci', 'RAM', 'Ekran kartı', 'Ekran kartı belleği']) {
      expect(find.text(t), findsWidgets, reason: t);
    }
    expect(find.textContaining('Hızı belirleyen: işlemci'), findsOneWidget);
    expect(find.text('Tüm oyunlar (ortalama)'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byTooltip('Geri'), findsWidgets);
  });

  testWidgets('changing the resolution changes the numbers', (tester) async {
    await pumpApp(tester, build: _CpuBoundBuild.new);
    await openTab(tester, 'Analiz');
    await tapText(tester, _open);
    await tapText(tester, '1080p');
    final at1080 = _result(tester);
    await tapText(tester, '4K');
    expect(_result(tester), isNot(at1080));
  });

  testWidgets('one memory stick shows the FPS it costs and why', (
    tester,
  ) async {
    await pumpApp(tester, build: _SingleStickBuild.new);
    await openTab(tester, 'Analiz');
    await tapText(tester, _open);
    expect(find.textContaining('tek modül'), findsOneWidget);
    expect(find.textContaining('−'), findsWidgets); // a loss badge
  });

  testWidgets('a game card opens the page for that game', (tester) async {
    await pumpApp(tester, build: _CpuBoundBuild.new);
    await openTab(tester, 'Analiz');
    await tapText(tester, 'Oyun');
    await tapText(tester, _open);
    expect(find.text('Tüm oyunlar (ortalama)'), findsNothing);
    expect(find.text('Parça parça FPS'), findsOneWidget);
  });
}
