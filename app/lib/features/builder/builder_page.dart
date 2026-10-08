import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:perf_engine/perf_engine.dart';

import 'package:darbogaz/core/theme/tokens.dart';
import 'package:darbogaz/core/images/part_images.dart';
import 'package:darbogaz/core/providers.dart';
import 'package:darbogaz/core/theme/app_theme.dart';
import 'package:darbogaz/core/widgets/buttons.dart';
import 'package:darbogaz/core/widgets/cards.dart';
import 'package:darbogaz/core/widgets/common.dart';
import 'package:darbogaz/core/widgets/flow.dart';
import 'package:darbogaz/core/widgets/part_labels.dart';
import 'package:darbogaz/core/widgets/part_thumb.dart';

/// Core parts are always visible; the rest sit in a collapsed section to
/// keep the screen short.
const _mainSlots = [
  PartCategory.cpu,
  PartCategory.gpu,
  PartCategory.motherboard,
  PartCategory.ram,
];
const _otherSlots = [
  PartCategory.psu,
  PartCategory.pcCase,
  PartCategory.cooler,
];

/// PC build editor shown in the "Cihaz" tab when PC is selected.
class PcPanel extends ConsumerWidget {
  const PcPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final build = ref.watch(buildProvider);
    final report = ref.watch(compatibilityProvider);
    final prebuilt = ref.watch(prebuiltProvider);
    final isLaptop = prebuilt?.isLaptop ?? false;
    final othersChosen = _otherSlots.where((c) => build.partFor(c) != null);
    // Laptops have a fixed board, case, PSU and cooler.
    final slots = isLaptop
        ? const [PartCategory.cpu, PartCategory.gpu, PartCategory.ram]
        : _mainSlots;

    return ListView(
      padding: Insets.page,
      children: [
        _PrebuiltCard(selection: prebuilt),
        const SizedBox(height: Space.cardGap),
        _StatusBanner(pcBuild: build, report: report, showPsu: !isLaptop),
        const SizedBox(height: Space.cardGap),
        for (final c in slots) ...[
          _SlotTile(category: c, part: build.partFor(c), report: report),
          const SizedBox(height: Space.s),
        ],
        if (!isLaptop)
          Card(
            clipBehavior: Clip.antiAlias,
            child: ExpansionTile(
              initiallyExpanded: othersChosen.isNotEmpty,
              shape: const Border(),
              leading: const Icon(Icons.tune_rounded),
              title: const Text('Diğer parçalar'),
              subtitle: Text(
                othersChosen.isEmpty
                    ? 'Güç kaynağı, kasa, soğutucu (isteğe bağlı)'
                    : '${othersChosen.length}/3 seçildi',
              ),
              childrenPadding: const EdgeInsets.fromLTRB(
                Space.s,
                0,
                Space.s,
                Space.s,
              ),
              children: [
                for (final c in _otherSlots) ...[
                  _SlotTile(
                    category: c,
                    part: build.partFor(c),
                    report: report,
                  ),
                  const SizedBox(height: Space.s),
                ],
              ],
            ),
          ),
        const SizedBox(height: Space.l),
        if (build.cpu != null && build.gpu != null) ...[
          PrimaryButton(
            onPressed: () => context.go('/analysis'),
            icon: Icons.speed_rounded,
            label: 'Darboğazı analiz et',
          ),
          const SizedBox(height: Space.s),
        ],
        if (build.parts.isNotEmpty) ...[
          SecondaryButton(
            expand: true,
            onPressed: () => context.push('/cart'),
            icon: Icons.shopping_cart_rounded,
            label: 'Sepeti hazırla: nereden en ucuza?',
          ),
          const SizedBox(height: Space.s),
          TertiaryButton(
            label: 'Temizle',
            icon: Icons.restart_alt_rounded,
            onPressed: () async {
              final ok = await confirmAction(
                context,
                title: 'Parçalar temizlensin mi?',
                message: 'Bu bilgisayar için seçtiğin tüm parçalar kaldırılır.',
                confirmLabel: 'Temizle',
              );
              if (ok) ref.read(buildProvider.notifier).reset();
            },
          ),
        ],
      ],
    );
  }
}

