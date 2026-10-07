import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:perf_engine/perf_engine.dart';

import 'package:darbogaz/core/widgets/app_controls.dart';
import 'package:darbogaz/core/theme/app_theme.dart';
import 'package:darbogaz/core/widgets/common.dart';
import 'package:darbogaz/core/widgets/score_scale.dart';
import 'package:darbogaz/features/performance/apps_tab.dart';
import 'package:darbogaz/features/watch/watch_pages.dart';

const _est = PhoneEstimator();

/// Component bars are drawn against this so >100 flagship chips still fit.
const double _barFullScale = 140;

final _mobilePresetProvider = NotifierProvider<_MobilePreset, GraphicsPreset>(
  _MobilePreset.new,
);

class _MobilePreset extends Notifier<GraphicsPreset> {
  @override
  GraphicsPreset build() => GraphicsPreset.high;

  void set(GraphicsPreset p) => state = p;
}

class PhoneSummaryView extends ConsumerWidget {
  const PhoneSummaryView({super.key, required this.spec});

  final PhoneSpec spec;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = _est.summarize(spec);
    final palette = context.palette;
    final theme = Theme.of(context);
    final highlights = [
      for (final id in ['pubg-mobile', 'genshin', 'codm', 'mlbb'])
        _est.game(kMobileGames.firstWhere((g) => g.id == id), spec),
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        SectionCard(
          hero: true,
          title: spec.phone.displayName,
          icon: Icons.speed_rounded,
          trailing: StatusPill(
            text: s.tier.label,
            color: theme.colorScheme.primary,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    s.score.round().toString(),
                    style: numberStyle(context, size: 36),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Darboğaz puanı · ${spec.soc.name}, ${spec.ramGb} GB',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: palette.muted,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ScoreScale.phoneScore(context, s.score),
              const SizedBox(height: 8),
              for (final e in s.components.entries)
                MetricBar(
                  label: e.key,
                  value: e.value,
                  max: _barFullScale,
                  valueText: e.value.round().toString(),
                  color: e.key == s.weakest ? palette.warn : palette.good,
                ),
              const SizedBox(height: 4),
              Text(
                'Uzun oyunda performansın ~%${s.sustainedPercent.round()}\'i '
                'korunur (ısınma). En zayıf halka: ${s.weakest}.',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: palette.muted,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        SectionCard(
          title: 'Önerilen oyun ayarları',
          icon: Icons.sports_esports_rounded,
          child: Column(
            children: [
              for (final g in highlights)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(g.game.name),
                  trailing: Text(
                    '${g.recommendedPreset.label} · ~${_est.game(g.game, spec, preset: g.recommendedPreset).sustainedFps.round()} FPS',
                    style: theme.textTheme.labelMedium,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          kEstimateDisclaimer,
          style: theme.textTheme.labelSmall?.copyWith(color: palette.muted),
        ),
      ],
    );
  }
}

class PhoneGamesView extends ConsumerWidget {
  const PhoneGamesView({super.key, required this.spec});

  final PhoneSpec spec;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preset = ref.watch(_mobilePresetProvider);
    final palette = context.palette;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        AppSegmented<GraphicsPreset>(
          values: GraphicsPreset.values,
          selected: preset,
          labelOf: (p) => p.label,
          onChanged: ref.read(_mobilePresetProvider.notifier).set,
        ),
        const SizedBox(height: 8),
        SectionCard(
          title: 'Tahmini FPS (ilk / ısınınca)',
          icon: Icons.sports_esports_rounded,
          child: Column(
            children: [
              for (final g in kMobileGames)
                _gameRow(context, _est.game(g, spec, preset: preset), palette),
            ],
          ),
        ),
      ],
    );
  }

  Widget _gameRow(BuildContext context, MobileGameEstimate e, AppPalette p) {
    final atLimit = e.sustainedFps >= e.limitFps * 0.92;
    final color = atLimit ? p.good : (e.sustainedFps >= 30 ? p.warn : p.bad);
    return MetricBar(
      label: e.game.name,
      value: e.sustainedFps,
      max: e.limitFps.toDouble(),
      valueText: '${e.peakFps.round()} / ${e.sustainedFps.round()}',
      color: color,
      subtitle: [
        'Sınır ${e.limitFps} FPS',
        'önerilen: ${e.recommendedPreset.label}',
        if (e.ramShort) 'RAM yetersiz',
      ].join(' · '),
    );
  }
}

class PhoneAppsView extends StatelessWidget {
  const PhoneAppsView({super.key, required this.spec});

  final PhoneSpec spec;

  @override
  Widget build(BuildContext context) {
    final results = [for (final a in kMobileApps) _est.app(a, spec)];
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: results.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, i) => AppResultCard(result: results[i]),
    );
  }
}

/// Watch "Özet": smoothness, battery and features.
class WatchSummaryView extends ConsumerWidget {
  const WatchSummaryView({super.key, required this.report});

  final WatchReport report;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final w = report.watch;
    final palette = context.palette;
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        SectionCard(
          hero: true,
          title: w.displayName,
          icon: Icons.watch_rounded,
          trailing: StatusPill(
            text: report.phone == null
                ? 'Telefon seç'
                : (report.isCompatible ? 'Uyumlu' : 'Uyumsuz'),
            color: report.phone == null
                ? palette.warn
                : (report.isCompatible ? palette.good : palette.bad),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MetricBar(
                label: 'Akıcılık (${w.chip})',
                value: report.smoothness,
                max: 100,
                valueText: '${report.smoothness.round()}/100',
                color: report.smoothness >= 70 ? palette.good : palette.warn,
              ),
              MetricBar(
                label: 'Pil (karışık kullanım)',
                value: report.batteryDays.clamp(0, 14),
                max: 14,
                valueText: '~${batteryLabel(report.watch.batteryHours)}',
                color: report.batteryDays >= 2 ? palette.good : palette.warn,
              ),
              const SizedBox(height: 6),
              Text(
                '${w.os.label} · ${w.storageGb} GB depolama · ${w.year}',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: palette.muted,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        SectionCard(
          title: 'Özellikler',
          icon: Icons.favorite_rounded,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (w.features.length > report.availableFeatures.length)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    report.availableFeatures.isEmpty
                        ? 'Saat bu telefonla eşleşmediği için özellikler '
                              'kullanılamaz.'
                        : 'Soluk olanlar bu telefonla çalışmaz.',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: palette.muted,
                    ),
                  ),
                ),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final f in WatchFeature.values)
                    if (w.features.contains(f))
                      StatusPill(
                        text: f.label,
                        color: report.availableFeatures.contains(f)
                            ? palette.good
                            : palette.muted,
                      ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
