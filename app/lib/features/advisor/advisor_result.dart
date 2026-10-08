import 'package:flutter/material.dart';

import 'package:darbogaz/core/widgets/explain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:perf_engine/perf_engine.dart';

import 'package:darbogaz/core/devices.dart';
import 'package:darbogaz/core/providers.dart';
import 'package:darbogaz/core/theme/app_theme.dart';
import 'package:darbogaz/core/theme/tokens.dart';
import 'package:darbogaz/core/widgets/buttons.dart';
import 'package:darbogaz/core/widgets/cards.dart';
import 'package:darbogaz/core/widgets/common.dart';
import 'package:darbogaz/core/widgets/flow.dart';
import 'package:darbogaz/features/prices/store_list.dart';
import 'package:darbogaz/features/sandbox/sandbox_state.dart';

/// "~28.200 TL": estimates rounded to hundreds (no false precision).
String roughTl(double v) =>
    '~${formatPrice((v / 100).round() * 100.0, 'TRY').replaceAll(' TRY', '')} TL';

String budgetLabel(double? b) => b == null
    ? 'Bilmiyorum / fark etmez'
    : '${formatPrice(b, 'TRY').replaceAll(' TRY', '')} TL\'ye kadar';

/// Advisor results: fitting systems, then the traps to avoid.
class AdvisorResult extends ConsumerWidget {
  const AdvisorResult({
    super.key,
    required this.profile,
    required this.onRestart,
  });

  final UsageProfile profile;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rate = ref.watch(usdTryProvider);
    return rate.when(
      loading: () => const StatView.loading(lines: 6),
      error: (_, _) => _body(context, ref, kFallbackUsdTry),
      data: (r) => _body(context, ref, r),
    );
  }

  Widget _body(BuildContext context, WidgetRef ref, double usdTry) {
    final advice = const PurchaseAdvisor().advise(
      profile,
      ref.read(catalogProvider),
      usdTry: usdTry,
    );
    final theme = Theme.of(context);
    return ListView(
      padding: Insets.page,
      children: [
        Text(
          advice.options.isEmpty
              ? 'Uygun bir sistem bulamadık'
              : 'Sana uygun ${advice.options.length} seçenek',
          style: theme.textTheme.headlineSmall,
        ),
        const SizedBox(height: Space.xs),
        Text(
          [
            for (final u in profile.uses) u.label,
            if (profile.uses.contains(Usage.gaming)) profile.gameLevel.label,
            budgetLabel(profile.budgetTry),
          ].join(' · '),
          style: theme.textTheme.bodySmall?.copyWith(
            color: context.palette.muted,
          ),
        ),
        const SizedBox(height: Space.l),
        if (advice.overBudget) ...[
          const Notice(
            title: 'Bütçene uyan bir sistem yok',
            message: 'İşini görecek en yakın seçenekleri gösteriyoruz.',
            tone: Tone.warn,
          ),
          const SizedBox(height: Space.cardGap),
        ],
        for (final o in advice.options) ...[
          _OptionCard(option: o),
          const SizedBox(height: Space.cardGap),
        ],
        if (advice.cautions.isNotEmpty) ...[
          Explain(
            question: 'Dikkat et: satın alırken nelere bakmalı?',
            icon: Icons.warning_amber_rounded,
            color: context.palette.warn,
            points: advice.cautions,
          ),
          const SizedBox(height: Space.s),
        ],
        const ExplainNote(
          question: 'Fiyatlar nasıl hesaplandı?',
          answer:
              'Bunlar tahmini fiyatlardır: ürünün liste fiyatı bugünkü dolar '
              'kuruyla çevrildi, vergiler eklendi. Gerçek fiyat için '
              '"Fiyatlara bak"a dokun.',
        ),
        const SizedBox(height: Space.l),
        TertiaryButton(
          label: 'Baştan başla',
          icon: Icons.restart_alt_rounded,
          onPressed: onRestart,
        ),
      ],
    );
  }
}

/// "A, b, c." → ["A", "B", "C"]: one reason per line.
List<String> _reasons(String why) {
  final parts = why
      .replaceAll(RegExp(r'\.$'), '')
      .split(', ')
      .where((p) => p.trim().isNotEmpty);
  return [for (final p in parts) '${p[0].toUpperCase()}${p.substring(1)}.'];
}

class _OptionCard extends ConsumerWidget {
  const _OptionCard({required this.option});

  final PurchaseOption option;

  void _toSandbox(WidgetRef ref) {
    ref.read(sandboxProvider.notifier)
      ..setKind(DeviceKind.pc)
      ..setPc(0, SandboxPc(label: option.name, build: option.build));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final tone = switch (option.label) {
      'En uygun' => Tone.good,
      'Dengeli' => Tone.brand,
      _ => Tone.neutral,
    };
    return SectionCard(
      hero: option.label == 'En uygun',
      title: option.label,
      icon: option.isLaptop
          ? Icons.laptop_chromebook_rounded
          : Icons.desktop_windows_rounded,
      trailing: VerdictChip(roughTl(option.priceTry), tone: tone),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(option.name, style: theme.textTheme.titleMedium),
          const SizedBox(height: Space.m),
          Explain(
            question: 'Neden bu önerildi?',
            icon: Icons.lightbulb_outline_rounded,
            points: _reasons(option.why),
          ),
          const SizedBox(height: Space.m),
          ActionRow(
            secondary: TertiaryButton(
              label: 'Analiz et',
              icon: Icons.speed_rounded,
              onPressed: () {
                _toSandbox(ref);
                context.push('/sandbox?tab=pc');
              },
            ),
            primary: SecondaryButton(
              label: 'Fiyatlara bak',
              icon: Icons.sell_rounded,
              onPressed: () {
                _toSandbox(ref);
                context.push('/cart?src=sandbox');
              },
            ),
          ),
        ],
      ),
    );
  }
}
