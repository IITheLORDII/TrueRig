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

/// Pre-filled build so the flow does not depend on tapping through pickers.
class _SeededBuild extends BuildController {
  @override
  PcBuild build() {
    final c = PartCatalog.seed();
    return PcBuild(
      cpu: c.byId('r5-5600') as Cpu,
      gpu: c.byId('rtx-4090') as Gpu,
      motherboard: c.byId('msi-b650-tomahawk') as Motherboard,
    );
  }
}

Future<void> _pump(
  WidgetTester tester, {
  bool seeded = false,
  String? selfId,
  SharedPreferences? prefs,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        if (seeded) buildProvider.overrideWith(_SeededBuild.new),
        selfDeviceIdProvider.overrideWith((ref) async => selfId),
        if (prefs != null) prefsProvider.overrideWithValue(prefs),
      ],
      child: const DarbogazApp(),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tapText(WidgetTester tester, String text) async {
  final f = find.text(text);
  if (f.evaluate().isEmpty) {
    // Lazily built list items: scroll the main list until it appears.
    await tester.scrollUntilVisible(
      f,
      200,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await tester.ensureVisible(f.first);
  await tester.tap(f.first);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('device tab: PC is default with compact slots', (tester) async {
    await _pump(tester);
    expect(find.text('Cihazım'), findsOneWidget);
    for (final t in ['PC', 'Telefon', 'Saat', 'İşlemci', 'Ekran Kartı']) {
      expect(find.text(t), findsWidgets, reason: t);
    }
    expect(find.text('Hazır sistem seç (isteğe bağlı)'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Diğer parçalar'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Diğer parçalar'), findsOneWidget);
    expect(find.text('Kasa'), findsNothing); // collapsed
  });

  testWidgets('picking a CPU fills the slot', (tester) async {
    await _pump(tester);
    await _tapText(tester, 'İşlemci');
    await tester.enterText(find.byType(TextField), '7800X3D');
    await tester.pumpAndSettle();
    await _tapText(tester, 'AMD Ryzen 7 7800X3D');
    expect(find.text('AMD Ryzen 7 7800X3D'), findsOneWidget);
    expect(find.text('Cihazım'), findsOneWidget);
  });

  testWidgets('PC: mismatch banner, analysis and performance sections', (
    tester,
  ) async {
    await _pump(tester, seeded: true);
    expect(find.textContaining('uyumsuzluk var'), findsOneWidget);
    await _tapText(tester, 'Darboğazı Analiz Et');
    expect(find.text('Performans · PC'), findsOneWidget);
    expect(find.text('İşlemci sınırlıyor'), findsOneWidget);

    await _tapText(tester, 'Oyun');
    expect(find.text('Counter-Strike 2'), findsOneWidget);
    await _tapText(tester, 'Uygulama');
    expect(find.text('SolidWorks'), findsOneWidget);
    await _tapText(tester, 'AI');
    expect(find.text('Qwen3 8B'), findsOneWidget);
  });

  testWidgets('phone: pick from catalog, see score and mobile games', (
    tester,
  ) async {
    await _pump(tester);
    await _tapText(tester, 'Telefon');
    await _tapText(tester, 'Telefon seç');
    await tester.enterText(find.byType(TextField), 'iPhone 15 Pro');
    await tester.pumpAndSettle();
    await _tapText(tester, 'Apple iPhone 15 Pro');
    expect(find.text('Apple iPhone 15 Pro'), findsOneWidget);
    expect(find.text('Amiral gemisi'), findsOneWidget);

    await _tapText(tester, 'Performansı gör');
    expect(find.text('Performans · Telefon'), findsOneWidget);
    await _tapText(tester, 'Oyun');
    expect(find.text('Genshin Impact'), findsOneWidget);
  });

  testWidgets('phone: the running device is recognised and selectable', (
    tester,
  ) async {
    await _pump(tester, selfId: 'SM-S921B');
    await _tapText(tester, 'Telefon');
    expect(find.text('Bu telefon: Samsung Galaxy S24'), findsOneWidget);
    await _tapText(tester, 'Seç');
    expect(find.textContaining('Exynos 2400'), findsOneWidget);
    expect(find.textContaining('Bu telefon:'), findsNothing);
  });

  testWidgets('watch: compatible with iPhone, not with an Android phone', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'phone.selection': ['iphone-15-pro', 'a17-pro', '8'],
    });
    final prefs = await SharedPreferences.getInstance();
    await _pump(tester, prefs: prefs);
    await _tapText(tester, 'Saat');
    await _tapText(tester, 'Saat seç');
    await tester.enterText(find.byType(TextField), 'Series 10');
    await tester.pumpAndSettle();
    await _tapText(tester, 'Apple Watch Series 10');
    expect(find.text('Uyumlu'), findsOneWidget);

    await _tapText(tester, 'Apple iPhone 15 Pro');
    await tester.enterText(find.byType(TextField), 'Galaxy S24 Ultra');
    await tester.pumpAndSettle();
    await _tapText(tester, 'Samsung Galaxy S24 Ultra');
    expect(find.text('Uyumsuz'), findsOneWidget);
  });

  testWidgets('selections persist across restarts', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await _pump(tester, prefs: prefs);
    await _tapText(tester, 'Telefon');
    expect(prefs.getString('device.kind'), 'phone');

    final c = ProviderContainer(
      overrides: [prefsProvider.overrideWithValue(prefs)],
    );
    addTearDown(c.dispose);
    c
        .read(phoneSelectionProvider.notifier)
        .select(c.read(mobileCatalogProvider).phone('pixel-8')!);
    final restored = ProviderContainer(
      overrides: [prefsProvider.overrideWithValue(prefs)],
    );
    addTearDown(restored.dispose);
    expect(restored.read(activeDeviceProvider), DeviceKind.phone);
    expect(restored.read(phoneSpecProvider)?.phone.id, 'pixel-8');
    expect(restored.read(phoneSpecProvider)?.soc.id, 'tensor-g3');
  });

  testWidgets('prices: search shows store links', (tester) async {
    await _pump(tester);
    await _tapText(tester, 'Fiyat');
    await tester.enterText(find.byType(TextField), 'rtx 4070 super');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(find.text('NVIDIA GeForce RTX 4070 Super'), findsOneWidget);
    expect(find.text('Akakçe'), findsOneWidget);
  });
}
