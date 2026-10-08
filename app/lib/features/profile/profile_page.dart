import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';
import 'package:darbogaz/core/widgets/page_nav.dart';
import 'package:darbogaz/core/widgets/app_controls.dart';
import 'package:darbogaz/core/providers.dart';
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
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
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
          const SizedBox(height: 12),
          const SavedDevicesCard(),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.help_outline_rounded),
              title: const Text('Nasıl kullanılır?'),
              subtitle: const Text('Kısa tanıtımı yeniden göster'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => context.push('/welcome'),
            ),
          ),
          const SizedBox(height: 12),
          const SectionCard(
            title: 'Tahminler hakkında',
            icon: Icons.info_outline_rounded,
            child: Text(
              '$kEstimateDisclaimer\n\nFPS hesabı işlemcinin besleyebildiği '
              've ekran kartının çizebildiği kare hızlarının birleşimidir. '
              'Darboğaz yüzdesi, güçlü bileşenin ne kadarının boşta kaldığını '
              'gösterir. Fiyat bağlantıları mağazaların kendi arama '
              'sayfalarını açar.',
            ),
          ),
          const SizedBox(height: 12),
          const AboutListTile(
            icon: Icon(Icons.memory_rounded),
            applicationName: kAppName,
            applicationIcon: TrueRigMark(size: 40),
            applicationVersion: '1.0.0',
            aboutBoxChildren: [Text(kEstimateDisclaimer)],
          ),
        ],
      ),
    );
  }
}
