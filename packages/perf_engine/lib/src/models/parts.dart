/// Immutable hardware part models.
///
/// Performance scores are relative indices (higher is better):
/// - [Cpu.stScore]: single-thread, best desktop CPU ~= 100
/// - [Cpu.mtScore]: multi-thread, Ryzen 9 9950X = 100
/// - [Cpu.gamingScore]: gaming index, Ryzen 7 7800X3D = 100
/// - [Gpu.rasterScore]: rasterization, RTX 4090 = 100
library;

enum PartCategory { cpu, gpu, motherboard, ram, psu, pcCase, cooler }

enum MemoryType { ddr3, ddr4, ddr5 }

/// Physical memory module: desktop DIMM, laptop SO-DIMM, or soldered to the
/// board (LPDDR, not upgradable). Different sizes: they never fit each other.
enum RamFormFactor { dimm, sodimm, soldered }

enum FormFactor { miniItx, microAtx, atx, eAtx }

/// Common identity and lookup data shared by every part.
abstract class Part {
  const Part({
    required this.id,
    required this.brand,
    required this.model,
    this.mpn,
    this.eans = const [],
    this.refPriceUsd,
  });

  final String id;
  final String brand;
  final String model;

  /// Manufacturer part number, used for serial/model number price search.
  final String? mpn;
  final List<String> eans;

  /// Approximate launch/street price, only for relative value ranking.
  final double? refPriceUsd;

  PartCategory get category;

  String get displayName => '$brand $model';
}

class Cpu extends Part {
  const Cpu({
    required super.id,
    required super.brand,
    required super.model,
    super.mpn,
    super.eans,
    super.refPriceUsd,
    required this.socket,
    required this.cores,
    required this.threads,
    required this.boostGhz,
    required this.tdpW,
    required this.maxPowerW,
    required this.stScore,
    required this.mtScore,
    required this.gamingScore,
    required this.memoryTypes,
    required this.pcieGen,
    required this.hasIgpu,
    this.memChannels = 2,
  });

  final String socket;
  final int cores;
  final int threads;
  final double boostGhz;
  final int tdpW;
  final int maxPowerW;
  final double stScore;
  final double mtScore;
  final double gamingScore;
  final List<MemoryType> memoryTypes;
  final int pcieGen;
  final bool hasIgpu;
  final int memChannels;

  @override
  PartCategory get category => PartCategory.cpu;
}

class Gpu extends Part {
  const Gpu({
    required super.id,
    required super.brand,
    required super.model,
    super.mpn,
    super.eans,
    super.refPriceUsd,
    required this.vramGb,
    required this.memBandwidthGbs,
    required this.rasterScore,
    required this.rtScore,
    required this.tdpW,
    required this.lengthMm,
    required this.pcieGen,
    this.needs12vhpwr = false,
  });

  final int vramGb;
  final double memBandwidthGbs;
  final double rasterScore;
  final double rtScore;
  final int tdpW;
  final int lengthMm;
  final int pcieGen;
  final bool needs12vhpwr;

  @override
  PartCategory get category => PartCategory.gpu;
}

class Motherboard extends Part {
  const Motherboard({
    required super.id,
    required super.brand,
    required super.model,
    super.mpn,
    super.eans,
    super.refPriceUsd,
    required this.socket,
    required this.chipset,
    required this.formFactor,
    required this.memoryType,
    required this.memSlots,
    required this.maxMemSpeed,
    required this.m2Slots,
    required this.pcieGen,
    this.biosUpdateRequiredFor = const [],
  });

  final String socket;
  final String chipset;
  final FormFactor formFactor;
  final MemoryType memoryType;
  final int memSlots;
  final int maxMemSpeed;
  final int m2Slots;
  final int pcieGen;

  /// CPU ids that only boot after a BIOS update on early board revisions.
  final List<String> biosUpdateRequiredFor;

  @override
  PartCategory get category => PartCategory.motherboard;
}

class Ram extends Part {
  const Ram({
    required super.id,
    required super.brand,
    required super.model,
    super.mpn,
    super.eans,
    super.refPriceUsd,
    required this.type,
    required this.speedMts,
    required this.moduleCount,
    required this.moduleSizeGb,
    required this.casLatency,
    this.formFactor = RamFormFactor.dimm,
  });

  final MemoryType type;
  final RamFormFactor formFactor;
  final int speedMts;
  final int moduleCount;
  final int moduleSizeGb;
  final int casLatency;

  int get totalGb => moduleCount * moduleSizeGb;

  @override
  PartCategory get category => PartCategory.ram;
}

class Psu extends Part {
  const Psu({
    required super.id,
    required super.brand,
    required super.model,
    super.mpn,
    super.eans,
    super.refPriceUsd,
    required this.watts,
    required this.rating,
    this.has12vhpwr = false,
  });

  final int watts;
  final String rating;
  final bool has12vhpwr;

  @override
  PartCategory get category => PartCategory.psu;
}

class PcCase extends Part {
  const PcCase({
    required super.id,
    required super.brand,
    required super.model,
    super.mpn,
    super.eans,
    super.refPriceUsd,
    required this.supportedFormFactors,
    required this.maxGpuLengthMm,
    required this.maxCoolerHeightMm,
  });

  final List<FormFactor> supportedFormFactors;
  final int maxGpuLengthMm;
  final int maxCoolerHeightMm;

  @override
  PartCategory get category => PartCategory.pcCase;
}

class Cooler extends Part {
  const Cooler({
    required super.id,
    required super.brand,
    required super.model,
    super.mpn,
    super.eans,
    super.refPriceUsd,
    required this.sockets,
    required this.heightMm,
    required this.tdpRatingW,
    this.isLiquid = false,
  });

  final List<String> sockets;

  /// Air cooler height. Liquid coolers report 0 (radiator fit not modelled).
  final int heightMm;
  final int tdpRatingW;
  final bool isLiquid;

  @override
  PartCategory get category => PartCategory.cooler;
}

/// Laptop / BGA CPUs (Intel BGA*, AMD FP*/FL*) cannot be swapped.
bool isSolderedCpu(Cpu c) =>
    c.socket.startsWith('BGA') ||
    c.socket.startsWith('FP') ||
    c.socket.startsWith('FL');

/// Laptop GPUs are modelled with length 0 (built into the chassis).
/// Integrated graphics ('-igpu') are not: desktop APUs have them too.
bool isLaptopGpu(Gpu g) => g.lengthMm == 0 && !isIntegratedGpu(g);

/// Graphics built into the processor (no graphics card).
bool isIntegratedGpu(Gpu g) => g.id.endsWith('-igpu');

/// A laptop build: soldered processor or built-in laptop graphics.
bool isLaptopBuild(Cpu? cpu, Gpu? gpu) =>
    (cpu != null && isSolderedCpu(cpu)) || (gpu != null && isLaptopGpu(gpu));
