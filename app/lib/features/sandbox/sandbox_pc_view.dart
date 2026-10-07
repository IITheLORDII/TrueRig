import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:perf_engine/perf_engine.dart';

import 'package:darbogaz/features/analysis/plain_verdict.dart';
import 'package:darbogaz/core/widgets/plain_verdict_card.dart';
import 'package:darbogaz/core/theme/app_theme.dart';
import 'package:darbogaz/core/theme/tokens.dart';
import 'package:darbogaz/core/widgets/app_controls.dart';
import 'package:darbogaz/core/widgets/common.dart';
import 'package:darbogaz/core/widgets/part_labels.dart';
import 'package:darbogaz/features/analysis/analysis_page.dart';
import 'package:darbogaz/features/analysis/compatibility_card.dart';
import 'package:darbogaz/features/builder/prebuilt_picker_page.dart';
import 'package:darbogaz/features/sandbox/sandbox_state.dart';

const _editable = [
  PartCategory.cpu,
  PartCategory.gpu,
  PartCategory.ram,
  PartCategory.motherboard,
  PartCategory.psu,
  PartCategory.pcCase,
];

Part? _partOf(PcBuild b, PartCategory c) => switch (c) {
  PartCategory.cpu => b.cpu,
  PartCategory.gpu => b.gpu,
  PartCategory.motherboard => b.motherboard,
  PartCategory.ram => b.ram,
  PartCategory.psu => b.psu,
  PartCategory.pcCase => b.pcCase,
  PartCategory.cooler => b.cooler,
};

/// Opens the ready-made system picker and puts the result into [slot].
Future<void> pickSandboxPrebuilt(
  BuildContext context,
  WidgetRef ref,
  int slot,
) async {
  final picked = await context.push<PickedSystem>('/pick/prebuilt?mode=return');
  if (picked == null) return;
  ref
      .read(sandboxProvider.notifier)
      .setPc(slot, SandboxPc(label: picked.label, build: picked.build));
}

/// Parts of one scratch PC: ready-made system or one part at a time.
class SandboxPcEditor extends ConsumerWidget {
  const SandboxPcEditor({super.key, required this.slot});

  final int slot;

  Future<void> _pickPart(
    BuildContext context,
    WidgetRef ref,
    PartCategory c,
  ) async {
    final part = await context.push<Part>('/pick/part/${c.name}?mode=return');
    if (part != null) ref.read(sandboxProvider.notifier).setPart(slot, part);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pc = ref.watch(sandboxProvider).pcs[slot];
    final palette = context.palette;
    return SectionCard(
      title: pc.label ?? 'Bilgisayar topla',
      icon: Icons.build_circle_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton.tonalIcon(
            onPressed: () => pickSandboxPrebuilt(context, ref, slot),
            icon: const Icon(Icons.laptop_chromebook_rounded),
            label: const Text('Hazır modellerde gez'),
          ),
          for (final c in _editable)
            () {
              final part = _partOf(pc.build, c);
              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(c.icon),
                title: Text(c.label),
                subtitle: Text(
                  part?.displayName ?? 'Seç',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: part == null
                      ? TextStyle(color: palette.muted)
                      : const TextStyle(fontWeight: FontWeight.w600),
                ),
                trailing: part == null
                    ? const Icon(Icons.add_circle_outline_rounded)
                    : IconButton(
                        tooltip: 'Kaldır',
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => ref
                            .read(sandboxProvider.notifier)
                            .clearPart(slot, c),
                      ),
                onTap: () => _pickPart(context, ref, c),
              );
            }(),
        ],
      ),
    );
  }
}

/// Results for a scratch PC, computed straight from the engine.
class SandboxPcResults extends StatefulWidget {
  const SandboxPcResults({super.key, required this.build});

  final PcBuild build;

  @override
  State<SandboxPcResults> createState() => _SandboxPcResultsState();
}

class _SandboxPcResultsState extends State<SandboxPcResults> {
  Resolution _resolution = Resolution.p1080;

  @override
  Widget build(BuildContext context) {
    final b = widget.build;
    final cpu = b.cpu;
    final gpu = b.gpu;
    final report = const CompatibilityChecker().check(b);
    if (cpu == null || gpu == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const EmptyHint(
            icon: Icons.speed_rounded,
            message:
                'Darboğaz için işlemci ve ekran kartı seç ya da hazır bir '
                'model seç.',
          ),
          if (b.parts.isNotEmpty) CompatibilityCard(report: report),
        ],
      );
    }
    const analyzer = SystemBottleneckAnalyzer();
    final general = analyzer.analyze(
      cpu: cpu,
      gpu: gpu,
      ram: b.ram,
      resolution: _resolution,
    );
    final rows = analyzer.byResolution(cpu: cpu, gpu: gpu, ram: b.ram);
    final games = [...general.perGame]
      ..sort((x, y) => y.avgFps.compareTo(x.avgFps));
    final palette = context.palette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSegmented<Resolution>(
          values: Resolution.values,
          selected: _resolution,
          labelOf: (r) => r.label,
          onChanged: (r) => setState(() => _resolution = r),
        ),
        const SizedBox(height: Space.s),
        PlainVerdictCard(verdict: pcVerdict(general)),
        const SizedBox(height: Space.s),
        GeneralBottleneckCard(general: general),
        const SizedBox(height: Space.s),
        ResolutionBottleneckCard(rows: rows),
        const SizedBox(height: Space.s),
        SectionCard(
          title: 'Oyunlarda FPS (${_resolution.label} Yüksek)',
          icon: Icons.sports_esports_rounded,
          child: Column(
            children: [
              for (final e in games)
                MetricBar(
                  label: e.game.name,
                  subtitle: limiterCaption(e.limiter),
                  value: e.avgFps,
                  max: games.first.avgFps,
                  valueText: '${e.avgFps.round()} FPS',
                  color: e.avgFps >= 60
                      ? palette.good
                      : (e.avgFps >= 30 ? palette.warn : palette.bad),
                ),
            ],
          ),
        ),
        const SizedBox(height: Space.s),
        CompatibilityCard(report: report),
      ],
    );
  }
}
