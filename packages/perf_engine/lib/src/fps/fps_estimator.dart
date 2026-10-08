import 'dart:math' as math;

import 'package:perf_engine/src/fps/game_profile.dart';
import 'package:perf_engine/src/models/parts.dart';

enum Limiter { cpu, gpu, balanced }

enum Confidence { high, medium, low }

class FpsEstimate {
  const FpsEstimate({
    required this.game,
    required this.resolution,
    required this.preset,
    required this.avgFps,
    required this.minFps,
    required this.maxFps,
    required this.onePercentLowFps,
    required this.cpuCapFps,
    required this.gpuCapFps,
    required this.bottleneckPercent,
    required this.limiter,
    required this.vramShortfallGb,
    required this.confidence,
  });

  final GameProfile game;
  final Resolution resolution;
  final GraphicsPreset preset;
  final double avgFps;

  /// Lower and upper bound of the expected average.
  final double minFps;
  final double maxFps;
  final double onePercentLowFps;
  final double cpuCapFps;
  final double gpuCapFps;

  /// 0..100: how much the stronger side is held back by the weaker side.
  final double bottleneckPercent;
  final Limiter limiter;
  final double vramShortfallGb;
  final Confidence confidence;
}

/// Bottleneck below this is reported as balanced.
const double kBalancedThresholdPercent = 5;

/// Exponent of the soft-min that blends CPU and GPU limits.
const double _softMinK = 4;

/// Base uncertainty band for the FPS range (+/-).
const double _baseBand = 0.10;

/// VRAM overflow penalty: fps *= (have/need)^exp, never below the floor.
const double _vramPenaltyExp = 0.5;
const double _minVramFactor = 0.5;

/// mtScore of the reference CPU (Ryzen 7 7800X3D).
const double _refCpuMtScore = 48;

class FpsEstimator {
  const FpsEstimator();

  static const Map<GraphicsPreset, double> _gpuPresetGain = {
    GraphicsPreset.low: 2.0,
    GraphicsPreset.medium: 1.55,
    GraphicsPreset.high: 1.22,
    GraphicsPreset.ultra: 1.0,
  };

  static const Map<GraphicsPreset, double> _cpuPresetGain = {
    GraphicsPreset.low: 1.15,
    GraphicsPreset.medium: 1.08,
    GraphicsPreset.high: 1.03,
    GraphicsPreset.ultra: 1.0,
  };

  static const Map<GraphicsPreset, double> _vramPresetScale = {
    GraphicsPreset.low: 0.6,
    GraphicsPreset.medium: 0.72,
    GraphicsPreset.high: 0.86,
    GraphicsPreset.ultra: 1.0,
  };

  FpsEstimate estimate({
    required GameProfile game,
    required Cpu cpu,
    required Gpu gpu,
    Ram? ram,
    Resolution resolution = Resolution.p1080,
    GraphicsPreset preset = GraphicsPreset.ultra,
  }) {
    final cpuCap = cpuCapFps(game, cpu, ram, preset);
    final vramNeed =
        (game.vramNeedGb[resolution] ?? 8) * _vramPresetScale[preset]!;
    final shortfall = math.max(0.0, vramNeed - gpu.vramGb);
    final gpuCap = _gpuCapFps(game, gpu, resolution, preset, vramNeed);

    var avg = math
        .pow(
          math.pow(cpuCap, -_softMinK) + math.pow(gpuCap, -_softMinK),
          -1 / _softMinK,
        )
        .toDouble();
    final cap = game.engineFpsCap;
    if (cap != null) avg = math.min(avg, cap);

    final low = math.min(cpuCap, gpuCap);
    final high = math.max(cpuCap, gpuCap);
    final bottleneck = (1 - low / high) * 100;
    final limiter = bottleneck < kBalancedThresholdPercent
        ? Limiter.balanced
        : (cpuCap < gpuCap ? Limiter.cpu : Limiter.gpu);

    final confidence = _confidence(game, shortfall);
    final band = _baseBand + (confidence == Confidence.low ? 0.08 : 0);
    // CPU-limited scenes have wider frame-time spread.
    final lowRatio = limiter == Limiter.cpu ? 0.68 : 0.78;

    return FpsEstimate(
      game: game,
      resolution: resolution,
      preset: preset,
      avgFps: avg,
      minFps: avg * (1 - band),
      maxFps: cap == null ? avg * (1 + band) : math.min(cap, avg * (1 + band)),
      onePercentLowFps: avg * lowRatio,
      cpuCapFps: cpuCap,
      gpuCapFps: gpuCap,
      bottleneckPercent: bottleneck,
      limiter: limiter,
      vramShortfallGb: shortfall,
      confidence: confidence,
    );
  }

  /// FPS ceiling imposed by CPU (and memory) independent of resolution.
  double cpuCapFps(GameProfile game, Cpu cpu, Ram? ram, GraphicsPreset p) {
    // Multi-thread index normalised so the reference 7800X3D maps to 100.
    final mtAsGaming = cpu.mtScore / _refCpuMtScore * 100;
    final w = game.threadSensitivity;
    final index = math.pow(cpu.gamingScore, 1 - w) * math.pow(mtAsGaming, w);
    var fps = game.cpuRefFps * (index / 100) * _cpuPresetGain[p]!;
    if (cpu.cores < game.minCores) {
      fps *= math.pow(cpu.cores / game.minCores, 1.2);
    }
    return fps * ramFactor(cpu, ram);
  }

  /// Memory impact on the CPU limit. 1.0 = dual-channel DDR5-6000 baseline.
  static double ramFactor(Cpu cpu, Ram? ram) {
    if (ram == null) return 1.0;
    final isX3d = cpu.model.contains('X3D');
    final baseline = switch (ram.type) {
      MemoryType.ddr5 => 6000,
      MemoryType.ddr4 => 3600,
      MemoryType.ddr3 => 1600,
    };
    final speedDelta = (ram.speedMts - baseline) / baseline;
    final sensitivity = isX3d ? 0.15 : 0.35;
    var f = 1 + speedDelta * sensitivity;
    if (ram.type == MemoryType.ddr4) f *= isX3d ? 0.98 : 0.95;
    if (ram.type == MemoryType.ddr3) f *= 0.9;
    if (ram.moduleCount == 1) f *= 0.85;
    if (ram.totalGb < 16) f *= 0.8;
    return f.clamp(0.6, 1.08).toDouble();
  }

  double _gpuCapFps(
    GameProfile game,
    Gpu gpu,
    Resolution res,
    GraphicsPreset preset,
    double vramNeed,
  ) {
    final ref = game.gpuRefFps[res] ?? game.gpuRefFps.values.first;
    var fps = ref * (gpu.rasterScore / 100) * _gpuPresetGain[preset]!;
    if (gpu.vramGb < vramNeed) {
      // Overflowing VRAM streams textures over PCIe: average FPS drops
      // moderately (stutter is the bigger effect, flagged separately).
      fps *= math.max(
        _minVramFactor,
        math.pow(gpu.vramGb / vramNeed, _vramPenaltyExp).toDouble(),
      );
    }
    return fps;
  }

  Confidence _confidence(GameProfile game, double shortfall) {
    if (game.isProjection) return Confidence.low;
    if (shortfall > 0) return Confidence.medium;
    return Confidence.high;
  }
}
