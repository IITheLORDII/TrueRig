import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:perf_engine/perf_engine.dart';

import 'package:darbogaz/core/brand/truerig_logo.dart';
import 'package:darbogaz/core/theme/app_theme.dart';

/// A point in case space: x = across the front (0 = glass side, [w] =
/// motherboard side), y = up, z = depth (0 = front).
typedef V3 = (double, double, double);

/// An "aquarium" case (glass front and side meeting at a pillarless corner,
/// RGB fans at the bottom and back) seen from the front-left, with parts
/// drawn the way they look in real builds: vertical graphics card with
/// three fans, RAM with light bars, tower cooler with fins.
///
/// One long drawing routine on purpose (over the 400-line guide): the parts
/// share the projection state and splitting it would only scatter it.
class PcCasePainter extends CustomPainter {
  PcCasePainter({
    required this.progressOf,
    required this.present,
    required this.colors,
    required this.branded,
    required this.caseGlowOf,
    super.repaint,
  });

  /// 0 = outside the case, 1 = in place (read on every frame).
  final double Function(PartCategory) progressOf;

  /// Parts that are chosen (missing ones get a dashed outline).
  final Set<PartCategory> present;
  final CaseColors colors;

  /// A case is chosen: its fans light up in brand colours.
  final bool branded;

  /// 0..1 pulse when the case is chosen.
  final double Function() caseGlowOf;

  static const double w = 0.55;
  static const double h = 1.0;
  static const double d = 1.1;

  // Projection: the long side is shown wide, the front narrow.
  static const double _cx = 0.42;
  static const double _cz = 0.92;
  static const double _ax = 0.13;
  static const double _az = 0.17;

  static const _black = Color(0xFF1F232C);
  static const _shroud = Color(0xFF262B35);
  static const _alu = Color(0xFFB9C0CC);

  late Offset _origin;
  late double _s;

  Offset get _ux => Offset(_cx, -_ax) * _s;
  Offset get _uy => Offset(0, -1) * _s;
  Offset get _uz => Offset(-_cz, -_az) * _s;

  Offset _p(V3 v) =>
      _origin +
      Offset(
        (v.$1 * _cx - v.$3 * _cz) * _s,
        -(v.$2 + v.$1 * _ax + v.$3 * _az) * _s,
      );

  Path _poly(List<V3> pts) {
    final path = Path();
    for (var i = 0; i < pts.length; i++) {
      final o = _p(pts[i]);
      i == 0 ? path.moveTo(o.dx, o.dy) : path.lineTo(o.dx, o.dy);
    }
    return path..close();
  }

