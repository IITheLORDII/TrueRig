import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:perf_engine/perf_engine.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:darbogaz/core/devices.dart';
import 'package:darbogaz/core/images/part_images.dart';
import 'package:darbogaz/core/providers.dart';
import 'package:darbogaz/core/theme/app_theme.dart';
import 'package:darbogaz/core/widgets/common.dart';
import 'package:darbogaz/core/widgets/part_labels.dart';
import 'package:darbogaz/core/widgets/part_thumb.dart';
import 'package:darbogaz/features/prices/price_repository.dart';
import 'package:darbogaz/core/brand/truerig_logo.dart';

final priceRepositoryProvider = Provider<PriceRepository>(
  (ref) => RemotePriceRepository(),
);

/// Live search; an MPN-matched image is remembered for the whole session so
/// the part shows its picture everywhere in the app.
final priceSearchProvider = FutureProvider.family<PriceSearchResult, String>((
  ref,
  query,
) async {
  final result = await ref.watch(priceRepositoryProvider).search(query);
  final image = result.imageUrl;
  if (image != null) {
    ref.read(sessionPartImagesProvider.notifier).remember(query, image);
  }
  return result;
});

final _priceFormat = NumberFormat.decimalPattern('tr');

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
      appBar: AppBar(title: const BrandTitle('Fiyat & Nerede Bulunur')),
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
          if (_query.isEmpty)
            _BuildShortcuts(pcBuild: build, onPick: _setQuery)
          else ...[
            if (match != null) _MatchCard(part: match),
            const SizedBox(height: 12),
            _LiveOffers(query: query, showImage: match == null),
            const SizedBox(height: 12),
            _StoreLinks(query: query),
          ],
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
  const _MatchCard({required this.part});

  final Part part;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final muted = Theme.of(context).textTheme.labelMedium
        ?.copyWith(color: context.palette.muted);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
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
        ),
      ),
    );
  }
}

class _LiveOffers extends ConsumerWidget {
  const _LiveOffers({required this.query, required this.showImage});

  final String query;

  /// True when the query is not a catalog part, so the card shows the image.
  final bool showImage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(priceRepositoryProvider).isConfigured) {
      return const SizedBox.shrink();
    }
    final result = ref.watch(priceSearchProvider(query));
    final palette = context.palette;
    final muted = Theme.of(context).textTheme.labelSmall
        ?.copyWith(color: palette.muted);
    return SectionCard(
      title: 'Güncel fiyatlar',
      icon: Icons.local_offer_rounded,
      child: result.when(
        loading: () => const LinearProgressIndicator(),
        error: (e, _) => Text(
          e is PriceApiException ? e.message : 'Fiyatlar alınamadı.',
          style: TextStyle(color: palette.bad),
        ),
        data: (r) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showImage && r.imageUrl != null)
              Center(
                child: PartThumb(
                  imageUrl: r.imageUrl,
                  fallbackIcon: Icons.inventory_2_rounded,
                  size: 140,
                ),
              ),
            if (r.offers.isEmpty)
              const Text(
                'Herkese açık sayfalarda bu ürün için fiyat bulunamadı. '
                'Aşağıdaki mağaza bağlantılarını deneyebilirsin.',
              ),
            for (final o in r.offers)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(o.store),
                subtitle: Text(
                  [
                    o.inStock ? 'Stokta' : 'Stokta yok',
                    if (r.isOutlier(o)) 'olağan dışı fiyat',
                  ].join(' · '),
                  style: r.isOutlier(o) ? TextStyle(color: palette.warn) : null,
                ),
                trailing: Text(
                  '${_priceFormat.format(o.price)} ${o.currency}',
                  style: numberStyle(context, size: 15),
                ),
                onTap: () => _open(context, o.url),
              ),
            if (r.offers.isNotEmpty || r.imageSource != null)
              Text(
                'Fiyatlar satıcı ilanlarından alınır ve 6 saate kadar '
                'gecikebilir.${r.imageSource != null ? ' Görsel: ${r.imageSource!.host}' : ''}',
                style: muted,
              ),
          ],
        ),
      ),
    );
  }
}

class _StoreLinks extends StatelessWidget {
  const _StoreLinks({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    final links = storeSearchLinks(query);
    return SectionCard(
      title: 'Mağazalarda ara',
      icon: Icons.storefront_rounded,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final l in links)
            ActionChip(
              avatar: Icon(
                l.region == 'TR' ? Icons.flag_rounded : Icons.public_rounded,
                size: 18,
              ),
              label: Text(l.store),
              onPressed: () => _open(context, l.url),
            ),
        ],
      ),
    );
  }
}

Future<void> _open(BuildContext context, Uri url) async {
  final ok = await launchUrl(url, mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Bağlantı açılamadı.')));
  }
}
