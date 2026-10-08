import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:perf_engine/perf_engine.dart';

import 'package:darbogaz/core/devices.dart';
import 'package:darbogaz/core/providers.dart';
import 'package:darbogaz/core/saved_devices.dart';
import 'package:darbogaz/core/theme/app_theme.dart';
import 'package:darbogaz/core/theme/tokens.dart';
import 'package:darbogaz/core/verdicts.dart';
import 'package:darbogaz/core/widgets/cards.dart';
import 'package:darbogaz/core/widgets/common.dart';
import 'package:darbogaz/core/widgets/device_chip.dart';
import 'package:darbogaz/features/device/add_device_sheet.dart';
import 'package:darbogaz/features/device/device_page.dart';

/// "Cihazların": one line per device; tapping a configured one opens its
/// analysis, an empty one the "how do you want to add it" sheet.
class HomeStatusCard extends ConsumerWidget {
  const HomeStatusCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final general = ref.watch(generalBottleneckProvider);
    final spec = ref.watch(phoneSpecProvider);
    final watch = ref.watch(watchReportProvider);
    final phoneSummary = spec == null
        ? null
        : const PhoneEstimator().summarize(spec);
    final theme = Theme.of(context);

    Widget? pcVerdict() {
      final g = general;
      if (g == null) return null;
      final pct = g.bottleneckPercent;
      return VerdictChip(
        pct < 10 ? 'Dengeli' : (pct < 20 ? 'Biraz darboğaz' : 'Darboğaz'),
        tone: bottleneckTone(pct),
      );
    }

    Widget? watchVerdict() {
      final w = watch;
      if (w == null) return null;
      if (w.phone == null) {
        return const VerdictChip('Telefon seç', tone: Tone.warn);
      }
      return VerdictChip(
        w.isCompatible ? 'Uyumlu' : 'Uyumsuz',
        tone: w.isCompatible ? Tone.good : Tone.bad,
      );
    }

    return HeroFrame(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Space.s),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Space.l,
                Space.xs,
                Space.l,
                Space.xs,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Cihazların',
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  Flexible(
                    child: Text(
                      'Dokun, sonucu gör',
                      textAlign: TextAlign.end,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: context.palette.muted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            _StatusRow(
              kind: DeviceKind.pc,
              name: deviceName(ref, DeviceKind.pc),
              verdict: pcVerdict(),
            ),
            _StatusRow(
              kind: DeviceKind.phone,
              name: spec?.phone.displayName,
              verdict: phoneSummary == null
                  ? null
                  : VerdictChip(phoneSummary.tier.label, tone: Tone.brand),
            ),
            _StatusRow(
              kind: DeviceKind.watch,
              name: watch?.watch.displayName,
              verdict: watchVerdict(),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusRow extends ConsumerWidget {
  const _StatusRow({required this.kind, required this.name, this.verdict});

  final DeviceKind kind;
  final String? name;
  final Widget? verdict;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configured = name != null;
    final theme = Theme.of(context);
    final count = ref
        .watch(savedDevicesProvider)
        .of(kind)
        .where((d) => !d.isEmpty)
        .length;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: Space.l),
      leading: IconTile(
        deviceIcon(kind),
        size: 40,
        color: configured ? null : context.palette.muted,
      ),
      title: Text(
        name ?? '${kind.mine} eklenmedi',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: configured
            ? theme.textTheme.titleSmall
            : theme.textTheme.bodyMedium?.copyWith(
                color: context.palette.muted,
              ),
      ),
      subtitle: count > 1 ? Text('$count kayıtlı ${kind.label}') : null,
      trailing: configured
          ? verdict
          : TextButton.icon(
              onPressed: () => showAddDeviceSheet(context, ref, kind),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Ekle'),
            ),
      onTap: () {
        if (!configured) {
          showAddDeviceSheet(context, ref, kind);
          return;
        }
        ref.read(activeDeviceProvider.notifier).set(kind);
        context.go('/analysis');
      },
    );
  }
}
