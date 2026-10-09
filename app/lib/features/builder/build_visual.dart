import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:perf_engine/perf_engine.dart';

import 'package:darbogaz/core/brand/truerig_logo.dart';
import 'package:darbogaz/core/theme/app_theme.dart';
import 'package:darbogaz/core/theme/tokens.dart';
import 'package:darbogaz/core/widgets/part_labels.dart';

/// Picture of the user's computer at the top of "Bilgisayarım": each chosen
/// part drops into a desktop case, or a laptop opens with the TrueRig mark
/// on its screen. Missing parts show as dashed empty slots.
class BuildVisual extends StatefulWidget {
  const BuildVisual({
    super.key,
    required this.build,
    required this.isLaptop,
    this.systemName,
  });

  final PcBuild build;
  final bool isLaptop;

  /// Ready-made system name, shown under a laptop.
  final String? systemName;

  @override
  State<BuildVisual> createState() => _BuildVisualState();
}

/// Order parts settle in when several arrive at once (ready-made system).
const _order = [
  PartCategory.pcCase,
  PartCategory.motherboard,
  PartCategory.cpu,
  PartCategory.cooler,
  PartCategory.ram,
  PartCategory.gpu,
  PartCategory.psu,
];

/// The four parts every desktop needs.
const _core = [
  PartCategory.cpu,
  PartCategory.gpu,
  PartCategory.motherboard,
  PartCategory.ram,
];

const _stagger = Duration(milliseconds: 120);

String _name(PartCategory c) => switch (c) {
  PartCategory.cpu => 'işlemci',
  PartCategory.gpu => 'ekran kartı',
  PartCategory.motherboard => 'anakart',
  PartCategory.ram => 'RAM',
  PartCategory.psu => 'güç kaynağı',
  PartCategory.pcCase => 'kasa',
  PartCategory.cooler => 'soğutucu',
};

class _BuildVisualState extends State<BuildVisual> {
  /// Delay before each newly added part starts to fall.
  Map<PartCategory, Duration> _delays = const {};

  @override
  void initState() {
    super.initState();
    _delays = _stagger0(_order.where((c) => widget.build.partFor(c) != null));
  }

  @override
  void didUpdateWidget(BuildVisual old) {
    super.didUpdateWidget(old);
    final added = _order.where(
      (c) =>
          widget.build.partFor(c) != null &&
          widget.build.partFor(c)?.id != old.build.partFor(c)?.id,
    );
    _delays = _stagger0(added);
  }

  static Map<PartCategory, Duration> _stagger0(Iterable<PartCategory> cats) {
    var i = 0;
    return {for (final c in cats) c: _stagger * i++};
  }

  String _semantics() {
    final b = widget.build;
    if (widget.isLaptop) {
      final has = [
        if (b.cpu != null) b.cpu!.model,
        if (b.gpu != null) b.gpu!.model,
      ];
      return 'Dizüstü bilgisayar'
          '${has.isEmpty ? '' : ': ${has.join(', ')}'}';
    }
    final present = [
      for (final c in _order)
        if (b.partFor(c) != null) _name(c),
    ];
    final missing = [
      for (final c in _core)
        if (b.partFor(c) == null) _name(c),
    ];
    if (present.isEmpty) return 'Masaüstü kasa: henüz parça yok';
    return 'Masaüstü kasa: ${present.join(', ')} takılı'
        '${missing.isEmpty ? '' : '; ${missing.join(', ')} eksik'}';
  }

  String _caption() {
    final b = widget.build;
    if (widget.isLaptop) return widget.systemName ?? 'Dizüstü bilgisayar';
    final done = _core.where((c) => b.partFor(c) != null).length;
    if (done == 0) return 'Parça seçtikçe kasana yerleşecek';
    if (done == _core.length) return 'Ana parçalar tamam';
    return '${_core.length} ana parçadan $done tanesi takılı';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      container: true,
      label: _semantics(),
      excludeSemantics: true,
      child: Column(
        children: [
          SizedBox(
            height: 170,
            child: AnimatedSwitcher(
              duration: _motion(context, Motion.normal),
              child: widget.isLaptop
                  ? _Laptop(key: const ValueKey('laptop'), pc: widget.build)
                  : _Desktop(
                      key: const ValueKey('desktop'),
                      pc: widget.build,
                      delays: _delays,
                    ),
            ),
          ),
          const SizedBox(height: Space.s),
          Text(
            _caption(),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelMedium?.copyWith(
              color: context.palette.muted,
            ),
          ),
        ],
      ),
    );
  }
}

