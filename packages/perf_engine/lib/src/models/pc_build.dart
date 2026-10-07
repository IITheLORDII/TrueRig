import 'package:perf_engine/src/models/parts.dart';

/// An immutable selection of parts. Any slot may be empty while building.
class PcBuild {
  const PcBuild({
    this.cpu,
    this.gpu,
    this.motherboard,
    this.ram,
    this.psu,
    this.pcCase,
    this.cooler,
  });

  final Cpu? cpu;
  final Gpu? gpu;
  final Motherboard? motherboard;
  final Ram? ram;
  final Psu? psu;
  final PcCase? pcCase;
  final Cooler? cooler;

  /// Returns a new build with [part] placed in its matching slot.
  PcBuild withPart(Part part) => switch (part) {
        Cpu p => _copy(cpu: p),
        Gpu p => _copy(gpu: p),
        Motherboard p => _copy(motherboard: p),
        Ram p => _copy(ram: p),
        Psu p => _copy(psu: p),
        PcCase p => _copy(pcCase: p),
        Cooler p => _copy(cooler: p),
        _ => throw ArgumentError('Unknown part type: ${part.runtimeType}'),
      };

  /// Returns a new build with the slot for [category] cleared.
  PcBuild without(PartCategory category) => PcBuild(
        cpu: category == PartCategory.cpu ? null : cpu,
        gpu: category == PartCategory.gpu ? null : gpu,
        motherboard: category == PartCategory.motherboard ? null : motherboard,
        ram: category == PartCategory.ram ? null : ram,
        psu: category == PartCategory.psu ? null : psu,
        pcCase: category == PartCategory.pcCase ? null : pcCase,
        cooler: category == PartCategory.cooler ? null : cooler,
      );

  Part? partFor(PartCategory category) => switch (category) {
        PartCategory.cpu => cpu,
        PartCategory.gpu => gpu,
        PartCategory.motherboard => motherboard,
        PartCategory.ram => ram,
        PartCategory.psu => psu,
        PartCategory.pcCase => pcCase,
        PartCategory.cooler => cooler,
      };

  List<Part> get parts => [
        for (final c in PartCategory.values)
          if (partFor(c) != null) partFor(c)!,
      ];

  PcBuild _copy({
    Cpu? cpu,
    Gpu? gpu,
    Motherboard? motherboard,
    Ram? ram,
    Psu? psu,
    PcCase? pcCase,
    Cooler? cooler,
  }) =>
      PcBuild(
        cpu: cpu ?? this.cpu,
        gpu: gpu ?? this.gpu,
        motherboard: motherboard ?? this.motherboard,
        ram: ram ?? this.ram,
        psu: psu ?? this.psu,
        pcCase: pcCase ?? this.pcCase,
        cooler: cooler ?? this.cooler,
      );
}
