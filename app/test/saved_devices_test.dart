import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:darbogaz/core/devices.dart';
import 'package:darbogaz/core/providers.dart';
import 'package:darbogaz/core/saved_devices.dart';

import 'support.dart';

void main() {
  Future<ProviderContainer> container(Map<String, Object> prefs) async {
    final p = await prefsWith(prefs);
    final c = ProviderContainer(
      overrides: [prefsProvider.overrideWithValue(p)],
    );
    addTearDown(c.dispose);
    // Keep the controller alive like the app root does.
    c.listen(savedDevicesProvider, (_, _) {});
    return c;
  }

  test('existing selection becomes the first saved device', () async {
    final c = await container({
      'phone.selection': ['iphone-15', 'a16', '6'],
    });
    final s = c.read(savedDevicesProvider);
    expect(s.of(DeviceKind.phone), hasLength(1));
    expect(
      c.read(savedDevicesProvider.notifier).labelOf(DeviceKind.phone, 0),
      'Apple iPhone 15',
    );
  });

  test('add, switch and remove phones', () async {
    final c = await container({
      'phone.selection': ['iphone-15', 'a16', '6'],
    });
    final ctl = c.read(savedDevicesProvider.notifier);
    final catalog = c.read(mobileCatalogProvider);

    ctl.addNew(DeviceKind.phone);
    expect(c.read(phoneSelectionProvider), isNull);
    c.read(phoneSelectionProvider.notifier).select(catalog.phone('pixel-8')!);
    expect(c.read(savedDevicesProvider).of(DeviceKind.phone), hasLength(2));
    expect(ctl.labelOf(DeviceKind.phone, 1), 'Google Pixel 8');

    ctl.switchTo(DeviceKind.phone, 0);
    expect(c.read(phoneSelectionProvider)?.phoneId, 'iphone-15');
    ctl.switchTo(DeviceKind.phone, 1);
    expect(c.read(phoneSelectionProvider)?.phoneId, 'pixel-8');

    ctl.remove(DeviceKind.phone, 1);
    expect(c.read(savedDevicesProvider).of(DeviceKind.phone), hasLength(1));
    expect(c.read(phoneSelectionProvider)?.phoneId, 'iphone-15');
  });

  test('switching PCs loads the build and ready-made name', () async {
    final c = await container({
      'pc.build': ['r5-5600', 'rtx-3060-12'],
    });
    final ctl = c.read(savedDevicesProvider.notifier);
    final catalog = c.read(catalogProvider);

    ctl.addNew(DeviceKind.pc);
    expect(c.read(buildProvider).parts, isEmpty);
    c.read(buildProvider.notifier).setPart(catalog.byId('i5-12450h')!);
    ctl.rename(DeviceKind.pc, 1, 'İş laptopu');

    ctl.switchTo(DeviceKind.pc, 0);
    expect(c.read(buildProvider).cpu?.id, 'r5-5600');
    expect(ctl.labelOf(DeviceKind.pc, 1), 'İş laptopu');
  });

  test('saved list survives encode / decode', () {
    const s = SavedDevices(
      lists: {
        DeviceKind.watch: [
          SavedDevice(name: 'Spor', data: ['gw-7', '']),
        ],
      },
      active: {DeviceKind.watch: 0},
    );
    final back = SavedDevices.decode(s.encode());
    expect(back.of(DeviceKind.watch).single.name, 'Spor');
    expect(back.of(DeviceKind.watch).single.data, ['gw-7', '']);
  });
}
