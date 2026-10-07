// Builds the public price index: for every catalog item, the cheapest offer
// per store, read from product pages that robots.txt allows. Product URLs
// come from the stores' sitemaps (search pages are closed to bots).
// Network goes through PoliteFetcher (robots, Crawl-delay, backoff).

import { extractPageData } from "../../supabase/functions/price-search/public/jsonld.ts";
import type { PoliteFetcher } from "../../supabase/functions/price-search/public/polite_fetch.ts";
import { type IndexStore, parseSitemap } from "./sitemap.ts";
import { bestUrls, matchScore, type PriceItem } from "./slug_match.ts";

export interface IndexOffer {
  store: string;
  price: number;
  currency: string;
  url: string;
  in_stock: boolean;
  rating: number | null;
  review_count: number | null;
  /** Product title on the store page (shows the exact configuration). */
  title: string;
  fetched_at: string;
}

export interface IndexEntry {
  name: string;
  kind: string;
  mpn?: string;
  ref_usd?: number;
  offers: IndexOffer[];
  /** Per store: when this item was last looked up there. */
  checked: Record<string, string>;
}

export interface StoreStatus {
  name: string;
  status: "ok" | "unavailable";
  reason?: string;
  product_urls: number;
  requests: number;
}

export interface PriceIndex {
  version: 1;
  generated_at: string;
  usd_try: number | null;
  stores: StoreStatus[];
  items: Record<string, IndexEntry>;
}

export interface BuildOptions {
  items: PriceItem[];
  stores: IndexStore[];
  fetcher: PoliteFetcher;
  previous?: PriceIndex | null;
  now: () => Date;
  /** Product page requests per store and run (keeps the crawl small). */
  requestsPerStore: number;
  /** Product pages tried per item and store. */
  urlsPerItem?: number;
  /** Child sitemaps read per store. */
  maxChildSitemaps?: number;
  log?: (msg: string) => void;
}

/** Offers older than this are dropped when not refreshed. */
const MAX_OFFER_AGE_MS = 7 * 86400_000;

export async function buildIndex(o: BuildOptions): Promise<PriceIndex> {
  const log = o.log ?? (() => {});
  const items = mergeItems(o.items, o.previous?.items ?? {});
  const rate = await usdTry(o.fetcher, o.previous?.usd_try ?? null);
  const statuses = await Promise.all(
    o.stores.map((s) => crawlStore(s, o, items, rate, log)),
  );
  const cutoff = o.now().getTime() - MAX_OFFER_AGE_MS;
  for (const e of Object.values(items)) {
    e.offers = e.offers
      .filter((x) => Date.parse(x.fetched_at) >= cutoff)
      .sort((a, b) => a.price - b.price);
  }
  return {
    version: 1,
    generated_at: o.now().toISOString(),
    usd_try: rate,
    stores: statuses,
    items,
  };
}

/** Current catalog items, keeping earlier offers and check times. */
function mergeItems(
  items: PriceItem[],
  previous: Record<string, IndexEntry>,
): Record<string, IndexEntry> {
  const out: Record<string, IndexEntry> = {};
  for (const it of items) {
    const prev = previous[it.key];
    out[it.key] = {
      name: it.name,
      kind: it.kind,
      ...(it.mpn ? { mpn: it.mpn } : {}),
      ...(it.ref_usd ? { ref_usd: it.ref_usd } : {}),
      offers: prev?.offers ? [...prev.offers] : [],
      checked: { ...(prev?.checked ?? {}) },
    };
  }
  return out;
}

