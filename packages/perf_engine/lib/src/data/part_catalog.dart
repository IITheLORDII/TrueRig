import 'package:perf_engine/src/data/cpu_catalog.dart';
import 'package:perf_engine/src/data/cpu_catalog_more.dart';
import 'package:perf_engine/src/data/gpu_catalog.dart';
import 'package:perf_engine/src/data/gpu_catalog_more.dart';
import 'package:perf_engine/src/data/platform_catalog.dart';
import 'package:perf_engine/src/data/platform_generic.dart';
import 'package:perf_engine/src/models/parts.dart';

/// In-memory, read-only part catalog with model / MPN / EAN search.
class PartCatalog {
  PartCatalog({
    required List<Cpu> cpus,
    required List<Gpu> gpus,
    required List<Motherboard> motherboards,
    required List<Ram> rams,
    required List<Psu> psus,
    required List<PcCase> cases,
    required List<Cooler> coolers,
  })  : cpus = List.unmodifiable(cpus),
        gpus = List.unmodifiable(gpus),
        motherboards = List.unmodifiable(motherboards),
        rams = List.unmodifiable(rams),
        psus = List.unmodifiable(psus),
        cases = List.unmodifiable(cases),
        coolers = List.unmodifiable(coolers);

  /// Named models first (better search ranking), then generic classes.
  factory PartCatalog.seed() => PartCatalog(
        cpus: [...kCpus, ...kMoreCpus],
        gpus: [...kGpus, ...kMoreGpus],
        motherboards: [...kMotherboards, ...kGenericBoards],
        rams: [...kRams, ...kGenericRams],
        psus: [...kPsus, ...kGenericPsus],
        cases: [...kCases, ...kGenericCases],
        coolers: [...kCoolers, ...kGenericCoolers],
      );

  final List<Cpu> cpus;
  final List<Gpu> gpus;
  final List<Motherboard> motherboards;
  final List<Ram> rams;
  final List<Psu> psus;
  final List<PcCase> cases;
  final List<Cooler> coolers;

  List<Part> get all => [
        ...cpus,
        ...gpus,
        ...motherboards,
        ...rams,
        ...psus,
        ...cases,
        ...coolers,
      ];

  List<Part> byCategory(PartCategory c) => switch (c) {
        PartCategory.cpu => cpus,
        PartCategory.gpu => gpus,
        PartCategory.motherboard => motherboards,
        PartCategory.ram => rams,
        PartCategory.psu => psus,
        PartCategory.pcCase => cases,
        PartCategory.cooler => coolers,
      };

  Part? byId(String id) {
    for (final p in all) {
      if (p.id == id) return p;
    }
    return null;
  }

  /// Ranked search over name, MPN and EAN. Exact MPN/EAN hits rank first,
  /// then parts whose name contains every query token.
  List<Part> search(String query, {PartCategory? category, int limit = 20}) {
    final q = normalize(query);
    if (q.isEmpty) return const [];
    final tokens = q.split(' ');
    final pool = category == null ? all : byCategory(category);

    final scored = <(Part, int)>[];
    for (final p in pool) {
      final score = _score(p, q, tokens);
      if (score > 0) scored.add((p, score));
    }
    scored.sort((a, b) => b.$2.compareTo(a.$2));
    return scored.take(limit).map((e) => e.$1).toList(growable: false);
  }

  static int _score(Part p, String q, List<String> tokens) {
    final compactQ = q.replaceAll(' ', '');
    final mpn = p.mpn == null ? '' : normalize(p.mpn!).replaceAll(' ', '');
    if (mpn.isNotEmpty && mpn == compactQ) return 1000;
    if (p.eans.contains(compactQ)) return 1000;

    final name = normalize(p.displayName);
    final compactName = name.replaceAll(' ', '');
    if (!tokens.every((t) => name.contains(t) || compactName.contains(t))) {
      return mpn.isNotEmpty && mpn.contains(compactQ) ? 300 : 0;
    }
    // Prefer shorter names (closer match) and prefix hits.
    var score = 500 - name.length;
    if (name.startsWith(q) || normalize(p.model).startsWith(q)) score += 100;
    return score;
  }

  /// Lowercases, folds Turkish characters and collapses punctuation.
  static String normalize(String s) {
    // Fold before lowercasing: 'İ'.toLowerCase() yields 'i' + combining dot.
    const fold = {
      'ı': 'i', 'İ': 'i', 'ş': 's', 'Ş': 's', 'ğ': 'g', 'Ğ': 'g', //
      'ü': 'u', 'Ü': 'u', 'ö': 'o', 'Ö': 'o', 'ç': 'c', 'Ç': 'c',
    };
    final lower = s.split('').map((c) => fold[c] ?? c).join().toLowerCase();
    return lower
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ');
  }
}
