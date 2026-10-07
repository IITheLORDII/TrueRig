import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:darbogaz/core/brand/truerig_logo.dart';
import 'package:darbogaz/core/devices.dart';
import 'package:darbogaz/features/builder/builder_page.dart';
import 'package:darbogaz/features/phone/phone_panel.dart';
import 'package:darbogaz/features/watch/watch_pages.dart';

/// Full-screen editor for one device, opened from a "Cihazlarım" card.
class DeviceEditorPage extends StatelessWidget {
  const DeviceEditorPage({super.key, required this.kind});

  final DeviceKind kind;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: BrandTitle(switch (kind) {
        DeviceKind.pc => 'PC sistemim',
        DeviceKind.phone => 'Telefonum',
        DeviceKind.watch => 'Saatim',
      }),
      actions: [
        // PC hardware can only be read on the website, not on a phone.
        if (kind == DeviceKind.pc && kIsWeb)
          IconButton(
            tooltip: 'Bilgisayarımı algıla',
            icon: const Icon(Icons.radar_rounded),
            onPressed: () => context.push('/detect'),
          ),
      ],
    ),
    body: switch (kind) {
      DeviceKind.pc => const PcPanel(),
      DeviceKind.phone => const PhonePanel(),
      DeviceKind.watch => const WatchPanel(),
    },
  );
}
