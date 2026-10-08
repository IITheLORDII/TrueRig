import 'package:flutter/material.dart';

import 'package:darbogaz/core/widgets/term_info.dart';

import 'package:darbogaz/core/widgets/explain.dart';

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
      bottomNavigationBar: const InnerNavBar(),
      appBar: AppBar(
        leading: const PageBackButton(),
        title: const BrandTitle('Profil'),
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
          SectionCard(
            title: 'Sık sorulanlar',
            icon: Icons.help_outline_rounded,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Explain.term(Term.bottleneck),
                const SizedBox(height: Space.s),
                Explain.term(Term.fps),
                const SizedBox(height: Space.s),
                const Explain(
                  question: 'Fiyatlar nereden geliyor?',
                  answer:
                      'Mağazaların herkese açık sayfalarından günde bir kez '
                      'toplanır. Son fiyat için mağazaya bak.',
                ),
                const SizedBox(height: Space.s),
                const Explain(
                  question: 'Bu sayılar ne kadar doğru?',
                  answer: kEstimateDisclaimer,
                ),
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
