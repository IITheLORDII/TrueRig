import 'dart:math' as math;

import 'package:perf_engine/src/app_perf/app_estimator.dart';
import 'package:perf_engine/src/fps/game_profile.dart';
import 'package:perf_engine/src/llm/llm_estimator.dart';
import 'package:perf_engine/src/mobile/mobile_models.dart';
import 'package:perf_engine/src/mobile/mobile_workloads.dart';

/// A chosen phone with the chip variant and RAM option resolved.
class PhoneSpec {
  const PhoneSpec(
      {required this.phone, required this.soc, required this.ramGb});

  final Phone phone;
  final Soc soc;
  final int ramGb;
}

enum PhoneTier { flagship, upper, mid, entry }

extension PhoneTierLabel on PhoneTier {
  String get label => switch (this) {
        PhoneTier.flagship => 'Amiral gemisi',
        PhoneTier.upper => 'Üst segment',
        PhoneTier.mid => 'Orta segment',
        PhoneTier.entry => 'Giriş seviyesi',
      };
}

class PhoneSummary {
  const PhoneSummary({
    required this.score,
    required this.tier,
    required this.components,
    required this.weakest,
    required this.sustainedPercent,
  });

  /// Weighted index; A18 Pro with 8 GB ~= 98. Above 100 is possible.
  final double score;
  final PhoneTier tier;

  /// 0..100 per component.
  final Map<String, double> components;
  final String weakest;
  final double sustainedPercent;
}

class MobileGameEstimate {
  const MobileGameEstimate({
    required this.game,
    required this.preset,
    required this.peakFps,
    required this.sustainedFps,
    required this.limitFps,
    required this.ramShort,
    required this.recommendedPreset,
  });

  final MobileGameProfile game;
  final GraphicsPreset preset;
  final double peakFps;

  /// After ~20 min of play (thermal throttling).
  final double sustainedFps;

  /// min(game cap, display refresh rate).
  final int limitFps;
  final bool ramShort;

  /// Highest preset that holds near the limit (or 60) when warm.
  final GraphicsPreset recommendedPreset;
}

/// Mobile settings change cost far more than on PC (resolution scale,
/// shadows, effects are all bundled into one preset).
const Map<GraphicsPreset, double> _presetGain = {
  GraphicsPreset.low: 3.0,
  GraphicsPreset.medium: 1.8,
  GraphicsPreset.high: 1.0,
  GraphicsPreset.ultra: 0.7,
};

/// Score thresholds: A17 Pro / SD 8 Gen 2 class and up are flagships.
const double _flagshipFrom = 75;
const double _upperFrom = 50;
const double _midFrom = 25;

const double _gpuScalingExp = 0.7;
const double _cpuScalingExp = 0.6;

/// Share of phone RAM a single app (e.g. an LLM runtime) can use.
const double _appRamShare = 0.45;
const double _mobileBwEfficiency = 0.6;

class PhoneEstimator {
  const PhoneEstimator();

  PhoneSummary summarize(PhoneSpec s) {
    final ramPct = math.min(100.0, s.ramGb / 12 * 100);
    final components = <String, double>{
      'Tek çekirdek': s.soc.cpuSt,
      'Çok çekirdek': s.soc.cpuMt,
      'Grafik (GPU)': s.soc.gpuScore,
      'RAM': ramPct,
    };
    final score = 0.3 * s.soc.cpuSt +
        0.25 * s.soc.cpuMt +
        0.3 * s.soc.gpuScore +
        0.15 * ramPct;
    final weakest =
        components.entries.reduce((a, b) => a.value <= b.value ? a : b).key;
    return PhoneSummary(
      score: score,
      tier: score >= _flagshipFrom
          ? PhoneTier.flagship
          : score >= _upperFrom
              ? PhoneTier.upper
              : score >= _midFrom
                  ? PhoneTier.mid
                  : PhoneTier.entry,
      components: Map.unmodifiable(components),
      weakest: weakest,
      sustainedPercent: s.soc.sustained * 100,
    );
  }

