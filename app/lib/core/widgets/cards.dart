import 'package:flutter/material.dart';

import 'package:darbogaz/core/theme/app_theme.dart';
import 'package:darbogaz/core/theme/tokens.dart';
import 'package:darbogaz/core/widgets/common.dart';

/// Rounded square holding an icon (navigation and selection cards).
class IconTile extends StatelessWidget {
  const IconTile(this.icon, {super.key, this.color, this.size = 44});

  final IconData icon;
  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.primary;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(Radii.m),
      ),
      child: Icon(icon, color: c, size: IconSizes.m),
    );
  }
}

/// Tappable card: icon tile, title, one-line hint, trailing chevron (or a
/// custom trailing widget). Read by screen readers as one button.
class NavCard extends StatelessWidget {
  const NavCard({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.trailing,
    this.tint,
    this.emphasized = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final Widget? trailing;

  /// Icon colour (defaults to primary).
  final Color? tint;

  /// Tinted background for the one featured card on a screen.
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = tint ?? theme.colorScheme.primary;
    return Semantics(
      button: true,
      label: subtitle == null ? title : '$title. $subtitle',
      excludeSemantics: true,
      child: Card(
        clipBehavior: Clip.antiAlias,
        color: emphasized ? c.withValues(alpha: 0.10) : null,
        shape: emphasized
            ? RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(Radii.l),
                side: BorderSide(color: c.withValues(alpha: 0.45)),
              )
            : null,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: Insets.card,
            child: Row(
              children: [
                IconTile(icon, color: c),
                const SizedBox(width: Space.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: theme.textTheme.titleMedium),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: context.palette.muted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: Space.s),
                trailing ??
                    Icon(
                      Icons.chevron_right_rounded,
                      color: context.palette.muted,
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Choice card for questions (single or multiple selection).
class SelectCard extends StatelessWidget {
  const SelectCard({
    super.key,
    required this.title,
    required this.selected,
    required this.onTap,
    this.icon,
    this.subtitle,
    this.multi = false,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final bool selected;
  final bool multi;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: subtitle == null ? title : '$title. $subtitle',
      excludeSemantics: true,
      child: AnimatedContainer(
        duration: Motion.fast,
        decoration: BoxDecoration(
          color: selected
              ? scheme.primary.withValues(alpha: 0.12)
              : scheme.surfaceContainer,
          borderRadius: BorderRadius.circular(Radii.l),
          border: Border.all(
            color: selected ? scheme.primary : context.palette.outline,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(Radii.l),
            onTap: onTap,
            child: Padding(
              padding: Insets.card,
              child: Row(
                children: [
                  if (icon != null) ...[
                    IconTile(icon!, size: 40),
                    const SizedBox(width: Space.m),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: theme.textTheme.titleSmall),
                        if (subtitle != null)
                          Text(
                            subtitle!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: context.palette.muted,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: Space.s),
                  Icon(
                    multi
                        ? (selected
                              ? Icons.check_box_rounded
                              : Icons.check_box_outline_blank_rounded)
                        : (selected
                              ? Icons.radio_button_checked_rounded
                              : Icons.radio_button_unchecked_rounded),
                    color: selected ? scheme.primary : context.palette.muted,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Tinted message banner (info / good / warn / bad) with an optional action.
class Notice extends StatelessWidget {
  const Notice({
    super.key,
    required this.title,
    this.message,
    this.tone = Tone.neutral,
    this.icon,
    this.action,
  });

  final String title;
  final String? message;
  final Tone tone;
  final IconData? icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = context.palette;
    final (Color c, IconData defaultIcon) = switch (tone) {
      Tone.good => (p.good, Icons.check_circle_rounded),
      Tone.warn => (p.warn, Icons.info_rounded),
      Tone.bad => (p.bad, Icons.warning_rounded),
      Tone.brand => (theme.colorScheme.primary, Icons.auto_awesome_rounded),
      Tone.neutral => (p.muted, Icons.info_outline_rounded),
    };
    return Semantics(
      container: true,
      label: message == null ? title : '$title. $message',
      child: Container(
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(Radii.l),
          border: Border.all(color: c.withValues(alpha: 0.40)),
        ),
        padding: Insets.card,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon ?? defaultIcon, color: c, size: IconSizes.l),
                const SizedBox(width: Space.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: theme.textTheme.titleMedium),
                      if (message != null) ...[
                        const SizedBox(height: Space.xs),
                        Text(message!, style: theme.textTheme.bodyMedium),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            if (action != null) ...[
              const SizedBox(height: Space.m),
              Align(alignment: Alignment.centerRight, child: action),
            ],
          ],
        ),
      ),
    );
  }
}

/// One line of a list with a leading icon (tips, cautions, reasons).
class BulletRow extends StatelessWidget {
  const BulletRow(this.text, {super.key, this.icon = Icons.circle, this.color});

  final String text;
  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final small = icon == Icons.circle;
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.s),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(top: small ? 7 : 1),
            child: Icon(
              icon,
              size: small ? 6 : IconSizes.s,
              color: color ?? context.palette.muted,
            ),
          ),
          const SizedBox(width: Space.s),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

/// Small explanatory note under a section (estimates, sources).
class Footnote extends StatelessWidget {
  const Footnote(this.text, {super.key, this.align = TextAlign.start});

  final String text;
  final TextAlign align;

  @override
  Widget build(BuildContext context) => Text(
    text,
    textAlign: align,
    style: Theme.of(context).textTheme.labelSmall
        ?.copyWith(color: context.palette.muted),
  );
}
