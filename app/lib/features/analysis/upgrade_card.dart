import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:darbogaz/core/providers.dart';
import 'package:darbogaz/core/theme/app_theme.dart';
import 'package:darbogaz/core/widgets/common.dart';
import 'package:darbogaz/core/widgets/part_labels.dart';

/// "Reduce the bottleneck" suggestions: free tips + best-value upgrades.
class UpgradeCard extends ConsumerWidget {
  const UpgradeCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final advice = ref.watch(upgradeAdviceProvider);
    if (advice == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final palette = context.palette;

    return SectionCard(
      title: 'Darboğazı Azalt',
      icon: Icons.trending_up_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final tip in advice.freeTips)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lightbulb_rounded, size: 18, color: palette.warn),
                  const SizedBox(width: 8),
                  Expanded(child: Text(tip, style: theme.textTheme.bodySmall)),
                ],
              ),
            ),
          if (advice.options.isEmpty)
            Text(
              'Bu ayarda anlamlı (%3+) FPS kazandıracak uyumlu bir yükseltme '
              'bulunamadı.',
              style: theme.textTheme.bodyMedium,
            )
          else ...[
            Text(
              'En iyi fiyat/performans yükseltmeler',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            for (final o in advice.options)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(o.part.category.icon),
                title: Text(o.part.displayName),
                subtitle: Text(
                  '${o.newEstimate.avgFps.round()} FPS · darboğaz '
                  '%${o.newBottleneckPercent.round()}'
                  '${o.needsPsuUpgrade ? ' · PSU yetmez' : ''}',
                ),
                trailing: Text(
                  '+%${o.gainPercent.round()}',
                  style: numberStyle(context, size: 15, color: palette.good),
                ),
                onTap: () => context.go(
                  '/prices?q=${Uri.encodeQueryComponent(o.part.mpn ?? o.part.displayName)}',
                ),
              ),
          ],
        ],
      ),
    );
  }
}
