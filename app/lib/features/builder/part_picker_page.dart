import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:perf_engine/perf_engine.dart';

import 'package:darbogaz/core/widgets/page_nav.dart';
import 'package:darbogaz/features/sandbox/sandbox_state.dart';
import 'package:darbogaz/core/devices.dart';
import 'package:darbogaz/core/images/part_images.dart';
import 'package:darbogaz/core/providers.dart';
import 'package:darbogaz/core/theme/tokens.dart';
import 'package:darbogaz/core/widgets/buttons.dart';
import 'package:darbogaz/core/widgets/cards.dart';
import 'package:darbogaz/core/widgets/common.dart';
import 'package:darbogaz/core/widgets/picker.dart';
import 'package:darbogaz/core/widgets/part_labels.dart';
import 'package:darbogaz/core/widgets/part_thumb.dart';
import 'package:darbogaz/core/brand/truerig_logo.dart';

/// Searchable list of parts for one slot. Parts that would create a
/// compatibility error with the current build are sorted last and flagged.
class PartPickerPage extends ConsumerStatefulWidget {
  const PartPickerPage({
    super.key,
    required this.category,
    this.returnMode = false,
    this.against,
  });

  final PartCategory category;

  /// Pop with the chosen part (comparison) instead of editing the build.
  final bool returnMode;

  /// Build the choice is checked against: null = the user's own PC,
  /// 'sandbox0' / 'sandbox1' = a scratch-area PC, 'none' = nothing.
  final String? against;

  @override
  ConsumerState<PartPickerPage> createState() => _PartPickerPageState();
}

class _PartPickerPageState extends ConsumerState<PartPickerPage> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(catalogProvider);
    final PcBuild build = switch (widget.against) {
      'none' => const PcBuild(),
      'sandbox0' => ref.watch(sandboxProvider).pcs[0].build,
      'sandbox1' => ref.watch(sandboxProvider).pcs[1].build,
      _ => ref.watch(buildProvider),
    };
    final parts = _query.trim().isEmpty
        ? catalog.byCategory(widget.category)
        : catalog.search(_query, category: widget.category, limit: 100);
    final rows = _rank(parts, build);

    return Scaffold(
      bottomNavigationBar: const InnerNavBar(),
      appBar: AppBar(
        leading: const PageBackButton(),
        title: BrandTitle('${widget.category.label} seç'),
      ),
      body: Column(
        children: [
          PickerSearchField(
            hint: 'Model adı ya da parça kodu (MPN)',
            onChanged: (v) => setState(() => _query = v),
          ),
          Expanded(
            child: PickerList(
              itemCount: rows.length,
              itemBuilder: (context, i) => _PartRow(
                row: rows[i],
                selected: build.partFor(widget.category)?.id == rows[i].part.id,
                onTap: () => _choose(rows[i]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _choose(_Row row) async {
    if (row.errors.isNotEmpty && !await _confirmIncompatible(row)) return;
    if (!mounted) return;
    if (widget.returnMode) {
      context.pop(row.part);
      return;
    }
    ref.read(buildProvider.notifier).setPart(row.part);
    ref.read(prebuiltProvider.notifier).markEdited();
    ref.read(activeDeviceProvider.notifier).set(DeviceKind.pc);
    context.pop();
  }

  /// Incompatible parts stay selectable (people compare on purpose), but
  /// only after saying why they will not work together.
  Future<bool> _confirmIncompatible(_Row row) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(Space.xl, 0, Space.xl, Space.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Notice(
              title: 'Bu parça uyumsuz',
              message: row.errors.join('\n\n'),
              tone: Tone.bad,
            ),
            const SizedBox(height: Space.xl),
            PrimaryButton(
              label: 'Vazgeç',
              onPressed: () => Navigator.of(ctx).pop(false),
            ),
            const SizedBox(height: Space.s),
            TertiaryButton(
              label: 'Yine de seç',
              onPressed: () => Navigator.of(ctx).pop(true),
            ),
          ],
        ),
      ),
    );
    return ok ?? false;
  }

  List<_Row> _rank(List<Part> parts, PcBuild build) {
    const checker = CompatibilityChecker();
    final rows = [
      for (final p in parts)
        _Row(
          p,
          checker
              .check(build.withPart(p))
              .issues
              .where(
                (i) =>
                    i.severity == IssueSeverity.error &&
                    !_incompleteBuild.contains(i.code) &&
                    i.involved.contains(widget.category),
              )
              .map((i) => i.message)
              .toList(growable: false),
        ),
    ];
    // Stable partition: compatible parts first, original order otherwise.
    return [
      ...rows.where((r) => r.errors.isEmpty),
      ...rows.where((r) => r.errors.isNotEmpty),
    ];
  }
}

/// Errors about a part that is simply not chosen yet (e.g. a CPU without
/// graphics before the graphics card is picked): not an incompatibility.
const _incompleteBuild = {'no_display_output'};

class _Row {
  const _Row(this.part, this.errors);
  final Part part;
  final List<String> errors;
}

class _PartRow extends ConsumerWidget {
  const _PartRow({
    required this.row,
    required this.selected,
    required this.onTap,
  });

  final _Row row;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final price = row.part.refPriceUsd;
    return PickerTile(
      leading: PartThumb(
        imageUrl: ref.watch(partImageProvider(row.part)),
        fallbackIcon: row.part.category.icon,
      ),
      title: row.part.displayName,
      subtitle: partSubtitle(row.part),
      warning: row.errors.isEmpty ? null : row.errors.first,
      trailingText: price == null || price == 0
          ? null
          : '~\$${price.toStringAsFixed(0)}',
      selected: selected,
      onTap: onTap,
    );
  }
}
