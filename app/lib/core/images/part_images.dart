import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:perf_engine/perf_engine.dart';

import 'package:darbogaz/core/providers.dart';

/// Public Supabase project URL and anon key (safe to ship; RLS protects data).
const String kSupabaseUrl = String.fromEnvironment('SUPABASE_URL');
const String kSupabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

const Duration _timeout = Duration(seconds: 10);

/// Characters allowed in a lookup key (mirrors the server's query rules).
final RegExp _safeKey = RegExp(r'^[a-z0-9 ._\-/+()]{1,100}$');

/// Lookup key for a part image: the lowercased MPN.
String? imageKeyFor(Part part) {
  final key = part.mpn?.trim().toLowerCase();
  return key != null && _safeKey.hasMatch(key) ? key : null;
}

/// Reads MPN-matched image URLs collected by the price-search function.
class PartImageRepository {
  PartImageRepository({
    http.Client? client,
    this.baseUrl = kSupabaseUrl,
    this.anonKey = kSupabaseAnonKey,
  }) : _client = client ?? http.Client();

  final http.Client _client;
  final String baseUrl;
  final String anonKey;

  bool get isConfigured => baseUrl.startsWith('https://') && anonKey.isNotEmpty;

  Future<Map<String, Uri>> fetch(Iterable<String> keys) async {
    final safe = keys.where(_safeKey.hasMatch).toSet();
    if (!isConfigured || safe.isEmpty) return const {};
    final list = safe.map((k) => '"$k"').join(',');
    final uri = Uri.parse('$baseUrl/rest/v1/part_images').replace(
      queryParameters: {'select': 'query,image_url', 'query': 'in.($list)'},
    );
    final res = await _client
        .get(
          uri,
          headers: {'apikey': anonKey, 'Authorization': 'Bearer $anonKey'},
        )
        .timeout(_timeout);
    if (res.statusCode != 200) {
      throw http.ClientException('part_images ${res.statusCode}', uri);
    }
    final rows = jsonDecode(res.body);
    if (rows is! List) return const {};
    return Map.unmodifiable({
      for (final r in rows.whereType<Map<String, dynamic>>())
        if (r['query'] is String && _https(r['image_url']) != null)
          r['query'] as String: _https(r['image_url'])!,
    });
  }

  static Uri? _https(Object? v) {
    final u = v is String ? Uri.tryParse(v) : null;
    return u != null && u.scheme == 'https' && u.host.isNotEmpty ? u : null;
  }
}

final partImageRepositoryProvider = Provider<PartImageRepository>(
  (ref) => PartImageRepository(),
);

/// Images already collected server-side for catalog parts with an MPN.
final cachedPartImagesProvider = FutureProvider<Map<String, Uri>>((ref) async {
  final repo = ref.watch(partImageRepositoryProvider);
  final keys = ref.watch(catalogProvider).all.map(imageKeyFor).nonNulls;
  try {
    return await repo.fetch(keys);
  } on Exception catch (e) {
    // Images are decorative: fall back to category icons, but leave a trace.
    debugPrint('part images unavailable: $e');
    return const {};
  }
});

/// Images learned during this session from price searches.
final sessionPartImagesProvider =
    NotifierProvider<SessionPartImages, Map<String, Uri>>(
      SessionPartImages.new,
    );

class SessionPartImages extends Notifier<Map<String, Uri>> {
  @override
  Map<String, Uri> build() => const {};

  void remember(String query, Uri imageUrl) {
    final key = query.trim().toLowerCase();
    if (!_safeKey.hasMatch(key) || state[key] == imageUrl) return;
    state = Map.unmodifiable({...state, key: imageUrl});
  }
}

/// Image for a catalog part, or null (show the category icon).
final partImageProvider = Provider.family<Uri?, Part>((ref, part) {
  final key = imageKeyFor(part);
  if (key == null) return null;
  return ref.watch(sessionPartImagesProvider)[key] ??
      ref.watch(cachedPartImagesProvider).value?[key];
});
