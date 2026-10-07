import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:perf_engine/perf_engine.dart';

import 'package:darbogaz/core/brand/truerig_logo.dart';
import 'package:darbogaz/core/devices.dart';
import 'package:darbogaz/core/providers.dart';
import 'package:darbogaz/core/theme/tokens.dart';
import 'package:darbogaz/core/widgets/common.dart';
import 'package:darbogaz/core/widgets/device_card.dart';
import 'package:darbogaz/core/widgets/profile_action.dart';
import 'package:darbogaz/features/detect/self_device.dart';
import 'package:darbogaz/features/watch/watch_pages.dart';

/// "Cihazlarım": all three devices with an at-a-glance result each.
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  void _open(BuildContext context, WidgetRef ref, DeviceKind kind) {
    ref.read(activeDeviceProvider.notifier).set(kind);
    context.push('/devices/${kind.name}');
  }

  void _analyze(BuildContext context, WidgetRef ref, DeviceKind kind) {
    ref.read(activeDeviceProvider.notifier).set(kind);
    context.go('/analysis');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(activeDeviceProvider);
    return Scaffold(
      appBar: AppBar(
        title: const BrandTitle('Cihazlarım'),
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
          const _QuickActions(),
          const SectionHeader('Cihazların'),
          _PcCard(
            active: active == DeviceKind.pc,
            onEdit: () => _open(context, ref, DeviceKind.pc),
            onAnalyze: () => _analyze(context, ref, DeviceKind.pc),
          ),
          const SizedBox(height: Space.s),
          _PhoneCard(
            active: active == DeviceKind.phone,
            onEdit: () => _open(context, ref, DeviceKind.phone),
            onAnalyze: () => _analyze(context, ref, DeviceKind.phone),
          ),
          const SizedBox(height: Space.s),
          _WatchCard(
            active: active == DeviceKind.watch,
            onEdit: () => _open(context, ref, DeviceKind.watch),
            onAnalyze: () => _analyze(context, ref, DeviceKind.watch),
          ),
        ],
      ),
    );
  }
}

class _QuickActions extends ConsumerWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final self = ref.watch(selfPhoneProvider).value;
    final phone = ref.watch(phoneSpecProvider)?.phone;
    final showSelf = self != null && phone?.id != self.phone.id;
    return SizedBox(
      height: kMinTap,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          if (showSelf) ...[
            ActionChip(
              avatar: const Icon(Icons.phone_iphone_rounded, size: 18),
              label: Text('Bu telefon: ${self.phone.model}'),
              onPressed: () {
                ref
                    .read(phoneSelectionProvider.notifier)
                    .select(self.phone, socId: self.socId);
                ref.read(activeDeviceProvider.notifier).set(DeviceKind.phone);
              },
            ),
            const SizedBox(width: Space.s),
          ],
          ActionChip(
            avatar: const Icon(Icons.laptop_chromebook_rounded, size: 18),
            label: const Text('Hazır sistem seç'),
            onPressed: () => context.push('/pick/prebuilt'),
          ),
          if (kIsWeb) ...[
            const SizedBox(width: Space.s),
            ActionChip(
              avatar: const Icon(Icons.radar_rounded, size: 18),
              label: const Text('Bilgisayarımı algıla'),
              onPressed: () => context.push('/detect'),
            ),
          ],
        ],
      ),
    );
  }
}

class _PcCard extends ConsumerWidget {
  const _PcCard({
    required this.active,
    required this.onEdit,
    required this.onAnalyze,
  });

  final bool active;
  final VoidCallback onEdit;
  final VoidCallback onAnalyze;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final build = ref.watch(buildProvider);
    final prebuilt = ref.watch(prebuiltProvider);
    final report = ref.watch(compatibilityProvider);
    final fps = ref.watch(fpsEstimateProvider);
    final cpu = build.cpu;
    final gpu = build.gpu;
    final title =
        prebuilt?.label ??
        (cpu == null && gpu == null
            ? null
            : [cpu?.model, gpu?.model].nonNulls.join(' + '));
    return DeviceCard(
      icon: prebuilt?.isLaptop ?? false
          ? Icons.laptop_chromebook_rounded
          : Icons.desktop_windows_rounded,
      kindLabel: 'PC',
      title: title,
      emptyText: 'Parça seç, hazır sistem seç ya da ilan başlığı yapıştır',
      active: active,
      onEdit: onEdit,
      onAnalyze: fps == null ? null : onAnalyze,
      chip: report.isCompatible
          ? const VerdictChip('Uyumlu', tone: Tone.good)
          : const VerdictChip('Uyumsuz', tone: Tone.bad),
      metrics: fps == null
          ? const [CardMetric('—', 'Ekran kartı ve işlemci seç')]
          : [
              CardMetric(
                '%${fps.bottleneckPercent.round()}',
                switch (fps.limiter) {
                  Limiter.cpu => 'Darboğaz · İşlemci',
                  Limiter.gpu => 'Darboğaz · Ekran kartı',
                  Limiter.balanced => 'Dengeli sistem',
                },
              ),
              CardMetric(
                '${fps.avgFps.round()} FPS',
                '${fps.game.name} · ${fps.resolution.label}',
              ),
            ],
    );
  }
}

class _PhoneCard extends ConsumerWidget {
  const _PhoneCard({
    required this.active,
    required this.onEdit,
    required this.onAnalyze,
  });

  final bool active;
  final VoidCallback onEdit;
  final VoidCallback onAnalyze;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spec = ref.watch(phoneSpecProvider);
    final s = spec == null ? null : const PhoneEstimator().summarize(spec);
    return DeviceCard(
      icon: Icons.smartphone_rounded,
      kindLabel: 'Telefon',
      title: spec?.phone.displayName,
      emptyText: 'iPhone, Samsung, Xiaomi ve 100+ model',
      active: active,
      onEdit: onEdit,
      onAnalyze: onAnalyze,
      chip: s == null ? null : VerdictChip(s.tier.label, tone: Tone.brand),
      metrics: spec == null || s == null
          ? const []
          : [
              CardMetric('${s.score.round()}', 'Puan'),
              CardMetric('%${s.sustainedPercent.round()}', 'Isınınca'),
              CardMetric('${spec.ramGb} GB', spec.soc.name),
            ],
    );
  }
}

class _WatchCard extends ConsumerWidget {
  const _WatchCard({
    required this.active,
    required this.onEdit,
    required this.onAnalyze,
  });

  final bool active;
  final VoidCallback onEdit;
  final VoidCallback onAnalyze;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = ref.watch(watchReportProvider);
    return DeviceCard(
      icon: Icons.watch_rounded,
      kindLabel: 'Saat',
      title: r?.watch.displayName,
      emptyText: 'Apple Watch, Galaxy Watch, Garmin…',
      active: active,
      onEdit: onEdit,
      onAnalyze: onAnalyze,
      chip: r == null
          ? null
          : r.phone == null
          ? const VerdictChip('Telefon seç', tone: Tone.warn)
          : r.isCompatible
          ? const VerdictChip('Uyumlu', tone: Tone.good)
          : const VerdictChip('Uyumsuz', tone: Tone.bad),
      metrics: r == null
          ? const []
          : [
              CardMetric(batteryLabel(r.watch.batteryHours), 'Pil'),
              CardMetric('${r.smoothness.round()}', 'Akıcılık'),
              CardMetric('${r.availableFeatures.length}', 'Özellik'),
            ],
    );
  }
}
