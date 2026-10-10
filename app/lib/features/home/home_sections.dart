import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:darbogaz/core/devices.dart';
import 'package:darbogaz/core/platform/store_app.dart';
import 'package:darbogaz/core/providers.dart';
import 'package:darbogaz/core/theme/tokens.dart';
import 'package:darbogaz/core/widgets/cards.dart';
import 'package:darbogaz/core/widgets/common.dart';
import 'package:darbogaz/features/device/add_device_sheet.dart';

/// "Bilgisayarı ne için alıyorsun?": the one featured card on Ana Sayfa.
class HomeAdvisorCard extends StatelessWidget {
  const HomeAdvisorCard({super.key});

  @override
  Widget build(BuildContext context) => NavCard(
    emphasized: true,
    icon: Icons.lightbulb_rounded,
    title: 'Bilgisayarı ne için alıyorsun?',
    subtitle: 'Birkaç kolay soru, sana uygun bilgisayar.',
    onTap: () => context.push('/advisor'),
  );
}

/// The three things most people open the app for, in everyday words.
class HomeQuestions extends ConsumerWidget {
  const HomeQuestions({super.key});

  /// First configured device (PC, then phone, then watch), if any.
  DeviceKind? _firstDevice(WidgetRef ref) {
    if (ref.read(buildProvider).cpu != null) return DeviceKind.pc;
    if (ref.read(phoneSpecProvider) != null) return DeviceKind.phone;
    if (ref.read(watchReportProvider) != null) return DeviceKind.watch;
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = [
      NavCard(
        icon: Icons.sports_esports_rounded,
        title: 'Cihazım oyunları ve programları kaldırır mı?',
        subtitle: 'Bilgisayar, telefon ya da saatinin sade bir karnesi',
        onTap: () {
          final kind = _firstDevice(ref);
          if (kind == null) {
            showAddDeviceSheet(context, ref, DeviceKind.pc);
            return;
          }
          ref.read(activeDeviceProvider.notifier).set(kind);
          context.go('/analysis');
        },
      ),
      NavCard(
        icon: Icons.compare_arrows_rounded,
        title: 'Hangisi daha iyi?',
        subtitle: 'İki bilgisayarı, telefonu ya da saati yan yana koy',
        onTap: () => context.go('/compare'),
      ),
      NavCard(
        icon: Icons.sell_rounded,
        title: 'Nereden en ucuza alırım?',
        subtitle: 'Parçayı ya da modeli yaz, mağaza fiyatlarını gör',
        onTap: () => context.go('/prices'),
      ),
    ];
    return Column(
      children: [
        for (final c in items)
          Padding(
            padding: const EdgeInsets.only(bottom: Space.cardGap),
            child: c,
          ),
      ],
    );
  }
}

/// "Kaydetmeden dene": scratch area that saves nothing.
class HomeTryCard extends StatelessWidget {
  const HomeTryCard({super.key});

  @override
  Widget build(BuildContext context) {
    Widget action(IconData icon, String label, String to) => Expanded(
      child: FilledButton.tonal(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 72),
          padding: const EdgeInsets.symmetric(
            vertical: Space.s,
            horizontal: Space.xs,
          ),
        ),
        onPressed: () => context.push(to),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon),
            const SizedBox(height: Space.xs),
            Text(label, textAlign: TextAlign.center, maxLines: 2),
          ],
        ),
      ),
    );
    return SectionCard(
      title: 'Kaydetmeden dene',
      icon: Icons.science_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Footnote('Dene, karşılaştır. Hiçbir şey kaydedilmez.'),
          const SizedBox(height: Space.m),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              action(
                Icons.travel_explore_rounded,
                'Model gez',
                '/sandbox?tab=browse',
              ),
              const SizedBox(width: Space.s),
              action(Icons.build_circle_rounded, 'PC topla', '/sandbox?tab=pc'),
              const SizedBox(width: Space.s),
              action(
                Icons.compare_arrows_rounded,
                'Karşılaştır',
                '/sandbox?compare=1',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Less common entry points (no duplicates of tabs or cards above).
class HomeShortcuts extends StatelessWidget {
  const HomeShortcuts({super.key});

  @override
  Widget build(BuildContext context) {
    Widget item(IconData icon, String title, VoidCallback onTap) => ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          if (isStoreApp)
            item(
              Icons.qr_code_scanner_rounded,
              'Kutudaki barkodu tara',
              () => context.push('/prices/scan'),
            )
          else
            item(
              Icons.radar_rounded,
              'Bu bilgisayarı otomatik tanı',
              () => context.push('/detect'),
            ),
          item(
            Icons.help_outline_rounded,
            'Nasıl kullanılır?',
            () => context.push('/welcome'),
          ),
        ],
      ),
    );
  }
}