async function crawlStore(
  store: IndexStore,
  o: BuildOptions,
  entries: Record<string, IndexEntry>,
  usdTryRate: number | null,
  log: (msg: string) => void,
): Promise<StoreStatus> {
  const urls = await productUrls(store, o.fetcher, o.maxChildSitemaps ?? 40);
  if (typeof urls === "string") {
    log(`${store.name}: sitemap unavailable (${urls})`);
    return { name: store.name, status: "unavailable", reason: urls, product_urls: 0, requests: 0 };
  }
  log(`${store.name}: ${urls.length} product URLs`);

  // Least recently checked first, so every run moves the whole list along.
  const order = [...o.items].sort((a, b) =>
    (entries[a.key].checked[store.name] ?? "").localeCompare(entries[b.key].checked[store.name] ?? "")
  );
  let requests = 0;
  for (const item of order) {
    if (requests >= o.requestsPerStore) break;
    const entry = entries[item.key];
    const candidates = bestUrls(item, urls, o.urlsPerItem ?? 2);
    let best: IndexOffer | null = null;
    for (const url of candidates) {
      if (requests >= o.requestsPerStore) break;
      requests++;
      const res = await o.fetcher.get(url);
      if (res.kind === "backing-off" || res.kind === "blocked-by-robots") {
        log(`${store.name}: stopping (${res.kind})`);
        return { name: store.name, status: "ok", reason: res.kind, product_urls: urls.length, requests };
      }
      if (res.kind !== "ok") continue;
      const offer = offerFrom(store.name, item, url, res.html, o.now());
      if (!offer || !plausible(offer, item, usdTryRate)) continue;
      if (best === null || offer.price < best.price) best = offer;
    }
    entry.offers = entry.offers.filter((x) => x.store !== store.name);
    if (best) entry.offers.push(best);
    entry.checked[store.name] = o.now().toISOString();
  }
  return { name: store.name, status: "ok", product_urls: urls.length, requests };
}

/**
 * Drops prices far from list price × exchange rate: usually a wrong
 * product (cable, used item) or a placeholder price.
 */
export function plausible(offer: IndexOffer, item: PriceItem, usdTryRate: number | null): boolean {
  if (!item.ref_usd || !usdTryRate || offer.currency !== "TRY") return true;
  const expected = item.ref_usd * usdTryRate;
  return offer.price >= expected * 0.45 && offer.price <= expected * 3;
}

/** Product page -> offer, when the page really is this item. */
export function offerFrom(
  store: string,
  item: PriceItem,
  url: string,
  html: string,
  now: Date,
): IndexOffer | null {
  for (const p of extractPageData(html, url).products) {
    if (p.price === null || p.price <= 0) continue;
    if (matchScore(item, p.name) === null) continue;
    return {
      store,
      price: p.price,
      currency: (p.currency ?? "TRY").toUpperCase().slice(0, 3),
      url: p.url?.startsWith("https://") ? p.url : url,
      in_stock: p.inStock,
      rating: p.rating,
      review_count: p.reviewCount,
      title: p.name.slice(0, 160),
      fetched_at: now.toISOString(),
    };
  }
  return null;
}

/** All product URLs from a store's sitemaps, or the failure reason. */
async function productUrls(
  store: IndexStore,
  fetcher: PoliteFetcher,
  maxChildren: number,
): Promise<string[] | string> {
  const out = new Set<string>();
  let lastError = "no sitemap";
  for (const root of store.sitemaps) {
    const res = await fetcher.get(root);
    if (res.kind !== "ok") {
      lastError = res.kind === "http-error" ? `http ${res.status}` : res.kind;
      continue;
    }
    const map = parseSitemap(res.html);
    const pages = map.isIndex
      ? map.locs.filter((u) => !store.childFilter || store.childFilter.test(u)).slice(0, maxChildren)
      : [];
    if (!map.isIndex) addProducts(map.locs, store, out);
    for (const child of pages) {
      const c = await fetcher.get(child);
      if (c.kind === "ok") addProducts(parseSitemap(c.html).locs, store, out);
      else if (c.kind === "backing-off") break;
    }
  }
  return out.size > 0 ? [...out] : lastError;
}

function addProducts(locs: string[], store: IndexStore, out: Set<string>): void {
  for (const u of locs) {
    if (u.startsWith(store.origin) && store.productFilter.test(u)) out.add(u);
  }
}

/** Central Bank of Turkey public rate (USD forex selling), for estimates. */
async function usdTry(fetcher: PoliteFetcher, fallback: number | null): Promise<number | null> {
  const res = await fetcher.get("https://www.tcmb.gov.tr/kurlar/today.xml");
  if (res.kind !== "ok") return fallback;
  return parseUsdTry(res.html) ?? fallback;
}

export function parseUsdTry(xml: string): number | null {
  const block = xml.match(/<Currency[^>]*CurrencyCode="USD"[\s\S]*?<\/Currency>/);
  const sell = block?.[0].match(/<ForexSelling>\s*([\d.]+)\s*<\/ForexSelling>/);
  const n = sell ? Number(sell[1]) : NaN;
  return Number.isFinite(n) && n > 0 ? n : null;
}
