import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:perf_engine/perf_engine.dart';

import 'package:darbogaz/core/brand/truerig_logo.dart';
import 'package:darbogaz/core/theme/app_theme.dart';
import 'package:darbogaz/core/theme/tokens.dart';
import 'package:darbogaz/features/builder/pc_case_painter.dart';
import 'package:darbogaz/features/builder/pc_case_shape.dart';

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

/// Parts listed in the screen reader sentence, in this order.
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
    final problems = _fitProblems();
    final tail = [
      ...problems,
      if (b.pcCase case final c?) caseFansText(c),
    ].map((t) => '. $t').join();
    if (present.isEmpty) return 'Masaüstü kasa: henüz parça yok$tail';
    return 'Masaüstü kasa: ${present.join(', ')} takılı'
        '${missing.isEmpty ? '' : '; ${missing.join(', ')} eksik'}$tail';
  }

  /// Parts too big for the chosen case, in plain words.
  List<String> _fitProblems() {
    final b = widget.build;
    final c = b.pcCase;
    if (c == null || widget.isLaptop) return const [];
    final shape = BuildShape.of(b);
    return [
      if (shape.gpuTooLong)
        'Ekran kartı bu kasaya sığmıyor: kart ${b.gpu!.lengthMm} mm, '
            'kasa en fazla ${c.maxGpuLengthMm} mm alıyor',
      if (shape.coolerTooTall)
        'Soğutucu bu kasaya sığmıyor: soğutucu ${b.cooler!.heightMm} mm, '
            'kasa en fazla ${c.maxCoolerHeightMm} mm alıyor',
    ];
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
            height: 240,
            child: AnimatedSwitcher(
              duration: _motion(context, Motion.normal),
              child: widget.isLaptop
                  ? _Laptop(key: const ValueKey('laptop'), pc: widget.build)
                  : _Desktop(key: const ValueKey('desktop'), pc: widget.build),
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
          for (final problem in _fitProblems())
            Padding(
              padding: const EdgeInsets.only(top: Space.xs),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 16,
                    color: context.palette.bad,
                  ),
                  const SizedBox(width: Space.xs),
                  Flexible(
                    child: Text(
                      problem,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: context.palette.bad,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (!widget.isLaptop && widget.build.pcCase != null)
            Padding(
              padding: const EdgeInsets.only(top: Space.xs),
              child: Text(
                [
                  if (caseSizeText(widget.build.pcCase!) case final size?)
                    '${widget.build.pcCase!.model}: $size',
                  caseFansText(widget.build.pcCase!),
                ].join('\n'),
                textAlign: TextAlign.center,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: context.palette.muted,
                ),
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

/// Parts drawn inside the case (the case itself only changes the shell).
const _inside = [
  PartCategory.motherboard,
  PartCategory.cpu,
  PartCategory.cooler,
  PartCategory.ram,
  PartCategory.gpu,
  PartCategory.psu,
];

/// Tower seen from the front-left; each newly chosen part moves into its
/// place (graphics card and power supply slide in through the glass side,
/// RAM drops into its slots). Parts arriving together go one after another.
class _Desktop extends StatefulWidget {
  const _Desktop({super.key, required this.pc});

  final PcBuild pc;

  @override
  State<_Desktop> createState() => _DesktopState();
}

class _DesktopState extends State<_Desktop> with TickerProviderStateMixin {
  static const _fall = Duration(milliseconds: 700);

  final _moves = <PartCategory, AnimationController>{};

  /// Share of each controller spent waiting (staggered arrivals).
  final _waits = <PartCategory, double>{};

  /// 0..1 while a newly chosen case lights up and gets its fans.
  late final AnimationController _caseIn = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  bool get _still => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  @override
  void initState() {
    super.initState();
    for (final c in _inside) {
      _moves[c] = AnimationController(vsync: this, duration: _fall);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _arrive(_inside.where((c) => widget.pc.partFor(c) != null));
      if (widget.pc.pcCase != null) _fitCase();
    });
  }

  @override
  void didUpdateWidget(_Desktop old) {
    super.didUpdateWidget(old);
    final added = <PartCategory>[];
    for (final c in _inside) {
      final now = widget.pc.partFor(c);
      final before = old.pc.partFor(c);
      if (now == null && before != null) {
        _still ? _moves[c]!.value = 0 : _moves[c]!.reverse();
      } else if (now != null && now.id != before?.id) {
        added.add(c);
      }
    }
    _arrive(added);
    if (widget.pc.pcCase != null && widget.pc.pcCase?.id != old.pc.pcCase?.id) {
      _fitCase();
    }
  }

  void _fitCase() => _still ? _caseIn.value = 1 : _caseIn.forward(from: 0);

  void _arrive(Iterable<PartCategory> cats) {
    var i = 0;
    for (final c in cats) {
      final ctl = _moves[c]!;
      if (_still) {
        ctl.value = 1;
        continue;
      }
      final wait = Duration(milliseconds: 140 * i++);
      ctl.duration = _fall + wait;
      _waits[c] = wait.inMilliseconds / ctl.duration!.inMilliseconds;
      ctl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    for (final c in _moves.values) {
      c.dispose();
    }
    _caseIn.dispose();
    super.dispose();
  }

  double _progress(PartCategory c) {
    final v = _moves[c]!.value;
    final wait = _waits[c] ?? 0;
    if (wait <= 0 || _moves[c]!.status == AnimationStatus.reverse) return v;
    return ((v - wait) / (1 - wait)).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = context.palette;
    final colors = CaseColors(
      body: theme.colorScheme.surfaceContainerHigh,
      interior: Color.alphaBlend(
        theme.colorScheme.primary.withValues(alpha: 0.05),
        p.surfaceAlt,
      ),
      glass: theme.colorScheme.primary.withValues(alpha: 0.05),
      edge: p.muted.withValues(alpha: 0.6),
      ghost: p.muted.withValues(alpha: 0.7),
      bad: p.bad,
    );
    return SizedBox.expand(
      child: CustomPaint(
        painter: PcCasePainter(
          repaint: Listenable.merge([..._moves.values, _caseIn]),
          shape: BuildShape.of(widget.pc),
          progressOf: _progress,
          present: {
            for (final c in _inside)
              if (widget.pc.partFor(c) != null) c,
          },
          colors: colors,
          caseInOf: () => _caseIn.value,
        ),
      ),
    );
  }
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
