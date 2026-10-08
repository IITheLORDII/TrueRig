import 'package:flutter/material.dart';

import 'package:darbogaz/core/theme/app_theme.dart';
import 'package:darbogaz/core/theme/tokens.dart';
import 'package:darbogaz/core/widgets/common.dart';
import 'package:darbogaz/features/compare/compare_metrics.dart';
import 'package:darbogaz/features/compare/compare_widgets.dart';

/// A comparison section with the two device names as column headers. The
/// better value is bold, coloured and ticked (colour is not the only sign).
class CompareTable extends StatelessWidget {
  const CompareTable({
    super.key,
    required this.section,
    required this.mine,
    required this.other,
  });

  final CompareSection section;
  final String mine;
  final String other;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);
    final mineColor = CompareColors.mine(context);
    final otherColor = CompareColors.other(context);

    Widget header(String text, Color color) => Expanded(
      flex: 3,
      child: Text(
        text,
        textAlign: TextAlign.end,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.labelMedium?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );

    Widget cell(String text, bool wins, Color color) => Expanded(
      flex: 3,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (wins) ...[
            Icon(Icons.check_rounded, size: 14, color: color),
            const SizedBox(width: 2),
          ],
          Flexible(
            child: Text(
              text,
              textAlign: TextAlign.end,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: numberStyle(
                context,
                size: 13,
                color: wins ? color : null,
              ).copyWith(fontWeight: wins ? FontWeight.w800 : FontWeight.w500),
            ),
          ),
        ],
      ),
    );

    return SectionCard(
      title: section.title,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: Space.xs),
            child: Row(
              children: [
                const Expanded(flex: 4, child: SizedBox.shrink()),
                header(mine, mineColor),
                const SizedBox(width: Space.s),
                header(other, otherColor),
              ],
            ),
          ),
          Divider(height: 1, color: palette.surfaceAlt),
          for (final r in section.rows)
            Semantics(
              label:
                  '${r.label}: $mine ${r.aDisplay}, $other ${r.bDisplay}'
                  '${r.winner == 0 ? '' : ', ${r.winner == -1 ? mine : other} önde'}',
              excludeSemantics: true,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: Space.s),
                child: Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: Text(r.label, style: theme.textTheme.bodyMedium),
                    ),
                    cell(r.aDisplay, r.winner == -1, mineColor),
                    const SizedBox(width: Space.s),
                    cell(r.bDisplay, r.winner == 1, otherColor),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
