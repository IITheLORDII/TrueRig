import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:perf_engine/perf_engine.dart';

import 'package:darbogaz/core/providers.dart';
import 'package:darbogaz/core/theme/app_theme.dart';
import 'package:darbogaz/core/theme/tokens.dart';
import 'package:darbogaz/core/widgets/common.dart';
import 'package:darbogaz/core/widgets/part_labels.dart';

/// "Darboğazı azalt": free tips + upgrades ranked by average FPS gain per
/// 100 \$ over the whole game library (not one game).
class UpgradeCard extends ConsumerWidget {
  const UpgradeCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final advice = ref.watch(generalAdviceProvider);
    if (advice == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final palette = context.palette;

    return SectionCard(
      title: 'Darboğazı azalt',
      icon: Icons.trending_up_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final tip in advice.freeTips)
            Padding(
              padding: const EdgeInsets.only(bottom: Space.s),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lightbulb_rounded, size: 18, color: palette.warn),
                  const SizedBox(width: Space.s),
                  Expanded(child: Text(tip, style: theme.textTheme.bodySmall)),
                ],
              ),
            ),
          if (advice.options.isEmpty)
            Text(
              'Oyunlarda ortalama %${kMinUsefulGainPercent.round()}+ kazanç '
              'sağlayacak uyumlu bir yükseltme bulunamadı.',
              style: theme.textTheme.bodySmall,
            )
          else ...[
            const SectionHeader('En iyi fiyat / performans'),
            for (final o in advice.options)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(o.part.category.icon),
                title: Text(o.part.displayName),
                subtitle: Text(
                  'Yeni darboğaz %${o.after.bottleneckPercent.round()} · '
                  '~\$${o.part.refPriceUsd!.round()}'
                  '${o.needsPsuUpgrade ? ' · güç kaynağı yetmez' : ''}',
                ),
                trailing: Text(
                  '+%${o.gainPercent.round()}',
                  style: numberStyle(context, size: 15, color: palette.good),
                ),
                onTap: () => context.go(
                  '/prices?q=${Uri.encodeQueryComponent(o.part.mpn ?? o.part.displayName)}',
                ),
              ),
            Text(
              'Kazanç: oyun kütüphanesinde ortalama FPS artışı.',
              style: theme.textTheme.labelSmall?.copyWith(color: palette.muted),
            ),
          ],
        ],
      ),
    );
  }
}
