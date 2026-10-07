import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:perf_engine/perf_engine.dart';

import 'package:darbogaz/core/devices.dart';
import 'package:darbogaz/core/providers.dart';
import 'package:darbogaz/core/theme/app_theme.dart';
import 'package:darbogaz/core/widgets/app_controls.dart';
import 'package:darbogaz/core/theme/tokens.dart';
import 'package:darbogaz/core/widgets/common.dart';
import 'package:darbogaz/core/widgets/profile_action.dart';
import 'package:darbogaz/features/builder/prebuilt_picker_page.dart';
import 'package:darbogaz/features/compare/compare_metrics.dart';
import 'package:darbogaz/core/brand/truerig_logo.dart';

/// "Karşılaştır": the user's current device vs another one of the same kind.
class ComparePage extends ConsumerStatefulWidget {
  const ComparePage({super.key});

  @override
  ConsumerState<ComparePage> createState() => _ComparePageState();
}

class _ComparePageState extends ConsumerState<ComparePage> {
  /// Own device-type choice; starts at the active device.
  DeviceKind? _kind;
  PickedSystem? _otherPc;
  Phone? _otherPhone;
  Watch? _otherWatch;

  Future<void> _pickPc() async {
    final how = await showOptionSheet<String>(
      context: context,
      title: 'Karşılaştırılacak bilgisayar',
      options: const ['prebuilt', 'parts'],
      labelOf: (o) => o == 'prebuilt'
          ? 'Hazır sistem ya da ilan başlığı'
          : 'İşlemci ve ekran kartı seç',
    );
    if (!mounted || how == null) return;
    if (how == 'prebuilt') {
      final picked = await context.push<PickedSystem>(
        '/pick/prebuilt?mode=return',
      );
      if (picked != null) setState(() => _otherPc = picked);
      return;
    }
    final cpu = await context.push<Part>('/pick/part/cpu?mode=return');
    if (!mounted || cpu is! Cpu) return;
    final gpu = await context.push<Part>('/pick/part/gpu?mode=return');
    if (!mounted || gpu is! Gpu) return;
    // Same RAM as the user's PC keeps the comparison about CPU + GPU.
    var build = PcBuild(cpu: cpu, gpu: gpu);
    final ram = ref.read(buildProvider).ram;
    if (ram != null) build = build.withPart(ram);
    setState(
      () => _otherPc = PickedSystem(
        label: '${cpu.model} + ${gpu.model}',
        build: build,
        isLaptop: false,
      ),
    );
  }

  Future<void> _pickPhone() async {
    final p = await context.push<Phone>('/pick/phone?mode=compare');
    if (p != null) setState(() => _otherPhone = p);
  }

  Future<void> _pickWatch() async {
    final w = await context.push<Watch>('/pick/watch?mode=return');
    if (w != null) setState(() => _otherWatch = w);
  }

