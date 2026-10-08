import 'package:flutter/material.dart';

import 'package:darbogaz/core/theme/app_theme.dart';
import 'package:darbogaz/core/theme/tokens.dart';

/// Button hierarchy (design system v2). One [PrimaryButton] per screen at
/// most; [SecondaryButton] for the other main choice; [TertiaryButton] for
/// small, optional actions; [DangerButton] for delete / reset.
///
/// All are at least 48 px tall (52 for primary / secondary) and share the
/// same icon + label layout.

/// The single most important action on a screen: brand gradient, full width
/// by default.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  /// Fill the available width (mobile default).
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final scheme = Theme.of(context).colorScheme;
    final fg = enabled ? const Color(0xFF00151A) : scheme.onSurfaceVariant;
    final child = _Label(label: label, icon: icon, color: fg);
    return Semantics(
      button: true,
      enabled: enabled,
      child: SizedBox(
        width: expand ? double.infinity : null,
        height: kButtonHeight,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: enabled ? kBrandGradient : null,
            color: enabled ? null : scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(Radii.m),
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: BorderRadius.circular(Radii.m),
              onTap: onPressed,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.xl),
                child: Center(widthFactor: 1, child: child),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Medium emphasis: tonal fill.
class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final b = FilledButton.tonal(
      onPressed: onPressed,
      child: _Label(label: label, icon: icon),
    );
    return expand ? SizedBox(width: double.infinity, child: b) : b;
  }
}

/// Low emphasis: text only.
class TertiaryButton extends StatelessWidget {
  const TertiaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: onPressed,
    child: _Label(label: label, icon: icon),
  );
}

/// Delete / reset: outlined in the "bad" colour.
class DangerButton extends StatelessWidget {
  const DangerButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final bad = context.palette.bad;
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        foregroundColor: bad,
        side: BorderSide(color: bad.withValues(alpha: 0.6)),
      ),
      onPressed: onPressed,
      child: _Label(label: label, icon: icon),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label({required this.label, this.icon, this.color});

  final String label;
  final IconData? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelLarge
        ?.copyWith(fontWeight: FontWeight.w700, color: color);
    final text = Flexible(
      child: Text(
        label,
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: style,
      ),
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: IconSizes.s, color: color),
          const SizedBox(width: Space.s),
        ],
        text,
      ],
    );
  }
}
