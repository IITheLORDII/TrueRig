import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:darbogaz/core/theme/tokens.dart';

/// Brand colour tokens not covered by [ColorScheme].
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.good,
    required this.warn,
    required this.bad,
    required this.accentAlt,
    required this.surfaceAlt,
    required this.muted,
  });

  final Color good;
  final Color warn;
  final Color bad;
  final Color accentAlt;
  final Color surfaceAlt;
  final Color muted;

  static const dark = AppPalette(
    good: Color(0xFF2EE59D),
    warn: Color(0xFFFFC547),
    bad: Color(0xFFFF4D6A),
    accentAlt: Color(0xFF7C4DFF),
    surfaceAlt: Color(0xFF1B2236),
    muted: Color(0xFF8A93A8),
  );

  static const light = AppPalette(
    good: Color(0xFF0F9D63),
    warn: Color(0xFFB7791F),
    bad: Color(0xFFD7263D),
    accentAlt: Color(0xFF5B2EE0),
    surfaceAlt: Color(0xFFEEF1F7),
    muted: Color(0xFF5D6577),
  );

  /// Green below 10%, amber to 20%, red above.
  Color forBottleneck(double percent) =>
      percent < 10 ? good : (percent < 20 ? warn : bad);

  @override
  AppPalette copyWith({
    Color? good,
    Color? warn,
    Color? bad,
    Color? accentAlt,
    Color? surfaceAlt,
    Color? muted,
  }) => AppPalette(
    good: good ?? this.good,
    warn: warn ?? this.warn,
    bad: bad ?? this.bad,
    accentAlt: accentAlt ?? this.accentAlt,
    surfaceAlt: surfaceAlt ?? this.surfaceAlt,
    muted: muted ?? this.muted,
  );

  @override
  AppPalette lerp(AppPalette? other, double t) {
    if (other == null) return this;
    return AppPalette(
      good: Color.lerp(good, other.good, t)!,
      warn: Color.lerp(warn, other.warn, t)!,
      bad: Color.lerp(bad, other.bad, t)!,
      accentAlt: Color.lerp(accentAlt, other.accentAlt, t)!,
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
    );
  }
}

extension AppPaletteContext on BuildContext {
  AppPalette get palette => Theme.of(this).extension<AppPalette>()!;
}

/// Monospace style for numbers (FPS, %, W).
TextStyle numberStyle(BuildContext context, {double size = 16, Color? color}) =>
    GoogleFonts.jetBrainsMono(
      fontSize: size,
      fontWeight: FontWeight.w700,
      color: color ?? Theme.of(context).colorScheme.onSurface,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

class AppTheme {
  const AppTheme._();

  static const _cyan = Color(0xFF00E5FF);
  static const _darkBg = Color(0xFF0B0F1A);
  static const _darkCard = Color(0xFF141A2A);

  static ThemeData dark() {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: _cyan,
          brightness: Brightness.dark,
        ).copyWith(
          primary: _cyan,
          onPrimary: const Color(0xFF00151A),
          secondary: AppPalette.dark.accentAlt,
          surface: _darkBg,
          surfaceContainer: _darkCard,
          surfaceContainerHigh: AppPalette.dark.surfaceAlt,
        );
    return _base(scheme, AppPalette.dark);
  }

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF0091A8),
      brightness: Brightness.light,
    ).copyWith(secondary: AppPalette.light.accentAlt);
    return _base(scheme, AppPalette.light);
  }

  static ThemeData _base(ColorScheme scheme, AppPalette palette) {
    final isDark = scheme.brightness == Brightness.dark;
    final text = GoogleFonts.interTextTheme(
      ThemeData(brightness: scheme.brightness).textTheme,
    );
    return ThemeData(
      useMaterial3: true,
      // One look on every platform: same page transition (with iOS-style
      // swipe-back) on Android, iOS and web.
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.fuchsia: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
        },
      ),
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      textTheme: text,
      extensions: [palette],
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        // Status bar icons readable on our background on both platforms.
        systemOverlayStyle: isDark
            ? SystemUiOverlayStyle.light.copyWith(
                statusBarColor: Colors.transparent,
                systemNavigationBarColor: scheme.surfaceContainer,
              )
            : SystemUiOverlayStyle.dark.copyWith(
                statusBarColor: Colors.transparent,
                systemNavigationBarColor: scheme.surfaceContainer,
              ),
        titleTextStyle: text.titleLarge?.copyWith(
          fontSize: 22,
          fontWeight: FontWeight.w800,
        ),
      ),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainer,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.l),
          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.3)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surfaceContainer,
        indicatorColor: scheme.primary.withValues(alpha: 0.18),
        labelTextStyle: WidgetStatePropertyAll(
          text.labelSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.s),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(kMinTap, kMinTap),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.m),
          ),
          textStyle: text.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(minimumSize: const Size(kMinTap, kMinTap)),
      ),
      listTileTheme: const ListTileThemeData(
        minVerticalPadding: Space.s,
        horizontalTitleGap: Space.m,
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withValues(alpha: 0.3),
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHigh,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.m),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
