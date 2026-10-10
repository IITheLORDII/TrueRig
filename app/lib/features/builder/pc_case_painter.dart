import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:perf_engine/perf_engine.dart';

import 'package:darbogaz/core/brand/truerig_logo.dart';
import 'package:darbogaz/core/theme/app_theme.dart';
import 'package:darbogaz/features/builder/pc_case_shape.dart';

/// A point in case space: x = across the front (0 = glass side, w =
/// motherboard side), y = up, z = depth (0 = front).
typedef V3 = (double, double, double);

/// The chosen case seen from the front-left: its size, style (aquarium,
/// airflow mesh or compact) and the fans it ships with, plus the parts the
/// way they look in real builds. A graphics card or cooler that does not
/// fit is drawn at its real size and outlined in red.
///
/// One long drawing routine on purpose (over the 400-line guide): the parts
/// share the projection state and splitting it would only scatter it.
class PcCasePainter extends CustomPainter {
  PcCasePainter({
    required this.shape,
    required this.progressOf,
    required this.present,
    required this.colors,
    required this.caseInOf,
    super.repaint,
  });

  final BuildShape shape;

  /// 0 = outside the case, 1 = in place (read on every frame).
  final double Function(PartCategory) progressOf;

  /// Parts that are chosen (missing ones get a dashed outline).
  final Set<PartCategory> present;
  final CaseColors colors;

  /// 0..1 while a newly chosen case gets its fans (read on every frame).
  final double Function() caseInOf;

  // Projection: the long side is shown wide, the front narrow.
  static const double _cx = 0.48;
  static const double _cz = 0.92;
  static const double _ax = 0.13;
  static const double _az = 0.17;

  /// Fan radius (120 mm).
  static const double _r = 0.13;

  static const _black = Color(0xFF1F232C);
  static const _shroud = Color(0xFF262B35);
  static const _alu = Color(0xFFB9C0CC);

  double get w => shape.w;
  double get h => shape.h;
  double get d => shape.d;
  double get _ys => h;
  double get _zs => d / 1.1;

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

