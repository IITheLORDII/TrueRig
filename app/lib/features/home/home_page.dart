import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:perf_engine/perf_engine.dart';

import 'package:darbogaz/features/detect/detect_prompt.dart';
import 'package:darbogaz/features/onboarding/onboarding_page.dart';
import 'package:darbogaz/core/brand/truerig_logo.dart';
import 'package:darbogaz/core/devices.dart';
import 'package:darbogaz/core/platform/store_app.dart';
import 'package:darbogaz/core/providers.dart';
import 'package:darbogaz/core/saved_devices.dart';
import 'package:darbogaz/core/theme/app_theme.dart';
import 'package:darbogaz/core/theme/tokens.dart';
import 'package:darbogaz/core/widgets/common.dart';
import 'package:darbogaz/core/widgets/device_chip.dart';
import 'package:darbogaz/core/widgets/profile_action.dart';
import 'package:darbogaz/features/detect/self_device.dart';
import 'package:darbogaz/features/device/add_device_sheet.dart';
import 'package:darbogaz/features/device/device_page.dart';
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
        padding: const EdgeInsets.fromLTRB(
          Space.page,
          Space.xs,
          Space.page,
          Space.xl,
        ),
        children: [
          const _PendingAdd(),
          const _SelfPhoneBanner(),
          const _StatusCard(),
          const SizedBox(height: Space.s),
          const _AdvisorCard(),
          const SizedBox(height: Space.s),
          const _TryCard(),
          const SectionHeader('Ne öğrenmek istersin?'),
          const _Questions(),
          if (hasWatch) ...[
            const SectionHeader('Eşleşme'),
            const PairingCard(),
          ],
          const SectionHeader('Diğer'),
          const _More(),
        ],
      ),
    );
  }
}

/// One line per device; tapping a configured one opens its analysis,
/// an empty one the "how do you want to add it" sheet.
class _StatusCard extends ConsumerWidget {
  const _StatusCard();

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
        tone: pct < 10 ? Tone.good : (pct < 20 ? Tone.warn : Tone.bad),
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
        padding: const EdgeInsets.symmetric(vertical: Space.xs),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Space.l,
                Space.s,
                Space.l,
                Space.xs,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Cihazların',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Flexible(
                    child: Text(
                      'Dokun, sonucu gör',
                      textAlign: TextAlign.end,
                      style: theme.textTheme.labelSmall?.copyWith(
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
    final count = ref
        .watch(savedDevicesProvider)
        .of(kind)
        .where((d) => !d.isEmpty)
        .length;
    return ListTile(
      leading: Icon(
        deviceIcon(kind),
        color: Theme.of(context).colorScheme.primary,
      ),
      title: Text(
        name ?? '${kind.mine} eklenmedi',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: configured
            ? const TextStyle(fontWeight: FontWeight.w600)
            : TextStyle(color: context.palette.muted),
      ),
      subtitle: count > 1 ? Text('$count kayıtlı ${kind.label}') : null,
      trailing: configured
          ? verdict
          : ActionChip(
              avatar: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Ekle'),
              onPressed: () => showAddDeviceSheet(context, ref, kind),
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

/// The three things most people open the app for, in everyday words.
class _Questions extends ConsumerWidget {
  const _Questions();

  /// First configured device (PC, then phone, then watch), if any.
  DeviceKind? _firstDevice(WidgetRef ref) {
    if (ref.read(buildProvider).cpu != null) return DeviceKind.pc;
    if (ref.read(phoneSpecProvider) != null) return DeviceKind.phone;
    if (ref.read(watchReportProvider) != null) return DeviceKind.watch;
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        _QuestionCard(
          icon: Icons.sports_esports_rounded,
          question: 'Cihazım oyunları ve programları kaldırır mı?',
          hint: 'Bilgisayar, telefon ya da saatinin sade bir karnesi',
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
        _QuestionCard(
          icon: Icons.compare_arrows_rounded,
          question: 'Hangisi daha iyi?',
          hint: 'İki bilgisayarı, telefonu ya da saati yan yana koy',
          onTap: () => context.go('/compare'),
        ),
        _QuestionCard(
          icon: Icons.sell_rounded,
          question: 'Nereden en ucuza alırım?',
          hint: 'Parçayı ya da modeli yaz, mağaza fiyatlarını gör',
          onTap: () => context.go('/prices'),
        ),
      ],
    );
  }
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({
    required this.icon,
    required this.question,
    required this.hint,
    required this.onTap,
  });

  final IconData icon;
  final String question;
  final String hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.s),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(Space.l),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(Radii.m),
                  ),
                  child: Icon(icon, color: theme.colorScheme.primary),
                ),
                const SizedBox(width: Space.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        question,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        hint,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: context.palette.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "Bilgisayarı ne için alıyorsun?": a few questions, then systems that
/// fit the job (not the looks or the price tag).
class _AdvisorCard extends StatelessWidget {
  const _AdvisorCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      color: theme.colorScheme.primary.withValues(alpha: 0.12),
      child: InkWell(
        onTap: () => context.push('/advisor'),
        child: Padding(
          padding: const EdgeInsets.all(Space.l),
          child: Row(
            children: [
              Icon(
                Icons.lightbulb_rounded,
                size: 36,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: Space.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bilgisayarı ne için alıyorsun?',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Birkaç kısa soru; işine gerçekten yetecek bilgisayarı '
                      'önerelim, yanlış alımdan kurtul.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Kaydetmeden dene": scratch area that saves nothing.
class _TryCard extends StatelessWidget {
  const _TryCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget action(IconData icon, String label, String to) => Expanded(
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
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
            Text(label, textAlign: TextAlign.center),
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
          Text(
            'Kaydetmeden dene: hiçbir şey kaydedilmez, uygulama kapanınca '
            'silinir.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: context.palette.muted,
            ),
          ),
          const SizedBox(height: Space.s),
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

/// Less common entry points as a plain list.
class _More extends ConsumerWidget {
  const _More();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget item(IconData icon, String title, VoidCallback onTap) => ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
    return Card(
      child: Column(
        children: [
          item(
            Icons.shopping_cart_rounded,
            'PC topla, en ucuz sepeti hazırla',
            () => context.push('/sandbox?tab=pc'),
          ),
          item(
            Icons.laptop_chromebook_rounded,
            'Hazır bilgisayar / laptop seç',
            () => context.push('/pick/prebuilt'),
          ),
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
            Icons.devices_rounded,
            'Cihazlarım',
            () => context.go('/devices'),
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
