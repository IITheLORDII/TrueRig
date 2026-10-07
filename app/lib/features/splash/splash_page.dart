import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:darbogaz/core/brand/truerig_logo.dart';

/// Branded launch screen: the mark scales in, the name and tagline fade in,
/// then the app continues to [next]. Driven by one animation (no timers) so
/// it also completes deterministically in tests.
class SplashPage extends StatefulWidget {
  const SplashPage({super.key, required this.next});

  final String next;

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..forward();

  late final Animation<double> _mark = CurvedAnimation(
    parent: _c,
    curve: const Interval(0, 0.45, curve: Curves.easeOutBack),
  );
  late final Animation<double> _text = CurvedAnimation(
    parent: _c,
    curve: const Interval(0.35, 0.7, curve: Curves.easeOut),
  );

  @override
  void initState() {
    super.initState();
    _c.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        context.go(widget.next);
      }
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Scaffold(
      backgroundColor: kBrandNight,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ScaleTransition(scale: _mark, child: const TrueRigMark(size: 120)),
            const SizedBox(height: 20),
            FadeTransition(
              opacity: _text,
              child: Column(
                children: [
                  const TrueRigWordmark(fontSize: 34),
                  const SizedBox(height: 6),
                  Text(kAppTagline, style: TextStyle(color: muted)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
