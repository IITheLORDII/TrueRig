import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:darbogaz/core/brand/truerig_logo.dart';
import 'package:darbogaz/core/providers.dart';
import 'package:darbogaz/core/saved_devices.dart';
import 'package:darbogaz/core/widgets/app_controls.dart';
import 'package:darbogaz/core/router/app_router.dart';
import 'package:darbogaz/core/theme/app_theme.dart';

class DarbogazApp extends ConsumerStatefulWidget {
  const DarbogazApp({super.key});

  @override
  ConsumerState<DarbogazApp> createState() => _DarbogazAppState();
}

class _DarbogazAppState extends ConsumerState<DarbogazApp> {
  late final GoRouter _router = createRouter();

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Keeps the saved-device list in sync with the active devices.
    ref.watch(savedDevicesProvider);
    return _app();
  }

  Widget _app() => MaterialApp.router(
    title: kAppName,
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light(),
    darkTheme: AppTheme.dark(),
    scrollBehavior: const AppScrollBehavior(),
    themeMode: ref.watch(themeModeProvider),
    routerConfig: _router,
    locale: const Locale('tr'),
    supportedLocales: const [Locale('tr'), Locale('en')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    builder: (context, child) => _CenteredFrame(child: child),
  );
}

/// On wide browser windows the website is shown as a phone-sized app so it
/// looks and behaves like the store apps. Phones are unaffected.
const double _phoneWidth = 430;
const double _phoneMaxHeight = 932;
const double _framedFromWidth = 600;

class _CenteredFrame extends StatelessWidget {
  const _CenteredFrame({required this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final app = child ?? const SizedBox.shrink();
    final size = MediaQuery.sizeOf(context);
    // Website only: tablets (iPad / Android) use the full screen.
    if (!kIsWeb || size.width < _framedFromWidth) return app;
    final scheme = Theme.of(context).colorScheme;
    final height = (size.height - 48).clamp(480.0, _phoneMaxHeight);
    return ColoredBox(
      color: scheme.surfaceContainerLowest,
      child: Center(
        child: Container(
          width: _phoneWidth,
          height: height,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(36),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.5),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 40,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          // Report a phone-sized screen to everything inside the frame.
          child: MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(size: Size(_phoneWidth, height)),
            child: app,
          ),
        ),
      ),
    );
  }
}
