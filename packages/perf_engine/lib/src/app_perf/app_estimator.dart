import 'dart:math' as math;

import 'package:perf_engine/src/models/pc_build.dart';

/// Workload profile for professional software. Weights must sum to 1.
class AppProfile {
  const AppProfile({
    required this.id,
    required this.name,
    required this.category,
    required this.singleThreadWeight,
    required this.multiThreadWeight,
    required this.gpuWeight,
    required this.ramWeight,
    required this.recommendedRamGb,
    required this.minVramGb,
    required this.tip,
  });

  final String id;
  final String name;
  final String category;
  final double singleThreadWeight;
  final double multiThreadWeight;
  final double gpuWeight;
  final double ramWeight;
  final int recommendedRamGb;
  final int minVramGb;

  /// Short Turkish advice shown with the result.
  final String tip;
}

enum AppRating { smooth, adequate, struggles }

extension AppRatingLabel on AppRating {
  String get label => switch (this) {
        AppRating.smooth => 'Akıcı',
        AppRating.adequate => 'Yeterli',
        AppRating.struggles => 'Zorlanır',
      };
}

class AppEstimate {
  const AppEstimate({
    required this.app,
    required this.score,
    required this.rating,
    required this.weakestComponent,
    required this.componentScores,
  });

  final AppProfile app;

  /// 0..100
  final double score;
  final AppRating rating;
  final String weakestComponent;
  final Map<String, double> componentScores;
}

/// Component score targets that count as "fully sufficient" (=100).
const double _stTarget = 95;
const double _mtTarget = 70;
const double _gpuTarget = 60;

class AppEstimator {
  const AppEstimator();

  AppEstimate estimate(AppProfile app, PcBuild build) {
    final cpu = build.cpu;
    final gpu = build.gpu;
    final ramGb = build.ram?.totalGb ?? 16;

    final st = sufficiency(cpu?.stScore ?? 0, _stTarget);
    final mt = sufficiency(cpu?.mtScore ?? 0, _mtTarget);
    var g = sufficiency(gpu?.rasterScore ?? 5, _gpuTarget);
    if (gpu != null && gpu.vramGb < app.minVramGb) {
      g *= gpu.vramGb / app.minVramGb;
    }
    final r = sufficiency(ramGb.toDouble(), app.recommendedRamGb.toDouble());

    final parts = <String, double>{
      'İşlemci (tek çekirdek)': st * 100,
      'İşlemci (çok çekirdek)': mt * 100,
      'Ekran kartı': g * 100,
      'RAM': r * 100,
    };
    final weights = <String, double>{
      'İşlemci (tek çekirdek)': app.singleThreadWeight,
      'İşlemci (çok çekirdek)': app.multiThreadWeight,
      'Ekran kartı': app.gpuWeight,
      'RAM': app.ramWeight,
    };

    final score = parts.entries
        .map((e) => e.value * weights[e.key]!)
        .fold<double>(0, (a, b) => a + b);
    final weakest = parts.entries
        .where((e) => weights[e.key]! >= 0.1)
        .reduce((a, b) => a.value <= b.value ? a : b)
        .key;

    return AppEstimate(
      app: app,
      score: score,
      rating: score >= 80
          ? AppRating.smooth
          : (score >= 55 ? AppRating.adequate : AppRating.struggles),
      weakestComponent: weakest,
      componentScores: Map.unmodifiable(parts),
    );
  }
}

/// 0..1 sufficiency of [value] against [target]. Below target the curve is
/// concave (a half-strength part still gets ~2/3 credit); at or above target
/// it saturates at 1.
double sufficiency(double value, double target) {
  final x = math.max(0.0, value / target);
  if (x >= 1) return 1;
  return 0.6 * math.sqrt(x) + 0.4 * x;
}
