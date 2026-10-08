import 'package:perf_engine/src/models/parts.dart';
import 'package:perf_engine/src/models/pc_build.dart';

enum IssueSeverity { error, warning, info }

/// One finding from the compatibility check.
class CompatibilityIssue {
  const CompatibilityIssue({
    required this.code,
    required this.severity,
    required this.message,
    required this.involved,
  });

  /// Stable machine code, e.g. `socket_mismatch`, for localisation/analytics.
  final String code;
  final IssueSeverity severity;

  /// Turkish user-facing explanation.
  final String message;
  final List<PartCategory> involved;
}

class CompatibilityReport {
  const CompatibilityReport(this.issues, this.recommendedPsuW);

  final List<CompatibilityIssue> issues;

  /// Recommended PSU wattage, or null when CPU/GPU are not both known.
  final int? recommendedPsuW;

  bool get isCompatible =>
      !issues.any((i) => i.severity == IssueSeverity.error);

  List<CompatibilityIssue> bySeverity(IssueSeverity s) =>
      issues.where((i) => i.severity == s).toList(growable: false);
}

/// Baseline draw for board, RAM, drives and fans.
const int kPlatformOverheadW = 75;

/// Headroom multiplier applied on top of estimated peak load.
const double kPsuHeadroom = 1.3;

/// Rounds the recommendation up to typical PSU sizes.
const int kPsuStepW = 50;

class CompatibilityChecker {
  const CompatibilityChecker();

  CompatibilityReport check(PcBuild build) {
    final issues = <CompatibilityIssue>[
      ..._cpuBoard(build),
      ..._memory(build),
      ..._caseFit(build),
      ..._cooler(build),
      ..._power(build),
      ..._graphics(build),
    ];
    return CompatibilityReport(
      List.unmodifiable(issues),
      recommendedPsuWatts(build),
    );
  }

  /// Estimated peak system draw in watts, or null if CPU is unknown.
  static int? estimatedLoadW(PcBuild build) {
    final cpu = build.cpu;
    if (cpu == null) return null;
    return cpu.maxPowerW + (build.gpu?.tdpW ?? 0) + kPlatformOverheadW;
  }

  static int? recommendedPsuWatts(PcBuild build) {
    final load = estimatedLoadW(build);
    if (load == null) return null;
    final raw = load * kPsuHeadroom;
    return (raw / kPsuStepW).ceil() * kPsuStepW;
  }

  Iterable<CompatibilityIssue> _cpuBoard(PcBuild b) sync* {
    final cpu = b.cpu;
    final mb = b.motherboard;
    if (cpu == null || mb == null) return;
    if (cpu.socket != mb.socket) {
      yield CompatibilityIssue(
        code: 'socket_mismatch',
        severity: IssueSeverity.error,
        message: '${cpu.model} ${cpu.socket} soketli, ${mb.model} ise '
            '${mb.socket}. Bu işlemci bu anakarta takılamaz.',
        involved: const [PartCategory.cpu, PartCategory.motherboard],
      );
      return;
    }
    if (mb.biosUpdateRequiredFor.contains(cpu.id)) {
      yield CompatibilityIssue(
        code: 'bios_update',
        severity: IssueSeverity.warning,
        message: '${mb.model} eski BIOS ile gelirse ${cpu.model} için BIOS '
            'güncellemesi gerekebilir (BIOS Flashback destekliyse sorun yok).',
        involved: const [PartCategory.cpu, PartCategory.motherboard],
      );
    }
    if (!cpu.memoryTypes.contains(mb.memoryType)) {
      yield CompatibilityIssue(
        code: 'cpu_board_memory',
        severity: IssueSeverity.error,
        message: '${cpu.model} ${mb.memoryType.name.toUpperCase()} '
            'desteklemiyor.',
        involved: const [PartCategory.cpu, PartCategory.motherboard],
      );
    }
    if (cpu.pcieGen > mb.pcieGen) {
      yield CompatibilityIssue(
        code: 'pcie_downgrade',
        severity: IssueSeverity.info,
        message: 'Anakart PCIe ${mb.pcieGen}.0 ile sınırlı; işlemcinin '
            'PCIe ${cpu.pcieGen}.0 hattı tam kullanılamaz.',
        involved: const [PartCategory.cpu, PartCategory.motherboard],
      );
    }
  }

