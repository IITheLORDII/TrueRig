import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Max query length accepted from the user / scanner.
const int kMaxQueryLength = 100;

/// Backend price endpoint (Supabase Edge Function `price-search`).
/// Configure with `--dart-define=PRICE_API_URL=https://...`.
const String kPriceApiUrl = String.fromEnvironment('PRICE_API_URL');

const Duration _requestTimeout = Duration(seconds: 12);

@immutable
class StoreLink {
  const StoreLink({
    required this.store,
    required this.region,
    required this.url,
  });

  final String store;
  final String region;
  final Uri url;
}

@immutable
class PriceOffer {
  const PriceOffer({
    required this.store,
    required this.price,
    required this.currency,
    required this.url,
    required this.inStock,
    required this.fetchedAt,
  });

  factory PriceOffer.fromJson(Map<String, dynamic> j) => PriceOffer(
    store: j['store'] as String,
    price: (j['price'] as num).toDouble(),
    currency: j['currency'] as String? ?? 'TRY',
    url: Uri.parse(j['url'] as String),
    inStock: j['in_stock'] as bool? ?? true,
    fetchedAt: DateTime.parse(j['fetched_at'] as String),
  );

  final String store;
  final double price;
  final String currency;
  final Uri url;
  final bool inStock;
  final DateTime fetchedAt;
}

class PriceApiException implements Exception {
  const PriceApiException(this.message);
  final String message;
  @override
  String toString() => 'PriceApiException: $message';
}

/// Trims, collapses whitespace and caps length of a search query.
String sanitizeQuery(String raw) {
  final q = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
  return q.length > kMaxQueryLength ? q.substring(0, kMaxQueryLength) : q;
}

/// Store search deep links. These work without any API agreement; the user
/// lands on the store's own search results for the model / part number.
List<StoreLink> storeSearchLinks(String rawQuery) {
  final q = Uri.encodeQueryComponent(sanitizeQuery(rawQuery));
  if (q.isEmpty) return const [];
  Uri u(String s) => Uri.parse(s);
  return [
    StoreLink(
      store: 'Akakçe',
      region: 'TR',
      url: u('https://www.akakce.com/arama/?q=$q'),
    ),
    StoreLink(
      store: 'Cimri',
      region: 'TR',
      url: u('https://www.cimri.com/arama?q=$q'),
    ),
    StoreLink(
      store: 'Hepsiburada',
      region: 'TR',
      url: u('https://www.hepsiburada.com/ara?q=$q'),
    ),
    StoreLink(
      store: 'Trendyol',
      region: 'TR',
      url: u('https://www.trendyol.com/sr?q=$q'),
    ),
    StoreLink(
      store: 'Amazon.com.tr',
      region: 'TR',
      url: u('https://www.amazon.com.tr/s?k=$q'),
    ),
    StoreLink(
      store: 'n11',
      region: 'TR',
      url: u('https://www.n11.com/arama?q=$q'),
    ),
    StoreLink(
      store: 'Amazon.com',
      region: 'Global',
      url: u('https://www.amazon.com/s?k=$q'),
    ),
    StoreLink(
      store: 'Newegg',
      region: 'Global',
      url: u('https://www.newegg.com/p/pl?d=$q'),
    ),
    StoreLink(
      store: 'PCPartPicker',
      region: 'Global',
      url: u('https://pcpartpicker.com/search/?q=$q'),
    ),
  ];
}

/// Offers plus a product image matched to the query by MPN/GTIN, if any.
@immutable
class PriceSearchResult {
  const PriceSearchResult({
    required this.offers,
    this.imageUrl,
    this.imageSource,
  });

  static const empty = PriceSearchResult(offers: []);

  /// Cheapest first.
  final List<PriceOffer> offers;
  final Uri? imageUrl;

  /// Page the image was taken from (shown as attribution).
  final Uri? imageSource;

  /// Offers priced above twice the median of a result set of 3+ offers;
  /// usually marketplace listings with placeholder prices.
  bool isOutlier(PriceOffer o) {
    if (offers.length < 3) return false;
    final prices = offers.map((e) => e.price).toList()..sort();
    final median = prices[prices.length ~/ 2];
    return o.price > median * 2;
  }
}

abstract interface class PriceRepository {
  bool get isConfigured;

  Future<PriceSearchResult> search(String query);
}

class RemotePriceRepository implements PriceRepository {
  RemotePriceRepository({http.Client? client, this.baseUrl = kPriceApiUrl})
    : _client = client ?? http.Client();

  final http.Client _client;
  final String baseUrl;

  @override
  bool get isConfigured => baseUrl.startsWith('https://');

  @override
  Future<PriceSearchResult> search(String query) async {
    if (!isConfigured) return PriceSearchResult.empty;
    final q = sanitizeQuery(query);
    if (q.isEmpty) return PriceSearchResult.empty;
    final uri = Uri.parse(baseUrl).replace(queryParameters: {'q': q});
    final http.Response res;
    try {
      res = await _client.get(uri).timeout(_requestTimeout);
    } on Exception catch (e) {
      throw PriceApiException('Fiyat servisine ulaşılamadı ($e)');
    }
    if (res.statusCode != 200) {
      throw PriceApiException('Fiyat servisi hata döndü: ${res.statusCode}');
    }
    final body = jsonDecode(res.body);
    if (body is! Map<String, dynamic> || body['data'] is! List) {
      throw const PriceApiException('Beklenmeyen yanıt biçimi');
    }
    final offers =
        (body['data'] as List)
            .whereType<Map<String, dynamic>>()
            .map(PriceOffer.fromJson)
            .where((o) => o.url.scheme == 'https')
            .toList()
          ..sort((a, b) => a.price.compareTo(b.price));
    final meta = body['meta'];
    return PriceSearchResult(
      offers: List.unmodifiable(offers),
      imageUrl: meta is Map<String, dynamic>
          ? httpsUri(meta['image_url'])
          : null,
      imageSource: meta is Map<String, dynamic>
          ? httpsUri(meta['image_source'])
          : null,
    );
  }
}

/// Parses [value] as an https URL; anything else (http, junk) yields null.
Uri? httpsUri(Object? value) {
  if (value is! String) return null;
  final u = Uri.tryParse(value);
  return u != null && u.scheme == 'https' && u.host.isNotEmpty ? u : null;
}
