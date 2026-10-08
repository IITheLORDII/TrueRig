import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:perf_engine/perf_engine.dart';

import 'package:darbogaz/core/router/tab_back.dart';
import 'package:darbogaz/features/device/add_device_sheet.dart';
import 'package:darbogaz/core/devices.dart';
import 'package:darbogaz/core/widgets/app_controls.dart';
import 'package:darbogaz/core/theme/tokens.dart';
import 'package:darbogaz/core/widgets/flow.dart';
import 'package:darbogaz/core/widgets/device_chip.dart';
import 'package:darbogaz/core/widgets/profile_action.dart';
import 'package:darbogaz/features/analysis/analysis_page.dart';
import 'package:darbogaz/features/analysis/compatibility_card.dart';
import 'package:darbogaz/features/performance/ai_tab.dart';
import 'package:darbogaz/features/performance/apps_tab.dart';
import 'package:darbogaz/features/performance/games_tab.dart';
import 'package:darbogaz/features/performance/mobile_views.dart';
import 'package:darbogaz/features/performance/phone_views.dart';
import 'package:darbogaz/core/brand/truerig_logo.dart';

enum _Section { summary, games, apps, ai, mobile, compat }

extension on _Section {
  String get label => switch (this) {
    _Section.summary => 'Özet',
    _Section.games => 'Oyun',
    _Section.apps => 'Uygulama',
    _Section.ai => 'Yapay zekâ (LLM-local)',
    _Section.mobile => 'Mobil',
    _Section.compat => 'Uyumluluk',
  };
}

const _pcSections = [
  _Section.summary,
  _Section.games,
  _Section.apps,
  _Section.ai,
];
const _phoneSections = [
  _Section.summary,
  _Section.games,
  _Section.apps,
  _Section.mobile,
];
const _watchSections = [_Section.summary, _Section.mobile, _Section.compat];

/// "Analiz" tab: details of the active device (see [DeviceChip]).
class PerformancePage extends ConsumerStatefulWidget {
  const PerformancePage({super.key});

  @override
  ConsumerState<PerformancePage> createState() => _PerformancePageState();
}

class _PerformancePageState extends ConsumerState<PerformancePage> {
  final Map<DeviceKind, _Section> _section = {};

  @override
  Widget build(BuildContext context) {
    final kind = ref.watch(activeDeviceProvider);
    final sections = switch (kind) {
      DeviceKind.pc => _pcSections,
      DeviceKind.phone => _phoneSections,
      DeviceKind.watch => _watchSections,
    };
    final saved = _section[kind];
    final current = saved != null && sections.contains(saved)
        ? saved
        : _Section.summary;

    return Scaffold(
      appBar: AppBar(
        leading: const TabBackButton(),
        title: const BrandTitle('Analiz'),
        actions: const [ProfileAction()],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Space.page,
              0,
              Space.page,
              Space.s,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const DeviceChip(),
                const SizedBox(height: Space.s),
                AnimatedSwitcher(
                  duration: Motion.normal,
                  child: AppSegmented<_Section>(
                    key: ValueKey(kind),
                    values: sections,
                    selected: current,
                    labelOf: (s) => s.label,
                    onChanged: (s) => setState(() => _section[kind] = s),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: Motion.normal,
              child: KeyedSubtree(
                key: ValueKey('$kind-$current'),
                child: _body(kind, current),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _body(DeviceKind kind, _Section section) {
    switch (kind) {
      case DeviceKind.pc:
        return switch (section) {
          _Section.games => const GamesTab(),
          _Section.apps => const AppsTab(),
          _Section.ai => const AiTab(),
          _ => const PcSummaryView(),
        };
      case DeviceKind.phone:
        final spec = ref.watch(phoneSpecProvider);
        if (spec == null) {
          return const _ChooseFirst(
            kind: DeviceKind.phone,
            icon: Icons.smartphone_rounded,
            message: 'Telefonunu ekle, ne kadar iyi olduğunu söyleyelim.',
          );
        }
        return switch (section) {
          _Section.games => PhoneGamesView(spec: spec),
          _Section.apps => PhoneAppsView(spec: spec),
          _Section.mobile => PhoneMobileView(spec: spec),
          _ => PhoneSummaryView(spec: spec),
        };
      case DeviceKind.watch:
        final report = ref.watch(watchReportProvider);
        if (report == null) {
          return const _ChooseFirst(
            kind: DeviceKind.watch,
            icon: Icons.watch_rounded,
            message: 'Saatini ekle, telefonunla uyumunu gösterelim.',
          );
        }
        return switch (section) {
          _Section.compat => ListView(
            padding: Insets.page,
            children: [
              CompatibilityCard(
                report: CompatibilityReport(report.issues, null),
              ),
            ],
          ),
          _Section.mobile => WatchMobileView(report: report),
          _ => WatchSummaryView(report: report),
        };
    }
  }
}

class _ChooseFirst extends ConsumerWidget {
  const _ChooseFirst({
    required this.kind,
    required this.icon,
    required this.message,
  });

  final DeviceKind kind;
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context, WidgetRef ref) => StatView.empty(
    icon: icon,
    message: message,
    actionLabel: '${kind.label} ekle',
    onAction: () => showAddDeviceSheet(context, ref, kind),
  );
}
