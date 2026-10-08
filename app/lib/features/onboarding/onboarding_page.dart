import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:darbogaz/core/brand/truerig_logo.dart';
import 'package:darbogaz/core/devices.dart';
import 'package:darbogaz/core/theme/app_theme.dart';
import 'package:darbogaz/core/theme/tokens.dart';
import 'package:darbogaz/core/widgets/buttons.dart';
import 'package:darbogaz/core/widgets/cards.dart';
import 'package:darbogaz/core/widgets/score_scale.dart';
import 'package:darbogaz/features/device/device_page.dart';

const _doneKey = 'onboarding.done';

/// True once the welcome tour was finished or skipped.
bool onboardingDone(WidgetRef ref) =>
    ref.read(prefsProvider)?.getBool(_doneKey) ?? false;

/// Device kind chosen on the last tour page; Ana Sayfa opens its "add"
/// sheet once and clears it.
final pendingAddProvider = NotifierProvider<PendingAdd, DeviceKind?>(
  PendingAdd.new,
);

class PendingAdd extends Notifier<DeviceKind?> {
  @override
  DeviceKind? build() => null;

  void set(DeviceKind? kind) => state = kind;
}

/// Where the app goes after the splash / tour.
/// The website asks about detection in a small popup on Ana Sayfa.
String homeRoute() => '/home';

/// Three-page welcome tour; "Atla" is always available.
class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  final _pages = PageController();
  int _index = 0;

  static const _count = 3;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _finish({DeviceKind? add}) {
    ref.read(prefsProvider)?.setBool(_doneKey, true);
    if (add != null) ref.read(pendingAddProvider.notifier).set(add);
    context.go(add != null ? '/home' : homeRoute());
  }

  void _next() {
    _pages.nextPage(duration: Motion.normal, curve: Curves.easeOutCubic);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Space.page,
                Space.s,
                Space.s,
                0,
              ),
              child: Row(
                children: [
                  const BrandTitle('Hoş geldin'),
                  const Spacer(),
                  TertiaryButton(label: 'Atla', onPressed: _finish),
                ],
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pages,
                onPageChanged: (i) => setState(() => _index = i),
                children: [
                  const _TourPage(
                    icon: Icons.verified_rounded,
                    title: 'TrueRig ne yapar?',
                    lines: [
                      'Cihazın oyunları kaldırır mı, söyler.',
                      'İki cihazı karşılaştırır.',
                      'En ucuz fiyatı bulur.',
                    ],
                  ),
                  _TourPage(
                    icon: Icons.speed_rounded,
                    title: 'Darboğaz nedir?',
                    lines: const [
                      'Bir parça, diğerini yavaşlatır.',
                      'Yeşil iyi, sarı orta, kırmızı kötü.',
                    ],
                    extra: Padding(
                      padding: const EdgeInsets.only(top: Space.m),
                      child: ScoreScale.bottleneck(context, 8),
                    ),
                  ),
                  _ChooseDevice(onChoose: (k) => _finish(add: k)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(Space.page),
              child: Row(
                children: [
                  for (var i = 0; i < _count; i++)
                    AnimatedContainer(
                      duration: Motion.fast,
                      margin: const EdgeInsets.only(right: Space.xs),
                      width: i == _index ? 22 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: i == _index
                            ? theme.colorScheme.primary
                            : context.palette.surfaceAlt,
                        borderRadius: BorderRadius.circular(Radii.pill),
                      ),
                    ),
                  const Spacer(),
                  if (_index < _count - 1)
                    PrimaryButton(
                      label: 'Devam',
                      expand: false,
                      onPressed: _next,
                    )
                  else
                    TertiaryButton(label: 'Şimdilik geç', onPressed: _finish),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TourPage extends StatelessWidget {
  const _TourPage({
    required this.icon,
    required this.title,
    required this.lines,
    this.extra,
  });

  final IconData icon;
  final String title;
  final List<String> lines;
  final Widget? extra;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(Space.xl),
      children: [
        Icon(icon, size: 64, color: theme.colorScheme.primary),
        const SizedBox(height: Space.l),
        Text(
          title,
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall,
        ),
        const SizedBox(height: Space.l),
        // One short sentence per line, easy to scan.
        for (final l in lines)
          Padding(
            padding: const EdgeInsets.only(bottom: Space.m),
            child: Row(
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  size: 22,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: Space.m),
                Expanded(child: Text(l, style: theme.textTheme.titleMedium)),
              ],
            ),
          ),
        ?extra,
      ],
    );
  }
}

class _ChooseDevice extends StatelessWidget {
  const _ChooseDevice({required this.onChoose});

  final ValueChanged<DeviceKind> onChoose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(Space.xl),
      children: [
        Icon(Icons.devices_rounded, size: 64, color: theme.colorScheme.primary),
        const SizedBox(height: Space.l),
        Text(
          'Neyin var?',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall,
        ),
        const SizedBox(height: Space.s),
        Text(
          'Birini seç, ekleyelim.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge,
        ),
        const SizedBox(height: Space.l),
        for (final k in DeviceKind.values)
          Padding(
            padding: const EdgeInsets.only(bottom: Space.s),
            child: NavCard(
              icon: switch (k) {
                DeviceKind.pc => Icons.computer_rounded,
                DeviceKind.phone => Icons.smartphone_rounded,
                DeviceKind.watch => Icons.watch_rounded,
              },
              title: k.mine,
              onTap: () => onChoose(k),
            ),
          ),
      ],
    );
  }
}
