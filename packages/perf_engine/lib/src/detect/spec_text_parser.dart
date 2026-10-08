import 'package:perf_engine/src/data/part_catalog.dart';
import 'package:perf_engine/src/detect/hardware_matcher.dart';
import 'package:perf_engine/src/models/parts.dart';
import 'package:perf_engine/src/models/pc_build.dart';

/// Parts found in a free-text product title.
class ParsedSpec {
  const ParsedSpec({
    required this.cpu,
    required this.gpu,
    required this.ram,
    required this.isLaptop,
  });

  final Cpu? cpu;
  final Gpu? gpu;
  final Ram? ram;
  final bool isLaptop;

  bool get isEmpty => cpu == null && gpu == null && ram == null;

  PcBuild toBuild() {
    var b = const PcBuild();
    for (final p in [cpu, gpu, ram]) {
      if (p != null) b = b.withPart(p);
    }
    return b;
  }
}

/// Extracts CPU / GPU / RAM from store listing titles such as
/// "Zeiron Mirage X15 Intel Core i7-14700KF 32 GB RAM 1 TB SSD RTX 4070 Super"
/// or "Casper Excalibur G770 i5 12450H 16GB RTX3050".
class SpecTextParser {
  const SpecTextParser(this.catalog);

  final PartCatalog catalog;

  static final _laptopWords = RegExp(
    r'laptop|notebook|dizüstü|dizustu|excalibur|tulpar|abra|semruk|tuf|rog|'
    r'legion|loq|katana|cyborg|victus|omen|nitro|predator|helios|alienware|'
    r'zephyrus|strix|thin gf',
    caseSensitive: false,
  );

  static final _ramPattern = RegExp(
    r'(\d{1,3})\s*gb\s*(?:ram|ddr\s*([345])|bellek)',
    caseSensitive: false,
  );
  static final _ddrPattern = RegExp(r'ddr\s*([345])', caseSensitive: false);
  static final _speedPattern = RegExp(
    r'(\d{4})\s*(?:mhz|mt/s)',
    caseSensitive: false,
  );

  ParsedSpec parse(String title) {
    final text = title.trim();
    final matcher = HardwareMatcher(catalog);
    final isLaptop = _laptopWords.hasMatch(text);
    final cpu = matcher.matchCpu(text);
    var gpu = matcher.matchGpu(text);
    if (gpu != null && isLaptop && !gpu.id.endsWith('-laptop')) {
      // Listings say "RTX 4060" for the laptop chip too.
      final laptop = catalog.byId('${gpu.id}-laptop');
      if (laptop is Gpu) gpu = laptop;
    }
    return ParsedSpec(
      cpu: cpu,
      gpu: gpu,
      ram: _ram(text, cpu, isLaptop: isLaptop),
      isLaptop: isLaptop,
    );
  }

  Ram? _ram(String text, Cpu? cpu, {required bool isLaptop}) {
    final m = _ramPattern.firstMatch(text);
    if (m == null) return null;
    final total = int.parse(m.group(1)!);
    if (total < 4 || total > 256) return null;
    final ddr = m.group(2) ?? _ddrPattern.firstMatch(text)?.group(1);
    final type = switch (ddr) {
      '5' => MemoryType.ddr5,
      '4' => MemoryType.ddr4,
      '3' => MemoryType.ddr3,
      _ => cpu != null && !cpu.memoryTypes.contains(MemoryType.ddr4)
          ? MemoryType.ddr5
          : MemoryType.ddr4,
    };
    final speed = int.tryParse(_speedPattern.firstMatch(text)?.group(1) ?? '');
    final laptop = isLaptop || (cpu != null && isSolderedCpu(cpu));
    return nearestGenericRam(
      catalog,
      type,
      total,
      speed,
      formFactor: laptop ? RamFormFactor.sodimm : RamFormFactor.dimm,
    );
  }
}

/// Closest generic RAM kit: same type, module size (laptop SO-DIMM or
/// desktop DIMM) and capacity (prefer dual channel), nearest speed
/// (default: 1600 DDR3 / 3200 DDR4 / 4800 DDR5).
Ram? nearestGenericRam(
  PartCatalog catalog,
  MemoryType type,
  int totalGb,
  int? speed, {
  RamFormFactor formFactor = RamFormFactor.dimm,
}) {
  final target = speed ??
      switch (type) {
        MemoryType.ddr5 => 4800,
        MemoryType.ddr4 => 3200,
        MemoryType.ddr3 => 1600,
      };
  final kits = catalog.rams
      .where((r) => r.id.startsWith('ram-') && r.type == type)
      .where((r) => r.formFactor == formFactor)
      .where((r) => r.totalGb == totalGb)
      .toList();
  if (kits.isEmpty) return null;
  kits.sort((a, b) {
    final dual = (b.moduleCount == 2 ? 1 : 0) - (a.moduleCount == 2 ? 1 : 0);
    if (dual != 0) return dual;
    return (a.speedMts - target).abs().compareTo((b.speedMts - target).abs());
  });
  return kits.first;
}

/// Alias used by [HardwareMatcher]: "rtx3050" -> {rtx3050, rtx, 3050} and
/// "14700kf" -> also "14700k" so suffix variants find the base model.
Set<String> expandTokens(Iterable<String> tokens) {
  final out = <String>{};
  for (final t in tokens) {
    out.add(t);
    for (final part in RegExp(r'[a-z]+|\d+').allMatches(t)) {
      out.add(part.group(0)!);
    }
    final suffix = RegExp(r'^(\d{4,5})(kf|ks|f)$').firstMatch(t);
    if (suffix != null) {
      final num = suffix.group(1)!;
      out.add(suffix.group(2) == 'f' ? num : '${num}k');
    }
  }
  return out;
}
