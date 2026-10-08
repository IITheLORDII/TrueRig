import 'package:flutter/material.dart';

import 'package:darbogaz/core/widgets/explain.dart';
import 'package:darbogaz/core/widgets/term_info.dart';
import 'package:darbogaz/core/theme/app_theme.dart';
import 'package:darbogaz/core/theme/tokens.dart';

/// Titled card used for every result block. [hero] adds the brand gradient
/// border; use it for the one key result on a screen.
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.title,
    required this.child,
    this.icon,
    this.trailing,
    this.hero = false,
    this.term,
  });

  final String title;
  final Widget child;
  final IconData? icon;
  final Widget? trailing;
  final bool hero;

  /// Adds a "… nedir?" button under the card that explains the word.
  final Term? term;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final content = Padding(
      padding: Insets.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: IconSizes.s, color: theme.colorScheme.primary),
                const SizedBox(width: Space.s),
              ],
              Expanded(child: Text(title, style: theme.textTheme.titleMedium)),
              ?trailing,
            ],
          ),
          const SizedBox(height: Space.m),
          child,
          if (term != null) ...[
            const SizedBox(height: Space.m),
            Explain.term(term!),
          ],
        ],
      ),
    );
    if (!hero) return Card(child: content);
    return HeroFrame(child: content);
  }
}

/// Card with a 1.5 px cyan → violet gradient border.
class HeroFrame extends StatelessWidget {
  const HeroFrame({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(Radii.l),
      gradient: kBrandGradient,
    ),
    child: Padding(
      padding: const EdgeInsets.all(1.5),
      // Material (not DecoratedBox) so ink splashes of tiles inside show.
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(Radii.l - 1.5),
        clipBehavior: Clip.antiAlias,
        child: child,
      ),
    ),
  );
}

/// Single-line metric: name (+ optional note) · inline bar · value.
class MetricBar extends StatelessWidget {
  const MetricBar({
    super.key,
    required this.label,
    required this.value,
    required this.max,
    required this.valueText,
    this.color,
    this.subtitle,
  });

  final String label;
  final double value;
  final double max;
  final String valueText;
  final Color? color;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final barColor = color ?? theme.colorScheme.primary;
    final fraction = max <= 0 ? 0.0 : (value / max).clamp(0.0, 1.0);
    return Semantics(
      label: '$label: $valueText',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Space.xs),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: theme.textTheme.bodyMedium),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: context.palette.muted,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: Space.s),
            SizedBox(
              width: kInlineBarWidth,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(Radii.s),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: fraction),
                  duration: Motion.slow,
                  curve: Curves.easeOutCubic,
                  builder: (_, v, _) => LinearProgressIndicator(
                    value: v,
                    minHeight: 6,
                    color: barColor,
                    backgroundColor: context.palette.surfaceAlt,
                  ),
                ),
              ),
            ),
            const SizedBox(width: Space.s),
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 64),
              child: Text(
                valueText,
                textAlign: TextAlign.end,
                style: numberStyle(context, size: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Coloured pill label.
class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: Space.s, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(Radii.pill),
    ),
    child: Text(
      text,
      style: Theme.of(context).textTheme.labelSmall
          ?.copyWith(color: color, fontWeight: FontWeight.w700),
    ),
  );
}

enum Tone { good, warn, bad, neutral, brand }

/// The one colour for each [Tone].
Color toneColor(BuildContext context, Tone tone) {
  final p = context.palette;
  return switch (tone) {
    Tone.good => p.good,
    Tone.warn => p.warn,
    Tone.bad => p.bad,
    Tone.neutral => p.muted,
    Tone.brand => Theme.of(context).colorScheme.primary,
  };
}

/// Status label with one meaning per colour across the app.
class VerdictChip extends StatelessWidget {
  const VerdictChip(this.text, {super.key, this.tone = Tone.neutral});

  final String text;
  final Tone tone;

  @override
  Widget build(BuildContext context) =>
      StatusPill(text: text, color: toneColor(context, tone));
}

/// Small uppercase heading above a group of rows.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(Space.xs, Space.m, Space.xs, Space.s),
    child: Row(
      children: [
        Expanded(
          child: Text(
            text.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: context.palette.muted,
              letterSpacing: 0.8,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        ?trailing,
      ],
    ),
  );
}

/// Grey placeholder bar shown while content loads.
class SkeletonBar extends StatelessWidget {
  const SkeletonBar({
    super.key,
    this.width = double.infinity,
    this.height = 14,
  });

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    margin: const EdgeInsets.symmetric(vertical: Space.xs),
    decoration: BoxDecoration(
      color: context.palette.surfaceAlt,
      borderRadius: BorderRadius.circular(Radii.s),
    ),
  );
}

/// "Bu sayılar ne kadar doğru?" button under every estimate.
class AccuracyNote extends StatelessWidget {
  const AccuracyNote({super.key});

  @override
  Widget build(BuildContext context) => const ExplainNote(
    question: 'Bu sayılar ne kadar doğru?',
    answer: kEstimateDisclaimer,
  );
}

const String kEstimateDisclaimer =
    'Değerler bağımsız testlerle kalibre edilmiş tahminlerdir; sürücü, '
    'oyun yaması, sahne ve sistem ayarlarına göre farklılık gösterebilir.';

/// Secondary action on the left, primary on the right; stacks vertically
/// (primary first) when the row does not fit (narrow screens, large text).
class ActionRow extends StatelessWidget {
  const ActionRow({super.key, this.secondary, this.primary});

  final Widget? secondary;
  final Widget? primary;

  @override
  Widget build(BuildContext context) => OverflowBar(
    alignment: MainAxisAlignment.spaceBetween,
    overflowAlignment: OverflowBarAlignment.end,
    overflowDirection: VerticalDirection.up,
    spacing: Space.s,
    overflowSpacing: Space.xs,
    children: [?secondary, ?primary],
  );
}
