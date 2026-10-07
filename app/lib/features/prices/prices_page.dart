import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:perf_engine/perf_engine.dart';

import 'package:darbogaz/core/devices.dart';
import 'package:darbogaz/core/images/part_images.dart';
import 'package:darbogaz/core/providers.dart';
import 'package:darbogaz/core/theme/app_theme.dart';
import 'package:darbogaz/core/theme/tokens.dart';
import 'package:darbogaz/core/widgets/common.dart';
import 'package:darbogaz/core/widgets/profile_action.dart';
import 'package:darbogaz/core/widgets/part_labels.dart';
import 'package:darbogaz/core/widgets/part_thumb.dart';
import 'package:darbogaz/features/prices/price_repository.dart';
import 'package:darbogaz/features/prices/store_list.dart';
import 'package:darbogaz/core/brand/truerig_logo.dart';

const _recentKey = 'prices.recent';
const _maxRecent = 8;

/// Last searches, newest first (persisted).
final recentSearchesProvider = NotifierProvider<RecentSearches, List<String>>(
  RecentSearches.new,
);

class RecentSearches extends Notifier<List<String>> {
  @override
  List<String> build() =>
      ref.read(prefsProvider)?.getStringList(_recentKey) ?? const [];

  void add(String q) {
    if (q.isEmpty) return;
    final next = [q, ...state.where((e) => e != q)].take(_maxRecent).toList();
    state = List.unmodifiable(next);
    ref.read(prefsProvider)?.setStringList(_recentKey, next);
  }
}

class PricesPage extends ConsumerStatefulWidget {
  const PricesPage({super.key, this.initialQuery = ''});

  final String initialQuery;

  @override
  ConsumerState<PricesPage> createState() => _PricesPageState();
}

class _PricesPageState extends ConsumerState<PricesPage> {
  late final TextEditingController _controller = TextEditingController(
    text: sanitizeQuery(widget.initialQuery),
  );
  late String _query = _controller.text;

