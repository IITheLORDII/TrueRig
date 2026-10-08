import 'package:flutter/material.dart';

import 'package:darbogaz/core/theme/tokens.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:perf_engine/perf_engine.dart';

import 'package:darbogaz/core/devices.dart';
import 'package:darbogaz/core/theme/app_theme.dart';
import 'package:darbogaz/core/widgets/common.dart';
import 'package:darbogaz/features/detect/self_device.dart';
import 'package:darbogaz/features/watch/pairing_card.dart';

/// Phone selection shown in the "Cihaz" tab.
class PhonePanel extends ConsumerWidget {
  const PhonePanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spec = ref.watch(phoneSpecProvider);
    final self = ref.watch(selfPhoneProvider).value;
    final showSelf = self != null && spec?.phone.id != self.phone.id;

    return ListView(
      padding: Insets.page,
      children: [
        if (showSelf) ...[
          _SelfPhoneCard(match: self),
          const SizedBox(height: 8),
        ],
        if (spec == null)
          EmptyHint(
            icon: Icons.smartphone_rounded,
            message:
                'Telefonunu seç; oyun FPS\'i, uygulama performansı ve '
                'telefonda çalışan yapay zekâ hızını hesaplayalım.',
            action: FilledButton.icon(
              onPressed: () => context.push('/pick/phone'),
              icon: const Icon(Icons.search_rounded),
              label: const Text('Telefon seç'),
            ),
          )
        else ...[
          _SelectedPhoneCard(spec: spec),
          const SizedBox(height: 8),
          const PairingCard(),
        ],
      ],
    );
  }
}

class _SelfPhoneCard extends ConsumerWidget {
  const _SelfPhoneCard({required this.match});

  final PhoneMatch match;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.primary.withValues(alpha: 0.12),
      child: ListTile(
        leading: Icon(Icons.phone_iphone_rounded, color: scheme.primary),
        title: Text('Bu telefon: ${match.phone.displayName}'),
        subtitle: const Text('Modelini otomatik tanıdık'),
        trailing: FilledButton(
          onPressed: () => ref
              .read(phoneSelectionProvider.notifier)
              .select(match.phone, socId: match.socId),
          child: const Text('Seç'),
        ),
      ),
    );
  }
}

class _SelectedPhoneCard extends ConsumerWidget {
  const _SelectedPhoneCard({required this.spec});

  final PhoneSpec spec;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final summary = const PhoneEstimator().summarize(spec);
    final p = spec.phone;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      p.platform == MobilePlatform.ios
                          ? Icons.phone_iphone_rounded
                          : Icons.phone_android_rounded,
                      size: 36,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.displayName,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            '${spec.soc.name} · ${p.displayHz} Hz · '
                            '${p.batteryMah} mAh · ${p.year}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: palette.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      summary.score.round().toString(),
                      style: numberStyle(context, size: 26),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    StatusPill(
                      text: summary.tier.label,
                      color: theme.colorScheme.primary,
                    ),
                    StatusPill(
                      text: 'Güncelleme: ${p.platform.label} ${p.maxOsMajor}',
                      color: palette.muted,
                    ),
                  ],
                ),
                if (p.ramOptionsGb.length > 1) ...[
                  const SizedBox(height: 10),
                  Text('RAM', style: theme.textTheme.labelMedium),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final r in p.ramOptionsGb)
                        ChoiceChip(
                          label: Text('$r GB'),
                          selected: spec.ramGb == r,
                          onSelected: (_) => ref
                              .read(phoneSelectionProvider.notifier)
                              .setRam(r),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        ActionRow(
          secondary: TextButton.icon(
            onPressed: () => context.push('/pick/phone'),
            icon: const Icon(Icons.swap_horiz_rounded),
            label: const Text('Değiştir'),
          ),
          primary: FilledButton.icon(
            onPressed: () => context.go('/analysis'),
            icon: const Icon(Icons.insights_rounded),
            label: const Text('Performansı gör'),
          ),
        ),
      ],
    );
  }
}
