import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:perf_engine/perf_engine.dart';

import 'package:darbogaz/features/prices/price_repository.dart';

/// Daily price index published by the `Price index` GitHub workflow
/// (tool/price-index). Override with `--dart-define=PRICE_INDEX_URL=...`.
const String kPriceIndexUrl = String.fromEnvironment(
  'PRICE_INDEX_URL',
  defaultValue: 'https://raw.githubusercontent.com/IITheLORDII/TrueRig/prices-data/prices.json',
);

/// How long a downloaded index is reused before it is fetched again.
const Duration _indexTtl = Duration(hours: 1);
const Duration _indexTimeout = Duration(seconds: 15);

/// One product of the index with its store offers.
@immutable
class IndexedItem {
  const IndexedItem({
    required this.key,
    required this.name,
    required this.offers,
    this.mpn,
    this.refUsd,
  });

  final String key;
  final String name;
  final String? mpn;
  final double? refUsd;
  final List<PriceOffer> offers;
}

/// Parsed prices.json.
@immutable
class PriceIndexData {
  const PriceIndexData({required this.items, this.usdTry, this.generatedAt});

  final List<IndexedItem> items;
  final double? usdTry;
  final DateTime? generatedAt;

  factory PriceIndexData.fromJson(Map<String, dynamic> j) {
    final items = <IndexedItem>[];
    final raw = j['items'];
    if (raw is Map<String, dynamic>) {
      for (final e in raw.entries) {
        final v = e.value;
        if (v is! Map<String, dynamic>) continue;
        final offers =
            [
                for (final o in (v['offers'] as List? ?? const []))
                  if (o is Map<String, dynamic>) _offer(o),
              ].whereType<PriceOffer>().toList()
              ..sort((a, b) => a.price.compareTo(b.price));
        items.add(
          IndexedItem(
            key: e.key,
            name: v['name'] as String? ?? e.key,
            mpn: v['mpn'] as String?,
            refUsd: (v['ref_usd'] as num?)?.toDouble(),
            offers: List.unmodifiable(offers),
          ),
        );
      }
    }
    return PriceIndexData(
      items: List.unmodifiable(items),
      usdTry: (j['usd_try'] as num?)?.toDouble(),
      generatedAt: DateTime.tryParse(j['generated_at'] as String? ?? ''),
    );
  }

  static PriceOffer? _offer(Map<String, dynamic> o) {
    try {
      final offer = PriceOffer.fromJson(o);
      return offer.url.scheme == 'https' ? offer : null;
    } on Object catch (e) {
      debugPrint('Fiyat indeksinde geçersiz teklif atlandı: $e');
      return null;
    }
  }

  /// The item a query names: exact name / MPN first, then the item whose
  /// name contains every query word with the fewest extra words.
  IndexedItem? find(String query) {
    final q = PartCatalog.normalize(query);
    if (q.isEmpty) return null;
    for (final it in items) {
      if (PartCatalog.normalize(it.name) == q) return it;
      final mpn = it.mpn;
      if (mpn != null && PartCatalog.normalize(mpn) == q) return it;
    }
    final words = q.split(' ');
    IndexedItem? best;
    var bestExtra = 1 << 30;
    for (final it in items) {
      final name = PartCatalog.normalize(it.name).split(' ').toSet();
      if (!words.every(name.contains)) continue;
      final extra = name.length - words.length;
      if (extra < bestExtra) {
        best = it;
        bestExtra = extra;
      }
    }
    return best;
  }
}

/// Reads prices from the published daily index (no live crawling in the
/// app: one polite crawler serves every user).
class IndexPriceRepository implements PriceRepository {
  IndexPriceRepository({http.Client? client, this.url = kPriceIndexUrl})
    : _client = client ?? http.Client();

  final http.Client _client;
  final String url;
  Future<PriceIndexData>? _loading;
  DateTime? _loadedAt;

  @override
  bool get isConfigured => url.startsWith('https://');

  Future<PriceIndexData> load() {
    final fresh =
        _loadedAt != null && DateTime.now().difference(_loadedAt!) < _indexTtl;
    if (_loading != null && fresh) return _loading!;
    _loadedAt = DateTime.now();
    return _loading = _download().catchError((Object e) {
      // Retry on the next search instead of caching the failure.
      _loading = null;
      _loadedAt = null;
      throw e;
    });
  }

  Future<PriceIndexData> _download() async {
    final http.Response res;
    try {
      res = await _client.get(Uri.parse(url)).timeout(_indexTimeout);
    } on Exception catch (e) {
      throw PriceApiException('Fiyat listesi indirilemedi ($e)');
    }
    if (res.statusCode == 404) {
      // Not published yet (first run of the workflow pending).
      return const PriceIndexData(items: []);
    }
    if (res.statusCode != 200) {
      throw PriceApiException('Fiyat listesi alınamadı: ${res.statusCode}');
    }
    final body = jsonDecode(utf8.decode(res.bodyBytes));
    if (body is! Map<String, dynamic>) {
      throw const PriceApiException('Fiyat listesi biçimi beklenmedik');
    }
    return PriceIndexData.fromJson(body);
  }

  @override
  Future<PriceSearchResult> search(String query) async {
    if (!isConfigured) return PriceSearchResult.empty;
    final q = sanitizeQuery(query);
    if (q.isEmpty) return PriceSearchResult.empty;
    final data = await load();
    final item = data.find(q);
    if (item == null) return PriceSearchResult.empty;
    final rate = data.usdTry;
    final ref = item.refUsd;
    return PriceSearchResult(
      offers: item.offers,
      estimateTry: ref != null && rate != null ? ref * rate : null,
      updatedAt: data.generatedAt,
    );
  }
}

/// Daily index plus the optional live service; offers are merged.
class CombinedPriceRepository implements PriceRepository {
  const CombinedPriceRepository(this.sources);

  final List<PriceRepository> sources;

  @override
  bool get isConfigured => sources.any((s) => s.isConfigured);

  @override
  Future<PriceSearchResult> search(String query) async {
    final active = sources.where((s) => s.isConfigured).toList();
    final results = <PriceSearchResult>[];
    Object? lastError;
    for (final r in await Future.wait(
      active.map(
        (s) => s.search(query).then<Object>((v) => v, onError: (Object e) => e),
      ),
    )) {
      if (r is PriceSearchResult) {
        results.add(r);
      } else {
        lastError = r;
      }
    }
    if (results.isEmpty && lastError != null) throw lastError;
    final seen = <String>{};
    final offers = [
      for (final r in results)
        for (final o in r.offers)
          if (seen.add(o.url.toString())) o,
    ]..sort((a, b) => a.price.compareTo(b.price));
    PriceSearchResult? withImage;
    for (final r in results) {
      if (r.imageUrl != null) withImage ??= r;
    }
    return PriceSearchResult(
      offers: List.unmodifiable(offers),
      imageUrl: withImage?.imageUrl,
      imageSource: withImage?.imageSource,
      estimateTry: results.map((r) => r.estimateTry).nonNulls.firstOrNull,
      updatedAt: results.map((r) => r.updatedAt).nonNulls.firstOrNull,
    );
  }
}
