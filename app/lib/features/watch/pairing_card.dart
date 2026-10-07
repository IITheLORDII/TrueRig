import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:perf_engine/perf_engine.dart';

import 'package:darbogaz/core/devices.dart';
import 'package:darbogaz/core/theme/app_theme.dart';
import 'package:darbogaz/core/theme/tokens.dart';
import 'package:darbogaz/core/widgets/common.dart';

/// Phone ⇄ watch pairing: verdict, reasons and how many watch features
/// work with this phone. [onChangePhone] lets the watch page pick another
/// phone; elsewhere tapping opens "Saatim".
class PairingCard extends ConsumerWidget {
  const PairingCard({super.key, this.onChangePhone});

  final VoidCallback? onChangePhone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = ref.watch(watchReportProvider);
    if (r == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final palette = context.palette;
    final phone = r.phone;
    final (String verdict, Tone tone) = phone == null
        ? ('Telefon seç', Tone.warn)
        : r.isCompatible
        ? ('Uyumlu', Tone.good)
        : ('Uyumsuz', Tone.bad);
    final reasons = r.issues
        .where((i) => i.severity != IssueSeverity.info || phone != null)
        .map((i) => i.message)
        .toList();

    Widget end(IconData icon, String name) => Expanded(
      child: Column(
        children: [
          Icon(icon, color: theme.colorScheme.primary),
          const SizedBox(height: Space.xs),
          Text(
            name,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );

    return SectionCard(
      title: 'Telefon ⇄ Saat eşleşmesi',
      icon: Icons.link_rounded,
      trailing: VerdictChip(verdict, tone: tone),
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.m),
        onTap:
            onChangePhone ??
            () {
              ref.read(activeDeviceProvider.notifier).set(DeviceKind.watch);
              context.go('/devices');
            },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                end(
                  phone?.platform == MobilePlatform.ios
                      ? Icons.phone_iphone_rounded
                      : Icons.phone_android_rounded,
                  phone?.displayName ?? 'Telefon seçilmedi',
                ),
                Icon(
                  phone == null || !r.isCompatible
                      ? Icons.link_off_rounded
                      : Icons.sync_alt_rounded,
                  color: switch (tone) {
                    Tone.good => palette.good,
                    Tone.bad => palette.bad,
                    _ => palette.warn,
                  },
                ),
                end(Icons.watch_rounded, r.watch.displayName),
              ],
            ),
            const SizedBox(height: Space.s),
            if (phone != null)
              Text(
                '${r.availableFeatures.length} / ${r.watch.features.length} '
                'saat özelliği bu telefonla çalışır',
                textAlign: TextAlign.center,
                style: theme.textTheme.labelMedium,
              ),
            for (final m in reasons.take(2))
              Padding(
                padding: const EdgeInsets.only(top: Space.xs),
                child: Text(
                  m,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: palette.muted,
                  ),
                ),
              ),
            if (onChangePhone != null)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: onChangePhone,
                  icon: const Icon(Icons.swap_horiz_rounded),
                  label: const Text('Eşlenecek telefonu değiştir'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
