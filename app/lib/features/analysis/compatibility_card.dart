import 'package:flutter/material.dart';
import 'package:perf_engine/perf_engine.dart';

import 'package:darbogaz/core/theme/app_theme.dart';
import 'package:darbogaz/core/widgets/common.dart';

class CompatibilityCard extends StatelessWidget {
  const CompatibilityCard({super.key, required this.report});

  final CompatibilityReport report;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final issues = [
      ...report.bySeverity(IssueSeverity.error),
      ...report.bySeverity(IssueSeverity.warning),
      ...report.bySeverity(IssueSeverity.info),
    ];
    return SectionCard(
      title: 'Uyumluluk',
      icon: Icons.fact_check_rounded,
      trailing: StatusPill(
        text: report.isCompatible ? 'Uyumlu' : 'Uyumsuz',
        color: report.isCompatible ? palette.good : palette.bad,
      ),
      child: issues.isEmpty
          ? Text(
              'Seçili parçalar arasında sorun bulunmadı.',
              style: Theme.of(context).textTheme.bodyMedium,
            )
          : Column(children: [for (final i in issues) _IssueTile(issue: i)]),
    );
  }
}

class _IssueTile extends StatelessWidget {
  const _IssueTile({required this.issue});

  final CompatibilityIssue issue;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final (color, icon) = switch (issue.severity) {
      IssueSeverity.error => (palette.bad, Icons.error_rounded),
      IssueSeverity.warning => (palette.warn, Icons.warning_amber_rounded),
      IssueSeverity.info => (palette.muted, Icons.info_outline_rounded),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              issue.message,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