  /// Fits the largest case, so smaller cases are drawn smaller.
  void _fit(Size size) {
    const bw = 0.78, bh = 1.1, bd = 1.16;
    const left = -bd * _cz;
    const right = bw * _cx;
    const top = bh + bw * _ax + bd * _az;
    _s = math.min(size.width / (right - left), size.height / top) * 0.9;
    _origin = Offset(
      size.width / 2 - (left + right) / 2 * _s,
      size.height / 2 + top / 2 * _s,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    _fit(size);
    final caseIn = caseInOf();
    _interior(canvas, caseIn);
    // Far to near so nearer parts cover farther ones.
    for (final c in const [
      PartCategory.motherboard,
      PartCategory.cpu,
      PartCategory.ram,
      PartCategory.cooler,
      PartCategory.psu,
      PartCategory.gpu,
    ]) {
      if (c == PartCategory.gpu && shape.gpuIntegrated) continue;
      final t = progressOf(c);
      if (t > 0) {
        _part(canvas, c, t);
      } else if (!present.contains(c) && c != PartCategory.cooler) {
        _ghost(canvas, c);
      }
    }
    _shell(canvas, caseIn);
  }

  // -------------------------------------------------------------- fans --

  /// Case fans with their plane axes, in the order they are fitted.
  List<(V3, Offset, Offset, double)> _caseFans({required bool filled}) => [
    for (final f in shape.fanSlots)
      if (f.filled == filled)
        (
          (f.x, f.y, f.z),
          _ux,
          f.place == FanPlace.front || f.place == FanPlace.rear ? _uy : _uz,
          f.r,
        ),
  ];

  /// Fan k of n grows into place while the case arrives.
  double _fanIn(int k, int n, double caseIn) =>
      Curves.easeOutBack.transform((caseIn * (n + 1) - k).clamp(0.0, 1.0));

  // ------------------------------------------------------------- case --

  void _interior(Canvas canvas, double caseIn) {
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
    // Empty fan places: dashed rings showing where fans can be added.
    for (final (c, ua, ub, r) in _caseFans(filled: false)) {
      _dashed(canvas, _ellipse(c, ua, ub, r), colors.ghost);
    }
    final fans = _caseFans(filled: true);
    for (var k = 0; k < fans.length; k++) {
      final scale = _fanIn(k, fans.length, caseIn);
      if (scale <= 0) continue;
      final (c, ua, ub, r) = fans[k];
      _fan(
        canvas,
        c,
        ua,
        ub,
        r * scale,
        spin: caseIn * 4 * math.pi,
        rgb: shape.rgbFans,
      );
    }
  }

  void _shell(Canvas canvas, double caseIn) {
    final glow = shape.caseChosen ? math.sin(math.pi * caseIn) : 0.0;
    final side = _poly([(0, 0, 0), (0, 0, d), (0, h, d), (0, h, 0)]);
    final front = _poly([(0, 0, 0), (w, 0, 0), (w, h, 0), (0, h, 0)]);
    final glassSides = shape.style == CaseStyle.aquarium
        ? [side, front]
        : [side];
    for (final glass in glassSides) {
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
    if (shape.style != CaseStyle.aquarium) _meshFront(canvas, front);
    // Solid base strip and the mesh top.
    canvas.drawPath(
      _poly([(0, 0, 0), (0, 0, d), (0, 0.05, d), (0, 0.05, 0)]),
      Paint()..color = colors.body,
    );
    canvas.drawPath(
      _poly([(0, 0, 0), (w, 0, 0), (w, 0.05, 0), (0, 0.05, 0)]),
      Paint()..color = Color.lerp(colors.body, Colors.black, 0.15)!,
    );
    canvas.drawPath(
      _poly([(0, h, 0), (w, h, 0), (w, h, d), (0, h, d)]),
      Paint()
        ..color = Color.lerp(
          colors.body,
          Colors.white,
          0.05,
        )!.withValues(alpha: 0.45),
    );
    // Power light.
    final lit = shape.caseChosen;
    final led = _p((w * 0.8, h, 0.04));
    if (lit) {
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
      Paint()..color = lit ? kBrandCyan : colors.edge,
    );
    // Frame edges; an aquarium's glass corner has no pillar.
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
    if (shape.style != CaseStyle.aquarium) {
      outline
        ..moveTo(q((0, 0, 0)).dx, q((0, 0, 0)).dy)
        ..lineTo(q((0, h, 0)).dx, q((0, h, 0)).dy);
    }
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = lit ? 1.6 : 1
      ..strokeJoin = StrokeJoin.round;
    if (lit) {
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
    if (shape.style == CaseStyle.aquarium) {
      canvas.drawLine(
        q((0, 0.05, 0)),
        q((0, h, 0)),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.18)
          ..strokeWidth = 0.8,
      );
    }
  }

  /// Mesh front (airflow and compact cases): front fans show through, RGB
  /// fans glow through it.
  void _meshFront(Canvas canvas, Path front) {
    canvas.drawPath(
      front,
      Paint()..color = colors.body.withValues(alpha: 0.55),
    );
    final dot = Paint()..color = Colors.black.withValues(alpha: 0.35);
    for (var y = 0.1; y < h - 0.04; y += 0.035) {
      for (var x = 0.04; x < w - 0.02; x += 0.035) {
        canvas.drawCircle(_p((x, y, 0)), 0.6, dot);
      }
    }
    if (!shape.rgbFans) return;
    for (final (c, ua, ub, r) in _caseFans(filled: true)) {
      if (c.$3 > 0.1) continue; // only front fans
      canvas.drawPath(
        _ellipse(c, ua, ub, r * 0.95),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = kBrandCyan.withValues(alpha: 0.45)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
    }
  }

  // ------------------------------------------------------------ parts --

  (V3, V3) get _psuBox {
    final top = shape.style == CaseStyle.compact ? 0.18 : 0.22;
    return ((0.05, 0.05, shape.psuFrontZ), (w - 0.05, top, d - 0.03));
  }

  /// Box of each part in drawing units (min, max).
  (V3, V3) _box(PartCategory c) => switch (c) {
    PartCategory.motherboard => (
      (w - 0.035, 0.28 * _ys, 0.12 * _zs),
      (w - 0.01, 0.95 * _ys, d - 0.1 * _zs),
    ),
    PartCategory.cpu => (
      (w - 0.05, 0.66 * _ys, 0.34 * _zs),
      (w - 0.035, 0.78 * _ys, 0.46 * _zs),
    ),
    PartCategory.cooler when shape.liquid => (
      (w - 0.105, 0.64 * _ys, 0.33 * _zs),
      (w - 0.035, 0.80 * _ys, 0.47 * _zs),
    ),
    PartCategory.cooler => (
      (w - 0.035 - shape.coolerReach, 0.60 * _ys, 0.30 * _zs),
      (w - 0.05, 0.88 * _ys, 0.44 * _zs),
    ),
    PartCategory.ram => (
      (w - 0.17, 0.58 * _ys, 0.52 * _zs),
      (w - 0.035, 0.90 * _ys, 0.76 * _zs),
    ),
    // The bracket sits at the back; a long card reaches toward the front.
    PartCategory.gpu => (
      (w - 0.21, 0.29 * _ys, d - 0.06 - shape.gpuLength),
      (w - 0.12, 0.55 * _ys, d - 0.06),
    ),
    PartCategory.psu => _psuBox,
    PartCategory.pcCase => ((0, 0, 0), (w, h, d)),
  };

  /// Where each part comes from (offset at progress 0): the graphics card
  /// and power supply slide in through the glass, RAM drops down.
  static const _from = <PartCategory, V3>{
    PartCategory.motherboard: (0, 0.7, 0),
    PartCategory.cpu: (0, 0.5, 0),
    PartCategory.cooler: (-0.6, 0.2, 0),
    PartCategory.ram: (0, 0.6, 0),
    PartCategory.gpu: (-0.8, 0, 0),
    PartCategory.psu: (-0.75, 0, 0),
  };

  void _part(Canvas canvas, PartCategory c, double t) {
    final (lo0, hi0) = _box(c);
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
        _cube(canvas, lo, hi, const Color(0xFF2E6B4F), a);
        _cube(
          canvas,
          (lo.$1 - 0.012, lo.$2 + 0.02, lo.$3 + 0.02),
          (lo.$1, hi.$2 - 0.02, hi.$3 - 0.02),
          _alu,
          a,
        );
      case PartCategory.ram:
        for (var i = 0; i < 4; i++) {
          final z0 = lo.$3 + i * 0.062 * _zs;
          _ramStick(
            canvas,
            (lo.$1, lo.$2, z0),
            (hi.$1, hi.$2, z0 + 0.036 * _zs),
            a,
          );
        }
      case PartCategory.cooler:
        if (shape.liquid) {
          _liquid(canvas, lo, hi, t, a);
        } else {
          _tower(canvas, lo, hi, t, a);
          if (shape.coolerTooTall) _warn(canvas, lo, hi, a);
        }
      case PartCategory.gpu:
        _gpu(canvas, lo, hi, t, a);
        if (shape.gpuTooLong) _warn(canvas, lo, hi, a);
      case PartCategory.psu:
        _psu(canvas, lo, hi, a);
      case PartCategory.pcCase:
        break;
    }
  }

  void _motherboard(Canvas canvas, V3 lo, V3 hi, double a) {
    _cube(canvas, lo, hi, _black, a);
    final x = lo.$1;
    double y(double v) => lo.$2 + (v - 0.28) * _ys;
    double z(double v) => v * _zs;
    // VRM heatsinks, chipset cover and the PCIe slots.
    _cube(
      canvas,
      (x - 0.03, y(0.85), z(0.2)),
      (x, y(0.92), z(0.56)),
      _shroud,
      a,
    );
    _cube(
      canvas,
      (x - 0.03, y(0.56), z(0.14)),
      (x, y(0.92), z(0.21)),
      _shroud,
      a,
    );
    _cube(
      canvas,
      (x - 0.02, y(0.32), z(0.62)),
      (x, y(0.42), z(0.88)),
      _shroud,
      a,
    );
    final slot = Paint()
      ..color = Colors.white.withValues(alpha: 0.18 * a)
      ..strokeWidth = 1;
    for (final v in const [0.50, 0.40]) {
      canvas.drawLine(
        _p((x - 0.002, y(v), z(0.16))),
        _p((x - 0.002, y(v), z(0.6))),
        slot,
      );
    }
  }

  void _ramStick(Canvas canvas, V3 lo, V3 hi, double a) {
    _cube(canvas, lo, hi, const Color(0xFF2A2F3B), a);
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

  /// Air tower: aluminium fin stack with a fan on its front.
  void _tower(Canvas canvas, V3 lo, V3 hi, double t, double a) {
    _cube(canvas, lo, hi, _alu, a);
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
      math.min(hi.$2 - lo.$2, hi.$1 - lo.$1) * 0.45,
      spin: t * 6 * math.pi,
      rgb: true,
      a: a,
    );
  }

  /// Liquid cooler: pump block with a light ring on the CPU, hoses up to
  /// a radiator with its fans under the top of the case.
  void _liquid(Canvas canvas, V3 lo, V3 hi, double t, double a) {
    final n = shape.radiatorFans;
    // Fans shrink a little if the radiator would not fit the case depth.
    final room = d - 0.12 * _zs - 0.08;
    final fr = math.min(_r, (room - 0.06) / (2 * n) - 0.01);
    final radLen = n * (2 * fr + 0.02) + 0.06;
    final r0 = (0.07, h - 0.11, 0.12 * _zs);
    final r1 = (w - 0.2, h - 0.04, 0.12 * _zs + radLen);
    // Fans hanging under the radiator.
    for (var i = 0; i < n; i++) {
      _fan(
        canvas,
        (
          (r0.$1 + r1.$1) / 2,
          r0.$2 - 0.004,
          r0.$3 + 0.04 + fr + i * (2 * fr + 0.02),
        ),
        _ux,
        _uz,
        fr * 0.9 * a,
        spin: t * 6 * math.pi,
        rgb: true,
        a: a,
      );
    }
    _cube(canvas, r0, r1, _black, a);
    final fin = Paint()
      ..color = Colors.white.withValues(alpha: 0.12 * a)
      ..strokeWidth = 0.7;
    for (var z = r0.$3 + 0.03; z < r1.$3 - 0.02; z += 0.02) {
      canvas.drawLine(
        _p((r0.$1, r0.$2 + 0.01, z)),
        _p((r0.$1, r1.$2 - 0.01, z)),
        fin,
      );
    }
    // Hoses from the pump to the radiator end.
    final hose = Paint()
      ..color = const Color(0xFF14171D).withValues(alpha: a)
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    for (final dz in const [0.0, 0.05]) {
      final from = _p((lo.$1 + 0.02, hi.$2, (lo.$3 + hi.$3) / 2 + dz - 0.025));
      final to = _p((r0.$1 + 0.1, r0.$2, r0.$3 + 0.02 + dz));
      final mid = _p((lo.$1 - 0.12, h - 0.2, r0.$3 + 0.1 + dz));
      canvas.drawPath(
        Path()
          ..moveTo(from.dx, from.dy)
          ..quadraticBezierTo(mid.dx, mid.dy, to.dx, to.dy),
        hose,
      );
    }
    // Pump block with a glowing ring.
    _cube(canvas, lo, hi, _black, a);
    final c = (lo.$1 - 0.002, (lo.$2 + hi.$2) / 2, (lo.$3 + hi.$3) / 2);
    final ring = _ellipse(c, _uz, _uy, (hi.$2 - lo.$2) * 0.36);
    canvas.drawPath(
      ring,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..shader = SweepGradient(
          transform: GradientRotation(t * 2 * math.pi),
          colors: [
            kBrandCyan.withValues(alpha: a),
            kBrandViolet.withValues(alpha: a),
            kBrandCyan.withValues(alpha: a),
          ],
        ).createShader(ring.getBounds()),
    );
  }

  void _gpu(Canvas canvas, V3 lo, V3 hi, double t, double a) {
    // Vertically mounted: the fan side faces the glass.
    _cube(canvas, lo, hi, _shroud, a, top: const Color(0xFF4A505C));
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
    _cube(canvas, lo, hi, _black, a);
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
    final len = hi.$3 - lo.$3;
    canvas.drawPath(
      _poly([
        (lo.$1 - 0.002, lo.$2 + 0.04, lo.$3 + len * 0.25),
        (lo.$1 - 0.002, lo.$2 + 0.04, lo.$3 + len * 0.65),
        (lo.$1 - 0.002, hi.$2 - 0.04, lo.$3 + len * 0.65),
        (lo.$1 - 0.002, hi.$2 - 0.04, lo.$3 + len * 0.25),
      ]),
      Paint()..color = Colors.white.withValues(alpha: 0.55 * a),
    );
  }

  /// Red outline around a part that does not fit the case.
  void _warn(Canvas canvas, V3 lo, V3 hi, double a) {
    final (x0, y0, z0) = lo;
    final (x1, y1, z1) = hi;
    final shape = Path()
      ..addPath(
        _poly([(x0, y0, z0), (x0, y0, z1), (x0, y1, z1), (x0, y1, z0)]),
        Offset.zero,
      )
      ..addPath(
        _poly([(x0, y1, z0), (x1, y1, z0), (x1, y1, z1), (x0, y1, z1)]),
        Offset.zero,
      );
    canvas.drawPath(
      shape,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..color = colors.bad.withValues(alpha: 0.35 * a)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawPath(
      shape,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = colors.bad.withValues(alpha: a),
    );
  }

  /// Box with its three visible faces (front, glass side, top) shaded.
  void _cube(Canvas canvas, V3 lo, V3 hi, Color color, double a, {Color? top}) {
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
    if (r <= 0) return;
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
    final (lo, hi) = _box(c);
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
    _dashed(canvas, path, colors.ghost);
  }

  void _dashed(Canvas canvas, Path path, Color color) {
    final paint = Paint()
      ..color = color
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
    required this.bad,
  });

  final Color body;
  final Color interior;
  final Color glass;
  final Color edge;
  final Color ghost;
  final Color bad;
}
