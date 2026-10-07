import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:darbogaz/core/theme/app_theme.dart';

/// Semicircle gauge showing a 0-100 bottleneck percentage.
class BottleneckGauge extends StatelessWidget {
  const BottleneckGauge({
    super.key,
    required this.percent,
    required this.caption,
    this.size = 220,
  });

  final double percent;
  final String caption;
  final double size;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final color = palette.forBottleneck(percent);
    return Semantics(
      label: 'Darboğaz yüzde ${percent.toStringAsFixed(0)}, $caption',
      child: SizedBox(
        width: size,
        height: size * 0.62,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: percent.clamp(0, 100)),
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeOutCubic,
          builder: (context, value, _) => CustomPaint(
            painter: _GaugePainter(
              value: value,
              track: palette.surfaceAlt,
              colors: [palette.good, palette.warn, palette.bad],
            ),
            child: Align(
              alignment: const Alignment(0, 0.85),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '%${value.toStringAsFixed(0)}',
                    style: numberStyle(
                      context,
                      size: size * 0.18,
                      color: color,
                    ),
                  ),
                  Text(
                    caption,
                    style: Theme.of(context).textTheme.labelMedium
                        ?.copyWith(color: palette.muted),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  _GaugePainter({
    required this.value,
    required this.track,
    required this.colors,
  });

  final double value;
  final Color track;
  final List<Color> colors;

  /// Visual full-scale; bottlenecks above this pin the needle.
  static const double _fullScale = 50;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.075;
    final rect = Rect.fromCircle(
      center: Offset(size.width / 2, size.height * 0.92),
      radius: size.width / 2 - stroke,
    );
    final trackPaint = Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = stroke;
    canvas.drawArc(rect, math.pi, math.pi, false, trackPaint);

    final sweep = math.pi * (value / _fullScale).clamp(0.0, 1.0);
    if (sweep <= 0) return;
    final arcPaint = Paint()
      ..shader = SweepGradient(
        startAngle: math.pi,
        endAngle: 2 * math.pi,
        colors: colors,
        stops: const [0.2, 0.4, 0.8],
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = stroke;
    canvas.drawArc(rect, math.pi, sweep, false, arcPaint);
  }

  @override
  bool shouldRepaint(_GaugePainter old) =>
      old.value != value || old.track != track;
}