  Iterable<CompatibilityIssue> _memory(PcBuild b) sync* {
    final ram = b.ram;
    if (ram == null) return;
    yield* _memoryFit(b, ram);
    final mb = b.motherboard;
    if (mb == null) return;
    if (ram.type != mb.memoryType) {
      yield CompatibilityIssue(
        code: 'ram_type_mismatch',
        severity: IssueSeverity.error,
        message: 'Anakart ${mb.memoryType.name.toUpperCase()} istiyor, seçilen '
            'bellek ${ram.type.name.toUpperCase()}. Fiziksel olarak takılmaz.',
        involved: const [PartCategory.ram, PartCategory.motherboard],
      );
      return;
    }
    if (ram.moduleCount > mb.memSlots) {
      yield CompatibilityIssue(
        code: 'ram_slots',
        severity: IssueSeverity.error,
        message: '${ram.moduleCount} modül var ama anakartta '
            '${mb.memSlots} slot bulunuyor.',
        involved: const [PartCategory.ram, PartCategory.motherboard],
      );
    }
    if (ram.speedMts > mb.maxMemSpeed) {
      yield CompatibilityIssue(
        code: 'ram_speed_capped',
        severity: IssueSeverity.info,
        message: 'Bellek ${ram.speedMts} MT/s, anakart en fazla '
            '${mb.maxMemSpeed} MT/s destekliyor; düşük hızda çalışır.',
        involved: const [PartCategory.ram, PartCategory.motherboard],
      );
    }
    if (ram.moduleCount == 1) {
      yield const CompatibilityIssue(
        code: 'ram_single_channel',
        severity: IssueSeverity.warning,
        message: 'Tek modül tek kanal çalışır; oyunlarda %10-20 FPS kaybı '
            'olabilir. 2 modüllü kit önerilir.',
        involved: [PartCategory.ram],
      );
    }
  }

  /// Rules that need no motherboard: memory type vs processor and module
  /// size (laptop SO-DIMM vs desktop DIMM).
  Iterable<CompatibilityIssue> _memoryFit(PcBuild b, Ram ram) sync* {
    final cpu = b.cpu;
    final type = ram.type.name.toUpperCase();
    // With a board, ram_type_mismatch / cpu_board_memory already cover it.
    if (cpu != null &&
        b.motherboard == null &&
        !cpu.memoryTypes.contains(ram.type)) {
      final supported =
          cpu.memoryTypes.map((t) => t.name.toUpperCase()).join(' ve ');
      yield CompatibilityIssue(
        code: 'ram_cpu_type',
        severity: IssueSeverity.error,
        message: '${cpu.model} yalnızca $supported destekler; seçilen bellek '
            '$type. Bu ikisi birlikte çalışmaz.',
        involved: const [PartCategory.ram, PartCategory.cpu],
      );
    }
    final laptop = isLaptopBuild(cpu, b.gpu);
    final desktop = b.motherboard != null ||
        (cpu != null && !isSolderedCpu(cpu)) ||
        (b.gpu != null && !isLaptopGpu(b.gpu!));
    if (laptop && ram.formFactor == RamFormFactor.dimm) {
      yield const CompatibilityIssue(
        code: 'ram_form_laptop',
        severity: IssueSeverity.error,
        message: 'Dizüstü bilgisayarlar küçük SO-DIMM bellek kullanır; '
            'masaüstü (DIMM) modül takılmaz.',
        involved: [PartCategory.ram],
      );
    } else if (!laptop && desktop && ram.formFactor != RamFormFactor.dimm) {
      yield const CompatibilityIssue(
        code: 'ram_form_desktop',
        severity: IssueSeverity.error,
        message: 'Masaüstü anakartlar DIMM bellek kullanır; dizüstü '
            '(SO-DIMM / lehimli) bellek takılmaz.',
        involved: [PartCategory.ram],
      );
    }
    if (ram.formFactor == RamFormFactor.soldered) {
      yield const CompatibilityIssue(
        code: 'ram_soldered',
        severity: IssueSeverity.info,
        message: 'Bu bellek anakarta lehimli; sonradan yükseltilemez.',
        involved: [PartCategory.ram],
      );
    }
  }

