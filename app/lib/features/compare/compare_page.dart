import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:perf_engine/perf_engine.dart';

import 'package:darbogaz/core/brand/truerig_logo.dart';
import 'package:darbogaz/core/devices.dart';
import 'package:darbogaz/core/providers.dart';
import 'package:darbogaz/core/saved_devices.dart';
import 'package:darbogaz/core/theme/app_theme.dart';
import 'package:darbogaz/core/theme/tokens.dart';
import 'package:darbogaz/core/widgets/app_controls.dart';
import 'package:darbogaz/core/widgets/common.dart';
import 'package:darbogaz/core/widgets/profile_action.dart';
import 'package:darbogaz/features/builder/prebuilt_picker_page.dart';
import 'package:darbogaz/features/compare/compare_metrics.dart';
import 'package:darbogaz/features/compare/compare_widgets.dart';

/// Everything needed to draw one comparison.
typedef _Comparison = ({
  String? mine,
  String? mineQuery,
  String? other,
  String? otherQuery,
  List<CompareSection>? sections,
});

/// "Karşılaştır": one of the user's devices vs another of the same kind.
class ComparePage extends ConsumerStatefulWidget {
  const ComparePage({super.key});

  @override
  ConsumerState<ComparePage> createState() => _ComparePageState();
}

class _ComparePageState extends ConsumerState<ComparePage> {
  /// Own device-type choice; starts at the active device.
  DeviceKind? _kind;

  /// Which saved device is "Benim" per kind (null = the active one).
  final Map<DeviceKind, int> _mine = {};
  PickedSystem? _otherPc;
  Phone? _otherPhone;
  Watch? _otherWatch;

  SavedDevice? _mineDevice(DeviceKind k) {
    final saved = ref.watch(savedDevicesProvider);
    final list = saved.of(k);
    if (list.isEmpty) return null;
    final i = (_mine[k] ?? saved.activeIndex(k)).clamp(0, list.length - 1);
    final d = list[i];
    return d.isEmpty ? null : d;
  }

