import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:darbogaz/core/images/part_images.dart';
import 'package:darbogaz/core/theme/app_theme.dart';
import 'package:darbogaz/core/theme/tokens.dart';
import 'package:darbogaz/core/widgets/app_controls.dart';
import 'package:darbogaz/core/widgets/common.dart';
import 'package:darbogaz/core/widgets/part_thumb.dart';
import 'package:darbogaz/features/prices/price_repository.dart';

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

final priceFormat = NumberFormat.decimalPattern('tr');

String formatPrice(double price, String? currency) =>
    '${priceFormat.format(price.round())} ${currency ?? 'TRY'}';

enum StoreSort { priceAsc, priceDesc, rating, name }

extension StoreSortLabel on StoreSort {
  String get label => switch (this) {
    StoreSort.priceAsc => 'Ucuz',
    StoreSort.priceDesc => 'Pahalı',
    StoreSort.rating => 'Puan',
    StoreSort.name => 'Mağaza',
  };
}

/// One store line: a search link, plus the live offer when one was found.
@immutable
class StoreRow {
  const StoreRow({
    required this.store,
    required this.url,
    this.region,
    this.offer,
    this.outlier = false,
  });

  final String store;
  final Uri url;
  final String? region;
  final PriceOffer? offer;
  final bool outlier;
}

String _key(String s) => s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

/// Store links merged with live offers: each known store shows its cheapest
/// offer; offers from other sellers get their own rows.
List<StoreRow> mergeStores(
  List<StoreLink> links,
  PriceSearchResult? result,
  StoreSort sort,
) {
  final offers = result?.offers ?? const <PriceOffer>[];
  final used = <PriceOffer>{};
  PriceOffer? bestFor(StoreLink l) {
    final k = _key(l.store.split('.').first);
    final hits = offers.where(
      (o) => _key(o.store).contains(k) || _key(o.url.host).contains(k),
    );
    if (hits.isEmpty) return null;
    final best = hits.reduce((a, b) => a.price <= b.price ? a : b);
    used.addAll(hits);
    return best;
  }

  final rows = [
    for (final l in links)
      () {
        final o = bestFor(l);
        return StoreRow(
          store: l.store,
          region: l.region,
          url: o?.url ?? l.url,
          offer: o,
          outlier: o != null && (result?.isOutlier(o) ?? false),
        );
      }(),
    for (final o in offers)
      if (!used.contains(o))
        StoreRow(
          store: o.store,
          url: o.url,
          offer: o,
          outlier: result?.isOutlier(o) ?? false,
        ),
  ];

  int byPrice(StoreRow a, StoreRow b, {required bool asc}) {
    final x = a.offer?.price;
    final y = b.offer?.price;
    if (x == null && y == null) return a.store.compareTo(b.store);
    if (x == null) return 1;
    if (y == null) return -1;
    return asc ? x.compareTo(y) : y.compareTo(x);
  }

  rows.sort(
    (a, b) => switch (sort) {
      StoreSort.priceAsc => byPrice(a, b, asc: true),
      StoreSort.priceDesc => byPrice(a, b, asc: false),
      StoreSort.rating => () {
        final x = a.offer?.rating;
        final y = b.offer?.rating;
        if (x == null && y == null) return byPrice(a, b, asc: true);
        if (x == null) return 1;
        if (y == null) return -1;
        return y.compareTo(x);
      }(),
      StoreSort.name => a.store.toLowerCase().compareTo(b.store.toLowerCase()),
    },
  );
  return rows;
}

/// "Mağazalar": every store with its price, sortable by price / rating.
class StoreList extends ConsumerStatefulWidget {
  const StoreList({super.key, required this.query, this.showImage = false});

  final String query;

  /// True when the query is not a catalog part, so the card shows the image.
  final bool showImage;

  @override
  ConsumerState<StoreList> createState() => _StoreListState();
}

class _StoreListState extends ConsumerState<StoreList> {
  StoreSort _sort = StoreSort.priceAsc;

