import 'package:flutter/material.dart';
import 'package:perf_engine/perf_engine.dart';

import 'package:darbogaz/core/theme/app_theme.dart';
import 'package:darbogaz/core/theme/tokens.dart';
import 'package:darbogaz/core/verdicts.dart';
import 'package:darbogaz/core/widgets/common.dart';
import 'package:darbogaz/core/widgets/explain.dart';

String fpsText(double v) => '${v.round()} FPS';

/// "+4 FPS" / "−12 FPS" / "±0".
String deltaText(double v) {
  final r = v.round();
  if (r == 0) return '±0';
  return r > 0 ? '+$r FPS' : '−${-r} FPS';
}

/// The headline: the frame rate you get and what limits it.
class FpsResultCard extends StatelessWidget {
  const FpsResultCard({super.key, required this.b});

  final FpsBreakdown b;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tone = fpsTone(b.resultFps);
    final limiter = b.engineCapped
        ? 'oyunun kendi sınırı'
        : switch (b.limiter) {
            Limiter.cpu => 'işlemci',
            Limiter.gpu => 'ekran kartı',
            Limiter.balanced => 'ikisi dengeli',
          };
    return SectionCard(
      hero: true,
      title: b.game == null ? '${b.gameCount} oyunun ortalaması' : b.game!.name,
      icon: Icons.speed_rounded,
      trailing: VerdictChip(
        '${b.resolution.label} · ${b.preset.label}',
        tone: Tone.neutral,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '~${b.resultFps.round()}',
                style: numberStyle(context, size: 40),
              ),
              const SizedBox(width: Space.xs),
              Text('FPS', style: theme.textTheme.titleMedium),
              const SizedBox(width: Space.m),
              VerdictChip(fpsWord(b.resultFps), tone: tone),
            ],
          ),
          const SizedBox(height: Space.xs),
          Text('Hızı belirleyen: $limiter.', style: theme.textTheme.bodyLarge),
          const SizedBox(height: Space.m),
          const Explain(
            question: 'Sonuç neden en yavaş parçadan biraz daha düşük?',
            answer:
                'İki parça da her karede iş yapar. Biri bekleyince diğeri de '
                'biraz yavaşlar; bu yüzden sonuç, en yavaş parçanın değerinin '
                'biraz altında çıkar. Parçalar birbirine ne kadar yakınsa bu '
                'fark o kadar büyür.',
          ),
        ],
      ),
    );
  }
}

/// One part's own FPS with a bar, a plain sentence and an optional badge.
class PartFpsRow extends StatelessWidget {
  const PartFpsRow({
    super.key,
    required this.icon,
    required this.title,
    required this.sentence,
    this.subtitle,
    this.fps,
    this.maxFps = 1,
    this.badge,
    this.badgeTone = Tone.neutral,
    this.limiting = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String sentence;

  /// The part's own frame rate (null for parts shown as a +/− effect).
  final double? fps;
  final double maxFps;
  final String? badge;
  final Tone badgeTone;

  /// This part sets the frame rate.
  final bool limiting;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = context.palette;
    final color = limiting ? p.bad : theme.colorScheme.primary;
    final value = fps;
    return Semantics(
      container: true,
      label: [
        title,
        ?subtitle,
        if (value != null) '${value.round()} FPS',
        ?badge,
        if (limiting) 'hızı belirleyen parça',
        sentence,
      ].join('. '),
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Space.s),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: IconSizes.s, color: color),
                const SizedBox(width: Space.s),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: theme.textTheme.titleSmall),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: p.muted,
                          ),
                        ),
                    ],
                  ),
                ),
                if (value != null)
                  Text(
                    fpsText(value),
                    style: numberStyle(context, size: 16, color: color),
                  ),
                if (badge != null) ...[
                  const SizedBox(width: Space.s),
                  VerdictChip(badge!, tone: badgeTone),
                ],
              ],
            ),
            if (value != null) ...[
              const SizedBox(height: Space.xs),
              ClipRRect(
                borderRadius: BorderRadius.circular(Radii.pill),
                child: LinearProgressIndicator(
                  value: (value / maxFps).clamp(0.0, 1.0),
                  minHeight: 6,
                  color: color,
                  backgroundColor: p.surfaceAlt,
                ),
              ),
            ],
            const SizedBox(height: Space.xs),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (limiting) ...[
                  Icon(Icons.flag_rounded, size: 16, color: p.bad),
                  const SizedBox(width: Space.xs),
                ],
                Expanded(
                  child: Text(sentence, style: theme.textTheme.bodyMedium),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// "Yeterli" / "Zayıf" status row for parts that do not change FPS.
class SupportRow extends StatelessWidget {
  const SupportRow({
    super.key,
    required this.icon,
    required this.title,
    required this.sentence,
    required this.tone,
    required this.status,
  });

  final IconData icon;
  final String title;
  final String sentence;
  final Tone tone;
  final String status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.s),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: IconSizes.s, color: context.palette.muted),
          const SizedBox(width: Space.s),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleSmall),
                Text(sentence, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
          const SizedBox(width: Space.s),
          VerdictChip(status, tone: tone),
        ],
      ),
    );
  }
}

/// Plain reason for the memory's effect.
String ramSentence(FpsBreakdown b, Ram? ram) {
  if (ram == null) {
    return 'RAM seçilmedi; hesapta çift kanallı DDR5-6000 varsayıldı.';
  }
  final notes = [
    for (final n in b.ramNotes)
      switch (n) {
        RamNote.fast => 'hızlı bellek biraz kazandırıyor',
        RamNote.slow => 'bellek hızı türüne göre düşük',
        RamNote.ddr4 => 'DDR4, DDR5\'ten biraz yavaş',
        RamNote.ddr3 => 'DDR3 eski ve yavaş',
        RamNote.singleModule =>
          'tek modül: tek kanal çalışır, iki modüle göre yavaştır',
        RamNote.lowCapacity => '16 GB\'ın altı yeni oyunlara dar gelir',
      },
  ];
  final d = b.ramDeltaFps.round();
  if (notes.isEmpty) return 'Belleğin işlemciyi yavaşlatmıyor.';
  final head = d < 0
      ? 'Belleğin yüzünden işlemci ${-d} FPS daha az hazırlıyor'
      : d > 0
      ? 'Belleğin işlemciye $d FPS kazandırıyor'
      : 'Belleğin işlemciyi neredeyse etkilemiyor';
  return '$head: ${notes.join('; ')}.';
}
