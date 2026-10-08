import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:perf_engine/perf_engine.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:darbogaz/core/widgets/page_nav.dart';
import 'package:darbogaz/core/brand/truerig_logo.dart';
import 'package:darbogaz/core/providers.dart';
import 'package:darbogaz/core/theme/app_theme.dart';
import 'package:darbogaz/core/theme/tokens.dart';
import 'package:darbogaz/core/widgets/app_controls.dart';
import 'package:darbogaz/core/widgets/buttons.dart';
import 'package:darbogaz/core/widgets/cards.dart';
import 'package:darbogaz/core/widgets/common.dart';
import 'package:darbogaz/core/widgets/flow.dart';
import 'package:darbogaz/core/widgets/part_labels.dart';
import 'package:darbogaz/features/cart/cart_plan.dart';
import 'package:darbogaz/features/prices/price_repository.dart';
import 'package:darbogaz/features/prices/store_list.dart';
import 'package:darbogaz/features/sandbox/sandbox_state.dart';

/// Store offers for every part of a build, keyed by comma-joined part ids.
final cartOffersProvider = FutureProvider.family<List<PartOffers>, String>((
  ref,
  key,
) async {
  final catalog = ref.watch(catalogProvider);
  final repo = ref.watch(priceRepositoryProvider);
  final parts = [
    for (final id in key.split(','))
      if (catalog.byId(id) case final Part p) p,
  ];
  Future<PartOffers> lookup(Part p) async {
    try {
      final r = await repo.search(p.mpn ?? p.displayName);
      return PartOffers(p, r.offers, estimateTry: r.estimateTry);
    } on PriceApiException catch (e) {
      debugPrint('Fiyat alınamadı (${p.displayName}): ${e.message}');
      return PartOffers(p, const []);
    }
  }

  return Future.wait(parts.map(lookup));
});

enum _Mode { cheapest, single }

/// "Sepeti hazırla": where to buy every part of a build, store by store.
/// [fromSandbox] uses the scratch-area PC instead of the user's own.
class CartPage extends ConsumerStatefulWidget {
  const CartPage({super.key, this.fromSandbox = false});

  final bool fromSandbox;

  @override
  ConsumerState<CartPage> createState() => _CartPageState();
}

class _CartPageState extends ConsumerState<CartPage> {
  _Mode _mode = _Mode.cheapest;

