import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:perf_engine/perf_engine.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:darbogaz/features/onboarding/onboarding_page.dart';
import 'package:darbogaz/core/devices.dart';
import 'package:darbogaz/core/widgets/app_controls.dart';
import 'package:darbogaz/features/sandbox/sandbox_page.dart';
import 'package:darbogaz/features/device/device_page.dart';
import 'package:darbogaz/features/builder/part_picker_page.dart';
import 'package:darbogaz/features/builder/prebuilt_picker_page.dart';
import 'package:darbogaz/features/compare/compare_page.dart';
import 'package:darbogaz/features/detect/detect_page.dart';
import 'package:darbogaz/features/home/home_page.dart';
import 'package:darbogaz/features/performance/performance_page.dart';
import 'package:darbogaz/features/phone/phone_picker_page.dart';
import 'package:darbogaz/features/prices/prices_page.dart';
import 'package:darbogaz/features/prices/scanner_page.dart';
import 'package:darbogaz/features/profile/profile_page.dart';
import 'package:darbogaz/features/splash/splash_page.dart';
import 'package:darbogaz/features/watch/watch_pages.dart';

final _rootKey = GlobalKey<NavigatorState>();

/// Full-screen routes on the root navigator (over the tab bar).
GoRoute _page(String path, Widget Function(GoRouterState s) build) => GoRoute(
  path: path,
  parentNavigatorKey: _rootKey,
  builder: (_, state) => build(state),
);

bool _returns(GoRouterState s) => s.uri.queryParameters['mode'] == 'return';

GoRouter createRouter() => GoRouter(
  navigatorKey: _rootKey,
  initialLocation: '/splash',
  routes: [
    // Everyone lands on Ana Sayfa; the website asks about detection there.
    // First launch shows the welcome tour; later launches go straight on.
    _page(
      '/splash',
      (_) => Consumer(
        builder: (_, ref, _) =>
            SplashPage(next: onboardingDone(ref) ? homeRoute() : '/welcome'),
      ),
    ),
    _page('/welcome', (_) => const OnboardingPage()),
    _page(
      '/detect',
      (s) => DetectPage(initialCode: s.uri.queryParameters['hw']),
    ),
    _page('/profile', (_) => const ProfilePage()),
    // Old device editor addresses open the matching Cihazlarım section.
    GoRoute(
      path: '/devices/:kind',
      redirect: (_, s) => '/devices?kind=${s.pathParameters['kind']}',
    ),
    GoRoute(
      path: '/pick/part/:category',
      parentNavigatorKey: _rootKey,
      redirect: (_, s) => _categoryFrom(s) == null ? '/home' : null,
      builder: (_, s) =>
          PartPickerPage(category: _categoryFrom(s)!, returnMode: _returns(s)),
    ),
    _page(
      '/pick/phone',
      (s) => PhonePickerPage(mode: s.uri.queryParameters['mode']),
    ),
    _page('/pick/watch', (s) => WatchPickerPage(returnMode: _returns(s))),
    _page('/pick/prebuilt', (s) => PrebuiltPickerPage(returnMode: _returns(s))),
    _page(
      '/sandbox',
      (s) => SandboxPage(
        initialTab: s.uri.queryParameters['tab'],
        startCompare: s.uri.queryParameters['compare'] == '1',
      ),
    ),
    // Older addresses (bookmarks, shared links).
    GoRoute(path: '/build', redirect: (_, _) => '/home'),
    GoRoute(path: '/device', redirect: (_, _) => '/home'),
    GoRoute(path: '/performance', redirect: (_, _) => '/analysis'),
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => _Shell(shell: shell),
      branches: [
        StatefulShellBranch(
          routes: [GoRoute(path: '/home', builder: (_, _) => const HomePage())],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/devices',
              builder: (_, state) => DevicesPage(
                initialKind: _kindNamed(state.uri.queryParameters['kind']),
              ),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/analysis',
              builder: (_, _) => const PerformancePage(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/compare', builder: (_, _) => const ComparePage()),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/prices',
              builder: (_, state) => PricesPage(
                initialQuery: state.uri.queryParameters['q'] ?? '',
              ),
              routes: [
                GoRoute(
                  path: 'scan',
                  parentNavigatorKey: _rootKey,
                  builder: (_, _) => const ScannerPage(),
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  ],
);

DeviceKind? _kindNamed(String? name) {
  for (final k in DeviceKind.values) {
    if (k.name == name) return k;
  }
  return null;
}

/// Validates the path parameter against known categories (deep-link safe).
PartCategory? _categoryFrom(GoRouterState state) {
  final name = state.pathParameters['category'];
  for (final c in PartCategory.values) {
    if (c.name == name) return c;
  }
  return null;
}

class _Shell extends StatelessWidget {
  const _Shell({required this.shell});

  final StatefulNavigationShell shell;

  static const _tabs = [
    AppTab('Ana Sayfa', Icons.home_outlined, Icons.home_rounded),
    AppTab('Cihazlarım', Icons.devices_outlined, Icons.devices_rounded),
    AppTab('Analiz', Icons.insights_outlined, Icons.insights_rounded),
    AppTab(
      'Karşılaştır',
      Icons.compare_arrows_outlined,
      Icons.compare_arrows_rounded,
    ),
    AppTab('Parça Ara', Icons.sell_outlined, Icons.sell_rounded),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
    body: shell,
    bottomNavigationBar: AppBottomBar(
      tabs: _tabs,
      currentIndex: shell.currentIndex,
      onTap: (i) => shell.goBranch(i, initialLocation: i == shell.currentIndex),
    ),
  );
}
