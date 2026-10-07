import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:darbogaz/core/theme/app_theme.dart';
import 'package:darbogaz/features/prices/price_index.dart';
import 'package:darbogaz/features/prices/price_repository.dart';
import 'package:darbogaz/features/prices/store_list.dart';

import 'support.dart';

Map<String, Object?> _offer(String store, double price, String title) => {
  'store': store,
  'price': price,
  'currency': 'TRY',
  'url': 'https://www.$store.com/p',
  'in_stock': true,
  'rating': 4.5,
  'review_count': 12,
  'title': title,
  'fetched_at': '2026-10-08T03:20:00Z',
};

final _index = {
  'version': 1,
  'generated_at': '2026-10-08T03:40:00Z',
  'usd_try': 49.2,
  'stores': [],
  'items': {
    'gpu:rtx-4060': {
      'name': 'NVIDIA GeForce RTX 4060',
      'kind': 'gpu',
      'ref_usd': 299,
      'offers': [
        _offer('itopya', 13499, 'ASUS Dual RTX 4060 OC 8GB'),
        _offer('mediamarkt', 12999, 'MSI RTX 4060 Ventus 2X'),
      ],
      'checked': {},
    },
    'gpu:rtx-4060ti': {
      'name': 'NVIDIA GeForce RTX 4060 Ti',
      'kind': 'gpu',
      'offers': [],
      'checked': {},
    },
    'phone:iphone-15': {
      'name': 'Apple iPhone 15',
      'kind': 'phone',
      'ref_usd': 799,
      'offers': [],
      'checked': {},
    },
  },
};

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('PriceIndexData', () {
    final data = PriceIndexData.fromJson(_index);

    test('exact names win over longer ones', () {
      expect(data.find('NVIDIA GeForce RTX 4060')?.key, 'gpu:rtx-4060');
      expect(data.find('rtx 4060 ti')?.key, 'gpu:rtx-4060ti');
      expect(data.find('RTX 4060')?.key, 'gpu:rtx-4060');
      expect(data.find('Samsung Galaxy'), isNull);
    });

    test('offers are cheapest first', () {
      final it = data.find('NVIDIA GeForce RTX 4060')!;
      expect(it.offers.map((o) => o.price), [12999, 13499]);
      expect(it.offers.first.title, 'MSI RTX 4060 Ventus 2X');
    });
  });

  group('IndexPriceRepository', () {
    test('downloads once and returns offers or an estimate', () async {
      var calls = 0;
      final repo = IndexPriceRepository(
        url: 'https://example.com/prices.json',
        client: MockClient((req) async {
          calls++;
          return http.Response.bytes(utf8.encode(jsonEncode(_index)), 200);
        }),
      );
      final gpu = await repo.search('NVIDIA GeForce RTX 4060');
      expect(gpu.offers, hasLength(2));
      expect(gpu.updatedAt, DateTime.utc(2026, 10, 8, 3, 40));
      final phone = await repo.search('Apple iPhone 15');
      expect(phone.offers, isEmpty);
      expect(phone.estimateTry, closeTo(799 * 49.2, 0.01));
      expect(calls, 1);
    });

    test('not published yet is empty, server errors are reported', () async {
      final missing = IndexPriceRepository(
        url: 'https://example.com/prices.json',
        client: MockClient((_) async => http.Response('', 404)),
      );
      expect((await missing.search('RTX 4060')).offers, isEmpty);
      final broken = IndexPriceRepository(
        url: 'https://example.com/prices.json',
        client: MockClient((_) async => http.Response('', 500)),
      );
      expect(broken.search('RTX 4060'), throwsA(isA<PriceApiException>()));
    });
  });

  testWidgets('store list shows prices without "Fiyatı gör"', (tester) async {
    final result = await IndexPriceRepository(
      url: 'https://example.com/prices.json',
      client: MockClient(
        (_) async => http.Response.bytes(utf8.encode(jsonEncode(_index)), 200),
      ),
    ).search('NVIDIA GeForce RTX 4060');
    tester.view.physicalSize = const Size(430, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          priceRepositoryProvider.overrideWithValue(
            FakePriceRepository(result),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: const Scaffold(
            body: SingleChildScrollView(
              child: StoreList(query: 'NVIDIA GeForce RTX 4060'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('12.999'), findsWidgets);
    expect(find.textContaining('MSI RTX 4060 Ventus 2X'), findsOneWidget);
    expect(find.textContaining('Diğer mağazalar'), findsOneWidget);
    expect(find.textContaining('Fiyatı gör'), findsNothing);
    expect(find.textContaining('Son güncelleme'), findsOneWidget);
  });
}
