import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:darbogaz/core/theme/app_theme.dart';
import 'package:darbogaz/core/theme/tokens.dart';
import 'package:darbogaz/core/widgets/common.dart';
import 'package:darbogaz/features/compare/compare_metrics.dart';
import 'package:darbogaz/features/prices/store_list.dart';

/// Fixed colours so "Benim" and "Karşılaştırılan" read the same everywhere.
abstract final class CompareColors {
  static Color mine(BuildContext context) =>
      Theme.of(context).colorScheme.primary;
  static Color other(BuildContext context) => context.palette.accentAlt;
}

/// One side of the comparison (name + tap to change).
class SideCard extends StatelessWidget {
  const SideCard({
    super.key,
    required this.caption,
    required this.name,
    required this.color,
    this.onTap,
    this.highlight = false,
  });

  final String caption;
  final String name;
  final Color color;
  final VoidCallback? onTap;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: highlight ? color.withValues(alpha: 0.12) : null,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.m),
        side: BorderSide(color: color.withValues(alpha: 0.6)),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(Space.m),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: Space.xs),
                  Expanded(
                    child: Text(
                      caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: context.palette.muted,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Space.xs),
              Row(
                children: [
                  if (highlight) ...[
                    Icon(Icons.add_rounded, size: 18, color: color),
                    const SizedBox(width: Space.xs),
                  ],
                  Expanded(
                    child: Text(
                      name,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              if (onTap != null && !highlight)
                Text('Değiştir', style: TextStyle(color: color, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Kim önde?": rows won by each side and a split bar.
class VerdictCard extends StatelessWidget {
  const VerdictCard({
    super.key,
    required this.mine,
    required this.other,
    required this.wins,
    this.highlights = const [],
  });

  final String mine;
  final String other;
  final ({int a, int b}) wins;

  /// Biggest differences, shown as plain lines under the headline.
  final List<CompareRow> highlights;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final a = wins.a;
    final b = wins.b;
    final total = a + b;
    final mineColor = CompareColors.mine(context);
    final otherColor = CompareColors.other(context);
    final String headline;
    if (total == 0 || (a - b).abs() <= total * 0.1) {
      headline = 'İkisi neredeyse aynı seviyede';
    } else if (a > b) {
      headline = '$mine daha iyi';
    } else {
      headline = '$other daha iyi';
    }
    return SectionCard(
      hero: true,
      title: 'Kim önde?',
      icon: Icons.emoji_events_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            headline,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: Space.s),
          ClipRRect(
            borderRadius: BorderRadius.circular(Radii.s),
            child: SizedBox(
              height: 10,
              child: Row(
                children: [
                  if (total == 0)
                    Expanded(child: ColoredBox(color: context.palette.muted))
                  else ...[
                    if (a > 0)
                      Expanded(
                        flex: a,
                        child: ColoredBox(color: mineColor),
                      ),
                    if (b > 0)
                      Expanded(
                        flex: b,
                        child: ColoredBox(color: otherColor),
                      ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: Space.xs),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Benim: $a başlıkta önde',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: mineColor,
                  ),
                ),
              ),
              Text(
                'Diğeri: $b başlıkta önde',
                style: theme.textTheme.labelMedium?.copyWith(color: otherColor),
              ),
            ],
          ),
          if (highlights.isNotEmpty) ...[
            const SizedBox(height: Space.s),
            Text(
              'En büyük farklar',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            for (final r in highlights)
              Padding(
                padding: const EdgeInsets.only(top: Space.xs),
                child: Text(
                  '• ${r.label}: ${r.winner == -1 ? mine : other} önde '
                  '(${r.aDisplay} / ${r.bDisplay})',
                  style: theme.textTheme.bodySmall,
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// Average store price per side; tapping opens the store list.
class PriceCompareCard extends StatelessWidget {
  const PriceCompareCard({
    super.key,
    required this.mine,
    required this.mineQuery,
    required this.other,
    required this.otherQuery,
  });

  final String mine;
  final String? mineQuery;
  final String other;
  final String? otherQuery;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Mağazalarda ortalama fiyat',
      icon: Icons.sell_rounded,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _PriceSide(
              name: mine,
              query: mineQuery,
              color: CompareColors.mine(context),
            ),
          ),
          const SizedBox(width: Space.s),
          Expanded(
            child: _PriceSide(
              name: other,
              query: otherQuery,
              color: CompareColors.other(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _PriceSide extends ConsumerWidget {
  const _PriceSide({
    required this.name,
    required this.query,
    required this.color,
  });

  final String name;
  final String? query;
  final Color color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final q = query;
    final configured = ref.watch(priceRepositoryProvider).isConfigured;
    final async = q != null && configured
        ? ref.watch(priceSearchProvider(q))
        : null;
    final avg = async?.value?.averagePrice;
    final Widget value;
    if (async?.isLoading ?? false) {
      value = const SkeletonBar(width: 80);
    } else if (avg != null) {
      value = Text(
        formatPrice(avg, async!.value!.currency),
        style: numberStyle(context, size: 16, color: color),
      );
    } else {
      value = Text(
        'Mağazalarda gör ›',
        style: theme.textTheme.labelLarge?.copyWith(color: color),
      );
    }
    return InkWell(
      borderRadius: BorderRadius.circular(Radii.s),
      onTap: q == null
          ? null
          : () => context.go('/prices?q=${Uri.encodeQueryComponent(q)}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Space.xs),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: context.palette.muted,
              ),
            ),
            const SizedBox(height: 2),
            value,
          ],
        ),
      ),
    );
  }
}

/// A comparison section with the two device names as column headers.
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
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );

    Widget cell(String text, bool wins, Color color) => Expanded(
      flex: 3,
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
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Space.xs),
              child: Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: Text(r.label, style: theme.textTheme.bodySmall),
                  ),
                  cell(r.aDisplay, r.winner == -1, mineColor),
                  const SizedBox(width: Space.s),
                  cell(r.bDisplay, r.winner == 1, otherColor),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