  @override
  Widget build(BuildContext context) {
    final PcBuild build = widget.fromSandbox
        ? ref.watch(sandboxProvider).pcs[0].build
        : ref.watch(buildProvider);
    final label = widget.fromSandbox
        ? ref.watch(sandboxProvider).pcs[0].label
        : ref.watch(prebuiltProvider)?.label;
    final key = build.parts.map((p) => p.id).join(',');
    final gpu = build.gpu;

    // A laptop's processor and graphics are not sold on their own: price the
    // system itself.
    if (isLaptopBuild(build.cpu, gpu)) {
      final system = (label ?? '').split(' · ').first;
      return Scaffold(
        appBar: AppBar(
          leading: const PageBackButton(),
          title: const BrandTitle('Sepeti hazırla'),
          actions: const [HomeButton()],
        ),
        body: ListView(
          padding: Insets.page,
          children: [
            Text(
              'Dizüstü bilgisayarların parçaları ayrı satılmaz; '
              '${system.isEmpty ? 'sistemin' : system} fiyatlarına bakalım.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: Space.s),
            StoreList(
              query: system.isEmpty
                  ? '${build.cpu?.model ?? ''} ${gpu?.model ?? ''}'.trim()
                  : system,
              showImage: true,
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: const PageBackButton(),
        title: const BrandTitle('Sepeti hazırla'),
        actions: const [HomeButton()],
      ),
      body: build.parts.isEmpty
          ? StatView.empty(
              icon: Icons.shopping_cart_outlined,
              message: 'Önce parçalarını seç.',
              actionLabel: 'Parça seç',
              onAction: () => context.go('/devices?kind=pc'),
            )
          : ref
                .watch(cartOffersProvider(key))
                .when(
                  loading: () => const StatView.loading(lines: 5),
                  error: (e, _) => StatView.error(
                    onAction: () => ref.invalidate(cartOffersProvider(key)),
                  ),
                  data: (parts) => _body(parts),
                ),
    );
  }

  Widget _body(List<PartOffers> parts) {
    final mix = cheapestMix(parts);
    final single = bestSingleStore(parts);
    final plan = _mode == _Mode.single && single != null ? single : mix;
    final asins = [
      for (final p in parts)
        if (kAmazonAsins[p.part.id] case final String a) a,
    ];
    final amazon = amazonCartUrl(asins);

    final list = ListView(
      padding: Insets.page,
      children: [
        _Summary(parts: parts, mix: mix, single: single),
        const SizedBox(height: Space.s),
        if (single != null && mix.baskets.length > 1) ...[
          AppSegmented<_Mode>(
            values: _Mode.values,
            selected: _mode,
            labelOf: (m) =>
                m == _Mode.cheapest ? 'En ucuz (karışık)' : 'Tek mağazadan',
            onChanged: (m) => setState(() => _mode = m),
          ),
          const SizedBox(height: Space.s),
        ],
        for (final b in plan.baskets) ...[
          _BasketCard(basket: b),
          const SizedBox(height: Space.s),
        ],
        if (plan.missing.isNotEmpty) ...[
          _MissingCard(parts: plan.missing),
          const SizedBox(height: Space.s),
        ],
        if (amazon != null) ...[
          NavCard(
            icon: Icons.shopping_cart_checkout_rounded,
            title: '${asins.length} parçayı Amazon sepetine ekle',
            subtitle: 'Amazon sepetin açılır, ödemeyi orada yaparsın.',
            trailing: const Icon(Icons.open_in_new_rounded),
            onTap: () => openStoreUrl(context, amazon),
          ),
          const SizedBox(height: Space.s),
        ],
        const Footnote(
          'Mağazalar dışarıdan sepete ekleme izni vermiyor. Ürün sayfaları '
          'açılır, sepete eklemeyi orada tek dokunuşla yaparsın. Fiyatlar '
          'her gün güncellenir.',
        ),
      ],
    );
    if (plan.baskets.isEmpty) return list;
    return Column(
      children: [
        Expanded(child: list),
        StickyActionBar(
          leading: Row(
            children: [
              Expanded(
                child: Text(
                  'Toplam',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              Text(
                '~${formatPrice(plan.total, 'TRY')}',
                style: numberStyle(context, size: 20),
              ),
            ],
          ),
          primary: PrimaryButton(
            icon: Icons.open_in_new_rounded,
            label: plan.baskets.length == 1
                ? '${plan.baskets.first.store}\'da aç'
                : '${plan.baskets.length} mağazada aç',
            onPressed: () async {
              for (final b in plan.baskets) {
                if (!await openBasket(b)) break;
              }
            },
          ),
        ),
      ],
    );
  }
}

/// Opens every product page of a store basket; false when one fails.
Future<bool> openBasket(StoreBasket basket) async {
  for (final i in basket.items) {
    final ok = await launchUrl(
      i.offer.url,
      mode: LaunchMode.externalApplication,
    );
    if (!ok) return false;
  }
  return true;
}

class _Summary extends StatelessWidget {
  const _Summary({required this.parts, required this.mix, this.single});

  final List<PartOffers> parts;
  final CartPlan mix;
  final CartPlan? single;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = single;
    final estimate = mix.missingEstimate;
    return SectionCard(
      hero: true,
      title: 'Özet',
      icon: Icons.shopping_cart_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (mix.pricedParts == 0)
            Text(
              estimate > 0
                  ? 'Tahmini ~${formatPrice(estimate, 'TRY')}'
                  : 'Henüz mağaza fiyatı yok',
              style: numberStyle(context, size: 26),
            )
          else
            Text(
              '~${formatPrice(mix.total, 'TRY')}',
              style: numberStyle(context, size: 30),
            ),
          const SizedBox(height: Space.xs),
          Text(
            mix.pricedParts == 0
                ? (estimate > 0
                      ? 'Mağaza fiyatı bulunamadı; liste fiyatı × kur ile tahmin.'
                      : 'Fiyat listesi şu an alınamadı; parçaları aşağıdan '
                            'mağazalarda arayabilirsin.')
                : '${parts.length} parçadan ${mix.pricedParts} tanesi, '
                      '${mix.baskets.length} mağazadan en ucuz şekilde.'
                      '${mix.missing.isEmpty ? '' : ' Fiyatı bulunamayanlar hariç.'}',
            style: theme.textTheme.bodyMedium,
          ),
          if (s != null && mix.baskets.length > 1)
            Padding(
              padding: const EdgeInsets.only(top: Space.xs),
              child: Text(
                'Tek mağazadan: ${s.baskets.first.store} '
                '~${formatPrice(s.total, 'TRY')} '
                '(${s.pricedParts}/${parts.length} parça)',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: context.palette.muted,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _BasketCard extends StatelessWidget {
  const _BasketCard({required this.basket});

  final StoreBasket basket;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: basket.store,
      icon: Icons.storefront_rounded,
      trailing: VerdictChip(
        formatPrice(basket.subtotal, 'TRY'),
        tone: Tone.brand,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final i in basket.items)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(i.part.category.icon),
              title: Text(i.part.displayName),
              subtitle: Text(
                [
                  if (i.offer.title != null) i.offer.title!,
                  i.offer.inStock ? 'Stokta' : 'Stokta yok',
                ].join(' · '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Text(
                formatPrice(i.offer.price, i.offer.currency),
                style: numberStyle(context, size: 14),
              ),
              onTap: () => openStoreUrl(context, i.offer.url),
            ),
          const SizedBox(height: Space.xs),
          SecondaryButton(
            expand: true,
            onPressed: () => openBasket(basket),
            icon: Icons.open_in_new_rounded,
            label: basket.items.length == 1
                ? '${basket.store}\'da ürünü aç'
                : '${basket.store}\'da ${basket.items.length} ürünü aç',
          ),
        ],
      ),
    );
  }
}

class _MissingCard extends StatelessWidget {
  const _MissingCard({required this.parts});

  final List<PartOffers> parts;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Fiyatı bulunamayanlar',
      icon: Icons.search_off_rounded,
      child: Column(
        children: [
          for (final p in parts)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(p.part.category.icon),
              title: Text(p.part.displayName),
              subtitle: Text(
                p.estimateTry == null
                    ? 'Mağazalarda ara'
                    : 'Tahmini ~${formatPrice(p.estimateTry!, 'TRY')} · '
                          'mağazalarda ara',
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => context.go(
                '/prices?q=${Uri.encodeQueryComponent(p.part.mpn ?? p.part.displayName)}',
              ),
            ),
        ],
      ),
    );
  }
}
