import 'package:flutter/material.dart';

import 'package:darbogaz/core/theme/app_theme.dart';
import 'package:darbogaz/core/theme/tokens.dart';
import 'package:darbogaz/core/widgets/common.dart';
import 'package:darbogaz/features/analysis/plain_verdict.dart';

/// The plain-language answer shown first on every result screen.
class PlainVerdictCard extends StatelessWidget {
  const PlainVerdictCard({
    super.key,
    required this.verdict,
    this.actionLabel,
    this.onAction,
  });

  final PlainVerdict verdict;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final theme = Theme.of(context);
    final (Color color, IconData icon) = switch (verdict.tone) {
      Tone.good => (p.good, Icons.check_circle_rounded),
      Tone.warn => (p.warn, Icons.info_rounded),
      Tone.bad => (p.bad, Icons.warning_rounded),
      Tone.brand => (theme.colorScheme.primary, Icons.thumb_up_alt_rounded),
      Tone.neutral => (p.muted, Icons.info_outline_rounded),
    };
    return Semantics(
      container: true,
      label: '${verdict.title}. ${verdict.detail}',
      child: Card(
        color: color.withValues(alpha: 0.12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.l),
          side: BorderSide(color: color.withValues(alpha: 0.5)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(Space.l),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, color: color, size: 32),
                  const SizedBox(width: Space.m),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          verdict.title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: Space.xs),
                        Text(verdict.detail, style: theme.textTheme.bodyMedium),
                      ],
                    ),
                  ),
                ],
              ),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: Space.s),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.tonal(
                    onPressed: onAction,
                    child: Text(actionLabel!),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
