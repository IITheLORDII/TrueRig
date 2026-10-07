import 'package:perf_engine/perf_engine.dart';
import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  const analyzer = SystemBottleneckAnalyzer();

  test('general set excludes capped and projected games', () {
    final ids = generalGameSet.map((g) => g.id);
    expect(ids, isNot(contains('elden-ring')));
    expect(ids, isNot(contains('gtav')));
    expect(ids, isNot(contains('gta6')));
    expect(ids, contains('cyberpunk'));
  });

  test('weak CPU + top GPU: CPU bound at 1080p, less so at 4K', () {
    final rows = analyzer.byResolution(
      cpu: part<Cpu>('r5-5600'),
      gpu: part<Gpu>('rtx-4090'),
      ram: part<Ram>('gskill-ddr4-3600-32'),
    );
    expect(rows.first.limiter, Limiter.cpu);
    expect(rows.first.bottleneckPercent, greaterThan(25));
    expect(rows.first.cpuBoundShare, greaterThan(0.5));
    expect(
      rows.last.bottleneckPercent,
      lessThan(rows.first.bottleneckPercent),
    );
  });

  test('strong CPU + entry GPU is GPU bound everywhere', () {
    final rows = analyzer.byResolution(
      cpu: part<Cpu>('r7-9800x3d'),
      gpu: part<Gpu>('gtx-1650'),
    );
    expect(rows.every((r) => r.limiter == Limiter.gpu), isTrue);
  });

  test('result does not depend on a single game choice', () {
    final r = analyzer.analyze(
      cpu: part<Cpu>('r7-7800x3d'),
      gpu: part<Gpu>('rtx-4070s'),
      resolution: Resolution.p1440,
    );
    expect(r.perGame.length, generalGameSet.length);
  });

  group('adviseGeneral', () {
    const advisor = UpgradeAdvisor();

    test('CPU-bound system gets CPU upgrades ranked by value', () {
      final b = PcBuild(
        cpu: part<Cpu>('r5-5600'),
        gpu: part<Gpu>('rtx-4080s'),
        motherboard: part<Motherboard>('asus-b550-plus'),
        ram: part<Ram>('gskill-ddr4-3600-32'),
      );
      final a = advisor.adviseGeneral(build: b, catalog: catalog);
      expect(a.current.limiter, Limiter.cpu);
      expect(a.options, isNotEmpty);
      expect(a.options.every((o) => o.part is Cpu), isTrue);
      for (var i = 1; i < a.options.length; i++) {
        expect(
          a.options[i].gainPer100Usd,
          lessThanOrEqualTo(a.options[i - 1].gainPer100Usd),
        );
      }
      expect(a.freeTips.first, contains('1440p'));
    });

    test('GPU-bound system gets GPU upgrades', () {
      final b =
          PcBuild(cpu: part<Cpu>('r7-7800x3d'), gpu: part<Gpu>('rtx-3060-12'));
      final a = advisor.adviseGeneral(
        build: b,
        catalog: catalog,
        resolution: Resolution.p1440,
      );
      expect(a.current.limiter, Limiter.gpu);
      expect(a.options.every((o) => o.part is Gpu), isTrue);
      expect(a.options.first.gainPercent, greaterThan(kMinUsefulGainPercent));
    });
  });
}
