/// One factory configuration of a ready-made system (e.g. "i7-12700H /
/// RTX 4060 / 16 GB"). Ids point into the part catalog.
class PrebuiltVariant {
  const PrebuiltVariant({
    required this.cpuId,
    required this.gpuId,
    required this.ramId,
    this.code,
  });

  final String cpuId;
  final String gpuId;
  final String ramId;

  /// Manufacturer SKU fragment when known (e.g. "G770.1245").
  final String? code;
}

/// A ready-made laptop / desktop line (brand + model name).
class PrebuiltSystem {
  const PrebuiltSystem({
    required this.id,
    required this.brand,
    required this.model,
    required this.isLaptop,
    required this.variants,
    this.aliases = const [],
  });

  final String id;
  final String brand;
  final String model;
  final bool isLaptop;
  final List<PrebuiltVariant> variants;

  /// Other names people search for (series codes like "FX507ZU").
  final List<String> aliases;

  String get displayName => '$brand $model';
}
