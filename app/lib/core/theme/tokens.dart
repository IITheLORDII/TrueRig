/// Design tokens: every spacing, radius and duration in the UI comes from
/// here so screens stay consistent.
library;

abstract final class Space {
  static const double xs = 4;
  static const double s = 8;
  static const double m = 12;
  static const double l = 16;
  static const double xl = 24;

  /// Horizontal page gutter.
  static const double page = l;
}

abstract final class Radii {
  static const double s = 10;
  static const double m = 14;
  static const double l = 20;
}

abstract final class Motion {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 600);
}

/// Minimum touch target (Material / Apple HIG).
const double kMinTap = 48;

/// Width of the inline bar in compact metric rows.
const double kInlineBarWidth = 64;
