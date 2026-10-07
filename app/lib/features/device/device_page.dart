import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:darbogaz/core/devices.dart';
import 'package:darbogaz/core/platform/store_app.dart';
import 'package:darbogaz/core/widgets/app_controls.dart';
import 'package:darbogaz/features/builder/builder_page.dart';
import 'package:darbogaz/features/phone/phone_panel.dart';
import 'package:darbogaz/features/watch/watch_pages.dart';
import 'package:darbogaz/core/brand/truerig_logo.dart';

/// "Cihaz" tab: PC / Telefon / Saat, each configured independently.
class DevicePage extends ConsumerWidget {
  const DevicePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kind = ref.watch(activeDeviceProvider);
    return Scaffold(
      appBar: AppBar(
        title: const BrandTitle('Cihazım'),
        actions: [
          IconButton(
            tooltip: 'Karşılaştır',
            icon: const Icon(Icons.compare_arrows_rounded),
            onPressed: () => context.push('/compare'),
          ),
          // PC hardware can only be read on the website, not on a phone.
          if (kind == DeviceKind.pc && !isStoreApp)
            IconButton(
              tooltip: 'Bilgisayarımı algıla',
              icon: const Icon(Icons.radar_rounded),
              onPressed: () => context.push('/detect'),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: AppSegmented<DeviceKind>(
              values: DeviceKind.values,
              selected: kind,
              labelOf: (k) => k.label,
              onChanged: ref.read(activeDeviceProvider.notifier).set,
            ),
          ),
          Expanded(
            child: switch (kind) {
              DeviceKind.pc => const PcPanel(),
              DeviceKind.phone => const PhonePanel(),
              DeviceKind.watch => const WatchPanel(),
            },
          ),
        ],
      ),
    );
  }
}
