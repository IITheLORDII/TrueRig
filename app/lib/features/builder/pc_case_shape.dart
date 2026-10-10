import 'package:flutter/foundation.dart';
import 'package:perf_engine/perf_engine.dart';

/// Millimetres in one drawing unit (a mid tower is about 1.1 units deep).
const double kMmPerUnit = 410;

/// Everything the case drawing needs to know about a build: case size and
/// look, its fans, the cooler type and how big the parts are, and whether
/// the graphics card or cooler is too big for the case.
@immutable
class BuildShape {
  const BuildShape({
    required this.style,
    required this.w,
    required this.h,
    required this.d,
    required this.fans,
    required this.rgbFans,
    required this.caseChosen,
    required this.liquid,
    required this.radiatorFans,
    required this.coolerReach,
    required this.gpuLength,
    required this.gpuIntegrated,
    required this.gpuTooLong,
    required this.coolerTooTall,
  });

  factory BuildShape.of(PcBuild b) {
    final c = b.pcCase;
    final (w, h, d) = switch (c?.largestBoard) {
      FormFactor.miniItx => (0.46, 0.72, 0.92),
      FormFactor.microAtx => (0.52, 0.96, 1.0),
      FormFactor.eAtx => (0.62, 1.1, 1.16),
      _ => (0.55, 1.0, 1.1),
    };
    final cooler = b.cooler;
    final gpu = b.gpu;
    final gpuMm = gpu == null || gpu.lengthMm == 0 ? 300 : gpu.lengthMm;
    final coolerMm = cooler == null || cooler.isLiquid ? 0 : cooler.heightMm;
    return BuildShape(
      style: c?.style ?? CaseStyle.aquarium,
      w: w,
      h: h,
      d: d,
      fans: c?.fans ?? const CaseFans(),
      rgbFans: c?.rgbFans ?? false,
      caseChosen: c != null,
      liquid: cooler?.isLiquid ?? false,
      radiatorFans: cooler != null && cooler.isLiquid
          ? (cooler.radiatorMm ~/ 120).clamp(1, 3)
          : 0,
      coolerReach: (coolerMm == 0 ? 155 : coolerMm) / kMmPerUnit,
      gpuLength: gpuMm / kMmPerUnit,
      gpuIntegrated: gpu != null && isIntegratedGpu(gpu),
      gpuTooLong:
          c != null &&
          gpu != null &&
          gpu.lengthMm > 0 &&
          gpu.lengthMm > c.maxGpuLengthMm,
      coolerTooTall: c != null && coolerMm > c.maxCoolerHeightMm,
    );
  }

  final CaseStyle style;

  /// Case width, height and depth in drawing units.
  final double w;
  final double h;
  final double d;
  final CaseFans fans;
  final bool rgbFans;
  final bool caseChosen;

  /// Liquid cooler: pump on the CPU, radiator under the top.
  final bool liquid;
  final int radiatorFans;

  /// How far a tower cooler sticks out from the board (units).
  final double coolerReach;

  /// Graphics card length (units).
  final double gpuLength;

  /// Built-in graphics: no card is drawn or expected.
  final bool gpuIntegrated;
  final bool gpuTooLong;
  final bool coolerTooTall;

  @override
  bool operator ==(Object other) =>
      other is BuildShape &&
      other.style == style &&
      other.w == w &&
      other.h == h &&
      other.d == d &&
      other.fans.front == fans.front &&
      other.fans.rear == fans.rear &&
      other.fans.top == fans.top &&
      other.fans.bottom == fans.bottom &&
      other.rgbFans == rgbFans &&
      other.caseChosen == caseChosen &&
      other.liquid == liquid &&
      other.radiatorFans == radiatorFans &&
      other.coolerReach == coolerReach &&
      other.gpuLength == gpuLength &&
      other.gpuIntegrated == gpuIntegrated &&
      other.gpuTooLong == gpuTooLong &&
      other.coolerTooTall == coolerTooTall;

  @override
  int get hashCode => Object.hash(
    style,
    w,
    h,
    d,
    fans.total,
    rgbFans,
    caseChosen,
    liquid,
    radiatorFans,
    coolerReach,
    gpuLength,
    gpuIntegrated,
    gpuTooLong,
    coolerTooTall,
  );
}

/// "2 fanla geliyor (1 ön, 1 arka)" / "Fansız geliyor; fan alman gerekir".
String caseFansText(PcCase c) {
  final f = c.fans;
  if (f.total == 0) return '${c.model} fansız geliyor; fan alman gerekir';
  final where = [
    if (f.front > 0) '${f.front} ön',
    if (f.top > 0) '${f.top} üst',
    if (f.bottom > 0) '${f.bottom} alt',
    if (f.rear > 0) '${f.rear} arka',
  ].join(', ');
  final rgb = c.rgbFans ? ' ışıklı' : '';
  return '${c.model} ${f.total}$rgb fanla geliyor ($where)';
}
