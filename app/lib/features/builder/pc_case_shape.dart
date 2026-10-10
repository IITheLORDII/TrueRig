import 'dart:math' as math;

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
      // A little wider than real cases so the inside reads well.
      FormFactor.miniItx => (0.6, 0.74, 0.92),
      FormFactor.microAtx => (0.66, 0.96, 1.0),
      FormFactor.eAtx => (0.78, 1.1, 1.16),
      _ => (0.7, 1.0, 1.1),
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

/// Where a case fan sits.
enum FanPlace { front, bottom, top, rear }

/// One case fan: mounting place, centre (drawing units) and radius.
@immutable
class FanSlot {
  const FanSlot(this.place, this.x, this.y, this.z, this.r);

  final FanPlace place;
  final double x;
  final double y;
  final double z;
  final double r;
}

/// Largest fan radius (a 120 mm fan, slightly enlarged like the case).
const double kFanRadius = 0.14;

extension BuildShapeLayout on BuildShape {
  /// Front edge of the power supply (it sits at the bottom back).
  double get psuFrontZ => d - 0.03 - (style == CaseStyle.compact ? 0.32 : 0.42);

  /// Every fan the case ships with, evenly spread over its mounting
  /// place. Never drops one: when space is short the fans get smaller.
  List<FanSlot> get fanSlots {
    List<double> spread(int n, double a, double b) => [
      for (var i = 0; i < n; i++) a + (b - a) * (i + 0.5) / n,
    ];
    double radius(int n, double a, double b, double across) => math.min(
      math.min(kFanRadius, (b - a) / (2 * n) - 0.01),
      across / 2 - 0.03,
    );
    final out = <FanSlot>[];
    void place(
      FanPlace p,
      int n,
      double a,
      double b,
      double across,
      FanSlot Function(double at, double r) at,
    ) {
      if (n <= 0) return;
      final r = radius(n, a, b, across);
      for (final v in spread(n, a, b)) {
        out.add(at(v, r));
      }
    }

    place(
      FanPlace.front,
      fans.front,
      0.08,
      h - 0.06,
      w,
      (y, r) => FanSlot(FanPlace.front, w / 2, y, 0.03, r),
    );
    place(
      FanPlace.bottom,
      fans.bottom,
      0.06,
      psuFrontZ - 0.02,
      w,
      (z, r) => FanSlot(FanPlace.bottom, w / 2, 0.012, z, r),
    );
    place(
      FanPlace.top,
      fans.top,
      0.06,
      d - 0.06,
      w,
      (z, r) => FanSlot(FanPlace.top, w * 0.42, h - 0.015, z, r),
    );
    place(
      FanPlace.rear,
      fans.rear,
      h * 0.45,
      h - 0.06,
      w,
      (y, r) => FanSlot(FanPlace.rear, w * 0.42, y, d - 0.012, r),
    );
    return out;
  }
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
