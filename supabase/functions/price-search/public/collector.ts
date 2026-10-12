// Turns a query into offers + an identifier-matched product image by reading
// public store pages through PoliteFetcher. No Deno APIs: testable in Node.

import { extractPageData, type PageProduct } from "./jsonld.ts";
import { matchKind } from "./match.ts";
import type { PoliteFetcher } from "./polite_fetch.ts";
import type { StoreConfig } from "./stores.ts";
import { isTrustedStoreUrl, sameSite } from "./url_safety.ts";

export interface Offer {
  store: string;
  price: number;
  currency: string;
  url: string;
  in_stock: boolean;
  rating: number | null;
  review_count: number | null;
}

export interface ImageHit {
  url: string;
  sourceUrl: string;
  store: string;
}

export interface CollectResult {
  offers: Offer[];
  /** Only set when a product's MPN/SKU/GTIN equals the query. */
  image: ImageHit | null;
  skipped: { store: string; reason: string }[];
}

/** Product pages followed per store when the search page lacks prices. */
const MAX_FOLLOW_UPS = 2;

export async function collect(
  query: string,
  stores: StoreConfig[],
  fetcher: PoliteFetcher,
): Promise<CollectResult> {
  const perStore = await Promise.all(stores.map((s) => collectStore(query, s, fetcher)));
  const offers = perStore.flatMap((r) => r.offers).sort((a, b) => a.price - b.price);
  const image = perStore.map((r) => r.image).find((i) => i !== null) ?? null;
  const skipped = perStore.flatMap((r) => r.skipped);
  return { offers, image, skipped };
}

async function collectStore(
  query: string,
  store: StoreConfig,
  fetcher: PoliteFetcher,
): Promise<CollectResult> {
  const searchUrl = store.searchUrl(query);
  const first = await fetcher.get(searchUrl);
  if (first.kind !== "ok") {
    return { offers: [], image: null, skipped: [{ store: store.name, reason: first.kind }] };
  }
  const page = extractPageData(first.html, searchUrl);
  // Each product with the (same-site) page it was read from.
  let found: Array<{ p: PageProduct; page: string }> = page.products
    .filter((p) => matchKind(p, query) !== "none")
    .map((p) => ({ p, page: searchUrl }));

  if (!found.some((f) => f.p.price !== null)) {
    for (const url of productLinks(page.listedUrls, first.html, searchUrl, store, query)) {
      const res = await fetcher.get(url);
      if (res.kind !== "ok") continue;
      found = found.concat(
        extractPageData(res.html, url).products
          .filter((p) => matchKind(p, query) !== "none")
          .map((p) => ({ p, page: url })),
      );
    }
  }

  const products = found.map((f) => f.p);
  return {
    offers: dedupe(found.flatMap((f) => toOffers(store, f.p, f.page))),
    image: imageFrom(store, products, query),
    skipped: [],
  };
}

/**
 * Same-origin product page URLs worth following: JSON-LD ItemList entries
 * first, otherwise links matched by the store's pattern whose slug already
 * looks like the requested product.
 */
export function productLinks(
  listed: string[],
  html: string,
  pageUrl: string,
  store: StoreConfig,
  query: string,
): string[] {
  const sameOrigin = (u: string) => new URL(u).origin === store.origin;
  if (listed.length > 0) return listed.filter(sameOrigin).slice(0, MAX_FOLLOW_UPS);
  if (!store.productLinkPattern) return [];
  const urls = new Set<string>();
  for (const m of html.matchAll(store.productLinkPattern)) {
    const url = new URL(m[1], pageUrl).toString();
    const slug = decodeURIComponent(new URL(url).pathname).replace(/[-/,.]/g, " ");
    const pseudo = { ...EMPTY_PRODUCT, name: slug };
    if (sameOrigin(url) && matchKind(pseudo, query) !== "none") urls.add(url);
    if (urls.size >= MAX_FOLLOW_UPS) break;
  }
  return [...urls];
}

const EMPTY_PRODUCT: PageProduct = {
  name: "", url: null, imageUrl: null, brand: null, sku: null, mpn: null,
  gtin: null, price: null, currency: null, inStock: true, rating: null,
  reviewCount: null, sellerOffers: [],
};

/**
 * Aggregator pages yield one offer per seller; shops yield their own.
 * Offer links must stay on the store's own site or a trusted store; any
 * other link is replaced by the page the offer was read from, so a crafted
 * page can never send people to a look-alike site.
 */
function toOffers(store: StoreConfig, p: PageProduct, page: string): Offer[] {
  const currency = (p.currency ?? "TRY").toUpperCase().slice(0, 3);
  const safe = (u: string | null) =>
    u && u.startsWith("https://") && (sameSite(u, store.origin) || isTrustedStoreUrl(u))
      ? u
      : page;
  if (p.sellerOffers.length > 0) {
    return p.sellerOffers.map((o) => ({
      store: o.seller, price: o.price, currency, url: safe(o.url), in_stock: o.inStock,
      rating: p.rating, review_count: p.reviewCount,
    }));
  }
  if (p.price === null || p.price <= 0) return [];
  return [{
    store: store.name, price: p.price, currency, url: safe(p.url), in_stock: p.inStock,
    rating: p.rating, review_count: p.reviewCount,
  }];
}

function dedupe(offers: Offer[]): Offer[] {
  const seen = new Set<string>();
  // Seller + link: several sellers may share the aggregator page link.
  const key = (o: Offer) => `${o.store}|${o.url}`;
  return offers.filter((o) => (seen.has(key(o)) ? false : (seen.add(key(o)), true)));
}

function imageFrom(store: StoreConfig, products: PageProduct[], query: string): ImageHit | null {
  for (const p of products) {
    if (p.imageUrl?.startsWith("https://") && matchKind(p, query) === "identifier") {
      // The source link is shown in the app: only the store's own pages.
      const source = p.url && sameSite(p.url, store.origin) ? p.url : store.origin;
      return { url: p.imageUrl, sourceUrl: source, store: store.name };
    }
  }
  return null;
}
