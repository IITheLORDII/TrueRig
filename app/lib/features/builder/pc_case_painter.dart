import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:perf_engine/perf_engine.dart';

import 'package:darbogaz/core/brand/truerig_logo.dart';
import 'package:darbogaz/core/theme/app_theme.dart';

/// A tower case seen from the front-left corner: the glass side panel shows
/// the inside, where parts are drawn in 3D boxes at their real places.
///
/// World units: x = across the front (0 = glass side, [w] = motherboard
/// side), y = up, z = depth (0 = front).
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

  /// A case is chosen: brand-coloured edges and power light.
  final bool branded;

  /// 0..1 pulse when the case is chosen.
  final double Function() caseGlowOf;

  static const double w = 0.55;
  static const double h = 1.0;
  static const double d = 1.1;

  // Projection: the long side is shown wide, the front narrow.
  static const double _cx = 0.42;
  static const double _cz = 0.92;
  static const double _ax = 0.22;
  static const double _az = 0.30;

  late Offset _origin;
  late double _s;

  Offset _p(double x, double y, double z) =>
      _origin + Offset((x * _cx - z * _cz) * _s, -(y + x * _ax + z * _az) * _s);

  Path _poly(List<(double, double, double)> pts) {
    final path = Path();
    for (var i = 0; i < pts.length; i++) {
      final o = _p(pts[i].$1, pts[i].$2, pts[i].$3);
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
    final inside = Paint()..color = colors.interior;
    canvas.drawPath(
      _poly([(w, 0, 0), (w, 0, d), (w, h, d), (w, h, 0)]),
      inside,
    );
    canvas.drawPath(
      _poly([(0, 0, d), (w, 0, d), (w, h, d), (0, h, d)]),
      Paint()..color = Color.lerp(colors.interior, Colors.black, 0.15)!,
    );
    canvas.drawPath(
      _poly([(0, 0, 0), (w, 0, 0), (w, 0, d), (0, 0, d)]),
      Paint()..color = Color.lerp(colors.interior, Colors.black, 0.25)!,
    );
  }

  void _shell(Canvas canvas, double caseGlow) {
    final glass = _poly([(0, 0, 0), (0, 0, d), (0, h, d), (0, h, 0)]);
    final glassBounds = glass.getBounds();
    canvas.drawPath(glass, Paint()..color = colors.glass);
    canvas.drawPath(
      glass,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.10),
            Colors.white.withValues(alpha: 0),
            Colors.white.withValues(alpha: 0.05),
          ],
          stops: const [0, 0.4, 1],
        ).createShader(glassBounds),
    );
    final front = _poly([(0, 0, 0), (w, 0, 0), (w, h, 0), (0, h, 0)]);
    canvas.drawPath(front, Paint()..color = colors.body);
    // Front mesh lines.
    final mesh = Paint()
      ..color = colors.edge
      ..strokeWidth = 1;
    for (var y = 0.18; y < 0.9; y += 0.08) {
      canvas.drawLine(_p(0.08, y, 0), _p(w - 0.08, y, 0), mesh);
    }
    final top = _poly([(0, h, 0), (w, h, 0), (w, h, d), (0, h, d)]);
    canvas.drawPath(
      top,
      Paint()..color = Color.lerp(colors.body, Colors.white, 0.06)!,
    );
    // Power light.
    final led = _p(w / 2, h - 0.06, 0);
    if (branded) {
      canvas.drawCircle(
        led,
        _s * 0.06,
        Paint()
          ..color = kBrandCyan.withValues(alpha: 0.5)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
    }
    canvas.drawCircle(
      led,
      _s * 0.025,
      Paint()..color = branded ? kBrandCyan : colors.edge,
    );
    // Outline (brand gradient once a case is chosen).
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = branded ? 1.8 : 1
      ..strokeJoin = StrokeJoin.round;
    final all = Path()
      ..addPath(glass, Offset.zero)
      ..addPath(front, Offset.zero)
      ..addPath(top, Offset.zero);
    if (branded) {
      stroke.shader = kBrandGradient.createShader(all.getBounds());
      if (caseGlow > 0) {
        canvas.drawPath(
          all,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 6
            ..color = kBrandCyan.withValues(alpha: 0.35 * caseGlow)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
        );
      }
    } else {
      stroke.color = colors.edge;
    }
    canvas.drawPath(all, stroke);
  }

  // ------------------------------------------------------------ parts --

  /// Box of each part (min corner, max corner) in world units.
  static const _boxes = <PartCategory, (List<double>, List<double>)>{
    PartCategory.motherboard: ([w - 0.035, 0.30, 0.10], [w - 0.01, 0.94, 1.00]),
    PartCategory.cpu: ([w - 0.05, 0.66, 0.32], [w - 0.035, 0.78, 0.44]),
    PartCategory.cooler: ([w - 0.25, 0.60, 0.28], [w - 0.05, 0.86, 0.46]),
    PartCategory.ram: ([w - 0.17, 0.60, 0.56], [w - 0.035, 0.88, 0.70]),
    PartCategory.gpu: ([w - 0.34, 0.42, 0.08], [w - 0.035, 0.52, 0.86]),
    PartCategory.psu: ([0.03, 0.02, 0.58], [w - 0.03, 0.20, 1.07]),
  };

  /// Where each part comes from (world offset at progress 0).
  static const _from = <PartCategory, (double, double, double)>{
    PartCategory.motherboard: (0, 0.7, 0),
    PartCategory.cpu: (0, 0.5, 0),
    PartCategory.cooler: (-0.6, 0.2, 0),
    PartCategory.ram: (0, 0.6, 0),
    PartCategory.gpu: (-0.75, 0, 0),
    PartCategory.psu: (-0.7, 0, 0),
  };

  void _part(Canvas canvas, PartCategory c, double t) {
    final (lo, hi) = _boxes[c]!;
    final (fx, fy, fz) = _from[c]!;
    final e = Curves.easeOutBack.transform(t.clamp(0.0, 1.0));
    final k = 1 - e;
    final o = (fx * k, fy * k, fz * k);
    final alpha = Curves.easeOut.transform((t * 2.5).clamp(0.0, 1.0));
    final color = colors.of(c).withValues(alpha: alpha);
    if (c == PartCategory.ram) {
      // Four sticks side by side.
      for (var i = 0; i < 4; i++) {
        final z0 = lo[2] + i * 0.034;
        _box(canvas, [lo[0], lo[1], z0], [hi[0], hi[1], z0 + 0.02], o, color);
      }
      return;
    }
    _box(canvas, lo, hi, o, color);
    if (c == PartCategory.gpu) {
      // Light strip along the side facing the glass.
      final y = (lo[1] + hi[1]) / 2;
      canvas.drawLine(
        _p(lo[0] + o.$1 - 0.002, y + o.$2, lo[2] + 0.08),
        _p(lo[0] + o.$1 - 0.002, y + o.$2, hi[2] - 0.08),
        Paint()
          ..color = kBrandCyan.withValues(alpha: alpha)
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round,
      );
    }
    if (c == PartCategory.cooler) _fan(canvas, lo, hi, o, t, alpha);
    if (c == PartCategory.psu) _grille(canvas, lo, hi, o, alpha);
  }

  void _box(
    Canvas canvas,
    List<double> lo,
    List<double> hi,
    (double, double, double) o,
    Color color,
  ) {
    final x0 = lo[0] + o.$1, y0 = lo[1] + o.$2, z0 = lo[2] + o.$3;
    final x1 = hi[0] + o.$1, y1 = hi[1] + o.$2, z1 = hi[2] + o.$3;
    // Visible faces: front (z0), glass side (x0), top (y1).
    canvas.drawPath(
      _poly([(x0, y0, z0), (x1, y0, z0), (x1, y1, z0), (x0, y1, z0)]),
      Paint()..color = Color.lerp(color, Colors.black, 0.30)!,
    );
    canvas.drawPath(
      _poly([(x0, y0, z0), (x0, y0, z1), (x0, y1, z1), (x0, y1, z0)]),
      Paint()..color = color,
    );
    canvas.drawPath(
      _poly([(x0, y1, z0), (x1, y1, z0), (x1, y1, z1), (x0, y1, z1)]),
      Paint()..color = Color.lerp(color, Colors.white, 0.25)!,
    );
  }

  /// Cooler fan on its front face; spins while it settles.
  void _fan(
    Canvas canvas,
    List<double> lo,
    List<double> hi,
    (double, double, double) o,
    double t,
    double alpha,
  ) {
    final xc = (lo[0] + hi[0]) / 2 + o.$1;
    final yc = (lo[1] + hi[1]) / 2 + o.$2;
    final z = lo[2] + o.$3 - 0.003;
    final r = (hi[1] - lo[1]) * 0.42;
    final ring = Path();
    for (var i = 0; i <= 24; i++) {
      final a = i / 24 * 2 * math.pi;
      final pt = _p(xc + r * math.cos(a), yc + r * math.sin(a), z);
      i == 0 ? ring.moveTo(pt.dx, pt.dy) : ring.lineTo(pt.dx, pt.dy);
    }
    canvas.drawPath(
      ring,
      Paint()..color = Colors.black.withValues(alpha: 0.35 * alpha),
    );
    final blade = Paint()
      ..color = Colors.white.withValues(alpha: 0.7 * alpha)
      ..strokeWidth = 1.4;
    final spin = t * 6 * math.pi;
    for (var i = 0; i < 5; i++) {
      final a = spin + i * 2 * math.pi / 5;
      canvas.drawLine(
        _p(xc, yc, z),
        _p(xc + r * 0.9 * math.cos(a), yc + r * 0.9 * math.sin(a), z),
        blade,
      );
    }
  }

  void _grille(
    Canvas canvas,
    List<double> lo,
    List<double> hi,
    (double, double, double) o,
    double alpha,
  ) {
    final line = Paint()
      ..color = Colors.white.withValues(alpha: 0.18 * alpha)
      ..strokeWidth = 1;
    for (var z = lo[2] + 0.06; z < hi[2] - 0.04; z += 0.06) {
      canvas.drawLine(
        _p(lo[0] + o.$1 + 0.05, hi[1] + o.$2, z + o.$3),
        _p(hi[0] + o.$1 - 0.05, hi[1] + o.$2, z + o.$3),
        line,
      );
    }
  }

  /// Dashed outline of the face a missing part would show.
  void _ghost(Canvas canvas, PartCategory c) {
    final (lo, hi) = _boxes[c]!;
    final path = c == PartCategory.ram || c == PartCategory.cpu
        ? _poly([
            (lo[0], lo[1], lo[2]),
            (hi[0], lo[1], lo[2]),
            (hi[0], hi[1], lo[2]),
            (lo[0], hi[1], lo[2]),
          ])
        : _poly([
            (lo[0], lo[1], lo[2]),
            (lo[0], lo[1], hi[2]),
            (lo[0], hi[1], hi[2]),
            (lo[0], hi[1], lo[2]),
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

/// Theme colours used by [PcCasePainter].
@immutable
class CaseColors {
  const CaseColors({
    required this.body,
    required this.interior,
    required this.glass,
    required this.edge,
    required this.ghost,
    required this.cpu,
    required this.gpu,
    required this.ram,
    required this.cooler,
  });

  final Color body;
  final Color interior;
  final Color glass;
  final Color edge;
  final Color ghost;
  final Color cpu;
  final Color gpu;
  final Color ram;
  final Color cooler;

  Color of(PartCategory c) => switch (c) {
    PartCategory.motherboard => const Color(0xFF0F4C4A),
    PartCategory.cpu => cpu,
    PartCategory.cooler => cooler,
    PartCategory.ram => ram,
    PartCategory.gpu => gpu,
    PartCategory.psu => const Color(0xFF3A4256),
    PartCategory.pcCase => body,
  };
}
