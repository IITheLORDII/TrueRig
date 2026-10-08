import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:perf_engine/perf_engine.dart';

import 'package:darbogaz/features/cart/cart_plan.dart';
import 'package:darbogaz/features/prices/price_repository.dart';

import 'support.dart';

PriceOffer _o(String store, double price, {bool inStock = true}) => PriceOffer(
  store: store,
  price: price,
  currency: 'TRY',
  url: Uri.parse('https://www.${store.toLowerCase()}.com/p/$price'),
  inStock: inStock,
  fetchedAt: DateTime(2026, 10, 8),
  title: '$store ürünü',
);

/// Different offers per query, like the real price index.
class _ByQuery implements PriceRepository {
  const _ByQuery(this.byName);

  final Map<String, PriceSearchResult> byName;

  @override
  bool get isConfigured => true;

  @override
  Future<PriceSearchResult> search(String query) async =>
      byName[query] ?? PriceSearchResult.empty;
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  final catalog = PartCatalog.seed();
  final cpu = catalog.byId('r5-5600')!;
  final gpu = catalog.byId('rtx-3060-12')!;
  final ram = catalog.byId('kingston-ddr4-3200-32')!;

  final parts = [
    PartOffers(cpu, [_o('İtopya', 4000), _o('Vatan', 4200)]),
    PartOffers(gpu, [_o('Vatan', 11000), _o('İtopya', 11500)]),
    PartOffers(ram, const [], estimateTry: 2500),
  ];

  group('cart plan', () {
    test('cheapest mix takes each part from its cheapest store', () {
      final plan = cheapestMix(parts);
      expect(plan.baskets.map((b) => b.store).toSet(), {'İtopya', 'Vatan'});
      expect(plan.total, 15000);
      expect(plan.missing.single.part, ram);
      expect(plan.missingEstimate, 2500);
    });

    test('single store covers the most parts at the lowest total', () {
      final plan = bestSingleStore(parts)!;
      // Vatan 4200 + 11000 beats İtopya 4000 + 11500.
      expect(plan.baskets.single.store, 'Vatan');
      expect(plan.total, 15200);
      expect(plan.pricedParts, 2);
    });

    test('out-of-stock offers lose to in-stock ones', () {
      final p = PartOffers(cpu, [_o('A', 3000, inStock: false), _o('B', 3500)]);
      expect(p.best?.store, 'B');
    });

    test('Amazon cart link lists every ASIN with quantity 1', () {
      final url = amazonCartUrl(['B0AAA', 'B0BBB'])!;
      expect(url.host, 'www.amazon.com.tr');
      expect(url.path, '/gp/aws/cart/add.html');
      expect(url.queryParameters['ASIN.2'], 'B0BBB');
      expect(url.queryParameters['Quantity.1'], '1');
      expect(amazonCartUrl(const []), isNull);
    });
  });

  testWidgets('Bilgisayarım → Sepeti hazırla shows store baskets', (
    tester,
  ) async {
    await pumpApp(
      tester,
      prefs: await prefsWith({
        'pc.build': ['r5-5600', 'rtx-3060-12'],
      }),
      prices: _ByQuery({
        cpu.mpn ?? cpu.displayName: PriceSearchResult(
          offers: [_o('İtopya', 4000)],
        ),
        gpu.mpn ?? gpu.displayName: PriceSearchResult(
          offers: [_o('Vatan', 11000), _o('İtopya', 11500)],
        ),
      }),
    );
    await openTab(tester, 'Cihazlarım');
    await tap(tester, find.text('Sepeti hazırla: nereden en ucuza?'));

    expect(find.text('Toplam'), findsOneWidget);
    expect(find.text('İtopya'), findsWidgets);
    expect(find.text('Vatan'), findsWidgets);
    expect(find.text('Tek mağazadan'), findsOneWidget);
    expect(find.text('Toplatmak için gönder'), findsNothing);
    expect(find.text('WhatsApp'), findsNothing);

    await tapText(tester, 'Tek mağazadan');
    expect(find.textContaining('İtopya\'da 2 ürünü aç'), findsOneWidget);
    expect(find.byType(Card), findsWidgets);
  });

  testWidgets('a laptop is priced as a whole system', (tester) async {
    await pumpApp(
      tester,
      prefs: await prefsWith({
        'pc.build': ['i5-12450h', 'rtx-3050-laptop', 'ram-ddr4-3200-2x8'],
        'pc.prebuilt': ['Casper Excalibur G770 · i5-12450H · RTX 3050', '1'],
      }),
    );
    await openTab(tester, 'Cihazlarım');
    await tap(tester, find.text('Sepeti hazırla: nereden en ucuza?'));
    expect(
      find.textContaining('Casper Excalibur G770 fiyatlarına'),
      findsOneWidget,
    );
    expect(find.text('Mağazalar'), findsOneWidget);
  });
}
