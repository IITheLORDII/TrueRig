import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:perf_engine/perf_engine.dart';

import 'package:darbogaz/core/widgets/app_controls.dart';
import 'package:darbogaz/core/providers.dart';

/// Game, resolution and preset selectors shared by analysis screens.
class AnalysisSettingsBar extends ConsumerWidget {
  const AnalysisSettingsBar({super.key, this.showGame = true});

  final bool showGame;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(analysisSettingsProvider);
    final ctrl = ref.read(analysisSettingsProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showGame) ...[
          _GamePickerTile(
            game: s.game,
            onPick: (id) => ctrl.update((s) => s.copyWith(gameId: id)),
          ),
          const SizedBox(height: 12),
        ],
        AppSegmented<Resolution>(
          values: Resolution.values,
          selected: s.resolution,
          labelOf: (r) => r.label,
          onChanged: (v) => ctrl.update((s) => s.copyWith(resolution: v)),
        ),
        const SizedBox(height: 8),
        AppSegmented<GraphicsPreset>(
          values: GraphicsPreset.values,
          selected: s.preset,
          labelOf: (p) => p.label,
          onChanged: (v) => ctrl.update((s) => s.copyWith(preset: v)),
        ),
      ],
    );
  }
}

/// Tappable row that opens a platform-native game picker sheet.
class _GamePickerTile extends StatelessWidget {
  const _GamePickerTile({required this.game, required this.onPick});

  final GameProfile game;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () async {
          final picked = await showOptionSheet<GameProfile>(
            context: context,
            title: 'Oyun seç',
            options: kGames,
            labelOf: (g) => g.name,
            selected: game,
          );
          if (picked != null) onPick(picked.id);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Icon(Icons.sports_esports_rounded, color: scheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  game.name,
                  style: Theme.of(context).textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              Icon(Icons.unfold_more_rounded, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
