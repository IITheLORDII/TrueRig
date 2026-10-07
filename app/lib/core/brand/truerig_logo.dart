import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Brand colours (also used for launcher icons and the native splash).
const Color kBrandCyan = Color(0xFF00E5FF);
const Color kBrandViolet = Color(0xFF7C4DFF);
const Color kBrandNight = Color(0xFF0B0F1A);

const String kAppName = 'TrueRig';
const String kAppTagline = 'Donanımının gerçek gücü';

/// TrueRig mark: a processor die (the "rig") with a check mark (the "true"
/// verdict), drawn in a cyan → violet gradient. Vector, so it stays sharp
/// from a 20 px app-bar icon to a 1024 px store icon.
class TrueRigMark extends StatelessWidget {
  const TrueRigMark({super.key, this.size = 28, this.withBackground = false});

  final double size;

  /// Rounded dark tile behind the mark (launcher icon style).
  final bool withBackground;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(painter: TrueRigMarkPainter(withBackground)),
  );
}

class TrueRigMarkPainter extends CustomPainter {
  const TrueRigMarkPainter(
    this.withBackground, {
    this.tileRadius = 0.22,
    this.markScale = 1,
  });

  final bool withBackground;

  /// Background corner radius as a share of the size (0 = square, which the
  /// App Store requires; the OS rounds the corners itself).
  final double tileRadius;

  /// Shrinks the mark inside the canvas (adaptive icon / splash safe zones).
  final double markScale;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    canvas.save();
    canvas.translate((size.width - s) / 2, (size.height - s) / 2);

    if (withBackground) {
      final tile = RRect.fromRectAndRadius(
        Offset.zero & Size.square(s),
        Radius.circular(s * tileRadius),
      );
      canvas.drawRRect(
        tile,
        Paint()
          ..shader = const RadialGradient(
            center: Alignment(-0.4, -0.5),
            radius: 1.2,
            colors: [Color(0xFF1B2440), kBrandNight],
          ).createShader(Offset.zero & Size.square(s)),
      );
    }

    if (markScale != 1) {
      canvas
        ..translate(s / 2, s / 2)
        ..scale(markScale)
        ..translate(-s / 2, -s / 2);
    }

    final gradient = const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [kBrandCyan, kBrandViolet],
    ).createShader(Offset.zero & Size.square(s));

    final stroke = Paint()
      ..shader = gradient
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.055
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Die body.
    final body = RRect.fromLTRBR(
      s * 0.24,
      s * 0.24,
      s * 0.76,
      s * 0.76,
      Radius.circular(s * 0.1),
    );
    canvas.drawRRect(body, stroke);

    // Pins: three per side.
    final pin = Paint()
      ..shader = gradient
      ..strokeWidth = s * 0.045
      ..strokeCap = StrokeCap.round;
    for (final t in const [0.38, 0.5, 0.62]) {
      final p = s * t;
      canvas
        ..drawLine(Offset(p, s * 0.1), Offset(p, s * 0.17), pin)
        ..drawLine(Offset(p, s * 0.83), Offset(p, s * 0.9), pin)
        ..drawLine(Offset(s * 0.1, p), Offset(s * 0.17, p), pin)
        ..drawLine(Offset(s * 0.83, p), Offset(s * 0.9, p), pin);
    }

    // Check mark: the honest verdict.
    final check = Path()
      ..moveTo(s * 0.37, s * 0.51)
      ..lineTo(s * 0.46, s * 0.6)
      ..lineTo(s * 0.64, s * 0.4);
    canvas.drawPath(
      check,
      Paint()
        ..shader = gradient
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.075
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // Small glow dot on the die corner (status LED).
    canvas.drawCircle(
      Offset(s * 0.67, s * 0.67),
      s * 0.03,
      Paint()
        ..color = kBrandCyan
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.01),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(TrueRigMarkPainter old) =>
      old.withBackground != withBackground;
}

/// "TrueRig" wordmark: "True" in the text colour, "Rig" in the brand
/// gradient.
class TrueRigWordmark extends StatelessWidget {
  const TrueRigWordmark({super.key, this.fontSize = 20});

  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final style = GoogleFonts.inter(
      fontSize: fontSize,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.3,
      color: Theme.of(context).colorScheme.onSurface,
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('True', style: style),
        ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (r) =>
              const LinearGradient(colors: [kBrandCyan, kBrandViolet])
                  .createShader(r),
          child: Text('Rig', style: style),
        ),
      ],
    );
  }
}

/// App-bar title: logo + "TrueRig", with the page name underneath.
class BrandTitle extends StatelessWidget {
  const BrandTitle(this.page, {super.key});

  final String page;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Semantics(
      header: true,
      label: '$kAppName, $page',
      child: ExcludeSemantics(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TrueRigMark(size: 22),
                SizedBox(width: 6),
                TrueRigWordmark(fontSize: 18),
              ],
            ),
            Text(
              page,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium
                  ?.copyWith(color: muted, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
