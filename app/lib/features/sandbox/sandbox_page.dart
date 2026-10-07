import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:perf_engine/perf_engine.dart';

import 'package:darbogaz/core/brand/truerig_logo.dart';
import 'package:darbogaz/core/devices.dart';
import 'package:darbogaz/core/theme/app_theme.dart';
import 'package:darbogaz/core/theme/tokens.dart';
import 'package:darbogaz/core/widgets/app_controls.dart';
import 'package:darbogaz/core/widgets/common.dart';
import 'package:darbogaz/features/compare/compare_metrics.dart';
import 'package:darbogaz/features/compare/compare_widgets.dart';
import 'package:darbogaz/features/performance/mobile_views.dart';
import 'package:darbogaz/features/performance/phone_views.dart';
import 'package:darbogaz/features/sandbox/sandbox_pc_view.dart';
import 'package:darbogaz/features/sandbox/sandbox_state.dart';

enum _View { summary, mobile }

/// "Analiz yap": try models, builds and comparisons without saving anything.
class SandboxPage extends ConsumerStatefulWidget {
  const SandboxPage({super.key, this.initialTab, this.startCompare = false});

  /// 'browse' opens the ready-made model list right away; 'pc' the builder.
  final String? initialTab;
  final bool startCompare;

  @override
  ConsumerState<SandboxPage> createState() => _SandboxPageState();
}

class _SandboxPageState extends ConsumerState<SandboxPage> {
  _View _view = _View.summary;