  void _fit(Size size) {
    const left = -d * _cz;
    const right = w * _cx;
    const top = h + w * _ax + d * _az;
    _s = math.min(size.width / (right - left), size.height / top) * 0.96;
    _origin = Offset(
      size.width / 2 - (left + right) / 2 * _s,
      size.height / 2 + top / 2 * _s,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    _fit(size);
    _interior(canvas);
    // Far to near so nearer parts cover farther ones.
    for (final c in const [
      PartCategory.motherboard,
      PartCategory.cpu,
      PartCategory.ram,
      PartCategory.cooler,
      PartCategory.psu,
      PartCategory.gpu,
    ]) {
      final t = progressOf(c);
      if (t > 0) {
        _part(canvas, c, t);
      } else if (!present.contains(c) && c != PartCategory.cooler) {
        _ghost(canvas, c);
      }
    }
    _shell(canvas, caseGlowOf());
  }

  // ------------------------------------------------------------- case --

  void _interior(Canvas canvas) {
    final base = colors.interior;
    canvas.drawPath(
      _poly([(w, 0, 0), (w, 0, d), (w, h, d), (w, h, 0)]),
      Paint()..color = base,
    );
    canvas.drawPath(
      _poly([(0, 0, d), (w, 0, d), (w, h, d), (0, h, d)]),
      Paint()..color = Color.lerp(base, Colors.black, 0.12)!,
    );
    canvas.drawPath(
      _poly([(0, 0, 0), (w, 0, 0), (w, 0, d), (0, 0, d)]),
      Paint()..color = Color.lerp(base, Colors.black, 0.22)!,
    );
    // Case fans: two in the floor, one at the back.
    for (final z in const [0.2, 0.46]) {
      _fan(canvas, (w / 2, 0.005, z), _ux, _uz, 0.11, rgb: branded);
    }
    _fan(canvas, (w * 0.45, 0.78, d - 0.005), _ux, _uy, 0.12, rgb: branded);
  }

  void _shell(Canvas canvas, double glow) {
    final side = _poly([(0, 0, 0), (0, 0, d), (0, h, d), (0, h, 0)]);
    final front = _poly([(0, 0, 0), (w, 0, 0), (w, h, 0), (0, h, 0)]);
    for (final glass in [side, front]) {
      canvas.drawPath(glass, Paint()..color = colors.glass);
      canvas.drawPath(
        glass,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: 0.12),
              Colors.white.withValues(alpha: 0),
              Colors.white.withValues(alpha: 0.04),
            ],
            stops: const [0, 0.35, 1],
          ).createShader(glass.getBounds()),
      );
    }
    // Solid base under the glass and the top panel with two fans.
    canvas.drawPath(
      _poly([(0, 0, 0), (0, 0, d), (0, 0.05, d), (0, 0.05, 0)]),
      Paint()..color = colors.body,
    );
    canvas.drawPath(
      _poly([(0, 0, 0), (w, 0, 0), (w, 0.05, 0), (0, 0.05, 0)]),
      Paint()..color = Color.lerp(colors.body, Colors.black, 0.15)!,
    );
    // Mesh top: see-through enough to show the parts below.
    canvas.drawPath(
      _poly([(0, h, 0), (w, h, 0), (w, h, d), (0, h, d)]),
      Paint()
        ..color = Color.lerp(
          colors.body,
          Colors.white,
          0.05,
        )!.withValues(alpha: 0.45),
    );
    for (final z in const [0.32, 0.72]) {
      canvas.drawPath(
        _ellipse((w / 2, h, z), _ux, _uz, 0.12),
        Paint()
          ..style = PaintingStyle.stroke
          ..color = colors.edge,
      );
    }
    // Power light on the top front edge.
    final led = _p((w * 0.8, h, 0.04));
    if (branded) {
      canvas.drawCircle(
        led,
        _s * 0.05,
        Paint()
          ..color = kBrandCyan.withValues(alpha: 0.5)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
    }
    canvas.drawCircle(
      led,
      _s * 0.018,
      Paint()..color = branded ? kBrandCyan : colors.edge,
    );
    // Frame edges; the glass corner has no pillar, only a faint seam.
    Offset q(V3 v) => _p(v);
    final outline = Path()
      ..addPath(
        _poly([(0, h, 0), (w, h, 0), (w, h, d), (0, h, d)]),
        Offset.zero,
      )
      ..moveTo(q((0, 0, d)).dx, q((0, 0, d)).dy)
      ..lineTo(q((0, h, d)).dx, q((0, h, d)).dy)
      ..moveTo(q((w, 0, 0)).dx, q((w, 0, 0)).dy)
      ..lineTo(q((w, h, 0)).dx, q((w, h, 0)).dy)
      ..moveTo(q((0, 0, d)).dx, q((0, 0, d)).dy)
      ..lineTo(q((0, 0, 0)).dx, q((0, 0, 0)).dy)
      ..lineTo(q((w, 0, 0)).dx, q((w, 0, 0)).dy);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = branded ? 1.6 : 1
      ..strokeJoin = StrokeJoin.round;
    if (branded) {
      stroke.shader = kBrandGradient.createShader(outline.getBounds());
      if (glow > 0) {
        canvas.drawPath(
          outline,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 6
            ..color = kBrandCyan.withValues(alpha: 0.35 * glow)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
        );
      }
    } else {
      stroke.color = colors.edge;
    }
    canvas.drawPath(outline, stroke);
    canvas.drawLine(
      q((0, 0.05, 0)),
      q((0, h, 0)),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.18)
        ..strokeWidth = 0.8,
    );
  }

  // ------------------------------------------------------------ parts --

  /// Box of each part in world units (min, max).
  static const _boxes = <PartCategory, (V3, V3)>{
    PartCategory.motherboard: ((w - 0.035, 0.28, 0.12), (w - 0.01, 0.95, 1.0)),
    PartCategory.cpu: ((w - 0.05, 0.66, 0.34), (w - 0.035, 0.78, 0.46)),
    PartCategory.cooler: ((w - 0.26, 0.60, 0.30), (w - 0.06, 0.88, 0.44)),
    PartCategory.ram: ((w - 0.17, 0.58, 0.52), (w - 0.035, 0.90, 0.76)),
    PartCategory.gpu: ((w - 0.21, 0.29, 0.12), (w - 0.12, 0.55, 0.93)),
    PartCategory.psu: ((0.05, 0.05, 0.62), (w - 0.05, 0.22, 1.07)),
  };

  /// Where each part comes from (world offset at progress 0): the graphics
  /// card and power supply slide in through the glass, RAM drops down.
  static const _from = <PartCategory, V3>{
    PartCategory.motherboard: (0, 0.7, 0),
    PartCategory.cpu: (0, 0.5, 0),
    PartCategory.cooler: (-0.6, 0.2, 0),
    PartCategory.ram: (0, 0.6, 0),
    PartCategory.gpu: (-0.8, 0, 0),
    PartCategory.psu: (-0.75, 0, 0),
  };

  void _part(Canvas canvas, PartCategory c, double t) {
    final (lo0, hi0) = _boxes[c]!;
    final f = _from[c]!;
    final k = 1 - Curves.easeOutBack.transform(t.clamp(0.0, 1.0));
    V3 m(V3 v) => (v.$1 + f.$1 * k, v.$2 + f.$2 * k, v.$3 + f.$3 * k);
    final lo = m(lo0);
    final hi = m(hi0);
    final a = Curves.easeOut.transform((t * 2.5).clamp(0.0, 1.0));
    switch (c) {
      case PartCategory.motherboard:
        _motherboard(canvas, lo, hi, a);
      case PartCategory.cpu:
        // Green substrate with the silver heat spreader on top.
        _box(canvas, lo, hi, const Color(0xFF2E6B4F), a);
        _box(
          canvas,
          (lo.$1 - 0.012, lo.$2 + 0.02, lo.$3 + 0.02),
          (lo.$1, hi.$2 - 0.02, hi.$3 - 0.02),
          _alu,
          a,
        );
      case PartCategory.ram:
        for (var i = 0; i < 4; i++) {
          final z0 = lo.$3 + i * 0.062;
          _ramStick(canvas, (lo.$1, lo.$2, z0), (hi.$1, hi.$2, z0 + 0.036), a);
        }
      case PartCategory.cooler:
        _cooler(canvas, lo, hi, t, a);
      case PartCategory.gpu:
        _gpu(canvas, lo, hi, t, a);
      case PartCategory.psu:
        _psu(canvas, lo, hi, a);
      case PartCategory.pcCase:
        break;
    }
  }

  void _motherboard(Canvas canvas, V3 lo, V3 hi, double a) {
    _box(canvas, lo, hi, _black, a);
    final x = lo.$1;
    final dy = lo.$2 - 0.28;
    // VRM heatsinks, chipset cover and the PCIe slots.
    _box(canvas, (x - 0.03, 0.85 + dy, 0.20), (x, 0.92 + dy, 0.56), _shroud, a);
    _box(canvas, (x - 0.03, 0.56 + dy, 0.14), (x, 0.92 + dy, 0.21), _shroud, a);
    _box(canvas, (x - 0.02, 0.32 + dy, 0.62), (x, 0.42 + dy, 0.88), _shroud, a);
    final slot = Paint()
      ..color = Colors.white.withValues(alpha: 0.18 * a)
      ..strokeWidth = 1;
    for (final y in const [0.50, 0.40]) {
      canvas.drawLine(
        _p((x - 0.002, y + dy, 0.16)),
        _p((x - 0.002, y + dy, 0.6)),
        slot,
      );
    }
  }

  void _ramStick(Canvas canvas, V3 lo, V3 hi, double a) {
    _box(canvas, lo, hi, const Color(0xFF2A2F3B), a);
    // Light bar along the top.
    final bar = _poly([
      (lo.$1, hi.$2, lo.$3),
      (hi.$1, hi.$2, lo.$3),
      (hi.$1, hi.$2, hi.$3),
      (lo.$1, hi.$2, hi.$3),
    ]);
    canvas.drawPath(
      bar,
      Paint()
        ..shader = LinearGradient(
          colors: [
            kBrandCyan.withValues(alpha: a),
            kBrandViolet.withValues(alpha: a),
          ],
        ).createShader(bar.getBounds()),
    );
    canvas.drawPath(
      _poly([
        (lo.$1, hi.$2 - 0.035, lo.$3),
        (hi.$1, hi.$2 - 0.035, lo.$3),
        (hi.$1, hi.$2, lo.$3),
        (lo.$1, hi.$2, lo.$3),
      ]),
      Paint()..color = kBrandCyan.withValues(alpha: 0.75 * a),
    );
    canvas.drawPath(
      _poly([
        (lo.$1, hi.$2 - 0.035, lo.$3),
        (lo.$1, hi.$2 - 0.035, hi.$3),
        (lo.$1, hi.$2, hi.$3),
        (lo.$1, hi.$2, lo.$3),
      ]),
      Paint()..color = kBrandViolet.withValues(alpha: 0.85 * a),
    );
  }

  void _cooler(Canvas canvas, V3 lo, V3 hi, double t, double a) {
    // Aluminium fin stack with a fan on its front.
    _box(canvas, lo, hi, _alu, a);
    final fin = Paint()
      ..color = Colors.black.withValues(alpha: 0.18 * a)
      ..strokeWidth = 0.8;
    for (var y = lo.$2 + 0.02; y < hi.$2; y += 0.025) {
      canvas.drawLine(_p((lo.$1, y, lo.$3)), _p((lo.$1, y, hi.$3)), fin);
    }
    canvas.drawPath(
      _poly([
        (lo.$1, lo.$2, lo.$3 - 0.003),
        (hi.$1, lo.$2, lo.$3 - 0.003),
        (hi.$1, hi.$2, lo.$3 - 0.003),
        (lo.$1, hi.$2, lo.$3 - 0.003),
      ]),
      Paint()..color = _black.withValues(alpha: a),
    );
    _fan(
      canvas,
      ((lo.$1 + hi.$1) / 2, (lo.$2 + hi.$2) / 2, lo.$3 - 0.004),
      _ux,
      _uy,
      (hi.$2 - lo.$2) * 0.45,
      spin: t * 6 * math.pi,
      rgb: true,
      a: a,
    );
  }

  void _gpu(Canvas canvas, V3 lo, V3 hi, double t, double a) {
    // Vertically mounted: the fan side faces the glass.
    _box(canvas, lo, hi, _shroud, a, top: const Color(0xFF4A505C));
    final len = hi.$3 - lo.$3;
    final r = math.min((hi.$2 - lo.$2) * 0.40, len / 6.6);
    for (var i = 0; i < 3; i++) {
      _fan(
        canvas,
        (lo.$1 - 0.002, (lo.$2 + hi.$2) / 2, lo.$3 + len * (i + 0.5) / 3),
        _uz,
        _uy,
        r,
        spin: t * 5 * math.pi,
        a: a,
      );
    }
    // Light strip along the top edge.
    canvas.drawLine(
      _p((lo.$1 - 0.003, hi.$2 - 0.015, lo.$3 + 0.04)),
      _p((lo.$1 - 0.003, hi.$2 - 0.015, hi.$3 - 0.04)),
      Paint()
        ..color = kBrandCyan.withValues(alpha: a)
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round,
    );
  }

  void _psu(Canvas canvas, V3 lo, V3 hi, double a) {
    _box(canvas, lo, hi, _black, a);
    final grille = Paint()
      ..color = Colors.white.withValues(alpha: 0.14 * a)
      ..strokeWidth = 0.8;
    for (var z = lo.$3 + 0.05; z < hi.$3 - 0.03; z += 0.045) {
      canvas.drawLine(
        _p((lo.$1 + 0.04, hi.$2, z)),
        _p((hi.$1 - 0.04, hi.$2, z)),
        grille,
      );
    }
    // Label on the side facing the glass.
    canvas.drawPath(
      _poly([
        (lo.$1 - 0.002, lo.$2 + 0.05, lo.$3 + 0.12),
        (lo.$1 - 0.002, lo.$2 + 0.05, lo.$3 + 0.30),
        (lo.$1 - 0.002, hi.$2 - 0.04, lo.$3 + 0.30),
        (lo.$1 - 0.002, hi.$2 - 0.04, lo.$3 + 0.12),
      ]),
      Paint()..color = Colors.white.withValues(alpha: 0.55 * a),
    );
  }

  /// Box with its three visible faces (front, glass side, top) shaded.
  void _box(Canvas canvas, V3 lo, V3 hi, Color color, double a, {Color? top}) {
    final (x0, y0, z0) = lo;
    final (x1, y1, z1) = hi;
    canvas.drawPath(
      _poly([(x0, y0, z0), (x1, y0, z0), (x1, y1, z0), (x0, y1, z0)]),
      Paint()
        ..color = Color.lerp(color, Colors.black, 0.3)!.withValues(alpha: a),
    );
    canvas.drawPath(
      _poly([(x0, y0, z0), (x0, y0, z1), (x0, y1, z1), (x0, y1, z0)]),
      Paint()..color = color.withValues(alpha: a),
    );
    canvas.drawPath(
      _poly([(x0, y1, z0), (x1, y1, z0), (x1, y1, z1), (x0, y1, z1)]),
      Paint()
        ..color = (top ?? Color.lerp(color, Colors.white, 0.22)!).withValues(
          alpha: a,
        ),
    );
    // Thin highlight so dark parts stand out on a dark case.
    canvas.drawLine(
      _p((x0, y1, z0)),
      _p((x0, y1, z1)),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.22 * a)
        ..strokeWidth = 0.8,
    );
  }

  Path _ellipse(V3 c, Offset ua, Offset ub, double r) {
    final o = _p(c);
    final path = Path();
    for (var i = 0; i <= 36; i++) {
      final t = i / 36 * 2 * math.pi;
      final pt = o + ua * (r * math.cos(t)) + ub * (r * math.sin(t));
      i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
    }
    return path..close();
  }

  /// Fan in the plane of screen axes [ua], [ub]: dark disc, curved blades,
  /// hub and (for RGB fans) a glowing ring.
  void _fan(
    Canvas canvas,
    V3 c,
    Offset ua,
    Offset ub,
    double r, {
    double spin = 0,
    bool rgb = false,
    double a = 1,
  }) {
    final disc = _ellipse(c, ua, ub, r);
    canvas.drawPath(
      disc,
      Paint()..color = const Color(0xFF14171D).withValues(alpha: 0.85 * a),
    );
    final o = _p(c);
    final blade = Paint()
      ..color = Colors.white.withValues(alpha: 0.35 * a)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    for (var i = 0; i < 7; i++) {
      final t = spin + i * 2 * math.pi / 7;
      final mid =
          o +
          ua * (r * 0.55 * math.cos(t + 0.35)) +
          ub * (r * 0.55 * math.sin(t + 0.35));
      final end =
          o + ua * (r * 0.9 * math.cos(t)) + ub * (r * 0.9 * math.sin(t));
      canvas.drawPath(
        Path()
          ..moveTo(o.dx, o.dy)
          ..quadraticBezierTo(mid.dx, mid.dy, end.dx, end.dy),
        blade,
      );
    }
    canvas.drawPath(
      _ellipse(c, ua, ub, r * 0.25),
      Paint()..color = const Color(0xFF2B303A).withValues(alpha: a),
    );
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = rgb ? 1.8 : 1;
    if (rgb) {
      ring.shader = SweepGradient(
        colors: [
          kBrandCyan.withValues(alpha: a),
          kBrandViolet.withValues(alpha: a),
          kBrandCyan.withValues(alpha: a),
        ],
      ).createShader(disc.getBounds());
      canvas.drawPath(
        disc,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..color = kBrandCyan.withValues(alpha: 0.25 * a)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
    } else {
      ring.color = colors.edge.withValues(alpha: a);
    }
    canvas.drawPath(disc, ring);
  }

  /// Dashed outline of the face a missing part would show.
  void _ghost(Canvas canvas, PartCategory c) {
    final (lo, hi) = _boxes[c]!;
    final path = c == PartCategory.ram || c == PartCategory.cpu
        ? _poly([
            (lo.$1, lo.$2, lo.$3),
            (hi.$1, lo.$2, lo.$3),
            (hi.$1, hi.$2, lo.$3),
            (lo.$1, hi.$2, lo.$3),
          ])
        : _poly([
            (lo.$1, lo.$2, lo.$3),
            (lo.$1, lo.$2, hi.$3),
            (lo.$1, hi.$2, hi.$3),
            (lo.$1, hi.$2, lo.$3),
          ]);
    final paint = Paint()
      ..color = colors.ghost
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    for (final m in path.computeMetrics()) {
      for (var s = 0.0; s < m.length; s += 7) {
        canvas.drawPath(m.extractPath(s, s + 3.5), paint);
      }
    }
  }

  @override
  bool shouldRepaint(PcCasePainter old) => true;
}

/// Theme colours used by [PcCasePainter] (parts keep their real colours).
@immutable
class CaseColors {
  const CaseColors({
    required this.body,
    required this.interior,
    required this.glass,
    required this.edge,
    required this.ghost,
  });

  final Color body;
  final Color interior;
  final Color glass;
  final Color edge;
  final Color ghost;
}
