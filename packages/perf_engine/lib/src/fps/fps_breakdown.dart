import 'dart:math' as math;

import '../models/parts.dart';
import 'fps_estimator.dart';
import 'game_profile.dart';

/// Why memory changes the CPU limit (for plain-language notes).
enum RamNote {
  /// Faster than the baseline for its type: a small gain.
  fast,

  /// Slower than the baseline for its type.
  slow,

  /// DDR4 instead of DDR5.
  ddr4,

  /// DDR3: old and slow.
  ddr3,

  /// One module: single channel, half the bandwidth.
  singleModule,

  /// Under 16 GB: games run out of room.
  lowCapacity,
}

/// Each part's own share of the frame rate in one game (or the average of
/// many): how many FPS the processor alone could prepare, what the memory
/// adds or takes, what the graphics card could draw, what missing video
/// memory costs, the game's own limit, and the result.
class FpsBreakdown {
  const FpsBreakdown({
    required this.game,
    required this.resolution,
    required this.preset,
    required this.cpuFps,
    required this.ramFactor,
    required this.gpuFps,
    required this.vramFactor,
    required this.vramNeedGb,
    required this.vramGb,
    required this.engineCapFps,
    required this.resultFps,
    required this.ramNotes,
    this.gameCount = 1,
  });

  /// Null for the average over several games.
  final GameProfile? game;
  final Resolution resolution;
  final GraphicsPreset preset;

  /// Processor alone, with ideal memory.
  final double cpuFps;

  /// Memory's effect on the processor limit (1 = none).
  final double ramFactor;

  /// Graphics card alone, with enough video memory.
  final double gpuFps;

  /// Missing video memory's effect (1 = enough).
  final double vramFactor;
  final double vramNeedGb;
  final double vramGb;

  /// The game's own frame cap, if any.
  final double? engineCapFps;

  /// The frame rate you get.
  final double resultFps;
  final List<RamNote> ramNotes;
  final int gameCount;

  /// Processor limit with this memory.
  double get cpuWithRamFps => cpuFps * ramFactor;

  /// FPS gained (+) or lost (−) because of the memory.
  double get ramDeltaFps => cpuWithRamFps - cpuFps;

  /// Graphics limit with this video memory.
  double get gpuWithVramFps => gpuFps * vramFactor;

  /// FPS lost because video memory is short (≤ 0).
  double get vramDeltaFps => gpuWithVramFps - gpuFps;

  /// 0..100: how much the stronger side waits for the weaker one.
  double get bottleneckPercent {
    final lo = math.min(cpuWithRamFps, gpuWithVramFps);
    final hi = math.max(cpuWithRamFps, gpuWithVramFps);
    return hi <= 0 ? 0 : (1 - lo / hi) * 100;
  }

  Limiter get limiter => bottleneckPercent < kBalancedThresholdPercent
      ? Limiter.balanced
      : (cpuWithRamFps < gpuWithVramFps ? Limiter.cpu : Limiter.gpu);

  /// The game's lock is what stops the frame rate.
  bool get engineCapped =>
      engineCapFps != null &&
      FpsEstimator.blend(cpuWithRamFps, gpuWithVramFps) >= engineCapFps!;

  /// Frame rate if the processor were no limit (a much faster CPU).
  double get fpsWithoutCpuLimit => _capped(gpuWithVramFps);

  /// Frame rate if the graphics card were no limit.
  double get fpsWithoutGpuLimit => _capped(cpuWithRamFps);

  double _capped(double v) =>
      engineCapFps == null ? v : math.min(v, engineCapFps!);

  /// Average over several games (geometric mean, so one very light game
  /// does not hide a struggling system).
  static FpsBreakdown average(List<FpsBreakdown> all) {
    if (all.isEmpty) throw ArgumentError('no games');
    double geo(double Function(FpsBreakdown) f) => math.exp(
          all.fold<double>(0, (s, b) => s + math.log(f(b))) / all.length,
        );
    final first = all.first;
    return FpsBreakdown(
      game: null,
      resolution: first.resolution,
      preset: first.preset,
      cpuFps: geo((b) => b.cpuFps),
      ramFactor: geo((b) => b.ramFactor),
      gpuFps: geo((b) => b.gpuFps),
      vramFactor: geo((b) => b.vramFactor),
      vramNeedGb: all.map((b) => b.vramNeedGb).reduce(math.max),
      vramGb: first.vramGb,
      engineCapFps: null,
      resultFps: geo((b) => b.resultFps),
      ramNotes: first.ramNotes,
      gameCount: all.length,
    );
  }
}

/// Memory notes behind [FpsEstimator.ramFactor].
List<RamNote> ramNotes(Ram? ram) {
  if (ram == null) return const [];
  final baseline = switch (ram.type) {
    MemoryType.ddr5 => 6000,
    MemoryType.ddr4 => 3600,
    MemoryType.ddr3 => 1600,
  };
  return [
    if (ram.speedMts > baseline) RamNote.fast,
    if (ram.speedMts < baseline) RamNote.slow,
    if (ram.type == MemoryType.ddr4) RamNote.ddr4,
    if (ram.type == MemoryType.ddr3) RamNote.ddr3,
    if (ram.moduleCount == 1) RamNote.singleModule,
    if (ram.totalGb < 16) RamNote.lowCapacity,
  ];
}

extension FpsBreakdownEstimator on FpsEstimator {
  /// Each part's share of the frame rate in [game]; its [FpsBreakdown]
  /// numbers combine to exactly what [FpsEstimator.estimate] returns.
  FpsBreakdown breakdown({
    required GameProfile game,
    required Cpu cpu,
    required Gpu gpu,
    Ram? ram,
    Resolution resolution = Resolution.p1080,
    GraphicsPreset preset = GraphicsPreset.high,
  }) {
    final need = vramNeedGb(game, resolution, preset);
    final result = estimate(
      game: game,
      cpu: cpu,
      gpu: gpu,
      ram: ram,
      resolution: resolution,
      preset: preset,
    );
    return FpsBreakdown(
      game: game,
      resolution: resolution,
      preset: preset,
      cpuFps: cpuCapFps(game, cpu, null, preset),
      ramFactor: FpsEstimator.ramFactor(cpu, ram),
      gpuFps: gpuRawFps(game, gpu, resolution, preset),
      vramFactor: FpsEstimator.vramFactor(gpu, need),
      vramNeedGb: need,
      vramGb: gpu.vramGb.toDouble(),
      engineCapFps: game.engineFpsCap,
      resultFps: result.avgFps,
      ramNotes: ramNotes(ram),
    );
  }
}
