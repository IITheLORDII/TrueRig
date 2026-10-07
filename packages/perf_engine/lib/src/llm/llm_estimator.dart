import 'dart:math' as math;

import 'package:perf_engine/src/models/parts.dart';

/// GGUF-style quantisation levels with effective bits per weight.
enum Quantization {
  q4km(4.85, 'Q4_K_M'),
  q5km(5.7, 'Q5_K_M'),
  q8(8.5, 'Q8_0'),
  fp16(16, 'FP16');

  const Quantization(this.bitsPerWeight, this.label);
  final double bitsPerWeight;
  final String label;
}

class LlmModel {
  const LlmModel({
    required this.id,
    required this.name,
    required this.family,
    required this.totalParamsB,
    double? activeParamsB,
  }) : activeParamsB = activeParamsB ?? totalParamsB;

  final String id;
  final String name;
  final String family;
  final double totalParamsB;

  /// For MoE models only the active experts are read per token.
  final double activeParamsB;

  bool get isMoe => activeParamsB < totalParamsB;
}

enum LlmPlacement { fullGpu, partialOffload, cpuOnly, doesNotFit }

class LlmEstimate {
  const LlmEstimate({
    required this.model,
    required this.quant,
    required this.contextTokens,
    required this.requiredGb,
    required this.placement,
    required this.gpuFraction,
    required this.tokensPerSecond,
  });

  final LlmModel model;
  final Quantization quant;
  final int contextTokens;
  final double requiredGb;
  final LlmPlacement placement;

  /// 0..1 share of weights resident in VRAM.
  final double gpuFraction;
  final double tokensPerSecond;

  /// Based on generation speed only: ~20 t/s feels like live chat,
  /// ~8 t/s is faster than reading speed.
  String get verdict => switch (placement) {
        LlmPlacement.doesNotFit => 'Sığmaz',
        _ when tokensPerSecond >= 20 => 'Akıcı',
        _ when tokensPerSecond >= 8 => 'Kullanılabilir',
        _ => 'Yavaş',
      };
}

/// Runtime and driver overhead reserved in VRAM.
const double _vramReserveGb = 0.8;

/// RAM kept free for the OS.
const double _osReserveGb = 6;

/// Fraction of theoretical bandwidth achieved during decoding.
const double _gpuEfficiency = 0.65;
const double _cpuEfficiency = 0.55;

/// KV-cache GB per billion params per 4k tokens (GQA-era models).
const double _kvGbPerBParam4k = 0.04;

class LlmEstimator {
  const LlmEstimator();

  static double weightsGb(LlmModel m, Quantization q) =>
      m.totalParamsB * q.bitsPerWeight / 8;

  static double kvCacheGb(LlmModel m, int ctx) =>
      m.activeParamsB.clamp(1, 70) * _kvGbPerBParam4k * (ctx / 4096);

  /// Dual-channel DDR5-6000 => 96 GB/s.
  static double systemRamBandwidthGbs(Cpu? cpu, Ram? ram) {
    if (ram == null) return 50;
    final channels = math.min(ram.moduleCount, cpu?.memChannels ?? 2);
    return channels * ram.speedMts * 8 / 1000;
  }

  LlmEstimate estimate({
    required LlmModel model,
    required Quantization quant,
    Cpu? cpu,
    Gpu? gpu,
    Ram? ram,
    int contextTokens = 8192,
  }) {
    final weights = weightsGb(model, quant);
    final required = weights + kvCacheGb(model, contextTokens);
    final vram = math.max(0.0, (gpu?.vramGb ?? 0) - _vramReserveGb);
    final ramFree = math.max(0.0, (ram?.totalGb ?? 16) - _osReserveGb);

    if (required > vram + ramFree) {
      return LlmEstimate(
        model: model,
        quant: quant,
        contextTokens: contextTokens,
        requiredGb: required,
        placement: LlmPlacement.doesNotFit,
        gpuFraction: 0,
        tokensPerSecond: 0,
      );
    }

    final gpuFraction = required <= vram ? 1.0 : vram / required;
    final placement = switch (gpuFraction) {
      1.0 => LlmPlacement.fullGpu,
      0.0 => LlmPlacement.cpuOnly,
      _ => LlmPlacement.partialOffload,
    };

    // Bytes read per generated token scale with active params only.
    final perTokenGb = model.activeParamsB * quant.bitsPerWeight / 8;
    final gpuBw = (gpu?.memBandwidthGbs ?? 1) * _gpuEfficiency;
    final cpuBw = systemRamBandwidthGbs(cpu, ram) * _cpuEfficiency;
    final seconds = gpuFraction * perTokenGb / gpuBw +
        (1 - gpuFraction) * perTokenGb / cpuBw;

    return LlmEstimate(
      model: model,
      quant: quant,
      contextTokens: contextTokens,
      requiredGb: required,
      placement: placement,
      gpuFraction: gpuFraction,
      tokensPerSecond: 1 / seconds,
    );
  }

  /// Largest-quality quantisation that fully fits in VRAM, if any.
  Quantization? bestFullGpuQuant(LlmModel model, Gpu gpu, {int ctx = 8192}) {
    final vram = gpu.vramGb - _vramReserveGb;
    for (final q in Quantization.values.reversed) {
      if (weightsGb(model, q) + kvCacheGb(model, ctx) <= vram) return q;
    }
    return null;
  }
}