  @override
  Widget build(BuildContext context) {
    final configured = ref.watch(priceRepositoryProvider).isConfigured;
    final async = configured
        ? ref.watch(priceSearchProvider(widget.query))
        : null;
    final result = async?.value;
    final loading = async?.isLoading ?? false;
    final rows = mergeStores(
      storeSearchLinks(widget.query),
      result,
      _sort,
    );
    final palette = context.palette;
    final theme = Theme.of(context);
    final muted = theme.textTheme.labelSmall?.copyWith(color: palette.muted);
    final avg = result?.averagePrice;
    final cheapest = result == null || result.offers.isEmpty
        ? null
        : result.offers.first;

    return SectionCard(
      title: 'Mağazalar',
      icon: Icons.storefront_rounded,
      trailing: avg == null
          ? null
          : VerdictChip(
              'Ort. ${formatPrice(avg, result!.currency)}',
              tone: Tone.brand,
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.showImage && result?.imageUrl != null)
            Center(
              child: PartThumb(
                imageUrl: result!.imageUrl,
                fallbackIcon: Icons.inventory_2_rounded,
                size: 140,
              ),
            ),
          AppSegmented<StoreSort>(
            values: StoreSort.values,
            selected: _sort,
            labelOf: (s) => s.label,
            onChanged: (s) => setState(() => _sort = s),
          ),
          const SizedBox(height: Space.s),
          if (cheapest != null)
            Padding(
              padding: const EdgeInsets.only(bottom: Space.xs),
              child: Text(
                'En düşük ${formatPrice(cheapest.price, cheapest.currency)} '
                '(${cheapest.store}) · ${result!.offers.length} teklif',
                style: theme.textTheme.labelMedium,
              ),
            ),
          if (async?.hasError ?? false)
            Text(
              async!.error is PriceApiException
                  ? (async.error! as PriceApiException).message
                  : 'Fiyatlar alınamadı.',
              style: TextStyle(color: palette.bad),
            ),
          for (final r in rows)
            _StoreTile(row: r, loading: loading && r.offer == null),
          const SizedBox(height: Space.xs),
          Text(
            configured
                ? 'Fiyatlar mağazaların herkese açık sayfalarından okunur ve '
                      '6 saate kadar gecikebilir. Fiyatı olmayan mağazada '
                      'dokununca arama sonucu açılır.'
                      '${result?.imageSource != null ? ' Görsel: ${result!.imageSource!.host}' : ''}'
                : 'Canlı fiyatlar fiyat servisi bağlanınca burada görünür; '
                      'şimdilik dokununca mağazanın arama sonucu açılır.',
            style: muted,
          ),
        ],
      ),
    );
  }
}

class _StoreTile extends StatelessWidget {
  const _StoreTile({required this.row, required this.loading});

  final StoreRow row;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);
    final o = row.offer;
    final details = [
      if (row.region != null) row.region!,
      if (o != null) o.inStock ? 'Stokta' : 'Stokta yok',
      if (row.outlier) 'olağan dışı fiyat',
    ];
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        row.region == 'Global' ? Icons.public_rounded : Icons.store_rounded,
        color: o == null ? palette.muted : theme.colorScheme.primary,
      ),
      title: Row(
        children: [
          Flexible(child: Text(row.store, overflow: TextOverflow.ellipsis)),
          if (o?.rating != null) ...[
            const SizedBox(width: Space.xs),
            Icon(Icons.star_rounded, size: 14, color: palette.warn),
            Text(
              o!.rating!.toStringAsFixed(1),
              style: theme.textTheme.labelSmall,
            ),
            if (o.reviewCount != null)
              Text(
                ' (${o.reviewCount})',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: palette.muted,
                ),
              ),
          ],
        ],
      ),
      subtitle: details.isEmpty
          ? null
          : Text(
              details.join(' · '),
              style: row.outlier ? TextStyle(color: palette.warn) : null,
            ),
      trailing: loading
          ? const SizedBox(width: 72, child: SkeletonBar(width: 72))
          : o == null
          ? Text(
              'Fiyatı gör ›',
              style: TextStyle(color: theme.colorScheme.primary),
            )
          : Text(
              formatPrice(o.price, o.currency),
              style: numberStyle(
                context,
                size: 15,
                color: row.outlier ? palette.warn : null,
              ),
            ),
      onTap: () => openStoreUrl(context, row.url),
    );
  }
}

Future<void> openStoreUrl(BuildContext context, Uri url) async {
  final ok = await launchUrl(url, mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Bağlantı açılamadı.')));
  }
}
