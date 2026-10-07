import 'package:perf_engine/src/data/part_catalog.dart';
import 'package:perf_engine/src/data/phone_catalog.dart';
import 'package:perf_engine/src/data/soc_catalog.dart';
import 'package:perf_engine/src/data/watch_catalog.dart';
import 'package:perf_engine/src/mobile/mobile_models.dart';

/// A phone identified from a device string, with the chip of that variant.
class PhoneMatch {
  const PhoneMatch(this.phone, this.socId);
  final Phone phone;
  final String socId;
}

/// Read-only phone / watch / chip catalog with search and device matching.
class MobileCatalog {
  MobileCatalog({
    required List<Soc> socs,
    required List<Phone> phones,
    required List<Watch> watches,
  })  : socs = List.unmodifiable(socs),
        phones = List.unmodifiable(phones),
        watches = List.unmodifiable(watches),
        _socById = {for (final s in socs) s.id: s};

  factory MobileCatalog.seed() =>
      MobileCatalog(socs: kSocs, phones: kPhones, watches: kWatches);

  final List<Soc> socs;
  final List<Phone> phones;
  final List<Watch> watches;
  final Map<String, Soc> _socById;

  Soc? soc(String id) => _socById[id];

  Phone? phone(String id) {
    for (final p in phones) {
      if (p.id == id) return p;
    }
    return null;
  }

  Watch? watch(String id) {
    for (final w in watches) {
      if (w.id == id) return w;
    }
    return null;
  }

  /// Brands in catalog order (Apple, Samsung, Google, ...).
  List<String> get phoneBrands => {for (final p in phones) p.brand}.toList();

  List<String> get watchBrands => {for (final w in watches) w.brand}.toList();

  /// Newest first; [query] matches every token in brand + model.
  List<Phone> searchPhones(String query, {String? brand}) {
    final tokens = _tokens(query);
    final out = phones.where((p) {
      if (brand != null && p.brand != brand) return false;
      final name = _tokens(p.displayName).join(' ');
      return tokens.every(name.contains);
    }).toList()
      ..sort((a, b) => b.year.compareTo(a.year));
    return out;
  }

  List<Watch> searchWatches(String query, {String? brand}) {
    final tokens = _tokens(query);
    final out = watches.where((w) {
      if (brand != null && w.brand != brand) return false;
      final name = _tokens(w.displayName).join(' ');
      return tokens.every(name.contains);
    }).toList()
      ..sort((a, b) => b.year.compareTo(a.year));
    return out;
  }

  /// Matches an iOS machine id ("iPhone16,1"), an Android model code
  /// ("SM-S928B", "SM-S928B/DS"), or a marketing name ("Galaxy S24 Ultra").
  PhoneMatch? matchPhone(String raw) {
    final code = raw.trim();
    if (code.isEmpty) return null;
    final upper = code.toUpperCase();
    for (final p in phones) {
      for (final id in p.identifiers) {
        final u = id.toUpperCase();
        if (upper == u || upper.startsWith('$u/') || upper.startsWith('$u ')) {
          return PhoneMatch(p, p.socIdFor(code));
        }
      }
    }
    final have = _tokens(code).toSet();
    Phone? best;
    var bestScore = 0;
    for (final p in phones) {
      final need = _tokens(p.model).toSet();
      if (need.isEmpty || !need.every(have.contains)) continue;
      if (_tierWords.any((t) => have.contains(t) && !need.contains(t))) {
        continue;
      }
      if (need.length > bestScore) {
        best = p;
        bestScore = need.length;
      }
    }
    return best == null ? null : PhoneMatch(best, best.socId);
  }

  /// Words that make a different model ("Pro", "Max", "+" ...).
  static const _tierWords = {
    'pro',
    'max',
    'plus',
    'ultra',
    'fe',
    'lite',
    'mini',
    'edge',
    'xl',
    'fold',
    'flip',
    'classic',
  };

  static List<String> _tokens(String s) => PartCatalog.normalize(
        s.replaceAll('+', ' plus '),
      ).split(' ').where((t) => t.isNotEmpty).toList();
}
