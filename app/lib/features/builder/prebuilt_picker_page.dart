import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:perf_engine/perf_engine.dart';

import 'package:darbogaz/core/devices.dart';
import 'package:darbogaz/core/providers.dart';
import 'package:darbogaz/core/theme/app_theme.dart';
import 'package:darbogaz/core/widgets/common.dart';
import 'package:darbogaz/core/brand/truerig_logo.dart';

/// A ready-made or parsed system chosen in the picker.
@immutable
class PickedSystem {
  const PickedSystem({
    required this.label,
    required this.build,
    required this.isLaptop,
  });

  final String label;
  final PcBuild build;
  final bool isLaptop;
}

/// Ready-made laptops / PCs plus "fill from listing title".
/// [returnMode]: pop with a [PickedSystem] (comparison) instead of replacing
/// the user's own PC build.
class PrebuiltPickerPage extends ConsumerStatefulWidget {
  const PrebuiltPickerPage({super.key, this.returnMode = false});

  final bool returnMode;

  @override
  ConsumerState<PrebuiltPickerPage> createState() => _PrebuiltPickerState();
}

class _PrebuiltPickerState extends ConsumerState<PrebuiltPickerPage> {
  String _query = '';

  List<PrebuiltSystem> _matches() {
    final tokens = PartCatalog.normalize(_query).split(' ')
      ..removeWhere((t) => t.isEmpty);
    return kPrebuilts.where((s) {
      final name = PartCatalog.normalize(
        '${s.displayName} ${s.aliases.join(' ')} '
        '${s.variants.map((v) => v.code ?? '').join(' ')}',
      );
      return tokens.every(name.contains);
    }).toList();
  }

  void _finish(PickedSystem picked) {
    if (widget.returnMode) {
      context.pop(picked);
      return;
    }
    ref
        .read(prebuiltProvider.notifier)
        .apply(
          PrebuiltSelection(label: picked.label, isLaptop: picked.isLaptop),
          picked.build,
        );
    ref.read(activeDeviceProvider.notifier).set(DeviceKind.pc);
    context.pop();
  }

  Future<void> _pickSystem(PrebuiltSystem s) async {
    final catalog = ref.read(catalogProvider);
    final variant = s.variants.length == 1
        ? s.variants.first
        : await showModalBottomSheet<PrebuiltVariant>(
            context: context,
            showDragHandle: true,
            isScrollControlled: true,
            useSafeArea: true,
            builder: (_) => _VariantSheet(system: s, catalog: catalog),
          );
    if (variant == null || !mounted) return;
    _finish(
      PickedSystem(
        label: '${s.displayName} · ${variantLabel(catalog, variant)}',
        build: buildFromVariant(catalog, variant),
        isLaptop: s.isLaptop,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(catalogProvider);
    final systems = _matches();
    final parsed = _query.trim().length >= 6
        ? SpecTextParser(catalog).parse(_query)
        : null;
    final palette = context.palette;

    return Scaffold(
      appBar: AppBar(title: const BrandTitle('Hazır sistem')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              minLines: 1,
              maxLines: 3,
              onChanged: (v) => setState(() => _query = v),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search_rounded),
                hintText:
                    'Model (ör. Excalibur G770) ya da ilan başlığını '
                    'yapıştır',
                isDense: true,
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              children: [
                if (parsed != null && !parsed.isEmpty) ...[
                  _ParsedCard(
                    parsed: parsed,
                    onApply: () => _finish(
                      PickedSystem(
                        label: _query.trim().length > 60
                            ? '${_query.trim().substring(0, 60)}…'
                            : _query.trim(),
                        build: parsed.toBuild(),
                        isLaptop: parsed.isLaptop,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                if (systems.isEmpty && (parsed == null || parsed.isEmpty))
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Listede yoksa mağazadaki ürün başlığını olduğu gibi '
                      'yapıştır; işlemci, ekran kartı ve RAM\'i biz bulalım.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: palette.muted),
                    ),
                  ),
                for (final s in systems)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      s.isLaptop
                          ? Icons.laptop_chromebook_rounded
                          : Icons.desktop_windows_rounded,
                    ),
                    title: Text(s.displayName),
                    subtitle: Text(
                      '${s.isLaptop ? 'Dizüstü' : 'Masaüstü'} · '
                      '${s.variants.length} yapılandırma'
                      '${_yearSpan(s)}',
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => _pickSystem(s),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _yearSpan(PrebuiltSystem s) {
  final years = s.variants.map((v) => v.year).whereType<int>().toList();
  if (years.isEmpty) return '';
  years.sort();
  return years.first == years.last
      ? ' · ${years.first}'
      : ' · ${years.first}–${years.last}';
}

/// Configurations of one system grouped by year, newest first.
class _VariantSheet extends StatelessWidget {
  const _VariantSheet({required this.system, required this.catalog});

  final PrebuiltSystem system;
  final PartCatalog catalog;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final sorted = [...system.variants]
      ..sort((a, b) => (b.year ?? 0).compareTo(a.year ?? 0));
    final children = <Widget>[
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 4),
        child: Text(
          '${system.displayName} · yapılandırma',
          style: theme.textTheme.titleMedium,
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
        child: Text(
          'Etiketteki ya da faturadaki işlemci ve ekran kartını seç.',
          style: theme.textTheme.bodySmall?.copyWith(color: palette.muted),
        ),
      ),
    ];
    int? lastYear = -1;
    for (final v in sorted) {
      if (v.year != lastYear) {
        lastYear = v.year;
        children.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 2),
            child: Text(
              v.year?.toString() ?? 'Diğer',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        );
      }
      children.add(
        ListTile(
          dense: true,
          title: Text(variantLabel(catalog, v)),
          subtitle: v.code == null ? null : Text(v.code!),
          onTap: () => Navigator.of(context).pop(v),
        ),
      );
    }
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      builder: (_, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.only(bottom: 24),
        children: children,
      ),
    );
  }
}

class _ParsedCard extends StatelessWidget {
  const _ParsedCard({required this.parsed, required this.onApply});

  final ParsedSpec parsed;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    Widget row(String label, Part? part) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            part == null ? Icons.help_outline_rounded : Icons.check_rounded,
            size: 16,
            color: part == null ? palette.muted : palette.good,
          ),
          const SizedBox(width: 6),
          Text('$label: '),
          Expanded(
            child: Text(
              part?.displayName ?? 'bulunamadı',
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
    return SectionCard(
      title: 'Başlıktan bulunanlar',
      icon: Icons.auto_fix_high_rounded,
      trailing: parsed.isLaptop
          ? StatusPill(text: 'Dizüstü', color: palette.muted)
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          row('İşlemci', parsed.cpu),
          row('Ekran kartı', parsed.gpu),
          row('RAM', parsed.ram),
          const SizedBox(height: 8),
          FilledButton(onPressed: onApply, child: const Text('Bununla doldur')),
        ],
      ),
    );
  }
}
