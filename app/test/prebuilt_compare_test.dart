import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:perf_engine/perf_engine.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:darbogaz/app.dart';
import 'package:darbogaz/core/devices.dart';
import 'package:darbogaz/core/providers.dart';
import 'package:darbogaz/features/detect/self_device.dart';
import 'package:darbogaz/features/prices/store_list.dart';

import 'support.dart' show FakePriceRepository;

Future<SharedPreferences> _prefs(Map<String, Object> values) async {
  SharedPreferences.setMockInitialValues({'onboarding.done': true, ...values});
  return SharedPreferences.getInstance();
}

Future<void> _pump(WidgetTester tester, SharedPreferences prefs) async {
  // Tall viewport so result tables are built without scrolling.
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        prefsProvider.overrideWithValue(prefs),
        selfDeviceIdProvider.overrideWith((ref) async => null),
        priceRepositoryProvider.overrideWithValue(const FakePriceRepository()),
      ],
      child: const DarbogazApp(),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f.first);
  await tester.tap(f.first);
  await tester.pumpAndSettle();
}

Future<void> _search(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField).first, text);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('ready-made laptop fills the build and enters laptop mode', (
    tester,
  ) async {
    await _pump(tester, await _prefs({}));
    await _tap(
      tester,
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Cihazlarım'),
      ),
    );
    await _tap(tester, find.text('Hazır sistem seç (isteğe bağlı)'));
    await _search(tester, 'G770');
    await _tap(tester, find.text('Casper Excalibur G770'));
    await _tap(tester, find.text('i7-12700H · RTX 4060 · 16 GB').first);

    // Back on Bilgisayarım: the ready-made card carries the system name.
    expect(
      find.textContaining('Casper Excalibur G770 · i7-12700H'),
      findsOneWidget,
    );
    expect(find.text('Intel Core i7-12700H'), findsOneWidget);
    expect(find.text('NVIDIA GeForce RTX 4060 Laptop GPU'), findsOneWidget);
    // Laptop: no board / case / PSU slots.
    expect(find.text('Anakart'), findsNothing);
    expect(find.text('Diğer parçalar'), findsNothing);
  });

  testWidgets('a pasted listing title fills CPU, GPU and RAM', (tester) async {
    await _pump(tester, await _prefs({}));
    await _tap(
      tester,
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Cihazlarım'),
      ),
    );
    await _tap(tester, find.text('Hazır sistem seç (isteğe bağlı)'));
    await _search(
      tester,
      'Gaming PC AMD Ryzen 5 7600 RX 7600 16GB DDR5 6000MHz 1TB NVMe',
    );
    expect(find.text('Başlıktan bulunanlar'), findsOneWidget);
    await _tap(tester, find.text('Bununla doldur'));
    expect(find.text('AMD Ryzen 5 7600'), findsOneWidget);
    expect(find.text('AMD Radeon RX 7600'), findsOneWidget);
    expect(find.textContaining('16GB (2x8) DDR5-6000'), findsOneWidget);
  });

  testWidgets('compare phones side by side', (tester) async {
    await _pump(
      tester,
      await _prefs({
        'device.kind': 'phone',
        'phone.selection': ['iphone-13', 'a15-4gpu', '4'],
      }),
    );
    await _tap(
      tester,
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Karşılaştır'),
      ),
    );
    await _tap(tester, find.text('Cihaz seç'));
    await _search(tester, 'iPhone 16 Pro');
    await _tap(tester, find.text('Apple iPhone 16 Pro'));

    expect(find.text('Genel puan'), findsOneWidget);
    expect(find.text('Kim önde?'), findsOneWidget);
    expect(find.text('Pil (karışık kullanım)'), findsOneWidget);
    expect(find.text('A15 Bionic (4 çekirdek GPU)'), findsOneWidget);
    expect(find.text('A18 Pro'), findsOneWidget);
    expect(find.text('Genshin Impact'), findsOneWidget);
  });

  testWidgets('compare PC against hand-picked CPU + GPU', (tester) async {
    await _pump(
      tester,
      await _prefs({
        'pc.build': ['r5-5600', 'rtx-3060-12', 'kingston-ddr4-3200-32'],
      }),
    );
    await _tap(
      tester,
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Karşılaştır'),
      ),
    );
    await _tap(tester, find.text('Cihaz seç'));
    await _tap(tester, find.text('İşlemci ve ekran kartı seç'));
    await _search(tester, '7800X3D');
    await _tap(tester, find.text('AMD Ryzen 7 7800X3D'));
    await _search(tester, 'RTX 4070 Super');
    await _tap(tester, find.text('NVIDIA GeForce RTX 4070 Super'));

    expect(find.text('Ryzen 7 7800X3D + GeForce RTX 4070 Super'), findsWidgets);
    expect(find.text('Mağazalarda ortalama fiyat'), findsOneWidget);
    expect(find.textContaining('Oyun FPS'), findsOneWidget);
    expect(find.text('Cyberpunk 2077'), findsOneWidget);
  });

  testWidgets('compare watches against the same phone', (tester) async {
    await _pump(
      tester,
      await _prefs({
        'device.kind': 'watch',
        'phone.selection': ['galaxy-s24', 'exynos-2400', '8'],
        'watch.selection': ['gw-7', ''],
      }),
    );
    await _tap(
      tester,
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Karşılaştır'),
      ),
    );
    await _tap(tester, find.text('Cihaz seç'));
    await _search(tester, 'Series 10');
    await _tap(tester, find.text('Apple Watch Series 10'));
    expect(find.text('Telefonunla'), findsOneWidget);
    expect(find.text('Uyumsuz'), findsOneWidget); // Apple Watch + Galaxy
  });

  test('variant labels are short and readable', () {
    final c = PartCatalog.seed();
    final v = kPrebuilts
        .firstWhere((s) => s.id == 'casper-g770')
        .variants
        .firstWhere((v) => v.code == 'G770.1245');
    expect(variantLabel(c, v), 'i5-12450H · RTX 3050 · 16 GB');
  });
}
