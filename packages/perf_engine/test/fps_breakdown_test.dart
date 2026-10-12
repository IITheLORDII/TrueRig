import 'dart:math' as math;

import 'package:perf_engine/perf_engine.dart';
import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  const fps = FpsEstimator();
  final ddr5 = part<Ram>('corsair-ddr5-6000-32');

  FpsBreakdown run(
    String cpu,
    String gpu,
    String g, {
    Ram? ram,
    Resolution res = Resolution.p1080,
    GraphicsPreset preset = GraphicsPreset.high,
  }) =>
      fps.breakdown(
        game: game(g),
        cpu: part<Cpu>(cpu),
        gpu: part<Gpu>(gpu),
        ram: ram ?? ddr5,
        resolution: res,
        preset: preset,
      );

  test('the parts add up to the same frame rate as the estimate', () {
    for (final (cpu, gpu, g, res) in [
      ('r7-7800x3d', 'rtx-4090', 'cyberpunk', Resolution.p2160),
      ('r5-5600', 'rtx-4090', 'cyberpunk', Resolution.p1080),
      ('r5-5600', 'rtx-4060', 'elden-ring', Resolution.p1440),
    ]) {
      final b = run(cpu, gpu, g, res: res);
      final e = fps.estimate(
        game: game(g),
        cpu: part<Cpu>(cpu),
        gpu: part<Gpu>(gpu),
        ram: ddr5,
        resolution: res,
        preset: GraphicsPreset.high,
      );
      var combined = FpsEstimator.blend(b.cpuWithRamFps, b.gpuWithVramFps);
      if (b.engineCapFps != null && combined > b.engineCapFps!) {
        combined = b.engineCapFps!;
      }
      expect(b.resultFps, closeTo(e.avgFps, 1e-9));
      expect(combined, closeTo(e.avgFps, 1e-9));
      expect(b.cpuWithRamFps, closeTo(e.cpuCapFps, 1e-9));
      expect(b.gpuWithVramFps, closeTo(e.gpuCapFps, 1e-9));
      expect(b.limiter, e.limiter);
    }
  });

  test('one memory stick shows up as lost FPS with its reason', () {
    final single = run(
      'r5-5600',
      'rtx-4090',
      'cyberpunk',
      ram: part<Ram>('kingston-ddr5-5600-16x1'),
    );
    expect(single.ramDeltaFps, lessThan(0));
    expect(single.ramNotes, contains(RamNote.singleModule));
    expect(single.ramNotes, contains(RamNote.slow));
    final dual = run('r5-5600', 'rtx-4090', 'cyberpunk');
    expect(dual.ramDeltaFps, closeTo(0, 1e-9));
    expect(dual.ramNotes, isEmpty);
  });

  test('too little video memory costs FPS at 4K ultra', () {
    final b = run(
      'r7-7800x3d',
      'rtx-4060',
      'cyberpunk',
      res: Resolution.p2160,
      preset: GraphicsPreset.ultra,
    );
    expect(b.vramNeedGb, greaterThan(b.vramGb));
    expect(b.vramDeltaFps, lessThan(0));
  });

  test('removing the limiting part shows what an upgrade would bring', () {
    final b = run('r5-5600', 'rtx-4090', 'cyberpunk');
    expect(b.limiter, Limiter.cpu);
    expect(b.fpsWithoutCpuLimit, greaterThan(b.resultFps));
    expect(b.fpsWithoutGpuLimit, closeTo(b.cpuWithRamFps, 1e-9));
  });

  test('a locked game reports its cap', () {
    final b = run('r7-7800x3d', 'rtx-4090', 'elden-ring');
    expect(b.engineCapFps, isNotNull);
    expect(b.engineCapped, isTrue);
    expect(b.resultFps, lessThanOrEqualTo(b.engineCapFps!));
  });

  test('the average over games uses the geometric mean', () {
    final list = [
      run('r5-5600', 'rtx-4060', 'cyberpunk'),
      run('r5-5600', 'rtx-4060', 'elden-ring'),
    ];
    final avg = FpsBreakdown.average(list);
    expect(avg.game, isNull);
    expect(avg.gameCount, 2);
    // Geometric mean of two values is the square root of their product.
    expect(
      avg.cpuFps,
      closeTo(math.sqrt(list[0].cpuFps * list[1].cpuFps), 1e-9),
    );
    final lo =
        [list[0].resultFps, list[1].resultFps].reduce((a, b) => a < b ? a : b);
    final hi =
        [list[0].resultFps, list[1].resultFps].reduce((a, b) => a > b ? a : b);
    expect(avg.resultFps, inInclusiveRange(lo, hi));
  });
}
