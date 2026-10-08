import 'package:flutter/material.dart';
import 'package:perf_engine/perf_engine.dart';

import 'package:darbogaz/core/theme/app_theme.dart';
import 'package:darbogaz/core/theme/tokens.dart';
import 'package:darbogaz/core/widgets/common.dart';

const _phoneInsights = PhoneInsightEstimator();
const _watchInsights = WatchInsightEstimator();

/// Hour count as "7 sa 30 dk".
String hoursLabel(double h) {
  final whole = h.floor();
  final min = ((h - whole) * 60).round();
  if (min == 0 || whole >= 24) return '$whole sa';
  return '$whole sa $min dk';
}

Color _usageColor(AppPalette p, double score) =>
    score >= 60 ? p.good : (score >= 40 ? p.warn : p.bad);

/// Phone "Mobil": battery, heat, updates and everyday scenarios.
class PhoneMobileView extends StatelessWidget {
  const PhoneMobileView({super.key, required this.spec});

  final PhoneSpec spec;

  @override
  Widget build(BuildContext context) {
    final i = _phoneInsights.analyze(spec, currentYear: DateTime.now().year);
    final palette = context.palette;
    final theme = Theme.of(context);
    final phone = spec.phone;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        Space.page,
        Space.xs,
        Space.page,
        Space.xl,
      ),
      children: [
        SectionCard(
          hero: true,
          title: 'Pil ve ısınma',
          icon: Icons.battery_charging_full_rounded,
          child: Column(
            children: [
              MetricBar(
                label: 'Karışık kullanım',
                subtitle: 'Sosyal medya, video, internet',
                value: i.screenOnHours,
                max: 12,
                valueText: hoursLabel(i.screenOnHours),
                color: i.screenOnHours >= 7 ? palette.good : palette.warn,
              ),
              MetricBar(
                label: 'Ağır oyun',
                subtitle: '${phone.batteryMah} mAh',
                value: i.gamingHours,
                max: 6,
                valueText: hoursLabel(i.gamingHours),
                color: i.gamingHours >= 3 ? palette.good : palette.warn,
              ),
              MetricBar(
                label: 'Isınınca korunan performans',
                subtitle: '~20 dk oyundan sonra',
                value: i.sustainedPercent,
                max: 100,
                valueText: '%${i.sustainedPercent.round()}',
                color: i.sustainedPercent >= 75
                    ? palette.good
                    : (i.sustainedPercent >= 60 ? palette.warn : palette.bad),
              ),
            ],
          ),
        ),
        const SizedBox(height: Space.s),
        SectionCard(
          title: 'Yazılım desteği',
          icon: Icons.system_update_rounded,
          trailing: VerdictChip(
            i.supportYearsLeft == 0
                ? 'Destek bitti'
                : '${i.supportYearsLeft} yıl kaldı',
            tone: i.supportYearsLeft >= 3
                ? Tone.good
                : (i.supportYearsLeft >= 1 ? Tone.warn : Tone.bad),
          ),
          child: Text(
            '${phone.platform.label} ${phone.maxOsMajor} sürümüne kadar '
            'güncelleme alır (~${i.supportUntilYear}). '
            '${phone.year} modeli · ${phone.displayHz} Hz ekran.',
            style: theme.textTheme.bodySmall,
          ),
        ),
        const SizedBox(height: Space.s),
        SectionCard(
          title: 'Günlük kullanımda',
          icon: Icons.touch_app_rounded,
          child: Column(
            children: [
              for (final u in i.usage)
                MetricBar(
                  label: u.name,
                  value: u.score,
                  max: 100,
                  valueText: u.verdict,
                  color: _usageColor(palette, u.score),
                ),
            ],
          ),
        ),
        const SizedBox(height: Space.s),
        const AccuracyNote(),
      ],
    );
  }
}

/// Watch "Mobil": battery modes plus health and sport features.
class WatchMobileView extends StatelessWidget {
  const WatchMobileView({super.key, required this.report});

  final WatchReport report;

  @override
  Widget build(BuildContext context) {
    final w = report.watch;
    final i = _watchInsights.analyze(w);
    final palette = context.palette;
    final theme = Theme.of(context);

    Widget features(List<WatchFeature> list, String empty) => list.isEmpty
        ? Text(empty, style: theme.textTheme.bodySmall)
        : Wrap(
            spacing: Space.xs,
            runSpacing: Space.xs,
            children: [
              for (final f in list)
                StatusPill(
                  text: f.label,
                  color: report.availableFeatures.contains(f)
                      ? palette.good
                      : palette.muted,
                ),
            ],
          );

    String days(double d) => d >= 1
        ? '~${d.toStringAsFixed(d >= 10 ? 0 : 1)} gün'
        : '~${hoursLabel(d * 24)}';

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        Space.page,
        Space.xs,
        Space.page,
        Space.xl,
      ),
      children: [
        SectionCard(
          hero: true,
          title: 'Pil',
          icon: Icons.battery_full_rounded,
          child: Column(
            children: [
              MetricBar(
                label: 'Normal kullanım',
                value: i.typicalDays.clamp(0, 14),
                max: 14,
                valueText: days(i.typicalDays),
                color: i.typicalDays >= 2 ? palette.good : palette.warn,
              ),
              MetricBar(
                label: 'Ekran hep açık',
                value: i.alwaysOnDays.clamp(0, 14),
                max: 14,
                valueText: days(i.alwaysOnDays),
                color: i.alwaysOnDays >= 1.5 ? palette.good : palette.warn,
              ),
              if (i.gpsHours > 0)
                MetricBar(
                  label: 'GPS ile antrenman',
                  value: i.gpsHours.clamp(0, 40),
                  max: 40,
                  valueText: hoursLabel(i.gpsHours),
                  color: i.gpsHours >= 8 ? palette.good : palette.warn,
                ),
            ],
          ),
        ),
        const SizedBox(height: Space.s),
        SectionCard(
          title: 'Sağlık',
          icon: Icons.monitor_heart_rounded,
          child: features(i.healthFeatures, 'Gelişmiş sağlık sensörü yok.'),
        ),
        const SizedBox(height: Space.s),
        SectionCard(
          title: 'Spor ve bağlantı',
          icon: Icons.directions_run_rounded,
          child: features(i.sportFeatures, 'GPS / LTE / ödeme özelliği yok.'),
        ),
        if (report.phone != null &&
            w.features.length > report.availableFeatures.length) ...[
          const SizedBox(height: Space.s),
          Text(
            'Soluk özellikler ${report.phone!.displayName} ile çalışmaz.',
            style: theme.textTheme.labelSmall?.copyWith(color: palette.muted),
          ),
        ],
      ],
    );
  }
}