/// Optional ready-made system (Casper Excalibur, Monster, ...) or a pasted
/// listing title that fills the slots below.
class _PrebuiltCard extends ConsumerWidget {
  const _PrebuiltCard({required this.selection});

  final PrebuiltSelection? selection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final sel = selection;
    return Card(
      clipBehavior: Clip.antiAlias,
      color: sel == null ? null : scheme.primary.withValues(alpha: 0.1),
      child: ListTile(
        leading: Icon(
          sel?.isLaptop ?? false
              ? Icons.laptop_chromebook_rounded
              : Icons.inventory_2_rounded,
          color: scheme.primary,
        ),
        title: Text(
          sel?.label ?? 'Hazır sistem seç (isteğe bağlı)',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          sel == null
              ? 'Dizüstü / hazır PC modeli ya da ilan başlığı: parçalar '
                    'otomatik dolsun'
              : (sel.isLaptop ? 'Dizüstü · hazır sistem' : 'Hazır sistem'),
        ),
        trailing: sel == null
            ? const Icon(Icons.chevron_right_rounded)
            : IconButton(
                tooltip: 'Hazır sistemi kaldır',
                icon: const Icon(Icons.close_rounded),
                onPressed: () {
                  ref.read(prebuiltProvider.notifier).clear();
                  ref.read(buildProvider.notifier).reset();
                },
              ),
        onTap: () => context.push('/pick/prebuilt'),
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({
    required this.pcBuild,
    required this.report,
    this.showPsu = true,
  });

  final bool showPsu;

  final PcBuild pcBuild;
  final CompatibilityReport report;

  @override
  Widget build(BuildContext context) {
    final errors = report.bySeverity(IssueSeverity.error).length;
    final warnings = report.bySeverity(IssueSeverity.warning).length;
    final (tone, icon, text) = switch ((
      pcBuild.parts.length,
      errors,
      warnings,
    )) {
      (0, _, _) => (
        Tone.neutral,
        Icons.touch_app_rounded,
        'Parça seçerek başla. Uyumluluk anında kontrol edilir.',
      ),
      (_, > 0, _) => (
        Tone.bad,
        Icons.error_rounded,
        '$errors uyumsuzluk var. Analiz sekmesinde ayrıntılar.',
      ),
      (_, _, > 0) => (
        Tone.warn,
        Icons.warning_amber_rounded,
        'Uyumlu, $warnings uyarı var.',
      ),
      _ => (Tone.good, Icons.check_circle_rounded, 'Seçilen parçalar uyumlu.'),
    };
    final psu = showPsu ? report.recommendedPsuW : null;
    return Notice(
      title: text,
      message: psu == null ? null : 'Önerilen güç kaynağı: $psu W',
      tone: tone,
      icon: icon,
    );
  }
}

class _SlotTile extends ConsumerWidget {
  const _SlotTile({
    required this.category,
    required this.part,
    required this.report,
  });

  final PartCategory category;
  final Part? part;
  final CompatibilityReport report;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final hasError = report.issues.any(
      (i) => i.severity == IssueSeverity.error && i.involved.contains(category),
    );
    final selected = part;
    return Card(
      shape: hasError
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(Radii.l),
              side: BorderSide(color: palette.bad, width: 1.5),
            )
          : null,
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: Space.m),
        leading: PartThumb(
          imageUrl: selected == null
              ? null
              : ref.watch(partImageProvider(selected)),
          fallbackIcon: category.icon,
        ),
        title: Text(
          selected?.displayName ?? category.label,
          style: theme.textTheme.titleSmall?.copyWith(
            color: selected == null ? palette.muted : null,
          ),
        ),
        subtitle: Text(
          selected == null
              ? 'Seçmek için dokun'
              : '${hasError ? 'Uyumsuz · ' : ''}${partSubtitle(selected)}',
          style: hasError ? TextStyle(color: palette.bad) : null,
        ),
        trailing: selected == null
            ? const Icon(Icons.add_rounded)
            : IconButton(
                tooltip: 'Kaldır',
                icon: const Icon(Icons.close_rounded),
                onPressed: () =>
                    ref.read(buildProvider.notifier).clear(category),
              ),
        onTap: () => context.push('/pick/part/${category.name}'),
      ),
    );
  }
}