  @override
  void didUpdateWidget(PricesPage old) {
    super.didUpdateWidget(old);
    if (old.initialQuery != widget.initialQuery) {
      _setQuery(widget.initialQuery);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _setQuery(String raw) {
    final q = sanitizeQuery(raw);
    _controller.text = q;
    setState(() => _query = q);
    ref.read(recentSearchesProvider.notifier).add(q);
  }

  /// Closes the shown product and returns to recent searches.
  void _clear() {
    _controller.clear();
    setState(() => _query = '');
    // Drop ?q= so opening the same product again works.
    if (GoRouterState.of(context).uri.queryParameters.containsKey('q')) {
      context.go('/prices');
    }
  }

  Future<void> _scan() async {
    final code = await context.push<String>('/prices/scan');
    if (!mounted || code == null) return;
    _setQuery(code);
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(catalogProvider);
    final matches = catalog.search(_query, limit: 5);
    final build = ref.watch(buildProvider);
    final match = matches.isEmpty ? null : matches.first;
    final query = match == null ? _query : (match.mpn ?? match.displayName);

    return Scaffold(
      appBar: AppBar(
        // Catalog products have their own close button on the card.
        leading: _query.isEmpty || match != null
            ? null
            : IconButton(
                tooltip: 'Ürünü kapat',
                icon: const Icon(Icons.close_rounded),
                onPressed: _clear,
              ),
        title: const BrandTitle('Parça Ara'),
        actions: const [ProfileAction()],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          TextField(
            controller: _controller,
            textInputAction: TextInputAction.search,
            maxLength: kMaxQueryLength,
            onSubmitted: _setQuery,
            decoration: InputDecoration(
              counterText: '',
              prefixIcon: const Icon(Icons.search_rounded),
              hintText: 'Model, seri / parça no (MPN) veya barkod',
              suffixIcon: IconButton(
                tooltip: 'Barkod tara',
                icon: const Icon(Icons.qr_code_scanner_rounded),
                onPressed: _scan,
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (_query.isEmpty) ...[
            _RecentSearches(onPick: _setQuery),
            _BuildShortcuts(pcBuild: build, onPick: _setQuery),
          ] else ...[
            if (match != null) _MatchCard(part: match, onClose: _clear),
            const SizedBox(height: 12),
            StoreList(query: query, showImage: match == null),
          ],
        ],
      ),
    );
  }
}

class _RecentSearches extends ConsumerWidget {
  const _RecentSearches({required this.onPick});

  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recent = ref.watch(recentSearchesProvider);
    if (recent.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader('Son aramalar'),
          Wrap(
            spacing: Space.s,
            runSpacing: Space.s,
            children: [
              for (final q in recent)
                ActionChip(
                  avatar: const Icon(Icons.history_rounded, size: 16),
                  label: Text(q, overflow: TextOverflow.ellipsis),
                  onPressed: () => onPick(q),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BuildShortcuts extends ConsumerWidget {
  const _BuildShortcuts({required this.pcBuild, required this.onPick});

  final PcBuild pcBuild;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final phone = ref.watch(phoneSpecProvider)?.phone;
    final watchSel = ref.watch(watchSelectionProvider);
    final watch = watchSel == null
        ? null
        : ref.watch(mobileCatalogProvider).watch(watchSel.watchId);
    if (pcBuild.parts.isEmpty && phone == null && watch == null) {
      return const EmptyHint(
        icon: Icons.sell_rounded,
        message:
            'Bir parça ara ya da kutudaki barkodu tara; mağazalardaki '
            'fiyatları karşılaştıralım.',
      );
    }
    return SectionCard(
      title: 'Cihazların',
      icon: Icons.inventory_2_rounded,
      child: Column(
        children: [
          if (phone != null)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const PartThumb(
                imageUrl: null,
                fallbackIcon: Icons.smartphone_rounded,
                size: 40,
              ),
              title: Text(phone.displayName),
              subtitle: const Text('Telefon'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => onPick(phone.displayName),
            ),
          if (watch != null)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const PartThumb(
                imageUrl: null,
                fallbackIcon: Icons.watch_rounded,
                size: 40,
              ),
              title: Text(watch.displayName),
              subtitle: const Text('Akıllı saat'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => onPick(watch.displayName),
            ),
          for (final p in pcBuild.parts)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: PartThumb(
                imageUrl: ref.watch(partImageProvider(p)),
                fallbackIcon: p.category.icon,
                size: 40,
              ),
              title: Text(p.displayName),
              subtitle: p.mpn == null ? null : Text('MPN: ${p.mpn}'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => onPick(p.mpn ?? p.displayName),
            ),
        ],
      ),
    );
  }
}

class _MatchCard extends ConsumerWidget {
  const _MatchCard({required this.part, required this.onClose});

  final Part part;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final muted = Theme.of(context).textTheme.labelMedium
        ?.copyWith(color: context.palette.muted);
    return Card(
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 44, 16),
            child: _body(context, ref, muted),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: IconButton(
              tooltip: 'Seçimi kaldır',
              icon: const Icon(Icons.close_rounded),
              onPressed: onClose,
            ),
          ),
        ],
      ),
    );
  }

  Widget _body(BuildContext context, WidgetRef ref, TextStyle? muted) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PartThumb(
          imageUrl: ref.watch(partImageProvider(part)),
          fallbackIcon: part.category.icon,
          size: 88,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                part.displayName,
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(partSubtitle(part)),
              if (part.mpn != null) Text('MPN: ${part.mpn}', style: muted),
              if (part.refPriceUsd != null && part.refPriceUsd! > 0)
                Text(
                  'Referans fiyat: ~\$${part.refPriceUsd!.toStringAsFixed(0)}',
                  style: muted,
                ),
            ],
          ),
        ),
      ],
    );
  }
}
