import 'package:perf_engine/perf_engine.dart';
import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  const fps = FpsEstimator();
  final ddr5 = part<Ram>('corsair-ddr5-6000-32');

  FpsEstimate run(String cpu, String gpu, String g,
          {Resolution res = Resolution.p1080,
          GraphicsPreset preset = GraphicsPreset.ultra,
          Ram? ram}) =>
      fps.estimate(
        game: game(g),
        cpu: part<Cpu>(cpu),
        gpu: part<Gpu>(gpu),
        ram: ram ?? ddr5,
        resolution: res,
        preset: preset,
      );

  group('golden builds', () {
    test('7800X3D + 4090 Cyberpunk 4K is GPU-bound near reference', () {
      final e =
          run('r7-7800x3d', 'rtx-4090', 'cyberpunk', res: Resolution.p2160);
      expect(e.limiter, Limiter.gpu);
      expect(e.avgFps, inInclusiveRange(65, 80));
    });

    test('Ryzen 5 5600 + RTX 4090 at 1080p is clearly CPU-bound', () {
      final e = run('r5-5600', 'rtx-4090', 'cyberpunk',
          ram: part<Ram>('gskill-ddr4-3600-32'));
      expect(e.limiter, Limiter.cpu);
      expect(e.bottleneckPercent, greaterThan(30));
    });

    test('CPU bottleneck shrinks as resolution rises', () {
      final p1080 = run('r5-5600', 'rtx-4090', 'rdr2',
          ram: part<Ram>('gskill-ddr4-3600-32'));
      final p2160 = run('r5-5600', 'rtx-4090', 'rdr2',
          res: Resolution.p2160, ram: part<Ram>('gskill-ddr4-3600-32'));
      expect(p2160.cpuCapFps, closeTo(p1080.cpuCapFps, 0.001));
      expect(p2160.limiter, isNot(Limiter.cpu));
    });

    test('i5-12400F + RX 6600 1080p Ultra RDR2 is in a playable range', () {
      final e = run('i5-12400f', 'rx-6600', 'rdr2',
          ram: part<Ram>('kingston-ddr4-3200-32'));
      expect(e.limiter, Limiter.gpu);
      expect(e.avgFps, inInclusiveRange(38, 58));
    });

    test('laptop i5-12450H + GTX 1650 Cyberpunk 1080p Ultra ~18-24 FPS', () {
      final e = run('i5-12450h', 'gtx-1650', 'cyberpunk',
          ram: part<Ram>('kingston-ddr4-3200-32'));
      expect(e.limiter, Limiter.gpu);
      expect(e.vramShortfallGb, greaterThan(0));
      expect(e.avgFps, inInclusiveRange(14, 26));
    });

    test('GTX 1650 CS2 1080p Low is comfortably playable', () {
      final e = run('i5-12450h', 'gtx-1650', 'cs2',
          preset: GraphicsPreset.low, ram: part<Ram>('kingston-ddr4-3200-32'));
      expect(e.avgFps, greaterThan(100));
    });

    test('7800X3D + 4070 Super CS2 1080p is above 300 FPS', () {
      final e = run('r7-7800x3d', 'rtx-4070s', 'cs2');
      expect(e.avgFps, greaterThan(300));
    });
  });

  test('engine cap limits Elden Ring to 60', () {
    final e = run('r7-9800x3d', 'rtx-5090', 'elden-ring');
    expect(e.avgFps, 60);
    expect(e.maxFps, 60);
  });

  test('lower preset raises FPS', () {
    final ultra = run('r7-7800x3d', 'rtx-4060', 'cyberpunk');
    final low =
        run('r7-7800x3d', 'rtx-4060', 'cyberpunk', preset: GraphicsPreset.low);
    expect(low.avgFps, greaterThan(ultra.avgFps * 1.5));
  });

  test('8GB card at 4K Ultra GTA VI has VRAM shortfall and low confidence', () {
    final e = run('r7-7800x3d', 'rtx-4060', 'gta6', res: Resolution.p2160);
    expect(e.vramShortfallGb, greaterThan(0));
    expect(e.confidence, Confidence.low);
  });

  test('VRAM shortfall alone gives medium confidence', () {
    final e = run('r7-7800x3d', 'rtx-4060', 'cyberpunk', res: Resolution.p2160);
    expect(e.vramShortfallGb, greaterThan(0));
    expect(e.confidence, Confidence.medium);
  });

  test('range brackets the average', () {
    final e = run('r5-7600', 'rx-7800xt', 'warzone', res: Resolution.p1440);
    expect(e.minFps, lessThan(e.avgFps));
    expect(e.maxFps, greaterThan(e.avgFps));
    expect(e.onePercentLowFps, lessThan(e.avgFps));
  });

  test('balanced limiter when CPU and GPU caps are close', () {
    final g = GameProfile(
      id: 't',
      name: 'Test',
      cpuRefFps: 100,
      gpuRefFps: {Resolution.p1080: 100},
      vramNeedGb: {Resolution.p1080: 4},
      threadSensitivity: 0,
    );
    final e = fps.estimate(
        game: g, cpu: part<Cpu>('r7-7800x3d'), gpu: part<Gpu>('rtx-4090'));
    expect(e.limiter, Limiter.balanced);
  });

  group('ramFactor', () {
    final cpu = part<Cpu>('r5-7600');
    test('no RAM is neutral',
        () => expect(FpsEstimator.ramFactor(cpu, null), 1.0));
    test('single channel penalises', () {
      expect(FpsEstimator.ramFactor(cpu, part<Ram>('kingston-ddr5-5600-16x1')),
          lessThan(0.9));
    });
    test('8GB total penalises heavily', () {
      const small = Ram(
          id: 's',
          brand: 'X',
          model: '8GB',
          type: MemoryType.ddr4,
          speedMts: 3200,
          moduleCount: 2,
          moduleSizeGb: 4,
          casLatency: 16);
      expect(
          FpsEstimator.ramFactor(part<Cpu>('r5-5600'), small), lessThan(0.8));
    });
  });

  test('CPU with fewer cores than game minimum is penalised', () {
    const quad = Cpu(
        id: 'q',
        brand: 'X',
        model: 'Quad',
        socket: 'AM5',
        cores: 4,
        threads: 8,
        boostGhz: 5,
        tdpW: 65,
        maxPowerW: 88,
        stScore: 80,
        mtScore: 25,
        gamingScore: 80,
        memoryTypes: [MemoryType.ddr5],
        pcieGen: 5,
        hasIgpu: true);
    final g = game('gta6');
    final quadCap = fps.cpuCapFps(g, quad, null, GraphicsPreset.ultra);
    final r5Cap =
        fps.cpuCapFps(g, part<Cpu>('r5-7600'), null, GraphicsPreset.ultra);
    expect(quadCap, lessThan(r5Cap * 0.6));
  });

  test('labels', () {
    expect(Resolution.p2160.label, '4K');
    expect(GraphicsPreset.medium.label, 'Orta');
  });
}
