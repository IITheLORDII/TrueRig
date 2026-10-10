import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:perf_engine/perf_engine.dart';

/// The reference case: Corsair 4000D Airflow, a common mid tower
/// (width, height, depth in mm). Every case and part is drawn with the
/// same millimetre scale, so cases keep their real size relative to it.
const (int, int, int) kReferenceCaseMm = (230, 466, 453);

/// Millimetres in one drawing unit: the reference case is 1.1 units deep.
const double kMmPerUnit = 453 / 1.1;

/// All cases are drawn this much wider than real (the same for every
/// case, so their proportions to each other stay true) to show the inside.
const double kWidthBoost = 1.25;

/// Case size in drawing units from its outside size in mm.
(double, double, double) caseUnits(int widthMm, int heightMm, int depthMm) => (
  widthMm / kMmPerUnit * kWidthBoost,
  heightMm / kMmPerUnit,
  depthMm / kMmPerUnit,
);

/// Typical size by board when a case has no measurements.
(int, int, int) _typicalMm(FormFactor? board) => switch (board) {
  FormFactor.miniItx => (185, 290, 370),
  FormFactor.microAtx => (210, 420, 400),
  FormFactor.eAtx => (285, 500, 500),
  _ => kReferenceCaseMm,
};

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
    required this.mounts,
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
    final (wm, hm, dm) = c == null
        ? kReferenceCaseMm
        : c.widthMm > 0 && c.heightMm > 0 && c.depthMm > 0
        ? (c.widthMm, c.heightMm, c.depthMm)
        : _typicalMm(c.largestBoard);
    final (w, h, d) = caseUnits(wm, hm, dm);
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
      mounts: c?.mounts ?? const CaseFans(),
      rgbFans: c?.rgbFans ?? false,
      caseChosen: c != null,
      liquid: cooler?.isLiquid ?? false,
      radiatorFans: cooler != null && cooler.isLiquid
          ? (cooler.radiatorMm ~/ 120).clamp(1, 3)
          : 0,
      // Coolers stick out across the width, so they get the same boost.
      coolerReach: (coolerMm == 0 ? 155 : coolerMm) / kMmPerUnit * kWidthBoost,
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

  /// Fan places the case offers (empty ones are drawn as outlines).
  final CaseFans mounts;
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
      other.mounts.total == mounts.total &&
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
    mounts.total,
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

/// One fan place: where it is, its centre (drawing units), its radius and
/// whether a fan comes in it.
@immutable
class FanSlot {
  const FanSlot(this.place, this.x, this.y, this.z, this.r, this.filled);

  final FanPlace place;
  final double x;
  final double y;
  final double z;
  final double r;
  final bool filled;
}

/// Largest fan radius (a 120 mm fan, slightly enlarged like the case).
const double kFanRadius = 0.14;

extension BuildShapeLayout on BuildShape {
  /// Front edge of the power supply (it sits at the bottom back).
  double get psuFrontZ => d - 0.03 - (style == CaseStyle.compact ? 0.32 : 0.42);

  /// Every fan place the case offers (front, bottom, top, rear), evenly
  /// spread; the first ones of each place hold the fans that come in the
  /// box. Never drops one: when space is short the fans get smaller. Side
  /// brackets are left to the text (they would cover the glass).
  List<FanSlot> get fanSlots {
    List<double> spread(int n, double a, double b) => [
      for (var i = 0; i < n; i++) a + (b - a) * (i + 0.5) / n,
    ];
    double radius(int n, double a, double b) =>
        math.min(math.min(kFanRadius, (b - a) / (2 * n) - 0.01), w / 2 - 0.03);
    final out = <FanSlot>[];
    void place(
      int filled,
      int mounts,
      double a,
      double b,
      FanSlot Function(double at, double r, bool filled) at,
    ) {
      // Mounts from the spec sheet; never fewer places than fans.
      final n = math.max(filled, mounts);
      if (n <= 0) return;
      final r = radius(n, a, b);
      final spots = spread(n, a, b);
      for (var i = 0; i < n; i++) {
        out.add(at(spots[i], r, i < filled));
      }
    }

    // Front fans fill from the top down.
    place(
      fans.front,
      mounts.front,
      0.08,
      h - 0.06,
      (y, r, f) => FanSlot(FanPlace.front, w / 2, h - y + 0.02, 0.03, r, f),
    );
    place(
      fans.bottom,
      mounts.bottom,
      0.06,
      psuFrontZ - 0.02,
      (z, r, f) => FanSlot(FanPlace.bottom, w / 2, 0.012, z, r, f),
    );
    place(
      fans.top,
      mounts.top,
      0.06,
      d - 0.06,
      (z, r, f) => FanSlot(FanPlace.top, w * 0.42, h - 0.015, z, r, f),
    );
    place(
      fans.rear,
      mounts.rear,
      h * 0.45,
      h - 0.06,
      (y, r, f) => FanSlot(FanPlace.rear, w * 0.42, y, d - 0.012, r, f),
    );
    return out;
  }
}

/// "230 × 466 × 453 mm (en × yükseklik × derinlik)", or null if unknown.
String? caseSizeText(PcCase c) {
  if (c.widthMm == 0 || c.heightMm == 0 || c.depthMm == 0) return null;
  return '${c.widthMm} × ${c.heightMm} × ${c.depthMm} mm '
      '(en × yükseklik × derinlik)';
}

String _places(CaseFans f) => [
  if (f.front > 0) '${f.front} ön',
  if (f.top > 0) '${f.top} üst',
  if (f.bottom > 0) '${f.bottom} alt',
  if (f.side > 0) '${f.side} yan',
  if (f.rear > 0) '${f.rear} arka',
].join(', ');

/// "4000D Airflow 2 fanla geliyor (1 ön, 1 arka). 6 fan takılabilir:
/// 3 ön, 2 üst, 1 arka."
String caseFansText(PcCase c) {
  final f = c.fans;
  final m = c.mounts;
  final inBox = f.total == 0
      ? '${c.model} fansız geliyor; fan alman gerekir'
      : '${c.model} ${f.total}${c.rgbFans ? ' ışıklı' : ''} fanla geliyor '
            '(${_places(f)})';
  if (m.total == 0) return '$inBox.';
  return '$inBox. ${m.total} fan takılabilir: ${_places(m)}.';
}
