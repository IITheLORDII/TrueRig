import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:perf_engine/perf_engine.dart';

import 'package:darbogaz/core/brand/truerig_logo.dart';
import 'package:darbogaz/core/devices.dart';
import 'package:darbogaz/core/platform/store_app.dart';
import 'package:darbogaz/core/providers.dart';
import 'package:darbogaz/core/theme/app_theme.dart';
import 'package:darbogaz/core/theme/tokens.dart';
import 'package:darbogaz/core/widgets/common.dart';
import 'package:darbogaz/core/widgets/device_chip.dart';
import 'package:darbogaz/core/widgets/profile_action.dart';
import 'package:darbogaz/features/detect/self_device.dart';
import 'package:darbogaz/features/device/device_page.dart';
import 'package:darbogaz/features/watch/pairing_card.dart';

/// "Ana Sayfa": status of the user's devices and entry points to every
/// feature.
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
          const _SelfPhoneBanner(),
          const _StatusCard(),
          const SectionHeader('Ne yapmak istersin?'),
          const _FeatureGrid(),
          if (hasWatch) ...[
            const SectionHeader('Eşleşme'),
            const PairingCard(),
          ],
        ],
      ),
    );
  }
}

/// One line per device; tapping a configured one opens its analysis.
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
      final part = switch (g.limiter) {
        Limiter.cpu => 'İşlemci',
        Limiter.gpu => 'Ekran kartı',
        Limiter.balanced => 'Dengeli',
      };
      return VerdictChip(
        '%${g.bottleneckPercent.round()} · $part',
        tone: g.bottleneckPercent < 10
            ? Tone.good
            : (g.bottleneckPercent < 20 ? Tone.warn : Tone.bad),
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
                  Text(
                    'Durumun',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Genel · '
                    '${ref.watch(analysisSettingsProvider).resolution.label}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: context.palette.muted,
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
                  : VerdictChip(
                      '${phoneSummary.score.round()} · '
                      '${phoneSummary.tier.label}',
                      tone: Tone.brand,
                    ),
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
    return ListTile(
      dense: true,
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
      trailing: configured
          ? verdict
          : const Icon(Icons.add_circle_outline_rounded),
      onTap: () {
        ref.read(activeDeviceProvider.notifier).set(kind);
        context.go(configured ? '/analysis' : '/devices');
      },
    );
  }
}

class _Feature {
  const _Feature(this.icon, this.title, this.subtitle, this.onTap);
  final IconData icon;
  final String title;
  final String subtitle;
  final void Function(BuildContext context) onTap;
}

class _FeatureGrid extends StatelessWidget {
  const _FeatureGrid();

  @override
  Widget build(BuildContext context) {
    final features = [
      _Feature(
        Icons.insights_rounded,
        'Darboğaz analizi',
        'Genel ve oyun bazlı',
        (c) => c.go('/analysis'),
      ),
      _Feature(
        Icons.compare_arrows_rounded,
        'Karşılaştır',
        'Cihazını başkasıyla kıyasla',
        (c) => c.go('/compare'),
      ),
      _Feature(
        Icons.sell_rounded,
        'Fiyat & nerede',
        'Mağaza fiyatları, seri no',
        (c) => c.go('/prices'),
      ),
      _Feature(
        Icons.devices_rounded,
        'Cihazlarım',
        'Bilgisayar, telefon, saat',
        (c) => c.go('/devices'),
      ),
      _Feature(
        Icons.laptop_chromebook_rounded,
        'Hazır sistem',
        'Laptop ya da ilan başlığı',
        (c) => c.push('/pick/prebuilt'),
      ),
      if (isStoreApp)
        _Feature(
          Icons.qr_code_scanner_rounded,
          'Barkod tara',
          'Kutudaki barkoddan fiyat',
          (c) => c.push('/prices/scan'),
        )
      else
        _Feature(
          Icons.radar_rounded,
          'Bilgisayarımı algıla',
          'Tarayıcıdan donanım okuma',
          (c) => c.push('/detect'),
        ),
    ];
    return LayoutBuilder(
      builder: (context, box) {
        final width = (box.maxWidth - Space.s) / 2;
        return Wrap(
          spacing: Space.s,
          runSpacing: Space.s,
          children: [
            for (final f in features)
              SizedBox(
                width: width,
                child: _FeatureTile(feature: f),
              ),
          ],
        );
      },
    );
  }
}

class _FeatureTile extends StatelessWidget {
  const _FeatureTile({required this.feature});

  final _Feature feature;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => feature.onTap(context),
        child: Padding(
          padding: const EdgeInsets.all(Space.m),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(feature.icon, color: theme.colorScheme.primary),
              const SizedBox(height: Space.s),
              Text(
                feature.title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                feature.subtitle,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: context.palette.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