  Future<void> _chooseMine(DeviceKind k) async {
    final saved = ref.read(savedDevicesProvider);
    final ctl = ref.read(savedDevicesProvider.notifier);
    final list = saved.of(k);
    if (list.where((d) => !d.isEmpty).length < 2) {
      context.go('/devices?kind=${k.name}');
      return;
    }
    final picked = await showOptionSheet<int>(
      context: context,
      title: 'Hangi cihazın karşılaştırılsın?',
      options: [
        for (var i = 0; i < list.length; i++)
          if (!list[i].isEmpty) i,
      ],
      labelOf: (i) => ctl.labelOf(k, i),
      selected: _mine[k] ?? saved.activeIndex(k),
    );
    if (picked != null) setState(() => _mine[k] = picked);
  }

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
    final c = switch (kind) {
      DeviceKind.pc => _pc(),
      DeviceKind.phone => _phone(),
      DeviceKind.watch => _watch(),
    };
    final pick = switch (kind) {
      DeviceKind.pc => _pickPc,
      DeviceKind.phone => _pickPhone,
      DeviceKind.watch => _pickWatch,
    };
    final sections = c.sections;

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
                child: SideCard(
                  caption: 'Benim',
                  name: c.mine ?? "Önce Cihazlarım'dan ekle",
                  color: CompareColors.mine(context),
                  onTap: () => _chooseMine(kind),
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(top: 22),
                child: Icon(Icons.compare_arrows_rounded),
              ),
              Expanded(
                child: SideCard(
                  caption: 'Karşılaştırılan',
                  name: c.other ?? 'Cihaz seç',
                  color: CompareColors.other(context),
                  highlight: c.other == null,
                  onTap: pick,
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.m),
          if (sections == null)
            const EmptyHint(
              icon: Icons.compare_arrows_rounded,
              message:
                  'İki cihaz da seçilince kim hangi konuda önde, burada '
                  'yan yana görünür.',
            )
          else ...[
            VerdictCard(
              mine: c.mine!,
              other: c.other!,
              wins: countWins(sections),
            ),
            const SizedBox(height: Space.s),
            PriceCompareCard(
              mine: c.mine!,
              mineQuery: c.mineQuery,
              other: c.other!,
              otherQuery: c.otherQuery,
            ),
            const SizedBox(height: Space.s),
            for (final s in sections) ...[
              CompareTable(section: s, mine: c.mine!, other: c.other!),
              const SizedBox(height: Space.s),
            ],
            Text(
              kEstimateDisclaimer,
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: context.palette.muted),
            ),
          ],
        ],
      ),
    );
  }

  /// Product name used for the store search ("Casper Excalibur G770").
  static String _systemQuery(String label) => label.split(' · ').first;

  _Comparison _pc() {
    final catalog = ref.watch(catalogProvider);
    final saved = _mineDevice(DeviceKind.pc);
    final mine = saved == null ? null : pcBuildOf(saved, catalog);
    final settings = ref.watch(analysisSettingsProvider);
    final hasMine = mine != null && mine.cpu != null && mine.gpu != null;
    final other = _otherPc;
    final prebuiltLabel = saved != null && saved.data[0].isNotEmpty
        ? saved.data[0]
        : null;
    final mineLabel = !hasMine
        ? null
        : (saved!.name ??
              prebuiltLabel ??
              '${mine.cpu!.model} + ${mine.gpu!.model}');

    /// Ready-made systems are searched by name; hand-picked builds by GPU.
    String? query(String? prebuilt, PcBuild? b) =>
        prebuilt != null ? _systemQuery(prebuilt) : b?.gpu?.model;

    final otherIsSystem = other != null && !other.label.contains(' + ');
    return (
      mine: mineLabel,
      mineQuery: hasMine ? query(prebuiltLabel, mine) : null,
      other: other?.label,
      otherQuery: other == null
          ? null
          : query(otherIsSystem ? other.label : null, other.build),
      sections: hasMine && other != null
          ? comparePcs(
              mine,
              other.build,
              resolution: settings.resolution,
              preset: settings.preset,
            )
          : null,
    );
  }

  _Comparison _phone() {
    final catalog = ref.watch(mobileCatalogProvider);
    final saved = _mineDevice(DeviceKind.phone);
    final mine = saved == null ? null : phoneSpecOf(saved, catalog);
    final other = _otherPhone;
    final otherSpec = other == null
        ? null
        : PhoneSpec(
            phone: other,
            soc: catalog.soc(other.socId)!,
            ramGb: other.defaultRamGb,
          );
    return (
      mine: mine?.phone.displayName,
      mineQuery: mine?.phone.displayName,
      other: other?.displayName,
      otherQuery: other?.displayName,
      sections: mine != null && otherSpec != null
          ? comparePhones(mine, otherSpec, currentYear: DateTime.now().year)
          : null,
    );
  }

  _Comparison _watch() {
    final catalog = ref.watch(mobileCatalogProvider);
    final saved = _mineDevice(DeviceKind.watch);
    final mineWatch = saved == null ? null : watchOf(saved, catalog);
    final pairedId = saved != null && saved.data.length > 1
        ? saved.data[1]
        : '';
    final phone = pairedId.isNotEmpty
        ? catalog.phone(pairedId)
        : ref.watch(phoneSpecProvider)?.phone;
    const compat = WatchCompatibility();
    final mine = mineWatch == null ? null : compat.check(mineWatch, phone);
    final other = _otherWatch;
    // Judge the other watch against the same phone as the user's watch.
    final otherReport = other == null ? null : compat.check(other, phone);
    return (
      mine: mineWatch?.displayName,
      mineQuery: mineWatch?.displayName,
      other: other?.displayName,
      otherQuery: other?.displayName,
      sections: mine != null && otherReport != null
          ? compareWatches(mine, otherReport)
          : null,
    );
  }
}
