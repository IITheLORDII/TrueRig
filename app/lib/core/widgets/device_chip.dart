import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:darbogaz/core/devices.dart';
import 'package:darbogaz/core/providers.dart';
import 'package:darbogaz/core/theme/app_theme.dart';
import 'package:darbogaz/core/theme/tokens.dart';
import 'package:darbogaz/core/widgets/app_controls.dart';

IconData deviceIcon(DeviceKind kind) => switch (kind) {
  DeviceKind.pc => Icons.desktop_windows_rounded,
  DeviceKind.phone => Icons.smartphone_rounded,
  DeviceKind.watch => Icons.watch_rounded,
};

/// Name of the user's device of [kind], or null when it is not set up.
String? deviceName(WidgetRef ref, DeviceKind kind) {
  switch (kind) {
    case DeviceKind.pc:
      final b = ref.watch(buildProvider);
      final label = ref.watch(prebuiltProvider)?.label;
      if (label != null) return label;
      final parts = [b.cpu?.model, b.gpu?.model].nonNulls;
      return parts.isEmpty ? null : parts.join(' + ');
    case DeviceKind.phone:
      return ref.watch(phoneSpecProvider)?.phone.displayName;
    case DeviceKind.watch:
      return ref.watch(watchReportProvider)?.watch.displayName;
  }
}

/// Active device switcher shown above the "Analiz" content.
class DeviceChip extends ConsumerWidget {
  const DeviceChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kind = ref.watch(activeDeviceProvider);
    final name = deviceName(ref, kind) ?? '${kind.label} seçilmedi';
    final names = {for (final k in DeviceKind.values) k: deviceName(ref, k)};
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(Radii.m),
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.m),
        onTap: () async {
          final picked = await showOptionSheet<DeviceKind>(
            context: context,
            title: 'Hangi cihazı analiz edelim?',
            options: DeviceKind.values,
            labelOf: (k) =>
                '${k.label}: ${names[k] ?? 'eklenmedi (Cihazlarım\'dan ekle)'}',
            selected: kind,
          );
          if (picked != null) {
            ref.read(activeDeviceProvider.notifier).set(picked);
          }
        },
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: kMinTap),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.m),
            child: Row(
              children: [
                Icon(deviceIcon(kind), size: 20, color: scheme.primary),
                const SizedBox(width: Space.s),
                Expanded(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                Icon(Icons.unfold_more_rounded, color: context.palette.muted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
