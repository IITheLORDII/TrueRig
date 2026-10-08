import 'dart:convert';

import 'package:perf_engine/src/detect/hardware_matcher.dart';
import 'package:perf_engine/src/models/parts.dart';
import 'package:perf_engine/src/models/pc_build.dart';

/// One installed memory module as reported by the OS.
class RamModule {
  const RamModule({required this.sizeGb, required this.speedMts, this.type});

  final int sizeGb;
  final int speedMts;
  final MemoryType? type;
}

/// Hardware facts from the Windows helper script or the browser probe.
/// Every field is optional: the browser only knows the GPU and thread count.
class HardwareReport {
  const HardwareReport({
    this.cpuName,
    this.cores,
    this.threads,
    this.gpuNames = const [],
    this.ramModules = const [],
    this.boardName,
    this.screenWidth,
    this.screenHeight,
    this.source = 'unknown',
  });

  final String? cpuName;
  final int? cores;
  final int? threads;
  final List<String> gpuNames;
  final List<RamModule> ramModules;
  final String? boardName;
  final int? screenWidth;
  final int? screenHeight;

  /// 'browser' or 'windows-helper'.
  final String source;

  /// Max accepted size of the encoded helper payload.
  static const int maxEncodedLength = 4096;

  /// Decodes the base64url JSON payload produced by detect-windows.ps1.
  /// Returns null for anything malformed; never throws on user input.
  static HardwareReport? decode(String encoded) {
    if (encoded.isEmpty || encoded.length > maxEncodedLength) return null;
    try {
      final normalized = base64Url.normalize(encoded.trim());
      final json = jsonDecode(utf8.decode(base64Url.decode(normalized)));
      if (json is! Map<String, dynamic> || json['v'] != 1) return null;
      return HardwareReport(
        cpuName: _str(json['cpu']),
        cores: _int(json['cores']),
        threads: _int(json['threads']),
        gpuNames: [
          for (final g in (json['gpus'] as List?) ?? const [])
            if (_str(g) != null) _str(g)!,
        ],
        ramModules: [
          for (final m in (json['ram'] as List?) ?? const [])
            if (m is Map<String, dynamic> && _int(m['gb']) != null)
              RamModule(
                sizeGb: _int(m['gb'])!,
                speedMts: _int(m['mts']) ?? 0,
                type: _smbiosMemoryType(_int(m['type'])),
              ),
        ],
        boardName: _str(json['board']),
        source: 'windows-helper',
      );
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }

  int get totalRamGb => ramModules.fold(0, (a, m) => a + m.sizeGb);

  static String? _str(Object? v) {
    if (v is! String) return null;
    final s = v.trim();
    return s.isEmpty || s.length > 200 ? null : s;
  }

  static int? _int(Object? v) =>
      v is int && v >= 0 && v < 1 << 20 ? v : (v is double ? v.round() : null);

  /// SMBIOS type 17 memory type codes.
  static MemoryType? _smbiosMemoryType(int? code) => switch (code) {
        24 => MemoryType.ddr3,
        26 => MemoryType.ddr4,
        34 => MemoryType.ddr5,
        _ => null,
      };
}

/// What could be resolved against the catalog.
class DetectionResult {
  const DetectionResult({
    required this.report,
    required this.build,
    required this.cpuCandidates,
    required this.unmatched,
  });

  final HardwareReport report;

  /// Parts that were identified; may be partial.
  final PcBuild build;

  /// When the CPU model is unknown (browser), plausible CPUs by thread count.
  final List<Cpu> cpuCandidates;

  /// Raw names that were detected but are not in the catalog yet.
  final List<String> unmatched;
}

class HardwareDetector {
  const HardwareDetector(this.matcher);

  final HardwareMatcher matcher;

  DetectionResult resolve(HardwareReport r) {
    var build = const PcBuild();
    final unmatched = <String>[];

    final cpuName = r.cpuName;
    final cpu = cpuName == null ? null : matcher.matchCpu(cpuName);
    if (cpu != null) {
      build = build.withPart(cpu);
    } else if (cpuName != null) {
      unmatched.add(cpuName);
    }

    // Prefer a discrete GPU when the system also reports an iGPU.
    for (final name in r.gpuNames) {
      final gpu = matcher.matchGpu(name);
      if (gpu != null) {
        build = build.withPart(gpu);
        break;
      }
    }
    if (build.gpu == null) unmatched.addAll(r.gpuNames);

    final boardName = r.boardName;
    final board =
        boardName == null ? null : matcher.matchMotherboard(boardName);
    if (board != null) build = build.withPart(board);

    final ram = _ramFrom(r, cpu);
    if (ram != null) build = build.withPart(ram);

    return DetectionResult(
      report: r,
      build: build,
      cpuCandidates: cpu == null && r.threads != null
          ? matcher.cpuCandidatesForThreads(r.threads!)
          : const [],
      unmatched: List.unmodifiable(unmatched),
    );
  }

  /// Builds a synthetic RAM part describing the installed modules.
  static Ram? _ramFrom(HardwareReport r, Cpu? cpu) {
    final mods = r.ramModules.where((m) => m.sizeGb > 0).toList();
    if (mods.isEmpty) return null;
    final type = mods.first.type ??
        (cpu != null && cpu.memoryTypes.length == 1
            ? cpu.memoryTypes.first
            : MemoryType.ddr5);
    final speed = mods.map((m) => m.speedMts).reduce((a, b) => a < b ? a : b);
    final size = mods.first.sizeGb;
    final label = '${r.totalRamGb}GB (${mods.length}x$size) '
        '${type.name.toUpperCase()}${speed > 0 ? '-$speed' : ''}';
    return Ram(
      id: 'detected-ram',
      brand: 'Algılanan',
      model: label,
      type: type,
      speedMts: speed > 0
          ? speed
          : switch (type) {
              MemoryType.ddr5 => 4800,
              MemoryType.ddr4 => 2666,
              MemoryType.ddr3 => 1600,
            },
      moduleCount: mods.length,
      moduleSizeGb: size,
      casLatency: 0,
      // A soldered (laptop) processor means laptop memory.
      formFactor: cpu != null && isSolderedCpu(cpu)
          ? RamFormFactor.sodimm
          : RamFormFactor.dimm,
    );
  }
}
