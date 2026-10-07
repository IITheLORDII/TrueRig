import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:perf_engine/perf_engine.dart';

import 'package:darbogaz/core/devices.dart';
import 'package:darbogaz/core/images/part_images.dart';
import 'package:darbogaz/core/providers.dart';
import 'package:darbogaz/core/theme/app_theme.dart';
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
  });

  final PartCategory category;

  /// Pop with the chosen part (comparison) instead of editing the build.
  final bool returnMode;

  @override
  ConsumerState<PartPickerPage> createState() => _PartPickerPageState();
}

class _PartPickerPageState extends ConsumerState<PartPickerPage> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(catalogProvider);
    final build = ref.watch(buildProvider);
    final parts = _query.trim().isEmpty
        ? catalog.byCategory(widget.category)
        : catalog.search(_query, category: widget.category, limit: 100);
    final rows = _rank(parts, build);

    return Scaffold(
      appBar: AppBar(title: BrandTitle('${widget.category.label} seç')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              controller: _controller,
              onChanged: (v) => setState(() => _query = v),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search_rounded),
                hintText: 'Model adı veya seri/parça no (MPN)',
              ),
            ),
          ),
          Expanded(
            child: rows.isEmpty
                ? const Center(child: Text('Sonuç bulunamadı'))
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    itemCount: rows.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, i) => _PartRow(
                      row: rows[i],
                      selected:
                          build.partFor(widget.category)?.id == rows[i].part.id,
                      onTap: () {
                        if (widget.returnMode) {
                          context.pop(rows[i].part);
                          return;
                        }
                        ref.read(buildProvider.notifier).setPart(rows[i].part);
                        ref.read(prebuiltProvider.notifier).markEdited();
                        ref
                            .read(activeDeviceProvider.notifier)
                            .set(DeviceKind.pc);
                        context.pop();
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
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
    final theme = Theme.of(context);
    final palette = context.palette;
    final incompatible = row.errors.isNotEmpty;
    final price = row.part.refPriceUsd;
    return Opacity(
      opacity: incompatible ? 0.55 : 1,
      child: Card(
        shape: selected
            ? RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: BorderSide(color: theme.colorScheme.primary, width: 1.5),
              )
            : null,
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          onTap: onTap,
          leading: PartThumb(
            imageUrl: ref.watch(partImageProvider(row.part)),
            fallbackIcon: row.part.category.icon,
          ),
          title: Text(
            row.part.displayName,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(partSubtitle(row.part)),
              if (incompatible)
                Text(
                  row.errors.first,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: palette.bad,
                  ),
                ),
            ],
          ),
          trailing: price == null || price == 0
              ? null
              : Text(
                  '~\$${price.toStringAsFixed(0)}',
                  style: numberStyle(context, size: 13, color: palette.muted),
                ),
        ),
      ),
    );
  }
}
