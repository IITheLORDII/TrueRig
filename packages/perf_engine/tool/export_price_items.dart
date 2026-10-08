// Prints the products the price indexer should look for, as JSON.
// Usage: dart run tool/export_price_items.dart > items.json
import 'dart:convert';

import 'package:perf_engine/perf_engine.dart';

Map<String, Object?> _item(
  String key,
  String kind,
  String brand,
  String model, {
  String? mpn,
  double? refUsd,
  List<String> aliases = const [],
}) =>
    {
      'key': key,
      'kind': kind,
      'brand': brand,
      'model': model,
      'name': '$brand $model',
      if (mpn != null && mpn.trim().isNotEmpty) 'mpn': mpn.trim(),
      if (refUsd != null) 'ref_usd': refUsd,
      if (aliases.isNotEmpty) 'aliases': aliases,
    };

void main() {
  final parts = PartCatalog.seed();
  final mobile = MobileCatalog.seed();
  final items = [
    // Laptop processors are soldered and never sold on their own.
    for (final c in parts.cpus)
      if (!isSolderedCpu(c))
        _item(
          'cpu:${c.id}',
          'cpu',
          c.brand,
          c.model,
          mpn: c.mpn,
          refUsd: c.refPriceUsd,
        ),
    // Laptop and integrated GPUs are not sold on their own.
    for (final g in parts.gpus)
      if (g.lengthMm > 0)
        _item(
          'gpu:${g.id}',
          'gpu',
          g.brand,
          g.model,
          mpn: g.mpn,
          refUsd: g.refPriceUsd,
        ),
    for (final s in kPrebuilts)
      _item(
        'system:${s.id}',
        s.isLaptop ? 'laptop' : 'desktop',
        s.brand,
        s.model,
        aliases: s.aliases,
      ),
    for (final p in mobile.phones)
      _item(
        'phone:${p.id}',
        'phone',
        p.brand,
        p.model,
        refUsd: p.refPriceUsd,
      ),
    for (final w in mobile.watches)
      _item(
        'watch:${w.id}',
        'watch',
        w.brand,
        w.model,
        refUsd: w.refPriceUsd,
      ),
  ];
  print(const JsonEncoder.withIndent(' ').convert(items));
}
