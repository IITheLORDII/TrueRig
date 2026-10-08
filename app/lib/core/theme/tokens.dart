/// Design tokens (design system v2): every spacing, radius, size and
/// duration in the UI comes from here so screens stay consistent.
/// 4 px grid; radii follow Material 3 (8 / 12 / 16 / 28).
library;

import 'package:flutter/widgets.dart';

abstract final class Space {
  static const double xs = 4;
  static const double s = 8;
  static const double m = 12;
  static const double l = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;

  /// Horizontal page gutter (phones); [pageWide] on tablets / web.
  static const double page = l;
  static const double pageWide = xl;

  /// Gap between stacked cards.
  static const double cardGap = m;

  /// Inside a card.
  static const double cardPad = l;
}

/// Standard insets.
abstract final class Insets {
  /// Scrollable page body: gutter on the sides, room at the bottom.
  static const EdgeInsets page = EdgeInsets.fromLTRB(
    Space.page,
    Space.xs,
    Space.page,
    Space.xl,
  );

  /// Header area above a page body (segmented controls, search).
  static const EdgeInsets pageHeader = EdgeInsets.fromLTRB(
    Space.page,
    0,
    Space.page,
    Space.s,
  );

  static const EdgeInsets card = EdgeInsets.all(Space.cardPad);
}

abstract final class Radii {
  /// Chips, small badges.
  static const double s = 8;

  /// Buttons, inputs, controls.
  static const double m = 12;

  /// Cards.
  static const double l = 16;

  /// Sheets, hero cards.
  static const double xl = 28;

  static const double pill = 999;
}

abstract final class IconSizes {
  static const double s = 18;
  static const double m = 24;
  static const double l = 32;
  static const double xl = 48;
}

abstract final class Motion {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 250);

  /// Gauges and number count-ups (once, on first view).
  static const Duration slow = Duration(milliseconds: 600);
  static const Curve curve = Curves.easeOutCubic;
}

/// Minimum touch target (Material / Apple HIG).
const double kMinTap = 48;

/// Primary / secondary button height.
const double kButtonHeight = 52;

/// Width of the inline bar in compact metric rows.
const double kInlineBarWidth = 64;
