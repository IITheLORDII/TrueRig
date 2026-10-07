import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:perf_engine/perf_engine.dart';

import 'package:darbogaz/core/providers.dart';
import 'package:darbogaz/core/theme/app_theme.dart';
import 'package:darbogaz/core/widgets/common.dart';
import 'package:darbogaz/features/analysis/settings_bar.dart';

/// Bars are drawn against this FPS so high-refresh results stay comparable.
const double _barFullScaleFps = 240;

final _allGamesProvider = Provider<List<FpsEstimate>?>((ref) {
  final build = ref.watch(buildProvider);
  final s = ref.watch(analysisSettingsProvider);
  final cpu = build.cpu;
  final gpu = build.gpu;
  if (cpu == null || gpu == null) return null;
  const est = FpsEstimator();
  return [
    for (final g in kGames)
      est.estimate(
        game: g,
        cpu: cpu,
        gpu: gpu,
        ram: build.ram,
        resolution: s.resolution,
        preset: s.preset,
      ),
  ];
});

class GamesTab extends ConsumerWidget {
  const GamesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final results = ref.watch(_allGamesProvider);
    if (results == null) {
      return const EmptyHint(
        icon: Icons.videogame_asset_off_rounded,
        message: 'Oyun FPS tahmini için bir ekran kartı da seç.',
      );
    }
    final palette = context.palette;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        const AnalysisSettingsBar(showGame: false),
        const SizedBox(height: 16),
        SectionCard(
          title: 'Tahmini ortalama FPS',
          icon: Icons.sports_esports_rounded,
          child: Column(
            children: [
              for (final e in results)
                MetricBar(
                  label: e.game.isProjection ? '${e.game.name} *' : e.game.name,
                  value: e.avgFps,
                  max: _barFullScaleFps,
                  valueText: '${e.minFps.round()}–${e.maxFps.round()}',
                  color: _fpsColor(palette, e.avgFps),
                  subtitle: _subtitle(e),
                ),
              const SizedBox(height: 8),
              Text(
                '* GTA VI henüz PC\'de yok; değerler konsol verisi ve motor '
                'gereksinimlerinden türetilmiş projeksiyondur.\n'
                '$kEstimateDisclaimer',
                style: Theme.of(context).textTheme.labelSmall
                    ?.copyWith(color: palette.muted),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static Color _fpsColor(AppPalette p, double fps) {
    if (fps >= 144) return p.good;
    if (fps >= 60) return const Color(0xFF00E5FF);
    if (fps >= 30) return p.warn;
    return p.bad;
  }

  static String _subtitle(FpsEstimate e) {
    final limiter = switch (e.limiter) {
      Limiter.cpu => 'CPU sınırlı',
      Limiter.gpu => 'GPU sınırlı',
      Limiter.balanced => 'Dengeli',
    };
    final cap = e.game.engineFpsCap;
    return [
      limiter,
      'darboğaz %${e.bottleneckPercent.round()}',
      if (cap != null) 'oyun ${cap.round()} FPS kilitli',
      if (e.vramShortfallGb > 0) 'VRAM yetersiz',
    ].join(' · ');
  }
}