  @override
  Widget build(BuildContext context) {
    final DeviceKind kind = _kind ?? ref.watch(activeDeviceProvider);
    final (
      String? mine,
      String? other,
      VoidCallback pick,
      List<CompareSection>? sections,
    ) = switch (kind) {
      DeviceKind.pc => _pc(),
      DeviceKind.phone => _phone(),
      DeviceKind.watch => _watch(),
    };

    return Scaffold(
      appBar: AppBar(
        title: const BrandTitle('Karşılaştır'),
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
          AppSegmented<DeviceKind>(
            values: DeviceKind.values,
            selected: kind,
            labelOf: (k) => k.label,
            onChanged: (k) => setState(() => _kind = k),
          ),
          const SizedBox(height: Space.s),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _SideCard(
                  caption: 'Benim',
                  name: mine ?? "Önce Cihazlarım'dan ekle",
                  onTap: mine == null ? () => context.go('/devices') : null,
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(top: 22),
                child: Icon(Icons.compare_arrows_rounded),
              ),
              Expanded(
                child: _SideCard(
                  caption: 'Karşılaştırılan',
                  name: other ?? 'Ekle',
                  highlight: other == null,
                  onTap: pick,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (sections == null)
            const EmptyHint(
              icon: Icons.compare_arrows_rounded,
              message:
                  'İki cihaz da seçilince yan yana karşılaştırma burada '
                  'görünür.',
            )
          else ...[
            for (final s in sections) ...[
              _CompareTable(section: s),
              const SizedBox(height: 8),
            ],
            Text(
              kEstimateDisclaimer,
              style: Theme.of(context).textTheme.labelSmall
                  ?.copyWith(color: context.palette.muted),
            ),
          ],
        ],
      ),
    );
  }

  (String?, String?, VoidCallback, List<CompareSection>?) _pc() {
    final mine = ref.watch(buildProvider);
    final settings = ref.watch(analysisSettingsProvider);
    final hasMine = mine.cpu != null && mine.gpu != null;
    final other = _otherPc;
    final mineLabel =
        ref.watch(prebuiltProvider)?.label ??
        (hasMine ? '${mine.cpu!.model} + ${mine.gpu!.model}' : null);
    return (
      mineLabel,
      other?.label,
      _pickPc,
      hasMine && other != null
          ? comparePcs(
              mine,
              other.build,
              resolution: settings.resolution,
              preset: settings.preset,
            )
          : null,
    );
  }

  (String?, String?, VoidCallback, List<CompareSection>?) _phone() {
    final mine = ref.watch(phoneSpecProvider);
    final other = _otherPhone;
    final catalog = ref.watch(mobileCatalogProvider);
    final otherSpec = other == null
        ? null
        : PhoneSpec(
            phone: other,
            soc: catalog.soc(other.socId)!,
            ramGb: other.defaultRamGb,
          );
    return (
      mine?.phone.displayName,
      other?.displayName,
      _pickPhone,
      mine != null && otherSpec != null ? comparePhones(mine, otherSpec) : null,
    );
  }

  (String?, String?, VoidCallback, List<CompareSection>?) _watch() {
    final mine = ref.watch(watchReportProvider);
    final other = _otherWatch;
    // Judge the other watch against the same phone as the user's watch.
    final otherReport = other == null
        ? null
        : const WatchCompatibility().check(
            other,
            mine?.phone ?? ref.watch(phoneSpecProvider)?.phone,
          );
    return (
      mine?.watch.displayName,
      other?.displayName,
      _pickWatch,
      mine != null && otherReport != null
          ? compareWatches(mine, otherReport)
          : null,
    );
  }
}

class _SideCard extends StatelessWidget {
  const _SideCard({
    required this.caption,
    required this.name,
    this.onTap,
    this.highlight = false,
  });

  final String caption;
  final String name;
  final VoidCallback? onTap;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: highlight ? scheme.primary.withValues(alpha: 0.12) : null,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                caption,
                style: Theme.of(context).textTheme.labelSmall
                    ?.copyWith(color: context.palette.muted),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  if (highlight) ...[
                    Icon(Icons.add_rounded, size: 18, color: scheme.primary),
                    const SizedBox(width: 4),
                  ],
                  Expanded(
                    child: Text(
                      name,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              if (onTap != null && !highlight)
                Text(
                  'Değiştir',
                  style: TextStyle(color: scheme.primary, fontSize: 12),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompareTable extends StatelessWidget {
  const _CompareTable({required this.section});

  final CompareSection section;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);
    Widget cell(String text, bool wins) => Expanded(
      flex: 3,
      child: Text(
        text,
        textAlign: TextAlign.end,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: numberStyle(
          context,
          size: 13,
          color: wins ? palette.good : null,
        ).copyWith(fontWeight: wins ? FontWeight.w800 : FontWeight.w500),
      ),
    );
    return SectionCard(
      title: section.title,
      child: Column(
        children: [
          for (final r in section.rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: Text(r.label, style: theme.textTheme.bodySmall),
                  ),
                  cell(r.aDisplay, r.winner == -1),
                  cell(r.bDisplay, r.winner == 1),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
