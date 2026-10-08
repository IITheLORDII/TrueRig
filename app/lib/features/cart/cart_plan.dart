import 'package:flutter/foundation.dart';
import 'package:perf_engine/perf_engine.dart';

import 'package:darbogaz/features/prices/price_repository.dart';

/// A part of the build with the store offers found for it.
@immutable
class PartOffers {
  const PartOffers(this.part, this.offers, {this.estimateTry});

  final Part part;

  /// Cheapest first.
  final List<PriceOffer> offers;

  /// List price × rate when no store price is known.
  final double? estimateTry;

  /// Cheapest in-stock offer (any offer if none is in stock).
  PriceOffer? get best {
    final inStock = offers.where((o) => o.inStock).toList();
    final pool = inStock.isEmpty ? offers : inStock;
    if (pool.isEmpty) return null;
    return pool.reduce((a, b) => a.price <= b.price ? a : b);
  }

  /// Cheapest offer from [store] (case-insensitive name match).
  PriceOffer? from(String store) {
    final hits = offers.where(
      (o) => o.store.toLowerCase() == store.toLowerCase(),
    );
    if (hits.isEmpty) return null;
    return hits.reduce((a, b) => a.price <= b.price ? a : b);
  }
}

@immutable
class BasketItem {
  const BasketItem(this.part, this.offer);

  final Part part;
  final PriceOffer offer;
}

/// What to buy at one store.
@immutable
class StoreBasket {
  const StoreBasket(this.store, this.items);

  final String store;
  final List<BasketItem> items;

  double get subtotal => items.fold(0, (s, i) => s + i.offer.price);
}

/// A way to buy the whole build: one or more store baskets plus the parts
/// no store price was found for.
@immutable
class CartPlan {
  const CartPlan(this.baskets, this.missing);

  final List<StoreBasket> baskets;
  final List<PartOffers> missing;

  double get total => baskets.fold(0, (s, b) => s + b.subtotal);

  /// Missing parts priced by their list-price estimate.
  double get missingEstimate =>
      missing.fold(0, (s, p) => s + (p.estimateTry ?? 0));

  int get pricedParts => baskets.fold(0, (s, b) => s + b.items.length);
}

/// Each part from wherever it is cheapest.
CartPlan cheapestMix(List<PartOffers> parts) {
  final byStore = <String, List<BasketItem>>{};
  final missing = <PartOffers>[];
  for (final p in parts) {
    final best = p.best;
    if (best == null) {
      missing.add(p);
      continue;
    }
    byStore.putIfAbsent(best.store, () => []).add(BasketItem(p.part, best));
  }
  final baskets = [
    for (final e in byStore.entries)
      StoreBasket(e.key, List.unmodifiable(e.value)),
  ]..sort((a, b) => b.subtotal.compareTo(a.subtotal));
  return CartPlan(List.unmodifiable(baskets), List.unmodifiable(missing));
}

/// Everything possible from a single store: most parts first, then the
/// lowest total. Null when no store has any of the parts.
CartPlan? bestSingleStore(List<PartOffers> parts) {
  final stores = {for (final p in parts) ...p.offers.map((o) => o.store)};
  CartPlan? best;
  for (final store in stores) {
    final items = <BasketItem>[];
    final missing = <PartOffers>[];
    for (final p in parts) {
      final o = p.from(store);
      if (o == null) {
        missing.add(p);
      } else {
        items.add(BasketItem(p.part, o));
      }
    }
    final plan = CartPlan([StoreBasket(store, items)], missing);
    if (best == null ||
        plan.pricedParts > best.pricedParts ||
        (plan.pricedParts == best.pricedParts && plan.total < best.total)) {
      best = plan;
    }
  }
  return best;
}

/// Amazon's official "add to cart" link: every item lands in the
/// customer's own Amazon cart, they check out on Amazon. Needs ASINs.
Uri? amazonCartUrl(
  List<String> asins, {
  String host = 'www.amazon.com.tr',
  String? associateTag,
}) {
  if (asins.isEmpty) return null;
  return Uri.https(host, '/gp/aws/cart/add.html', {
    for (var i = 0; i < asins.length; i++) ...{
      'ASIN.${i + 1}': asins[i],
      'Quantity.${i + 1}': '1',
    },
    'AssociateTag': ?associateTag,
  });
}

/// Amazon product codes for catalog parts (filled in as they are verified).
const Map<String, String> kAmazonAsins = {};
