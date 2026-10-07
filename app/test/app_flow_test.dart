import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:perf_engine/perf_engine.dart';

import 'package:darbogaz/core/devices.dart';
import 'package:darbogaz/core/providers.dart';
import 'package:darbogaz/features/home/home_page.dart';
import 'package:darbogaz/features/performance/performance_page.dart';

import 'support.dart';

/// Mismatched AM4 CPU on an AM5 board with an RTX 4090 (CPU bound).
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

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('home shows status and feature tiles', (tester) async {
    await pumpApp(tester);
    expect(find.text('Durumun'), findsOneWidget);
    for (final t in [
      'Bilgisayarım eklenmedi',
      'Telefonum eklenmedi',
      'Saatim eklenmedi',
      'Darboğaz analizi',
      'Karşılaştır',
      'Hazır sistem',
    ]) {
      expect(find.text(t), findsWidgets, reason: t);
    }
  });

  testWidgets('Cihazlarım: Bilgisayarım section edits the PC', (tester) async {
    await pumpApp(tester);
    await openTab(tester, 'Cihazlarım');
    for (final t in ['Bilgisayarım', 'Telefonum', 'Saatim']) {
      expect(find.text(t), findsOneWidget, reason: t);
    }
    expect(find.text('Diğer parçalar'), findsOneWidget);
    expect(find.text('Kasa'), findsNothing); // collapsed
    await tapText(tester, 'İşlemci');
    await search(tester, '7800X3D');
    await tapText(tester, 'AMD Ryzen 7 7800X3D');
    expect(find.text('AMD Ryzen 7 7800X3D'), findsOneWidget);
  });

  testWidgets('home status opens the general analysis; Oyun is per game', (
    tester,
  ) async {
    await pumpApp(tester, build: _SeededBuild.new);
    expect(find.textContaining('· İşlemci'), findsOneWidget);
    await tapText(tester, 'Ryzen 5 5600 + GeForce RTX 4090');
    expect(find.text('Genel darboğaz'), findsOneWidget);
    expect(find.text('Çözünürlüğe göre'), findsOneWidget);
    expect(find.text('İşlemci sınırlıyor'), findsWidgets);

    await tapText(tester, 'Oyun');
    expect(find.text('Tüm oyunlar (ortalama FPS)'), findsOneWidget);
    expect(find.text('Counter-Strike 2'), findsOneWidget);
    await tapText(tester, 'Uygulama');
    expect(find.text('SolidWorks'), findsOneWidget);
    await tapText(tester, 'AI');
    expect(find.text('Qwen3 8B'), findsOneWidget);
  });

  testWidgets('phone: add from catalog, then analyse', (tester) async {
    await pumpApp(tester);
    await openTab(tester, 'Cihazlarım');
    await tapText(tester, 'Telefonum');
    await tapText(tester, 'Telefon seç');
    await search(tester, 'iPhone 15 Pro');
    await tapText(tester, 'Apple iPhone 15 Pro');
    expect(find.text('Amiral gemisi'), findsOneWidget);

    await tapText(tester, 'Performansı gör');
    expect(find.byType(PerformancePage), findsOneWidget);
    expect(find.text('Apple iPhone 15 Pro'), findsWidgets); // device chip
    await tapText(tester, 'Oyun');
    expect(find.text('Genshin Impact'), findsOneWidget);
  });

  testWidgets('home offers the running phone as a quick action', (
    tester,
  ) async {
    await pumpApp(tester, selfId: 'SM-S921B');
    await tapText(tester, 'Bu telefon: Galaxy S24');
    expect(find.text('Samsung Galaxy S24'), findsOneWidget);
    expect(find.textContaining('Bu telefon:'), findsNothing);
  });

  testWidgets('Saatim: pairing card with iPhone, then with an Android', (
    tester,
  ) async {
    await pumpApp(
      tester,
      prefs: await prefsWith({
        'phone.selection': ['iphone-15-pro', 'a17-pro', '8'],
      }),
    );
    await openTab(tester, 'Cihazlarım');
    await tapText(tester, 'Saatim');
    await tapText(tester, 'Saat seç');
    await search(tester, 'Series 10');
    await tapText(tester, 'Apple Watch Series 10');
    expect(find.text('Telefon ⇄ Saat eşleşmesi'), findsOneWidget);
    expect(find.text('Uyumlu'), findsOneWidget);
    expect(
      find.textContaining('saat özelliği bu telefonla çalışır'),
      findsOneWidget,
    );

    await tapText(tester, 'Eşlenecek telefonu değiştir');
    await search(tester, 'Galaxy S24 Ultra');
    await tapText(tester, 'Samsung Galaxy S24 Ultra');
    expect(find.text('Uyumsuz'), findsOneWidget);
    expect(find.textContaining('yalnızca iPhone ile çalışır'), findsOneWidget);

    // Home shows the pairing too.
    await openTab(tester, 'Ana Sayfa');
    expect(find.text('EŞLEŞME'), findsOneWidget);
  });

  testWidgets('Analiz device chip switches the analysed device', (
    tester,
  ) async {
    await pumpApp(
      tester,
      build: _SeededBuild.new,
      prefs: await prefsWith({
        'phone.selection': ['pixel-8', 'tensor-g3', '8'],
      }),
    );
    await openTab(tester, 'Analiz');
    expect(find.text('Genel darboğaz'), findsOneWidget);
    await tap(tester, find.byIcon(Icons.unfold_more_rounded));
    await tapText(tester, 'Telefon: Google Pixel 8');
    expect(find.text('Darboğaz puanı · Tensor G3, 8 GB'), findsOneWidget);
  });

  testWidgets('selections persist across restarts', (tester) async {
    final prefs = await prefsWith({});
    await pumpApp(tester, prefs: prefs);
    await openTab(tester, 'Cihazlarım');
    await tapText(tester, 'Telefonum');
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
    expect(restored.read(phoneSpecProvider)?.soc.id, 'tensor-g3');
  });

  testWidgets('prices: search, store links and recent searches', (
    tester,
  ) async {
    await pumpApp(tester);
    await openTab(tester, 'Fiyat');
    await tester.enterText(find.byType(TextField), 'rtx 4070 super');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(find.text('NVIDIA GeForce RTX 4070 Super'), findsOneWidget);
    expect(find.text('Akakçe'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(find.text('SON ARAMALAR'), findsOneWidget);
    expect(find.text('rtx 4070 super'), findsOneWidget);
  });

  testWidgets('profile opens from the app bar', (tester) async {
    await pumpApp(tester);
    await tap(tester, find.byTooltip('Profil ve ayarlar'));
    expect(find.text('Görünüm'), findsOneWidget);
  });

  testWidgets('old addresses redirect to the new tabs', (tester) async {
    await pumpApp(tester);
    final router = GoRouter.of(tester.element(find.byType(HomePage)));
    router.go('/performance');
    await tester.pumpAndSettle();
    expect(find.byType(PerformancePage), findsOneWidget);
    router.go('/device');
    await tester.pumpAndSettle();
    expect(find.byType(HomePage), findsOneWidget);
    router.go('/devices/phone');
    await tester.pumpAndSettle();
    expect(find.text('Telefon seç'), findsOneWidget);
  });
}
