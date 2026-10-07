import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:perf_engine/perf_engine.dart';

import 'package:darbogaz/core/providers.dart';
import 'package:darbogaz/core/theme/app_theme.dart';
import 'package:darbogaz/core/widgets/common.dart';

class AppsTab extends ConsumerWidget {
  const AppsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final build = ref.watch(buildProvider);
    const est = AppEstimator();
    final results = [for (final a in kApps) est.estimate(a, build)];
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      itemCount: results.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) => AppResultCard(result: results[i]),
    );
  }
}

class AppResultCard extends StatelessWidget {
  const AppResultCard({super.key, required this.result});

  final AppEstimate result;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);
    final color = switch (result.rating) {
      AppRating.smooth => palette.good,
      AppRating.adequate => palette.warn,
      AppRating.struggles => palette.bad,
    };
    return SectionCard(
      title: result.app.name,
      trailing: StatusPill(text: result.rating.label, color: color),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MetricBar(
            label: result.app.category,
            value: result.score,
            max: 100,
            valueText: '${result.score.round()}/100',
            color: color,
          ),
          if (result.rating != AppRating.smooth)
            Text(
              'En zayıf halka: ${result.weakestComponent}',
              style: theme.textTheme.labelMedium?.copyWith(color: color),
            ),
          const SizedBox(height: 4),
          Text(
            result.app.tip,
            style: theme.textTheme.bodySmall?.copyWith(color: palette.muted),
          ),
        ],
      ),
    );
  }
}
