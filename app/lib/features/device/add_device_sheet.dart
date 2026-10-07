import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:darbogaz/core/devices.dart';
import 'package:darbogaz/core/theme/app_theme.dart';
import 'package:darbogaz/core/theme/tokens.dart';
import 'package:darbogaz/features/detect/self_device.dart';

class _AddOption {
  const _AddOption(this.icon, this.title, this.subtitle, this.run);

  final IconData icon;
  final String title;
  final String subtitle;
  final void Function(BuildContext context, WidgetRef ref) run;
}

/// "Nasıl eklemek istersin?": the easy ways to add a device, explained in
/// everyday words. Used from Ana Sayfa, empty Analiz screens and onboarding.
Future<void> showAddDeviceSheet(
  BuildContext context,
  WidgetRef ref,
  DeviceKind kind,
) async {
  ref.read(activeDeviceProvider.notifier).set(kind);
  final self = ref.read(selfPhoneProvider).value;
  final options = switch (kind) {
    DeviceKind.pc => [
      _AddOption(
        Icons.laptop_chromebook_rounded,
        'Laptop ya da hazır bilgisayar adını seç',
        'Örn. Casper Excalibur G770, ASUS TUF F15. Mağaza ilanının başlığını '
            'yapıştırabilirsin de.',
        (c, _) => c.push('/pick/prebuilt'),
      ),
      if (kIsWeb)
        _AddOption(
          Icons.radar_rounded,
          'Bu bilgisayarı otomatik tanı',
          'Tarayıcı izin verirse donanımını kendimiz okuruz.',
          (c, _) => c.push('/detect'),
        ),
      _AddOption(
        Icons.build_circle_rounded,
        'Parçaları tek tek seç',
        'İşlemci, ekran kartı ve RAM\'ini biliyorsan (bilenler için).',
        (c, _) => c.go('/devices?kind=pc'),
      ),
    ],
    DeviceKind.phone => [
      if (self != null)
        _AddOption(
          Icons.smartphone_rounded,
          'Bu telefon: ${self.phone.displayName}',
          'Şu an kullandığın telefon; tek dokunuşla eklenir.',
          (c, r) {
            r
                .read(phoneSelectionProvider.notifier)
                .select(self.phone, socId: self.socId);
            c.go('/analysis');
          },
        ),
      _AddOption(
        Icons.search_rounded,
        'Listeden telefonunu seç',
        'Marka ya da model yazman yeterli (örn. iPhone 15, Galaxy S24).',
        (c, _) => c.push('/pick/phone'),
      ),
    ],
    DeviceKind.watch => [
      _AddOption(
        Icons.watch_rounded,
        'Listeden saatini seç',
        'Telefonunla uyumlu olup olmadığını hemen gösteririz.',
        (c, _) => c.push('/pick/watch'),
      ),
    ],
  };

  final picked = await showModalBottomSheet<_AddOption>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Space.l, 0, Space.l, Space.l),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              switch (kind) {
                DeviceKind.pc => 'Bilgisayarını nasıl ekleyelim?',
                DeviceKind.phone => 'Telefonunu nasıl ekleyelim?',
                DeviceKind.watch => 'Saatini ekleyelim',
              },
              style: Theme.of(ctx).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: Space.s),
            for (final o in options)
              Padding(
                padding: const EdgeInsets.only(bottom: Space.s),
                child: Card(
                  clipBehavior: Clip.antiAlias,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: Space.m,
                      vertical: Space.xs,
                    ),
                    leading: Icon(
                      o.icon,
                      size: 28,
                      color: Theme.of(ctx).colorScheme.primary,
                    ),
                    title: Text(
                      o.title,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      o.subtitle,
                      style: TextStyle(color: ctx.palette.muted),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.of(ctx).pop(o),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
  if (picked != null && context.mounted) picked.run(context, ref);
}
