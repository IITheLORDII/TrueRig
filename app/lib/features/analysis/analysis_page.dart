import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:perf_engine/perf_engine.dart';

import 'package:darbogaz/core/providers.dart';
import 'package:darbogaz/core/theme/app_theme.dart';
import 'package:darbogaz/core/theme/tokens.dart';
import 'package:darbogaz/core/widgets/app_controls.dart';
import 'package:darbogaz/core/widgets/bottleneck_gauge.dart';
import 'package:darbogaz/core/widgets/common.dart';
import 'package:darbogaz/features/analysis/compatibility_card.dart';
import 'package:darbogaz/features/analysis/upgrade_card.dart';

String limiterCaption(Limiter l) => switch (l) {
  Limiter.cpu => 'İşlemci sınırlıyor',
  Limiter.gpu => 'Ekran kartı sınırlıyor',
  Limiter.balanced => 'Dengeli sistem',
};

/// PC "Özet": the general, game-independent bottleneck of the system.
class PcSummaryView extends ConsumerWidget {
  const PcSummaryView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final general = ref.watch(generalBottleneckProvider);
    final report = ref.watch(compatibilityProvider);
    final settings = ref.watch(analysisSettingsProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        Space.page,
        Space.xs,
        Space.page,
        Space.xl,
      ),
      children: [
        if (general == null)
          EmptyHint(
            icon: Icons.speed_rounded,
            message: 'Darboğaz analizi için işlemci ve ekran kartı seç.',
            action: FilledButton(
              onPressed: () => context.go('/devices'),
              child: const Text('Bilgisayarımı kur'),
            ),
          )
        else ...[
          AppSegmented<Resolution>(
            values: Resolution.values,
            selected: settings.resolution,
            labelOf: (r) => r.label,
            onChanged: (r) => ref
                .read(analysisSettingsProvider.notifier)
                .update((s) => s.copyWith(resolution: r)),
          ),
          const SizedBox(height: Space.m),
          _GeneralCard(general: general),
          const SizedBox(height: Space.s),
          const _ResolutionCard(),
          const SizedBox(height: Space.s),
          const UpgradeCard(),
        ],
        const SizedBox(height: Space.s),
        CompatibilityCard(report: report),
      ],
    );
  }
}

class _GeneralCard extends StatelessWidget {
  const _GeneralCard({required this.general});

  final SystemBottleneck general;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);
    final g = general;
    double geoMean(double Function(FpsEstimate) f) => math.exp(
      g.perGame.fold<double>(0, (s, e) => s + math.log(f(e))) /
          g.perGame.length,
    );
    final cpuCap = geoMean((e) => e.cpuCapFps);
    final gpuCap = geoMean((e) => e.gpuCapFps);
    final maxCap = math.max(cpuCap, gpuCap);
    final cpuGames = (g.cpuBoundShare * g.perGame.length).round();

    return SectionCard(
      hero: true,
      title: 'Genel darboğaz',
      icon: Icons.speed_rounded,
      trailing: VerdictChip(
        '${g.resolution.label} · Yüksek',
        tone: Tone.neutral,
      ),
      child: Column(
        children: [
          BottleneckGauge(
            percent: g.bottleneckPercent,
            caption: limiterCaption(g.limiter),
          ),
          Text(
            '${g.perGame.length} oyunun $cpuGames tanesinde işlemci, '
            '${g.perGame.length - cpuGames} tanesinde ekran kartı sınırlıyor.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(color: palette.muted),
          ),
          const SizedBox(height: Space.m),
          MetricBar(
            label: 'İşlemcinin besleyebildiği (ort.)',
            value: cpuCap,
            max: maxCap,
            valueText: '${cpuCap.round()} FPS',
            color: g.limiter == Limiter.cpu ? palette.bad : palette.good,
          ),
          MetricBar(
            label: 'Ekran kartının çizebildiği (ort.)',
            value: gpuCap,
            max: maxCap,
            valueText: '${gpuCap.round()} FPS',
            color: g.limiter == Limiter.gpu ? palette.bad : palette.good,
          ),
        ],
      ),
    );
  }
}

/// How the bottleneck moves with resolution (the classic "CPU at 1080p,
/// GPU at 4K" picture).
class _ResolutionCard extends ConsumerWidget {
  const _ResolutionCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = ref.watch(bottleneckByResolutionProvider);
    if (rows == null) return const SizedBox.shrink();
    final palette = context.palette;
    return SectionCard(
      title: 'Çözünürlüğe göre',
      icon: Icons.aspect_ratio_rounded,
      child: Column(
        children: [
          for (final r in rows)
            MetricBar(
              label: r.resolution.label,
              subtitle: limiterCaption(r.limiter),
              value: r.bottleneckPercent,
              max: 50,
              valueText: '%${r.bottleneckPercent.round()}',
              color: palette.forBottleneck(r.bottleneckPercent),
            ),
        ],
      ),
    );
  }
}

/// Bottleneck for one game (lives in the "Oyun" section).
class GameBottleneckCard extends StatelessWidget {
  const GameBottleneckCard({super.key, required this.estimate});

  final FpsEstimate estimate;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);
    final e = estimate;
    final maxCap = math.max(e.cpuCapFps, e.gpuCapFps);

    return SectionCard(
      hero: true,
      title: e.game.name,
      icon: Icons.sports_esports_rounded,
      trailing: e.game.isProjection
          ? const VerdictChip('Projeksiyon', tone: Tone.warn)
          : null,
      child: Column(
        children: [
          BottleneckGauge(
            percent: e.bottleneckPercent,
            caption: limiterCaption(e.limiter),
            size: 180,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '${e.minFps.round()}–${e.maxFps.round()}',
                style: numberStyle(context, size: 30),
              ),
              const SizedBox(width: Space.xs),
              Text('FPS', style: theme.textTheme.titleSmall),
            ],
          ),
          Text(
            '1% low ≈ ${e.onePercentLowFps.round()} FPS · '
            '${e.resolution.label} ${e.preset.label}',
            style: theme.textTheme.labelMedium?.copyWith(color: palette.muted),
          ),
          const SizedBox(height: Space.s),
          MetricBar(
            label: 'İşlemcinin besleyebildiği',
            value: e.cpuCapFps,
            max: maxCap,
            valueText: '${e.cpuCapFps.round()} FPS',
            color: e.limiter == Limiter.cpu ? palette.bad : palette.good,
          ),
          MetricBar(
            label: 'Ekran kartının çizebildiği',
            value: e.gpuCapFps,
            max: maxCap,
            valueText: '${e.gpuCapFps.round()} FPS',
            color: e.limiter == Limiter.gpu ? palette.bad : palette.good,
          ),
          if (e.vramShortfallGb > 0)
            Padding(
              padding: const EdgeInsets.only(top: Space.s),
              child: VerdictChip(
                'VRAM ${e.vramShortfallGb.toStringAsFixed(1)} GB yetersiz',
                tone: Tone.warn,
              ),
            ),
        ],
      ),
    );
  }
}
