import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:perf_engine/perf_engine.dart';

import 'package:darbogaz/core/providers.dart';
import 'package:darbogaz/core/theme/app_theme.dart';
import 'package:darbogaz/core/widgets/bottleneck_gauge.dart';
import 'package:darbogaz/core/widgets/common.dart';
import 'package:darbogaz/features/analysis/compatibility_card.dart';
import 'package:darbogaz/features/analysis/settings_bar.dart';
import 'package:darbogaz/features/analysis/upgrade_card.dart';

/// PC "Özet": bottleneck, upgrades and compatibility (no Scaffold; lives
/// inside the Performance tab).
class PcSummaryView extends ConsumerWidget {
  const PcSummaryView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estimate = ref.watch(fpsEstimateProvider);
    final report = ref.watch(compatibilityProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        if (estimate == null)
          EmptyHint(
            icon: Icons.speed_rounded,
            message: 'Darboğaz hesabı için en az işlemci ve ekran kartı seç.',
            action: FilledButton(
              onPressed: () => context.go('/home'),
              child: const Text('Sistemi Kur'),
            ),
          )
        else ...[
          const AnalysisSettingsBar(),
          const SizedBox(height: 12),
          _BottleneckCard(estimate: estimate),
          const SizedBox(height: 8),
          const UpgradeCard(),
        ],
        const SizedBox(height: 8),
        CompatibilityCard(report: report),
      ],
    );
  }
}

class _BottleneckCard extends StatelessWidget {
  const _BottleneckCard({required this.estimate});

  final FpsEstimate estimate;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);
    final e = estimate;
    final caption = switch (e.limiter) {
      Limiter.cpu => 'İşlemci sınırlıyor',
      Limiter.gpu => 'Ekran kartı sınırlıyor',
      Limiter.balanced => 'Dengeli sistem',
    };
    final maxCap = e.cpuCapFps > e.gpuCapFps ? e.cpuCapFps : e.gpuCapFps;

    return SectionCard(
      hero: true,
      title: e.game.name,
      icon: Icons.speed_rounded,
      trailing: e.game.isProjection
          ? StatusPill(text: 'Projeksiyon', color: palette.warn)
          : null,
      child: Column(
        children: [
          BottleneckGauge(percent: e.bottleneckPercent, caption: caption),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '${e.minFps.round()}–${e.maxFps.round()}',
                style: numberStyle(context, size: 34),
              ),
              const SizedBox(width: 6),
              Text('FPS', style: theme.textTheme.titleMedium),
            ],
          ),
          Text(
            '1% low ≈ ${e.onePercentLowFps.round()} FPS · '
            '${e.resolution.label} ${e.preset.label}',
            style: theme.textTheme.labelMedium?.copyWith(color: palette.muted),
          ),
          const SizedBox(height: 16),
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
              padding: const EdgeInsets.only(top: 8),
              child: StatusPill(
                text:
                    'VRAM ${e.vramShortfallGb.toStringAsFixed(1)} GB yetersiz',
                color: palette.warn,
              ),
            ),
          const SizedBox(height: 12),
          Text(
            kEstimateDisclaimer,
            style: theme.textTheme.labelSmall?.copyWith(color: palette.muted),
          ),
        ],
      ),
    );
  }
}
