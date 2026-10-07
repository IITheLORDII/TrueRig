import 'package:flutter_test/flutter_test.dart';

import 'package:darbogaz/features/prices/price_repository.dart';
import 'package:darbogaz/features/prices/store_list.dart';

PriceOffer _offer(String store, double price, {double? rating, String? host}) =>
    PriceOffer(
      store: store,
      price: price,
      currency: 'TRY',
      url: Uri.parse('https://${host ?? 'www.example.com'}/p/1'),
      inStock: true,
      fetchedAt: DateTime(2026, 10, 7),
      rating: rating,
    );

void main() {
  final links = storeSearchLinks('RTX 4060');
  final result = PriceSearchResult(
    offers: [
      _offer('Hepsiburada', 12000, rating: 4.2, host: 'www.hepsiburada.com'),
      _offer('Trendyol', 11500, rating: 4.7, host: 'www.trendyol.com'),
      _offer('Vatan Bilgisayar', 13000, rating: 3.9),
    ],
  );

  test('known stores get their price, other sellers get a row', () {
    final rows = mergeStores(links, result, StoreSort.name);
    expect(rows.firstWhere((r) => r.store == 'Trendyol').offer?.price, 11500);
    expect(rows.any((r) => r.store == 'Vatan Bilgisayar'), isTrue);
    expect(rows.firstWhere((r) => r.store == 'Akakçe').offer, isNull);
  });

  test('price sorts put stores without a price last', () {
    final asc = mergeStores(links, result, StoreSort.priceAsc);
    expect(asc.take(3).map((r) => r.offer?.price), [11500, 12000, 13000]);
    expect(asc.last.offer, isNull);
    final desc = mergeStores(links, result, StoreSort.priceDesc);
    expect(desc.first.offer?.price, 13000);
  });

  test('rating sort shows the best rated first', () {
    final rows = mergeStores(links, result, StoreSort.rating);
    expect(rows.first.store, 'Trendyol');
  });

  test('average ignores outliers', () {
    final r = PriceSearchResult(
      offers: [
        _offer('A', 100),
        _offer('B', 110),
        _offer('C', 120),
        _offer('D', 900),
      ],
    );
    expect(r.averagePrice, closeTo(110, 0.01));
  });

  test('no live data still lists every store', () {
    final rows = mergeStores(links, null, StoreSort.priceAsc);
    expect(rows, hasLength(links.length));
    expect(rows.every((r) => r.offer == null), isTrue);
  });
}