/// No movement when the system asks for reduced motion.
Duration _motion(BuildContext context, Duration d) =>
    MediaQuery.maybeDisableAnimationsOf(context) ?? false ? Duration.zero : d;

// ------------------------------------------------------------ desktop --

/// Where each part sits inside the case (fractions of the case box).
const _slots = <PartCategory, Rect>{
  PartCategory.motherboard: Rect.fromLTWH(0.07, 0.08, 0.60, 0.60),
  PartCategory.cpu: Rect.fromLTWH(0.26, 0.18, 0.16, 0.18),
  PartCategory.cooler: Rect.fromLTWH(0.24, 0.15, 0.20, 0.24),
  PartCategory.ram: Rect.fromLTWH(0.48, 0.13, 0.12, 0.30),
  PartCategory.gpu: Rect.fromLTWH(0.07, 0.50, 0.70, 0.13),
  PartCategory.psu: Rect.fromLTWH(0.07, 0.76, 0.52, 0.16),
};

class _Desktop extends StatelessWidget {
  const _Desktop({super.key, required this.pc, required this.delays});

  final PcBuild pc;
  final Map<PartCategory, Duration> delays;

  @override
  Widget build(BuildContext context) {
    final hasCase = pc.pcCase != null;
    return Center(
      child: AspectRatio(
        aspectRatio: 1.25,
        child: LayoutBuilder(
          builder: (context, box) {
            final size = box.biggest;
            Rect place(Rect f) => Rect.fromLTWH(
              f.left * size.width,
              f.top * size.height,
              f.width * size.width,
              f.height * size.height,
            );
            return Stack(
              children: [
                Positioned.fill(
                  child: _Glow(
                    on: hasCase,
                    delay: delays[PartCategory.pcCase] ?? Duration.zero,
                    child: CustomPaint(
                      painter: _CasePainter(
                        body: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHigh,
                        glass: Color.alphaBlend(
                          Theme.of(context).colorScheme.primary
                              .withValues(alpha: 0.06),
                          context.palette.surfaceAlt,
                        ),
                        edge: context.palette.outline,
                        branded: hasCase,
                      ),
                    ),
                  ),
                ),
                for (final c in [
                  PartCategory.motherboard,
                  PartCategory.psu,
                  PartCategory.gpu,
                  PartCategory.ram,
                  PartCategory.cpu,
                  PartCategory.cooler,
                ])
                  Positioned.fromRect(
                    rect: place(_slots[c]!),
                    child: AnimatedSwitcher(
                      duration: _motion(context, Motion.fast),
                      // Fill the slot (the default layout would shrink
                      // empty outlines and RAM sticks to nothing).
                      layoutBuilder: (current, previous) => Stack(
                        fit: StackFit.expand,
                        children: [...previous, ?current],
                      ),
                      child: switch (pc.partFor(c)) {
                        final Part p => _Drop(
                          key: ValueKey('${c.name}-${p.id}'),
                          delay: delays[c] ?? Duration.zero,
                          child: _PartPiece(category: c),
                        ),
                        // The cooler is optional and sits over the CPU.
                        null when c == PartCategory.cooler =>
                          const SizedBox.shrink(),
                        null => _Ghost(key: ValueKey('ghost-${c.name}')),
                      },
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Falls from above and settles with a small bounce.
class _Drop extends StatelessWidget {
  const _Drop({super.key, required this.delay, required this.child});

  final Duration delay;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final fall = _motion(context, Motion.slow);
    final total = fall == Duration.zero ? Duration.zero : fall + delay;
    final start = total == Duration.zero
        ? 0.0
        : delay.inMilliseconds / total.inMilliseconds;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: total,
      curve: Interval(start, 1),
      builder: (context, t, child) {
        final y = Curves.easeOutBack.transform(t);
        return Opacity(
          opacity: Curves.easeOut.transform(t).clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, (1 - y) * -70),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

/// Brief brand glow when [on] turns true (the case being chosen).
class _Glow extends StatelessWidget {
  const _Glow({required this.on, required this.delay, required this.child});

  final bool on;
  final Duration delay;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!on) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: _motion(context, Motion.slow),
      builder: (context, t, child) => DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Radii.l),
          boxShadow: [
            BoxShadow(
              color: kBrandCyan.withValues(alpha: 0.35 * math.sin(math.pi * t)),
              blurRadius: 24,
            ),
          ],
        ),
        child: child,
      ),
      child: child,
    );
  }
}

/// One part as a coloured block with its icon.
class _PartPiece extends StatelessWidget {
  const _PartPiece({required this.category});

  final PartCategory category;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final scheme = Theme.of(context).colorScheme;
    final (Color a, Color b) = switch (category) {
      PartCategory.motherboard => (
        const Color(0xFF0E4B4F),
        const Color(0xFF12343F),
      ),
      PartCategory.cpu => (scheme.primary, kBrandCyan),
      PartCategory.cooler => (p.accentAlt, kBrandViolet),
      PartCategory.ram => (p.good, const Color(0xFF14915F)),
      PartCategory.gpu => (kBrandViolet, p.accentAlt),
      PartCategory.psu => (const Color(0xFF3A4256), const Color(0xFF262C3B)),
      PartCategory.pcCase => (p.muted, p.muted),
    };
    if (category == PartCategory.ram) return _RamSticks(a: a, b: b);
    if (category == PartCategory.cooler) return _Fan(color: a);
    return LayoutBuilder(
      builder: (context, box) => DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [a, b]),
          borderRadius: BorderRadius.circular(Radii.s - 2),
          boxShadow: [
            BoxShadow(color: a.withValues(alpha: 0.35), blurRadius: 8),
          ],
        ),
        child: Center(
          child: Icon(
            category.icon,
            size: (box.biggest.shortestSide * 0.6).clamp(10, 28),
            color: Colors.white.withValues(alpha: 0.9),
          ),
        ),
      ),
    );
  }
}

class _RamSticks extends StatelessWidget {
  const _RamSticks({required this.a, required this.b});

  final Color a;
  final Color b;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (var i = 0; i < 2; i++) ...[
        if (i > 0) const SizedBox(width: 3),
        Expanded(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [a, b],
              ),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ],
    ],
  );
}

