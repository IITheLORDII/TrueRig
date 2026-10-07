import 'package:flutter/material.dart';

import 'package:darbogaz/core/theme/app_theme.dart';
import 'package:darbogaz/core/theme/tokens.dart';

/// One coloured band of a [ScoreScale].
class ScaleZone {
  const ScaleZone({
    required this.until,
    required this.label,
    required this.color,
  });

  /// Upper end of the zone on the scale.
  final double until;
  final String label;
  final Color color;
}

/// Horizontal bar split into coloured zones with a marker at [value]:
/// tells at a glance whether a score is safe, average or a bottleneck.
class ScoreScale extends StatelessWidget {
  const ScoreScale({
    super.key,
    required this.value,
    required this.zones,
    required this.valueText,
    this.min = 0,
    this.caption,
  });

  final double value;
  final double min;
  final List<ScaleZone> zones;
  final String valueText;
  final String? caption;

  double get _max => zones.last.until;

  ScaleZone get current =>
      zones.firstWhere((z) => value <= z.until, orElse: () => zones.last);

  /// Bottleneck percentage: lower is better (matches [AppPalette.forBottleneck]).
  factory ScoreScale.bottleneck(BuildContext context, double percent) {
    final p = context.palette;
    return ScoreScale(
      value: percent,
      valueText: '%${percent.round()}',
      zones: [
        ScaleZone(until: 10, label: 'Güvenli', color: p.good),
        ScaleZone(until: 20, label: 'Orta', color: p.warn),
        ScaleZone(until: 50, label: 'Aşırı darboğaz', color: p.bad),
      ],
      caption: '%0–10 güvenli · %10–20 orta · %20 üstü aşırı darboğaz',
    );
  }

  /// Phone score: higher is better, so red sits on the left.
  factory ScoreScale.phoneScore(BuildContext context, double score) {
    final p = context.palette;
    return ScoreScale(
      value: score,
      valueText: score.round().toString(),
      zones: [
        ScaleZone(until: 50, label: 'Aşırı darboğaz', color: p.bad),
        ScaleZone(until: 75, label: 'Orta', color: p.warn),
        ScaleZone(until: 110, label: 'Güvenli', color: p.good),
      ],
      caption:
          '75+ güvenli · 50–75 orta · 50 altı aşırı darboğaz '
          '(puan yükseldikçe darboğaz azalır)',
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final zone = current;
    final span = _max - min;
    final at = ((value - min) / span).clamp(0.0, 1.0);
    return Semantics(
      label: 'Puan $valueText, ${zone.label}',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, box) {
              final w = box.maxWidth;
              final markerX = (at * w).clamp(8.0, w - 8.0);
              return SizedBox(
                height: 34,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 16,
                      height: 10,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(Radii.s),
                        // Stretch: ColoredBox has no size of its own.
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (var i = 0; i < zones.length; i++)
                              Expanded(
                                flex:
                                    ((zones[i].until -
                                                (i == 0
                                                    ? min
                                                    : zones[i - 1].until)) *
                                            10)
                                        .round(),
                                child: ColoredBox(
                                  color: zones[i].color.withValues(
                                    alpha: zones[i] == zone ? 1 : 0.35,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      left: markerX - 8,
                      top: 0,
                      child: Column(
                        children: [
                          Icon(
                            Icons.arrow_drop_down_rounded,
                            size: 16,
                            color: theme.colorScheme.onSurface,
                          ),
                          Container(
                            width: 3,
                            height: 14,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.onSurface,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: Space.xs),
          Row(
            children: [
              for (final z in zones)
                Expanded(
                  child: Text(
                    z.label,
                    textAlign: z == zones.first
                        ? TextAlign.start
                        : (z == zones.last ? TextAlign.end : TextAlign.center),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: z == zone ? z.color : context.palette.muted,
                      fontWeight: z == zone ? FontWeight.w700 : null,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: Space.xs),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '$valueText · ${zone.label}',
                  style: TextStyle(
                    color: zone.color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (caption != null) TextSpan(text: '\n$caption'),
              ],
            ),
            style: theme.textTheme.labelSmall?.copyWith(
              color: context.palette.muted,
            ),
          ),
        ],
      ),
    );
  }
}