  /// PC slot whose part list is open in compare mode.
  int? _editing;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ctl = ref.read(sandboxProvider.notifier);
      if (widget.startCompare) ctl.setComparing(true);
      if (widget.initialTab == 'pc' || widget.initialTab == 'browse') {
        ctl.setKind(DeviceKind.pc);
      }
      if (widget.initialTab == 'browse') pickSandboxPrebuilt(context, ref, 0);
    });
  }

  Future<void> _pickPhone(int slot) async {
    final p = await context.push<Phone>('/pick/phone?mode=compare');
    if (p != null) ref.read(sandboxProvider.notifier).setPhone(slot, p);
  }

  Future<void> _pickWatch(int slot) async {
    final w = await context.push<Watch>('/pick/watch?mode=return');
    if (w != null) ref.read(sandboxProvider.notifier).setWatch(slot, w);
  }

  Future<void> _pickPcSlot(int slot) async {
    final how = await showOptionSheet<String>(
      context: context,
      title: slot == 0 ? 'Birinci bilgisayar' : 'İkinci bilgisayar',
      options: const ['prebuilt', 'parts'],
      labelOf: (o) =>
          o == 'prebuilt' ? 'Hazır modellerde gez' : 'Parça parça topla',
    );
    if (!mounted || how == null) return;
    if (how == 'prebuilt') {
      await pickSandboxPrebuilt(context, ref, slot);
    } else {
      setState(() => _editing = slot);
    }
  }

  PhoneSpec? _spec(Phone? p) {
    if (p == null) return null;
    final soc = ref.read(mobileCatalogProvider).soc(p.socId);
    return soc == null
        ? null
        : PhoneSpec(phone: p, soc: soc, ramGb: p.defaultRamGb);
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(sandboxProvider);
    final ctl = ref.read(sandboxProvider.notifier);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const BrandTitle('Analiz yap'),
        actions: [
          IconButton(
            tooltip: 'Temizle',
            icon: const Icon(Icons.restart_alt_rounded),
            onPressed: () {
              ctl.clear();
              setState(() => _editing = null);
            },
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Space.page,
              0,
              Space.page,
              Space.xs,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Hiçbir şey kaydedilmez; uygulama kapanınca silinir. '
                  'Cihazlarım etkilenmez.',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: context.palette.muted,
                  ),
                ),
                const SizedBox(height: Space.s),
                AppSegmented<DeviceKind>(
                  values: DeviceKind.values,
                  selected: s.kind,
                  labelOf: (k) => k.label,
                  onChanged: ctl.setKind,
                ),
                SwitchListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('İki cihazı karşılaştır'),
                  value: s.comparing,
                  onChanged: ctl.setComparing,
                ),
              ],
            ),
          ),
          Expanded(child: s.comparing ? _compare(s) : _single(s)),
        ],
      ),
    );
  }

  // ------------------------------------------------------------ single --

  Widget _single(SandboxState s) {
    switch (s.kind) {
      case DeviceKind.pc:
        return ListView(
          padding: _listPadding,
          children: [
            const SandboxPcEditor(slot: 0),
            const SizedBox(height: Space.s),
            SandboxPcResults(build: s.pcs[0].build),
          ],
        );
      case DeviceKind.phone:
        final spec = _spec(s.phones[0]);
        return _withPicker(
          name: spec?.phone.displayName,
          hint: 'Telefon seç',
          onPick: () => _pickPhone(0),
          child: spec == null
              ? null
              : _view == _View.mobile
              ? PhoneMobileView(spec: spec)
              : PhoneSummaryView(spec: spec),
        );
      case DeviceKind.watch:
        final watch = s.watches[0];
        final report = watch == null
            ? null
            : const WatchCompatibility().check(watch, s.phones[0]);
        return _withPicker(
          name: watch?.displayName,
          hint: 'Saat seç',
          onPick: () => _pickWatch(0),
          note: watch != null && s.phones[0] == null
              ? 'Uyumluluk için Telefon sekmesinden bir telefon seç.'
              : null,
          child: report == null
              ? null
              : _view == _View.mobile
              ? WatchMobileView(report: report)
              : WatchSummaryView(report: report),
        );
    }
  }

  Widget _withPicker({
    required String? name,
    required String hint,
    required VoidCallback onPick,
    required Widget? child,
    String? note,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.page),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SideCard(
                caption: 'İncelenen',
                name: name ?? hint,
                color: CompareColors.mine(context),
                highlight: name == null,
                onTap: onPick,
              ),
              if (note != null)
                Padding(
                  padding: const EdgeInsets.only(top: Space.xs),
                  child: Text(
                    note,
                    style: Theme.of(context).textTheme.labelSmall
                        ?.copyWith(color: context.palette.warn),
                  ),
                ),
              if (child != null) ...[
                const SizedBox(height: Space.s),
                AppSegmented<_View>(
                  values: _View.values,
                  selected: _view,
                  labelOf: (v) => v == _View.summary ? 'Özet' : 'Mobil',
                  onChanged: (v) => setState(() => _view = v),
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child:
              child ??
              const EmptyHint(
                icon: Icons.travel_explore_rounded,
                message: 'Katalogdaki modellerden birini seç ve incele.',
              ),
        ),
      ],
    );
  }

  // ----------------------------------------------------------- compare --

  Widget _compare(SandboxState s) {
    final (
      String? a,
      String? b,
      VoidCallback pickA,
      VoidCallback pickB,
    ) = switch (s.kind) {
      DeviceKind.pc => (
        s.pcs[0].name,
        s.pcs[1].name,
        () => _pickPcSlot(0),
        () => _pickPcSlot(1),
      ),
      DeviceKind.phone => (
        s.phones[0]?.displayName,
        s.phones[1]?.displayName,
        () => _pickPhone(0),
        () => _pickPhone(1),
      ),
      DeviceKind.watch => (
        s.watches[0]?.displayName,
        s.watches[1]?.displayName,
        () => _pickWatch(0),
        () => _pickWatch(1),
      ),
    };
    final sections = _sections(s);
    final editing = _editing;

    return ListView(
      padding: _listPadding,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: SideCard(
                caption: 'Birinci',
                name: a ?? 'Seç',
                color: CompareColors.mine(context),
                highlight: a == null,
                onTap: pickA,
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(top: 22),
              child: Icon(Icons.compare_arrows_rounded),
            ),
            Expanded(
              child: SideCard(
                caption: 'İkinci',
                name: b ?? 'Seç',
                color: CompareColors.other(context),
                highlight: b == null,
                onTap: pickB,
              ),
            ),
          ],
        ),
        if (s.kind == DeviceKind.pc && editing != null) ...[
          const SizedBox(height: Space.s),
          SandboxPcEditor(slot: editing),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => setState(() => _editing = null),
              child: const Text('Tamam'),
            ),
          ),
        ],
        const SizedBox(height: Space.m),
        if (sections == null)
          const EmptyHint(
            icon: Icons.compare_arrows_rounded,
            message: 'İki cihazı da seçince farklar burada görünür.',
          )
        else ...[
          VerdictCard(mine: a!, other: b!, wins: countWins(sections)),
          const SizedBox(height: Space.s),
          for (final sec in sections) ...[
            CompareTable(section: sec, mine: a, other: b),
            const SizedBox(height: Space.s),
          ],
        ],
      ],
    );
  }

  List<CompareSection>? _sections(SandboxState s) {
    switch (s.kind) {
      case DeviceKind.pc:
        final a = s.pcs[0];
        final b = s.pcs[1];
        if (!a.isReady || !b.isReady) return null;
        return comparePcs(
          a.build,
          b.build,
          resolution: Resolution.p1080,
          preset: GraphicsPreset.high,
        );
      case DeviceKind.phone:
        final a = _spec(s.phones[0]);
        final b = _spec(s.phones[1]);
        if (a == null || b == null) return null;
        return comparePhones(a, b, currentYear: DateTime.now().year);
      case DeviceKind.watch:
        final a = s.watches[0];
        final b = s.watches[1];
        if (a == null || b == null) return null;
        const compat = WatchCompatibility();
        return compareWatches(
          compat.check(a, s.phones[0]),
          compat.check(b, s.phones[0]),
        );
    }
  }
}

const _listPadding = EdgeInsets.fromLTRB(
  Space.page,
  Space.xs,
  Space.page,
  Space.xl,
);