/// CPU cooler fan: spins once as it lands.
class _Fan extends StatelessWidget {
  const _Fan({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: _motion(context, const Duration(milliseconds: 1200)),
    curve: Curves.easeOutCubic,
    builder: (context, t, child) =>
        Transform.rotate(angle: t * 4 * math.pi, child: child),
    child: DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.25),
        border: Border.all(color: color, width: 2),
      ),
      child: Center(
        child: LayoutBuilder(
          builder: (context, box) => Icon(
            Icons.toys_rounded,
            size: box.biggest.shortestSide * 0.7,
            color: color,
          ),
        ),
      ),
    ),
  );
}

/// Empty slot: dashed outline.
class _Ghost extends StatelessWidget {
  const _Ghost({super.key});

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _DashedRectPainter(
      color: context.palette.muted.withValues(alpha: 0.55),
    ),
  );
}

class _DashedRectPainter extends CustomPainter {
  const _DashedRectPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          const Radius.circular(Radii.s - 2),
        ),
      );
    for (final metric in path.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += 8) {
        canvas.drawPath(metric.extractPath(d, d + 4), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedRectPainter old) => old.color != color;
}

/// Tower case seen from the glass side, with a front strip and power dot.
class _CasePainter extends CustomPainter {
  const _CasePainter({
    required this.body,
    required this.glass,
    required this.edge,
    required this.branded,
  });

  final Color body;
  final Color glass;
  final Color edge;
  final bool branded;

