import 'package:flutter/material.dart';
import 'package:perf_engine/perf_engine.dart';

import 'package:darbogaz/core/theme/app_theme.dart';
import 'package:darbogaz/core/theme/tokens.dart';
import 'package:darbogaz/core/widgets/common.dart';

class CompatibilityCard extends StatelessWidget {
  const CompatibilityCard({super.key, required this.report});

  final CompatibilityReport report;

  @override
  Widget build(BuildContext context) {
    final issues = [
      ...report.bySeverity(IssueSeverity.error),
      ...report.bySeverity(IssueSeverity.warning),
      ...report.bySeverity(IssueSeverity.info),
    ];
    return SectionCard(
      title: 'Uyumluluk',
      icon: Icons.fact_check_rounded,
      trailing: VerdictChip(
        report.isCompatible ? '✓ Uyumlu' : '✕ Uyumsuz',
        tone: report.isCompatible ? Tone.good : Tone.bad,
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
      padding: const EdgeInsets.symmetric(vertical: Space.s - 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: Space.m),
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