  MobileGameEstimate game(
    MobileGameProfile g,
    PhoneSpec s, {
    GraphicsPreset preset = GraphicsPreset.high,
  }) {
    final limit = math.min(g.fpsCap, s.phone.displayHz);
    final ramShort = s.ramGb < g.minRamGb;

    /// Uncapped frame rate the chip could render.
    double rawAt(GraphicsPreset p) {
      final gpu = g.gpuRefFps *
          math.pow(s.soc.gpuScore / 100, _gpuScalingExp) *
          _presetGain[p]!;
      // Mobile games are tuned for weak CPUs: scale sub-linearly.
      final cpu = g.cpuRefFps * math.pow(s.soc.cpuSt / 100, _cpuScalingExp);
      final fps = math.min(gpu, cpu);
      return ramShort ? fps * 0.85 : fps;
    }

    // Throttling lowers the raw rate; a chip with headroom still holds the
    // cap when warm. Light games rarely hit the thermal limit.
    final keep = g.heavy ? s.soc.sustained : 1 - (1 - s.soc.sustained) * 0.4;
    double peakAt(GraphicsPreset p) => math.min(limit.toDouble(), rawAt(p));
    double sustainedAt(GraphicsPreset p) =>
        math.min(limit.toDouble(), rawAt(p) * keep);

    final target = math.min(limit, 60) * 0.92;
    var recommended = GraphicsPreset.low;
    for (final p in GraphicsPreset.values) {
      if (sustainedAt(p) >= target) recommended = p;
    }

    return MobileGameEstimate(
      game: g,
      preset: preset,
      peakFps: peakAt(preset),
      sustainedFps: sustainedAt(preset),
      limitFps: limit,
      ramShort: ramShort,
      recommendedPreset: recommended,
    );
  }

  AppEstimate app(MobileAppProfile a, PhoneSpec s) {
    final parts = <String, double>{
      'İşlemci (tek çekirdek)': sufficiency(s.soc.cpuSt, 70) * 100,
      'İşlemci (çok çekirdek)': sufficiency(s.soc.cpuMt, 70) * 100,
      'Grafik (GPU)': sufficiency(s.soc.gpuScore, 60) * 100,
      'RAM':
          sufficiency(s.ramGb.toDouble(), a.recommendedRamGb.toDouble()) * 100,
    };
    final weights = {
      'İşlemci (tek çekirdek)': a.singleThreadWeight,
      'İşlemci (çok çekirdek)': a.multiThreadWeight,
      'Grafik (GPU)': a.gpuWeight,
      'RAM': a.ramWeight,
    };
    final score = parts.entries
        .map((e) => e.value * weights[e.key]!)
        .fold<double>(0, (x, y) => x + y);
    final weakest = parts.entries
        .where((e) => weights[e.key]! >= 0.1)
        .reduce((x, y) => x.value <= y.value ? x : y)
        .key;
    return AppEstimate(
      app: AppProfile(
        id: a.id,
        name: a.name,
        category: a.category,
        singleThreadWeight: a.singleThreadWeight,
        multiThreadWeight: a.multiThreadWeight,
        gpuWeight: a.gpuWeight,
        ramWeight: a.ramWeight,
        recommendedRamGb: a.recommendedRamGb,
        minVramGb: 0,
        tip: a.tip,
      ),
      score: score,
      rating: score >= 80
          ? AppRating.smooth
          : (score >= 55 ? AppRating.adequate : AppRating.struggles),
      weakestComponent: weakest,
      componentScores: Map.unmodifiable(parts),
    );
  }

  /// On-device LLM: the whole model must fit in the app's share of RAM.
  LlmEstimate llm(
    LlmModel model,
    Quantization quant,
    PhoneSpec s, {
    int contextTokens = 4096,
  }) {
    final required = LlmEstimator.weightsGb(model, quant) +
        LlmEstimator.kvCacheGb(model, contextTokens);
    final available = s.ramGb * _appRamShare;
    if (required > available) {
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
    final perTokenGb = model.activeParamsB * quant.bitsPerWeight / 8;
    return LlmEstimate(
      model: model,
      quant: quant,
      contextTokens: contextTokens,
      requiredGb: required,
      placement: LlmPlacement.fullGpu,
      gpuFraction: 1,
      tokensPerSecond: s.soc.memBandwidthGbs * _mobileBwEfficiency / perTokenGb,
    );
  }
}
