import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:darbogaz/core/router/tab_back.dart';
import 'package:darbogaz/core/brand/truerig_logo.dart';
import 'package:darbogaz/core/devices.dart';
import 'package:darbogaz/features/device/device_slots.dart';
import 'package:darbogaz/core/theme/tokens.dart';
import 'package:darbogaz/core/widgets/app_controls.dart';
import 'package:darbogaz/core/widgets/profile_action.dart';
import 'package:darbogaz/features/builder/builder_page.dart';
import 'package:darbogaz/features/phone/phone_panel.dart';
import 'package:darbogaz/features/watch/watch_pages.dart';

extension DeviceSectionLabel on DeviceKind {
  /// Possessive section name used in "Cihazlarım".
  String get mine => switch (this) {
    DeviceKind.pc => 'Bilgisayarım',
    DeviceKind.phone => 'Telefonum',
    DeviceKind.watch => 'Saatim',
  };
}

/// "Cihazlarım" tab: Bilgisayarım / Telefonum / Saatim, each edited in
/// place. The chosen section is also the device "Analiz" shows.
class DevicesPage extends ConsumerStatefulWidget {
  const DevicesPage({super.key, this.initialKind});

  /// From `/devices?kind=phone` (deep links, home tiles).
  final DeviceKind? initialKind;

  @override
  ConsumerState<DevicesPage> createState() => _DevicesPageState();
}

class _DevicesPageState extends ConsumerState<DevicesPage> {
  @override
  void initState() {
    super.initState();
    final k = widget.initialKind;
    if (k != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => ref.read(activeDeviceProvider.notifier).set(k),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final kind = ref.watch(activeDeviceProvider);
    return Scaffold(
      appBar: AppBar(
        leading: const TabBackButton(),
        title: const BrandTitle('Cihazlarım'),
        actions: [
          // PC hardware can only be read on the website, not on a phone.
          if (kind == DeviceKind.pc && kIsWeb)
            IconButton(
              tooltip: 'Bilgisayarımı algıla',
              icon: const Icon(Icons.radar_rounded),
              onPressed: () => context.push('/detect'),
            ),
          const ProfileAction(),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: Insets.pageHeader,
            child: AppSegmented<DeviceKind>(
              values: DeviceKind.values,
              selected: kind,
              labelOf: (k) => k.mine,
              onChanged: ref.read(activeDeviceProvider.notifier).set,
            ),
          ),
          Padding(
            padding: Insets.pageHeader,
            child: DeviceSlotBar(kind: kind),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: Motion.normal,
              child: KeyedSubtree(
                key: ValueKey(kind),
                child: switch (kind) {
                  DeviceKind.pc => const PcPanel(),
                  DeviceKind.phone => const PhonePanel(),
                  DeviceKind.watch => const WatchPanel(),
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