  Iterable<CompatibilityIssue> _caseFit(PcBuild b) sync* {
    final pcCase = b.pcCase;
    if (pcCase == null) return;
    final mb = b.motherboard;
    if (mb != null && !pcCase.supportedFormFactors.contains(mb.formFactor)) {
      yield CompatibilityIssue(
        code: 'case_form_factor',
        severity: IssueSeverity.error,
        message: '${pcCase.model} ${_ff(mb.formFactor)} anakart almıyor.',
        involved: const [PartCategory.pcCase, PartCategory.motherboard],
      );
    }
    final gpu = b.gpu;
    if (gpu != null && gpu.lengthMm > pcCase.maxGpuLengthMm) {
      yield CompatibilityIssue(
        code: 'gpu_too_long',
        severity: IssueSeverity.error,
        message: '${gpu.model} ${gpu.lengthMm} mm, kasa en fazla '
            '${pcCase.maxGpuLengthMm} mm ekran kartı alıyor.',
        involved: const [PartCategory.gpu, PartCategory.pcCase],
      );
    }
  }

  Iterable<CompatibilityIssue> _cooler(PcBuild b) sync* {
    final cooler = b.cooler;
    if (cooler == null) return;
    final cpu = b.cpu;
    if (cpu != null && !cooler.sockets.contains(cpu.socket)) {
      yield CompatibilityIssue(
        code: 'cooler_socket',
        severity: IssueSeverity.error,
        message: '${cooler.model} ${cpu.socket} soketini desteklemiyor.',
        involved: const [PartCategory.cooler, PartCategory.cpu],
      );
    }
    if (cpu != null && cooler.tdpRatingW < cpu.maxPowerW * 0.8) {
      yield CompatibilityIssue(
        code: 'cooler_weak',
        severity: IssueSeverity.warning,
        message: '${cooler.model} (${cooler.tdpRatingW} W) ${cpu.model} için '
            'zayıf kalabilir; ısınma ve frekans düşüşü olur.',
        involved: const [PartCategory.cooler, PartCategory.cpu],
      );
    }
    final pcCase = b.pcCase;
    if (pcCase != null &&
        !cooler.isLiquid &&
        cooler.heightMm > pcCase.maxCoolerHeightMm) {
      yield CompatibilityIssue(
        code: 'cooler_too_tall',
        severity: IssueSeverity.error,
        message: '${cooler.model} ${cooler.heightMm} mm, kasa en fazla '
            '${pcCase.maxCoolerHeightMm} mm soğutucu alıyor.',
        involved: const [PartCategory.cooler, PartCategory.pcCase],
      );
    }
  }

  Iterable<CompatibilityIssue> _power(PcBuild b) sync* {
    final psu = b.psu;
    final load = estimatedLoadW(b);
    final rec = recommendedPsuWatts(b);
    if (psu == null || load == null || rec == null) return;
    if (psu.watts < load) {
      yield CompatibilityIssue(
        code: 'psu_insufficient',
        severity: IssueSeverity.error,
        message: 'Tahmini tepe tüketim $load W, güç kaynağı ${psu.watts} W. '
            'En az $rec W önerilir.',
        involved: const [PartCategory.psu],
      );
    } else if (psu.watts < rec) {
      yield CompatibilityIssue(
        code: 'psu_low_headroom',
        severity: IssueSeverity.warning,
        message: '${psu.watts} W çalışır ama pay az (tepe ~$load W). '
            '$rec W önerilir.',
        involved: const [PartCategory.psu],
      );
    }
    final gpu = b.gpu;
    if (gpu != null && gpu.needs12vhpwr && !psu.has12vhpwr) {
      yield const CompatibilityIssue(
        code: 'psu_connector',
        severity: IssueSeverity.warning,
        message: 'Ekran kartı 12V-2x6 (12VHPWR) istiyor; güç kaynağında yok, '
            'adaptör kullanılmalı (ATX 3.x PSU önerilir).',
        involved: [PartCategory.psu, PartCategory.gpu],
      );
    }
  }

  Iterable<CompatibilityIssue> _graphics(PcBuild b) sync* {
    final cpu = b.cpu;
    if (cpu != null && b.gpu == null && !cpu.hasIgpu) {
      yield CompatibilityIssue(
        code: 'no_display_output',
        severity: IssueSeverity.error,
        message: '${cpu.model} dahili grafik içermiyor; görüntü için ekran '
            'kartı gerekli.',
        involved: const [PartCategory.cpu, PartCategory.gpu],
      );
    }
  }

  static String _ff(FormFactor f) => switch (f) {
        FormFactor.miniItx => 'Mini-ITX',
        FormFactor.microAtx => 'Micro-ATX',
        FormFactor.atx => 'ATX',
        FormFactor.eAtx => 'E-ATX',
      };
}
