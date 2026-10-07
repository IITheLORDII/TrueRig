// Turns a query into offers + an identifier-matched product image by reading
// public store pages through PoliteFetcher. No Deno APIs: testable in Node.

import { extractPageData, type PageProduct } from "./jsonld.ts";
import { matchKind } from "./match.ts";
import type { PoliteFetcher } from "./polite_fetch.ts";
import type { StoreConfig } from "./stores.ts";

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
  let products = page.products.filter((p) => matchKind(p, query) !== "none");

  if (!products.some((p) => p.price !== null)) {
    for (const url of productLinks(page.listedUrls, first.html, searchUrl, store, query)) {
      const res = await fetcher.get(url);
      if (res.kind !== "ok") continue;
      products = products.concat(
        extractPageData(res.html, url).products.filter((p) => matchKind(p, query) !== "none"),
      );
    }
  }

  return {
    offers: dedupe(products.flatMap((p) => toOffers(store.name, p))),
    image: imageFrom(store.name, products, query),
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

/** Aggregator pages yield one offer per seller; shops yield their own. */
function toOffers(store: string, p: PageProduct): Offer[] {
  const currency = (p.currency ?? "TRY").toUpperCase().slice(0, 3);
  if (p.sellerOffers.length > 0) {
    return p.sellerOffers
      .filter((o) => o.url.startsWith("https://"))
      .map((o) => ({
        store: o.seller, price: o.price, currency, url: o.url, in_stock: o.inStock,
        rating: p.rating, review_count: p.reviewCount,
      }));
  }
  if (p.price === null || p.price <= 0 || !p.url?.startsWith("https://")) return [];
  return [{
    store, price: p.price, currency, url: p.url, in_stock: p.inStock,
    rating: p.rating, review_count: p.reviewCount,
  }];
}

function dedupe(offers: Offer[]): Offer[] {
  const seen = new Set<string>();
  return offers.filter((o) => (seen.has(o.url) ? false : (seen.add(o.url), true)));
}

function imageFrom(store: string, products: PageProduct[], query: string): ImageHit | null {
  for (const p of products) {
    if (p.imageUrl && matchKind(p, query) === "identifier") {
      return { url: p.imageUrl, sourceUrl: p.url ?? "", store };
    }
  }
  return null;
}