  @override
  void paint(Canvas canvas, Size size) {
    final outer = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(Radii.l),
    );
    canvas.drawRRect(outer, Paint()..color = body);
    // Glass side panel.
    final glassRect = Rect.fromLTWH(
      size.width * 0.03,
      size.height * 0.04,
      size.width * 0.78,
      size.height * 0.92,
    );
    final glassShape = RRect.fromRectAndRadius(
      glassRect,
      const Radius.circular(Radii.s),
    );
    canvas.drawRRect(glassShape, Paint()..color = glass);
    // Light sheen across the glass.
    canvas.drawRRect(
      glassShape,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.07),
            Colors.white.withValues(alpha: 0),
          ],
          stops: const [0, 0.45],
        ).createShader(glassRect),
    );
    canvas.drawRRect(
      glassShape,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = edge,
    );
    // Front strip and power button.
    final front = Rect.fromLTWH(
      size.width * 0.85,
      size.height * 0.06,
      size.width * 0.11,
      size.height * 0.88,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(front, const Radius.circular(Radii.s)),
      Paint()..color = glass,
    );
    canvas.drawCircle(
      Offset(front.center.dx, front.top + front.width * 0.7),
      front.width * 0.18,
      Paint()..color = branded ? kBrandCyan : edge,
    );
    // Outline: brand gradient once a case is chosen.
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = branded ? 2 : 1;
    if (branded) {
      stroke.shader = kBrandGradient.createShader(Offset.zero & size);
    } else {
      stroke.color = edge;
    }
    canvas.drawRRect(outer.deflate(0.5), stroke);
  }

  @override
  bool shouldRepaint(_CasePainter old) =>
      old.body != body ||
      old.glass != glass ||
      old.edge != edge ||
      old.branded != branded;
}

// ------------------------------------------------------------- laptop --

/// A laptop slides up and its lid opens on the TrueRig mark.
class _Laptop extends StatelessWidget {
  const _Laptop({super.key, required this.pc});

  final PcBuild pc;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final palette = context.palette;
    final specs = [
      if (pc.cpu != null) pc.cpu!.model,
      if (pc.gpu != null) pc.gpu!.model,
    ].join(' · ');
    return Center(
      child: SizedBox(
        width: 260,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: _motion(context, const Duration(milliseconds: 1100)),
          builder: (context, t, _) {
            final rise = Curves.easeOutCubic.transform(
              const Interval(0, 0.4).transform(t),
            );
            final open = Curves.easeOutBack.transform(
              const Interval(0.3, 1).transform(t),
            );
            final glow = Curves.easeIn.transform(
              const Interval(0.7, 1).transform(t),
            );
            return Opacity(
              opacity: rise,
              child: Transform.translate(
                offset: Offset(0, (1 - rise) * 40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Transform(
                      alignment: Alignment.bottomCenter,
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, 0.002)
                        ..rotateX((1 - open) * -math.pi / 2),
                      child: _Screen(glow: glow, specs: specs),
                    ),
                    // Base with keyboard deck.
                    Container(
                      height: 14,
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHigh,
                        borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(Radii.m),
                        ),
                        border: Border.all(color: palette.outline),
                      ),
                      child: Center(
                        child: Container(
                          width: 46,
                          height: 4,
                          decoration: BoxDecoration(
                            color: palette.surfaceAlt,
                            borderRadius: BorderRadius.circular(Radii.pill),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Screen extends StatelessWidget {
  const _Screen({required this.glow, required this.specs});

  final double glow;
  final String specs;

  @override
  Widget build(BuildContext context) => Container(
    height: 140,
    margin: const EdgeInsets.symmetric(horizontal: 18),
    padding: const EdgeInsets.all(6),
    decoration: BoxDecoration(
      color: const Color(0xFF1C2232),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(Radii.m)),
    ),
    child: Container(
      decoration: BoxDecoration(
        color: kBrandNight,
        borderRadius: BorderRadius.circular(Radii.s - 2),
        boxShadow: [
          BoxShadow(
            color: kBrandCyan.withValues(alpha: 0.25 * glow),
            blurRadius: 18,
          ),
        ],
      ),
      child: Opacity(
        opacity: glow,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const TrueRigMark(size: 40),
            const SizedBox(height: Space.xs),
            const TrueRigWordmark(fontSize: 14),
            if (specs.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Space.s,
                  Space.xs,
                  Space.s,
                  0,
                ),
                child: Text(
                  specs,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFFB8C0D4),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
