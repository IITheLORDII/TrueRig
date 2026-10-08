import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:darbogaz/core/images/part_images.dart';
import 'package:darbogaz/core/theme/app_theme.dart';
import 'package:darbogaz/core/theme/tokens.dart';
import 'package:darbogaz/core/widgets/app_controls.dart';
import 'package:darbogaz/core/widgets/buttons.dart';
import 'package:darbogaz/core/widgets/cards.dart';
import 'package:darbogaz/core/widgets/common.dart';
import 'package:darbogaz/core/widgets/flow.dart';
import 'package:darbogaz/core/widgets/part_thumb.dart';
import 'package:darbogaz/features/prices/price_index.dart';
import 'package:darbogaz/features/prices/price_repository.dart';

/// The published daily price index (also the source of the USD/TRY rate).
final priceIndexProvider = Provider<IndexPriceRepository>(
  (ref) => IndexPriceRepository(),
);

/// Daily published index (always on) plus the live service when deployed.
final priceRepositoryProvider = Provider<PriceRepository>(
  (ref) => CombinedPriceRepository([
    ref.watch(priceIndexProvider),
    RemotePriceRepository(),
  ]),
);

/// Used when the price index cannot be read (offline, not published yet).
const double kFallbackUsdTry = 41;

/// Today's USD/TRY selling rate from the price index, or the fallback.
final usdTryProvider = FutureProvider<double>((ref) async {
  try {
    final data = await ref.watch(priceIndexProvider).load();
    return data.usdTry ?? kFallbackUsdTry;
  } on Object catch (e) {
    debugPrint('Kur alınamadı, tahmini kur kullanılıyor: $e');
    return kFallbackUsdTry;
  }
});

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

/// How the cheapest offer compares with the usual price (list price ×
/// today's rate): within ±8 % is normal.
(String, Tone)? priceLevel(double cheapest, double? usual) {
  if (usual == null || usual <= 0) return null;
  final r = cheapest / usual;
  if (r < 0.92) return ('Uygun fiyat', Tone.good);
  if (r > 1.08) return ('Pahalı', Tone.warn);
  return ('Normal fiyat', Tone.neutral);
}

String _stamp(DateTime at) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(at.day)}.${two(at.month)} ${two(at.hour)}:${two(at.minute)}';
}

/// "Mağazalar": the cheapest price up top, then every store with its price,
/// sortable by price / rating.
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
    final rows = mergeStores(storeSearchLinks(widget.query), result, _sort);
    final priced = [
      for (final r in rows)
        if (r.offer != null) r,
    ];
    final unpriced = [
      for (final r in rows)
        if (r.offer == null) r,
    ]..sort((a, b) => a.store.toLowerCase().compareTo(b.store.toLowerCase()));
    final at = result?.updatedAt?.toLocal();

    return SectionCard(
      title: 'Mağazalar',
      icon: Icons.storefront_rounded,
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
          if (result != null) _PriceSummary(result: result),
          if (async?.hasError ?? false)
            Notice(
              title: async!.error is PriceApiException
                  ? (async.error! as PriceApiException).message
                  : 'Fiyatlar alınamadı.',
              tone: Tone.bad,
              action: TertiaryButton(
                label: 'Tekrar dene',
                icon: Icons.refresh_rounded,
                onPressed: () =>
                    ref.invalidate(priceSearchProvider(widget.query)),
              ),
            ),
          if (priced.length > 1) ...[
            const SizedBox(height: Space.m),
            AppSegmented<StoreSort>(
              values: StoreSort.values,
              selected: _sort,
              labelOf: (s) => s.label,
              onChanged: (s) => setState(() => _sort = s),
            ),
            const SizedBox(height: Space.s),
          ],
          for (final r in priced) _StoreTile(row: r),
          if (loading && priced.isEmpty) const StatView.loading(lines: 3),
          if (unpriced.isNotEmpty)
            Theme(
              data: Theme.of(context)
                  .copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                initiallyExpanded: priced.isEmpty,
                title: Text(
                  priced.isEmpty
                      ? 'Otomatik fiyat bulunamadı, mağazada ara'
                      : 'Diğer mağazalar (${unpriced.length})',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                subtitle: priced.isEmpty
                    ? null
                    : const Text('Fiyatları otomatik okunamıyor'),
                children: [for (final r in unpriced) _StoreTile(row: r)],
              ),
            ),
          const SizedBox(height: Space.xs),
          Footnote(
            [
              'Fiyatlar her gün mağazaların herkese açık ürün sayfalarından '
                  'okunur. Son fiyat için mağazaya bak.',
              if (at != null) 'Son güncelleme: ${_stamp(at)}.',
              if (result?.imageSource != null)
                'Görsel: ${result!.imageSource!.host}',
            ].join(' '),
          ),
        ],
      ),
    );
  }
}

/// Cheapest price in large type, with a "normal / cheap / expensive" label.
class _PriceSummary extends StatelessWidget {
  const _PriceSummary({required this.result});

  final PriceSearchResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: context.palette.muted,
    );
    final cheapest = result.offers.isEmpty ? null : result.offers.first;
    if (cheapest == null) {
      final est = result.estimateTry;
      if (est == null) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(bottom: Space.s),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tahmini piyasa fiyatı', style: muted),
            Text(
              '~${formatPrice(est, 'TRY')}',
              style: numberStyle(context, size: 26),
            ),
            Text('Liste fiyatı × bugünkü kur', style: muted),
          ],
        ),
      );
    }
    final level = priceLevel(cheapest.price, result.estimateTry);
    final avg = result.averagePrice;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('En düşük fiyat', style: muted),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: Space.s,
          runSpacing: Space.xs,
          children: [
            Text(
              formatPrice(cheapest.price, cheapest.currency),
              style: numberStyle(context, size: 30),
            ),
            if (level != null) VerdictChip(level.$1, tone: level.$2),
          ],
        ),
        Text(
          [
            cheapest.store,
            '${result.offers.length} teklif',
            if (avg != null) 'ortalama ${formatPrice(avg, result.currency)}',
          ].join(' · '),
          style: muted,
        ),
      ],
    );
  }
}

class _StoreTile extends StatelessWidget {
  const _StoreTile({required this.row});

  final StoreRow row;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);
    final o = row.offer;
    final details = [
      if (o?.title != null) o!.title!,
      if (row.region != null) row.region!,
      if (o != null) o.inStock ? 'Stokta' : 'Stokta yok',
      if (row.outlier) 'olağan dışı fiyat',
    ];
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: IconTile(
        row.region == 'Global' ? Icons.public_rounded : Icons.store_rounded,
        size: 40,
        color: o == null ? palette.muted : theme.colorScheme.primary,
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(
              row.store,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall,
            ),
          ),
          if (o?.rating != null) ...[
            const SizedBox(width: Space.xs),
            Icon(Icons.star_rounded, size: 16, color: palette.warn),
            Text(
              o!.rating!.toStringAsFixed(1),
              style: theme.textTheme.labelMedium,
            ),
            if (o.reviewCount != null)
              Text(
                ' (${o.reviewCount})',
                style: theme.textTheme.labelMedium?.copyWith(
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
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: row.outlier ? TextStyle(color: palette.warn) : null,
            ),
      trailing: o == null
          ? Icon(Icons.open_in_new_rounded, size: 18, color: palette.muted)
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
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Bağlantı açılamadı.')));
  }
}
