import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:darbogaz/core/brand/truerig_logo.dart';
import 'package:darbogaz/core/theme/tokens.dart';

/// Colour tokens not covered by [ColorScheme]. Status colours (good / warn /
/// bad) are separate from the brand and meet WCAG AA on their surface.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.good,
    required this.warn,
    required this.bad,
    required this.accentAlt,
    required this.surfaceAlt,
    required this.muted,
    required this.outline,
  });

  final Color good;
  final Color warn;
  final Color bad;

  /// Second brand colour (violet): the "other" side in comparisons.
  final Color accentAlt;

  /// Raised surface (inputs, tracks, chips).
  final Color surfaceAlt;

  /// Secondary text.
  final Color muted;

  /// 1 px card / divider line.
  final Color outline;

  static const dark = AppPalette(
    good: Color(0xFF2EE59D),
    warn: Color(0xFFFFC547),
    bad: Color(0xFFFF5C75),
    accentAlt: Color(0xFFA78BFF),
    surfaceAlt: Color(0xFF1A2133),
    muted: Color(0xFF98A1B5),
    outline: Color(0x14FFFFFF),
  );

  static const light = AppPalette(
    good: Color(0xFF0B7A4B),
    warn: Color(0xFF8A5A00),
    bad: Color(0xFFC21F35),
    accentAlt: Color(0xFF5B2EE0),
    surfaceAlt: Color(0xFFEEF1F7),
    muted: Color(0xFF4F5668),
    outline: Color(0x1F0B0F1A),
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
    Color? outline,
  }) => AppPalette(
    good: good ?? this.good,
    warn: warn ?? this.warn,
    bad: bad ?? this.bad,
    accentAlt: accentAlt ?? this.accentAlt,
    surfaceAlt: surfaceAlt ?? this.surfaceAlt,
    muted: muted ?? this.muted,
    outline: outline ?? this.outline,
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
      outline: Color.lerp(outline, other.outline, t)!,
    );
  }
}

extension AppPaletteContext on BuildContext {
  AppPalette get palette => Theme.of(this).extension<AppPalette>()!;
}

/// Brand gradient: only for the hero card frame, the primary button and
/// the active tab.
const LinearGradient kBrandGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [kBrandCyan, kBrandViolet],
);

/// Monospace style for numbers (FPS, %, W, prices): tabular figures so
/// columns line up.
TextStyle numberStyle(BuildContext context, {double size = 16, Color? color}) =>
    GoogleFonts.jetBrainsMono(
      fontSize: size,
      fontWeight: FontWeight.w700,
      color: color ?? Theme.of(context).colorScheme.onSurface,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

class AppTheme {
  const AppTheme._();

  // Dark surfaces stepped by tone instead of shadows.
  static const _darkContainer = Color(0xFF121827);

  static ThemeData dark() {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: kBrandCyan,
          brightness: Brightness.dark,
        ).copyWith(
          primary: kBrandCyan,
          onPrimary: const Color(0xFF00151A),
          secondary: AppPalette.dark.accentAlt,
          surface: kBrandNight,
          surfaceContainer: _darkContainer,
          surfaceContainerHigh: AppPalette.dark.surfaceAlt,
          onSurfaceVariant: AppPalette.dark.muted,
        );
    return _base(scheme, AppPalette.dark);
  }

  static ThemeData light() {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: const Color(0xFF00838F),
          brightness: Brightness.light,
        ).copyWith(
          // Darker teal: cyan text on white is unreadable (1.5:1).
          primary: const Color(0xFF00727D),
          secondary: AppPalette.light.accentAlt,
          surface: const Color(0xFFF7F8FB),
          surfaceContainer: Colors.white,
          surfaceContainerHigh: AppPalette.light.surfaceAlt,
          onSurfaceVariant: AppPalette.light.muted,
        );
    return _base(scheme, AppPalette.light);
  }

  /// Type scale (Material 3, Inter): page 24 · section 20 · card title 16
  /// · body 14 · secondary 13 · label 12. Nothing below 12.
  static TextTheme _text(Brightness b) {
    final base = GoogleFonts.interTextTheme(ThemeData(brightness: b).textTheme);
    TextStyle? w(TextStyle? s, double size, FontWeight weight, double height) =>
        s?.copyWith(fontSize: size, fontWeight: weight, height: height / size);
    return base.copyWith(
      displaySmall: w(base.displaySmall, 36, FontWeight.w800, 44),
      headlineMedium: w(base.headlineMedium, 28, FontWeight.w800, 36),
      headlineSmall: w(base.headlineSmall, 24, FontWeight.w800, 32),
      titleLarge: w(base.titleLarge, 20, FontWeight.w700, 28),
      titleMedium: w(base.titleMedium, 16, FontWeight.w700, 24),
      titleSmall: w(base.titleSmall, 15, FontWeight.w600, 22),
      bodyLarge: w(base.bodyLarge, 16, FontWeight.w400, 24),
      bodyMedium: w(base.bodyMedium, 14, FontWeight.w400, 20),
      bodySmall: w(base.bodySmall, 13, FontWeight.w400, 18),
      labelLarge: w(base.labelLarge, 14, FontWeight.w600, 20),
      labelMedium: w(base.labelMedium, 13, FontWeight.w500, 18),
      labelSmall: w(base.labelSmall, 12, FontWeight.w500, 16),
    );
  }

  static ThemeData _base(ColorScheme scheme, AppPalette palette) {
    final isDark = scheme.brightness == Brightness.dark;
    final text = _text(scheme.brightness);
    final controlShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(Radii.m),
    );
    const buttonSize = Size(kMinTap, kButtonHeight);
    final buttonText = text.labelLarge?.copyWith(fontWeight: FontWeight.w700);
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
      materialTapTargetSize: MaterialTapTargetSize.padded,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        toolbarHeight: 60,
        scrolledUnderElevation: 0,
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
        titleTextStyle: text.titleMedium,
      ),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainer,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.l),
          side: BorderSide(color: palette.outline),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        backgroundColor: scheme.surfaceContainer,
        indicatorColor: scheme.primary.withValues(alpha: isDark ? 0.18 : 0.14),
        indicatorShape: const StadiumBorder(),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => text.labelSmall?.copyWith(
            fontWeight: s.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
            letterSpacing: 0,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.s),
        ),
        side: BorderSide(color: palette.outline),
        labelStyle: text.labelMedium,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: buttonSize,
          shape: controlShape,
          textStyle: buttonText,
          padding: const EdgeInsets.symmetric(horizontal: Space.xl),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: buttonSize,
          shape: controlShape,
          textStyle: buttonText,
          side: BorderSide(color: scheme.outline.withValues(alpha: 0.5)),
          padding: const EdgeInsets.symmetric(horizontal: Space.xl),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(kMinTap, kMinTap),
          shape: controlShape,
          textStyle: buttonText,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(minimumSize: const Size(kMinTap, kMinTap)),
      ),
      listTileTheme: ListTileThemeData(
        minVerticalPadding: Space.s,
        minTileHeight: kMinTap,
        horizontalTitleGap: Space.m,
        iconColor: scheme.onSurfaceVariant,
        titleTextStyle: text.bodyLarge?.copyWith(
          color: scheme.onSurface,
          fontWeight: FontWeight.w500,
        ),
        subtitleTextStyle: text.bodySmall?.copyWith(color: palette.muted),
      ),
      dividerTheme: DividerThemeData(color: palette.outline, space: 1),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainer,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.xl)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.xl),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.m),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHigh,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: Space.l,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.m),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.m),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
      ),
    );
  }
}
