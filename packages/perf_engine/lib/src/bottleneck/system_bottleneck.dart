import 'dart:math' as math;

import 'package:perf_engine/src/data/workload_catalog.dart';
import 'package:perf_engine/src/fps/fps_estimator.dart';
import 'package:perf_engine/src/fps/game_profile.dart';
import 'package:perf_engine/src/models/parts.dart';

/// Game-independent CPU <-> GPU balance of a system at one resolution.
class SystemBottleneck {
  const SystemBottleneck({
    required this.resolution,
    required this.bottleneckPercent,
    required this.limiter,
    required this.cpuBoundShare,
    required this.perGame,
  });

  final Resolution resolution;

  /// 0..100 from the geometric mean of CPU-cap / GPU-cap over the library.
  final double bottleneckPercent;
  final Limiter limiter;

  /// Share (0..1) of games where the CPU is the limiting part.
  final double cpuBoundShare;
  final List<FpsEstimate> perGame;
}

/// Library used for the general analysis: released, non engine-capped games
/// so one 60 FPS lock or a projection does not skew the result.
List<GameProfile> get generalGameSet => kGames
    .where((g) => !g.isProjection && g.engineFpsCap == null)
    .toList(growable: false);

class SystemBottleneckAnalyzer {
  const SystemBottleneckAnalyzer({this.fps = const FpsEstimator()});

  final FpsEstimator fps;

  /// [preset] defaults to High: the setting most people play at.
  SystemBottleneck analyze({
    required Cpu cpu,
    required Gpu gpu,
    Ram? ram,
    required Resolution resolution,
    GraphicsPreset preset = GraphicsPreset.high,
    List<GameProfile>? games,
  }) {
    final library = games ?? generalGameSet;
    final estimates = [
      for (final g in library)
        fps.estimate(
          game: g,
          cpu: cpu,
          gpu: gpu,
          ram: ram,
          resolution: resolution,
          preset: preset,
        ),
    ];
    // Geometric mean of cap ratios: symmetric for CPU- and GPU-bound games.
    final logSum = estimates.fold<double>(
      0,
      (s, e) => s + math.log(e.cpuCapFps / e.gpuCapFps),
    );
    final ratio = math.exp(logSum / estimates.length);
    final percent = (1 - math.min(ratio, 1 / ratio)).toDouble() * 100;
    final limiter = percent < kBalancedThresholdPercent
        ? Limiter.balanced
        : (ratio < 1 ? Limiter.cpu : Limiter.gpu);
    final cpuBound = estimates.where((e) => e.limiter == Limiter.cpu).length;
    return SystemBottleneck(
      resolution: resolution,
      bottleneckPercent: percent,
      limiter: limiter,
      cpuBoundShare: cpuBound / estimates.length,
      perGame: List.unmodifiable(estimates),
    );
  }

  /// One result per resolution (1080p, 1440p, 4K).
  List<SystemBottleneck> byResolution({
    required Cpu cpu,
    required Gpu gpu,
    Ram? ram,
    GraphicsPreset preset = GraphicsPreset.high,
  }) =>
      [
        for (final r in Resolution.values)
          analyze(cpu: cpu, gpu: gpu, ram: ram, resolution: r, preset: preset),
      ];
}
