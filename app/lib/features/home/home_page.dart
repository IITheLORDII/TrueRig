import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:darbogaz/features/detect/detect_prompt.dart';
import 'package:darbogaz/features/onboarding/onboarding_page.dart';
import 'package:darbogaz/core/brand/truerig_logo.dart';
import 'package:darbogaz/core/devices.dart';
import 'package:darbogaz/core/theme/tokens.dart';
import 'package:darbogaz/core/widgets/common.dart';
import 'package:darbogaz/core/widgets/profile_action.dart';
import 'package:darbogaz/features/detect/self_device.dart';
import 'package:darbogaz/features/device/add_device_sheet.dart';
import 'package:darbogaz/features/home/home_hero.dart';
import 'package:darbogaz/features/home/home_sections.dart';
import 'package:darbogaz/features/home/home_status.dart';
import 'package:darbogaz/features/watch/pairing_card.dart';

/// "Ana Sayfa": your devices at a glance and three everyday questions.
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasWatch = ref.watch(watchReportProvider) != null;
    return Scaffold(
      appBar: AppBar(
        title: const BrandTitle('Ana Sayfa'),
        actions: const [ProfileAction()],
      ),
      body: ListView(
        padding: Insets.page,
        children: [
          const _PendingAdd(),
          const _SelfPhoneBanner(),
          const HomeHeroCard(),
          const SizedBox(height: Space.cardGap),
          const HomeStatusCard(),
          const SizedBox(height: Space.cardGap),
          const HomeAdvisorCard(),
          const SizedBox(height: Space.cardGap),
          const HomeTryCard(),
          const SectionHeader('Ne öğrenmek istersin?'),
          const HomeQuestions(),
          if (hasWatch) ...[
            const SectionHeader('Eşleşme'),
            const PairingCard(),
          ],
          const SectionHeader('Kısayollar'),
          const HomeShortcuts(),
        ],
      ),
    );
  }
}

/// Opens the "add" sheet for the device picked on the welcome tour, once.
/// On the website it otherwise asks once, in a small popup, whether to
/// recognise this computer (instead of a full detection page).
class _PendingAdd extends ConsumerWidget {
  const _PendingAdd();

  /// A popup is already scheduled or open.
  static bool _busy = false;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kind = ref.watch(pendingAddProvider);
    if (kind != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        ref.read(pendingAddProvider.notifier).set(null);
        showAddDeviceSheet(context, ref, kind);
      });
    } else if (!_busy && shouldAskDetect(ref)) {
      _busy = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (context.mounted) await showDetectPrompt(context, ref);
        _busy = false;
      });
    }
    return const SizedBox.shrink();
  }
}

/// "Bu telefon: Galaxy S24" when the running phone is known but not added.
class _SelfPhoneBanner extends ConsumerWidget {
  const _SelfPhoneBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final self = ref.watch(selfPhoneProvider).value;
    final phone = ref.watch(phoneSpecProvider)?.phone;
    if (self == null || phone?.id == self.phone.id) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.s),
      child: ActionChip(
        avatar: const Icon(Icons.phone_iphone_rounded, size: 18),
        label: Text('Bu telefon: ${self.phone.model}'),
        onPressed: () {
          ref
              .read(phoneSelectionProvider.notifier)
              .select(self.phone, socId: self.socId);
          ref.read(activeDeviceProvider.notifier).set(DeviceKind.phone);
        },
      ),
    );
  }
}
