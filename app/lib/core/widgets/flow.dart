import 'package:flutter/material.dart';

import 'package:darbogaz/core/brand/truerig_logo.dart';
import 'package:darbogaz/core/theme/app_theme.dart';
import 'package:darbogaz/core/theme/tokens.dart';
import 'package:darbogaz/core/widgets/buttons.dart';
import 'package:darbogaz/core/widgets/common.dart';

/// The same loading / empty / error look on every screen.
class StatView extends StatelessWidget {
  /// Skeleton rows while something loads.
  const StatView.loading({super.key, this.lines = 4})
    : _kind = _Kind.loading,
      icon = null,
      message = '',
      actionLabel = null,
      onAction = null;

  /// Nothing to show yet: icon, one sentence, one main action.
  const StatView.empty({
    super.key,
    required this.message,
    this.icon,
    this.actionLabel,
    this.onAction,
  }) : _kind = _Kind.empty,
       lines = 0;

  /// Something failed: one sentence and "Tekrar dene".
  const StatView.error({
    super.key,
    this.message =
        'Bir sorun oldu. İnternet bağlantını kontrol edip tekrar dene.',
    this.onAction,
  }) : _kind = _Kind.error,
       icon = Icons.cloud_off_rounded,
       actionLabel = 'Tekrar dene',
       lines = 0;

  final _Kind _kind;
  final IconData? icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final int lines;

  @override
  Widget build(BuildContext context) {
    if (_kind == _Kind.loading) {
      return Semantics(
        label: 'Yükleniyor',
        child: Padding(
          padding: Insets.card,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < lines; i++)
                SkeletonBar(width: i.isEven ? double.infinity : 180),
            ],
          ),
        ),
      );
    }
    final action = actionLabel != null && onAction != null
        ? (_kind == _Kind.error
              ? SecondaryButton(
                  label: actionLabel!,
                  icon: Icons.refresh_rounded,
                  onPressed: onAction,
                )
              : PrimaryButton(
                  label: actionLabel!,
                  onPressed: onAction,
                  expand: false,
                ))
        : null;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Space.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon == null)
              const Opacity(opacity: 0.8, child: TrueRigMark(size: 56))
            else
              Icon(
                icon,
                size: IconSizes.xl,
                color: _kind == _Kind.error
                    ? context.palette.bad
                    : context.palette.muted,
              ),
            const SizedBox(height: Space.l),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            if (action != null) ...[const SizedBox(height: Space.l), action],
          ],
        ),
      ),
    );
  }
}

enum _Kind { loading, empty, error }

/// "Adım 2 / 4" with a thin segmented bar (wizards, onboarding).
class StepProgress extends StatelessWidget {
  const StepProgress({super.key, required this.step, required this.total});

  /// 1-based.
  final int step;
  final int total;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: 'Adım $step / $total',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Adım $step / $total',
            style: Theme.of(context).textTheme.labelMedium
                ?.copyWith(color: context.palette.muted),
          ),
          const SizedBox(height: Space.s),
          Row(
            children: [
              for (var i = 1; i <= total; i++) ...[
                if (i > 1) const SizedBox(width: Space.xs),
                Expanded(
                  child: AnimatedContainer(
                    duration: Motion.normal,
                    height: 4,
                    decoration: BoxDecoration(
                      color: i <= step
                          ? scheme.primary
                          : scheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(Radii.pill),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Action area pinned to the bottom of a screen (use as
/// `Scaffold.bottomNavigationBar`). Optional [leading] shows a summary such
/// as a total price next to the buttons.
class StickyActionBar extends StatelessWidget {
  const StickyActionBar({
    super.key,
    required this.primary,
    this.secondary,
    this.leading,
  });

  final Widget primary;
  final Widget? secondary;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainer,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: context.palette.outline)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              Space.page,
              Space.m,
              Space.page,
              Space.m,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (leading != null) ...[
                  leading!,
                  const SizedBox(height: Space.s),
                ],
                Row(
                  children: [
                    if (secondary != null) ...[
                      secondary!,
                      const SizedBox(width: Space.s),
                    ],
                    Expanded(child: primary),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Asks before a destructive action. Returns true when confirmed.
Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Sil',
}) async {
  final ok = await showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    builder: (ctx) {
      final theme = Theme.of(ctx);
      return Padding(
        padding: const EdgeInsets.fromLTRB(Space.xl, 0, Space.xl, Space.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: theme.textTheme.titleLarge),
            const SizedBox(height: Space.s),
            Text(message, style: theme.textTheme.bodyMedium),
            const SizedBox(height: Space.xl),
            DangerButton(
              label: confirmLabel,
              icon: Icons.delete_outline_rounded,
              onPressed: () => Navigator.of(ctx).pop(true),
            ),
            const SizedBox(height: Space.s),
            TertiaryButton(
              label: 'Vazgeç',
              onPressed: () => Navigator.of(ctx).pop(false),
            ),
          ],
        ),
      );
    },
  );
  return ok ?? false;
}

/// Short snackbar with an optional "Geri al".
void showUndoSnack(
  BuildContext context,
  String message, {
  VoidCallback? onUndo,
}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        action: onUndo == null
            ? null
            : SnackBarAction(label: 'Geri al', onPressed: onUndo),
      ),
    );
}
