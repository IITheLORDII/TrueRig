import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:perf_engine/perf_engine.dart';

import 'package:darbogaz/core/widgets/app_controls.dart';
import 'package:darbogaz/features/device/device_page.dart';
import 'package:darbogaz/features/builder/part_picker_page.dart';
import 'package:darbogaz/features/builder/prebuilt_picker_page.dart';
import 'package:darbogaz/features/compare/compare_page.dart';
import 'package:darbogaz/features/detect/detect_page.dart';
import 'package:darbogaz/features/performance/performance_page.dart';
import 'package:darbogaz/features/phone/phone_picker_page.dart';
import 'package:darbogaz/features/prices/prices_page.dart';
import 'package:darbogaz/features/prices/scanner_page.dart';
import 'package:darbogaz/features/profile/profile_page.dart';
import 'package:darbogaz/features/splash/splash_page.dart';
import 'package:darbogaz/features/watch/watch_pages.dart';

final _rootKey = GlobalKey<NavigatorState>();

GoRouter createRouter() => GoRouter(
  navigatorKey: _rootKey,
  // The website opens on hardware detection; the apps open on "Cihaz".
  initialLocation: '/splash',
  routes: [
    GoRoute(
      path: '/splash',
      builder: (_, _) => SplashPage(next: kIsWeb ? '/detect' : '/device'),
    ),
    GoRoute(
      path: '/detect',
      builder: (_, state) =>
          DetectPage(initialCode: state.uri.queryParameters['hw']),
    ),
    GoRoute(path: '/compare', builder: (_, _) => const ComparePage()),
    // v1 addresses (bookmarks, shared links).
    GoRoute(path: '/build', redirect: (_, _) => '/device'),
    GoRoute(path: '/analysis', redirect: (_, _) => '/performance'),
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => _Shell(shell: shell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/device',
              builder: (_, _) => const DevicePage(),
              routes: [
                GoRoute(
                  path: 'pick/:category',
                  parentNavigatorKey: _rootKey,
                  redirect: (_, state) =>
                      _categoryFrom(state) == null ? '/device' : null,
                  builder: (_, state) => PartPickerPage(
                    category: _categoryFrom(state)!,
                    returnMode: state.uri.queryParameters['mode'] == 'return',
                  ),
                ),
                GoRoute(
                  path: 'phone',
                  parentNavigatorKey: _rootKey,
                  builder: (_, state) =>
                      PhonePickerPage(mode: state.uri.queryParameters['mode']),
                ),
                GoRoute(
                  path: 'watch',
                  parentNavigatorKey: _rootKey,
                  builder: (_, state) => WatchPickerPage(
                    returnMode: state.uri.queryParameters['mode'] == 'return',
                  ),
                ),
                GoRoute(
                  path: 'prebuilt',
                  parentNavigatorKey: _rootKey,
                  builder: (_, state) => PrebuiltPickerPage(
                    returnMode: state.uri.queryParameters['mode'] == 'return',
                  ),
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/performance',
              builder: (_, _) => const PerformancePage(),
            ),
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
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/profile', builder: (_, _) => const ProfilePage()),
          ],
        ),
      ],
    ),
  ],
);

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
    AppTab('Cihaz', Icons.devices_outlined, Icons.devices_rounded),
    AppTab('Performans', Icons.speed_outlined, Icons.speed_rounded),
    AppTab('Fiyat', Icons.sell_outlined, Icons.sell_rounded),
    AppTab('Profil', Icons.person_outline_rounded, Icons.person_rounded),
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
