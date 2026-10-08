import 'package:flutter/material.dart';

import 'package:darbogaz/core/theme/tokens.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';
import 'package:darbogaz/core/widgets/page_nav.dart';
import 'package:darbogaz/core/widgets/app_controls.dart';
import 'package:darbogaz/core/providers.dart';
import 'package:darbogaz/core/widgets/cards.dart';
import 'package:darbogaz/core/widgets/common.dart';
import 'package:darbogaz/core/brand/truerig_logo.dart';
import 'package:darbogaz/features/profile/saved_devices_card.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    return Scaffold(
      appBar: AppBar(
        leading: const PageBackButton(),
        title: const BrandTitle('Profil'),
        actions: const [HomeButton()],
      ),
      body: ListView(
        padding: Insets.page,
        children: [
          SectionCard(
            title: 'Görünüm',
            icon: Icons.palette_rounded,
            child: AppSegmented<ThemeMode>(
              values: const [ThemeMode.dark, ThemeMode.light, ThemeMode.system],
              selected: mode,
              labelOf: (m) => switch (m) {
                ThemeMode.dark => 'Koyu',
                ThemeMode.light => 'Açık',
                ThemeMode.system => 'Sistem',
              },
              onChanged: (m) => ref.read(themeModeProvider.notifier).set(m),
            ),
          ),
          const SizedBox(height: Space.cardGap),
          const SavedDevicesCard(),
          const SizedBox(height: Space.cardGap),
          NavCard(
            icon: Icons.help_outline_rounded,
            title: 'Nasıl kullanılır?',
            subtitle: 'Kısa tanıtımı yeniden göster',
            onTap: () => context.push('/welcome'),
          ),
          const SizedBox(height: Space.cardGap),
          const SectionCard(
            title: 'Tahminler hakkında',
            icon: Icons.info_outline_rounded,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BulletRow(
                  'FPS, işlemcinin hazırlayabildiği ve ekran kartının '
                  'çizebildiği kare sayısından hesaplanır.',
                ),
                BulletRow(
                  'Darboğaz yüzdesi, güçlü parçanın ne kadarının boşta '
                  'kaldığını gösterir.',
                ),
                BulletRow(
                  'Fiyatlar mağazaların herkese açık sayfalarından günde bir '
                  'kez toplanır. Son fiyat için mağazaya bak.',
                ),
                SizedBox(height: Space.xs),
                Footnote(kEstimateDisclaimer),
              ],
            ),
          ),
          const SizedBox(height: Space.cardGap),
          const Card(
            child: AboutListTile(
              icon: Icon(Icons.info_outline_rounded),
              applicationName: kAppName,
              applicationIcon: TrueRigMark(size: 40),
              applicationVersion: '1.0.0',
              aboutBoxChildren: [Text(kEstimateDisclaimer)],
              child: Text('Hakkında'),
            ),
          ),
        ],
      ),
    );
  }
}
