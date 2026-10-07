import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:darbogaz/features/prices/price_repository.dart';

void main() {
  group('sanitizeQuery', () {
    test('trims and collapses whitespace', () {
      expect(sanitizeQuery('  RTX   4070 \n Super '), 'RTX 4070 Super');
    });
    test('caps length', () {
      expect(sanitizeQuery('a' * 500).length, kMaxQueryLength);
    });
  });

  group('storeSearchLinks', () {
    test('empty query yields no links', () {
      expect(storeSearchLinks('   '), isEmpty);
    });

    test('encodes the query and uses https only', () {
      final links = storeSearchLinks('CMK32GX5M2B6000Z30 & co');
      expect(links, isNotEmpty);
      for (final l in links) {
        expect(l.url.scheme, 'https');
        expect(l.url.toString(), isNot(contains(' ')));
        expect(l.url.toString(), contains('CMK32GX5M2B6000Z30'));
      }
      expect(links.map((l) => l.store), containsAll(['Akakçe', 'Hepsiburada']));
    });
  });

  group('RemotePriceRepository', () {
    const base = 'https://example.supabase.co/functions/v1/price-search';

    test('not configured without https base url', () async {
      final repo = RemotePriceRepository(baseUrl: '');
      expect(repo.isConfigured, isFalse);
      expect((await repo.search('rtx 4090')).offers, isEmpty);
    });

    test('parses offers and sorts cheapest first', () async {
      final client = MockClient((req) async {
        expect(req.url.queryParameters['q'], 'RTX 4090');
        return http.Response(
          jsonEncode({
            'success': true,
            'data': [
              {
                'store': 'B',
                'price': 90000,
                'url': 'https://b.example/x',
                'fetched_at': '2026-10-07T10:00:00Z',
              },
              {
                'store': 'A',
                'price': 85000,
                'currency': 'TRY',
                'url': 'https://a.example/x',
                'in_stock': false,
                'fetched_at': '2026-10-07T10:00:00Z',
              },
            ],
            'meta': {
              'image_url': 'https://cdn.example/img.jpg',
              'image_source': 'http://insecure.example/p',
            },
          }),
          200,
        );
      });
      final repo = RemotePriceRepository(client: client, baseUrl: base);
      final result = await repo.search('  RTX 4090 ');
      expect(result.offers.map((o) => o.store), ['A', 'B']);
      expect(result.offers.first.inStock, isFalse);
      expect(result.imageUrl, Uri.parse('https://cdn.example/img.jpg'));
      expect(result.imageSource, isNull);
    });

    test('non-200 throws PriceApiException', () async {
      final repo = RemotePriceRepository(
        client: MockClient((_) async => http.Response('nope', 500)),
        baseUrl: base,
      );
      expect(() => repo.search('x'), throwsA(isA<PriceApiException>()));
    });

    test('malformed body throws PriceApiException', () async {
      final repo = RemotePriceRepository(
        client: MockClient((_) async => http.Response('[]', 200)),
        baseUrl: base,
      );
      expect(() => repo.search('x'), throwsA(isA<PriceApiException>()));
    });
  });

  group('PriceSearchResult.isOutlier', () {
    PriceOffer offer(double p) => PriceOffer(
      store: 's',
      price: p,
      currency: 'TRY',
      url: Uri.parse('https://x.example'),
      inStock: true,
      fetchedAt: DateTime(2026),
    );

    test('flags prices above twice the median of 3+ offers', () {
      final r = PriceSearchResult(
        offers: [offer(50000), offer(52000), offer(275000)],
      );
      expect(r.isOutlier(r.offers.last), isTrue);
      expect(r.isOutlier(r.offers.first), isFalse);
    });

    test('never flags with fewer than 3 offers', () {
      final r = PriceSearchResult(offers: [offer(1), offer(1000)]);
      expect(r.isOutlier(r.offers.last), isFalse);
    });
  });

  test('httpsUri accepts only https URLs', () {
    expect(httpsUri('https://a.example/x.jpg'), isNotNull);
    expect(httpsUri('http://a.example/x.jpg'), isNull);
    expect(httpsUri('javascript:alert(1)'), isNull);
    expect(httpsUri(42), isNull);
  });
}
