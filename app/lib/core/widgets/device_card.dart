import 'package:flutter/material.dart';

import 'package:darbogaz/core/theme/app_theme.dart';
import 'package:darbogaz/core/theme/tokens.dart';
import 'package:darbogaz/core/widgets/common.dart';

/// One headline number on a device card ("%13" / "Darboğaz").
class CardMetric {
  const CardMetric(this.value, this.label);
  final String value;
  final String label;
}

/// "Cihazlarım" card: one device with its at-a-glance result, or an
/// invitation to add it.
class DeviceCard extends StatelessWidget {
  const DeviceCard({
    super.key,
    required this.icon,
    required this.kindLabel,
    required this.title,
    required this.emptyText,
    required this.onEdit,
    this.metrics = const [],
    this.chip,
    this.active = false,
    this.onAnalyze,
  });

  final IconData icon;
  final String kindLabel;

  /// Null = not configured yet (empty card).
  final String? title;
  final String emptyText;
  final List<CardMetric> metrics;
  final Widget? chip;
  final bool active;
  final VoidCallback onEdit;
  final VoidCallback? onAnalyze;

  @override
  Widget build(BuildContext context) {
    final t = title;
    return t == null ? _empty(context) : _filled(context, t);
  }

  Widget _empty(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.all(Space.l),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: scheme.primary.withValues(alpha: 0.12),
                child: Icon(Icons.add_rounded, color: scheme.primary),
              ),
              const SizedBox(width: Space.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$kindLabel ekle',
                      style: Theme.of(context).textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      emptyText,
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: context.palette.muted),
                    ),
                  ],
                ),
              ),
              Icon(icon, color: context.palette.muted),
            ],
          ),
        ),
      ),
    );
  }

  Widget _filled(BuildContext context, String t) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final body = Material(
      type: MaterialType.transparency,
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.l),
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            Space.l,
            Space.m,
            Space.s,
            Space.s,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 18, color: theme.colorScheme.primary),
                  const SizedBox(width: Space.s),
                  Text(
                    kindLabel.toUpperCase(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: palette.muted,
                      letterSpacing: 0.8,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  ?chip,
                  const SizedBox(width: Space.s),
                ],
              ),
              const SizedBox(height: Space.xs),
              Text(
                t,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (metrics.isNotEmpty) ...[
                const SizedBox(height: Space.m),
                Wrap(
                  spacing: Space.xl,
                  runSpacing: Space.s,
                  children: [
                    for (final m in metrics)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(m.value, style: numberStyle(context, size: 20)),
                          Text(
                            m.label,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: palette.muted,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ],
              Row(
                children: [
                  const Spacer(),
                  if (onAnalyze != null)
                    TextButton.icon(
                      onPressed: onAnalyze,
                      iconAlignment: IconAlignment.end,
                      icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                      label: const Text('Analiz'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    return active ? HeroFrame(child: body) : Card(child: body);
  }
}
