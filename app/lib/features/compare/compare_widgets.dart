import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:darbogaz/core/theme/app_theme.dart';
import 'package:darbogaz/core/theme/tokens.dart';
import 'package:darbogaz/core/widgets/cards.dart';
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
        borderRadius: BorderRadius.circular(Radii.l),
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
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                ],
              ),
              if (onTap != null && !highlight)
                Text(
                  'Değiştir',
                  style: theme.textTheme.labelMedium?.copyWith(color: color),
                ),
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
          Text(headline, style: theme.textTheme.titleLarge),
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
            const SizedBox(height: Space.xs),
            for (final r in highlights)
              BulletRow(
                '${r.label}: ${r.winner == -1 ? mine : other} önde '
                '(${r.aDisplay} / ${r.bDisplay})',
                icon: Icons.check_rounded,
                color: r.winner == -1 ? mineColor : otherColor,
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
