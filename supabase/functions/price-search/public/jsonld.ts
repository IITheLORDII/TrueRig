// Extracts schema.org Product / Offer data (incl. image) from public HTML via
// JSON-LD. Stores publish this structured data for search engines; reading it
// avoids brittle CSS selectors. Pure: no I/O.

export interface SellerOffer {
  seller: string;
  price: number;
  url: string;
  inStock: boolean;
}

export interface PageProduct {
  name: string;
  url: string | null;
  imageUrl: string | null;
  brand: string | null;
  sku: string | null;
  mpn: string | null;
  gtin: string | null;
  price: number | null;
  currency: string | null;
  inStock: boolean;
  /** schema.org aggregateRating (0..5 stars) and its review count. */
  rating: number | null;
  reviewCount: number | null;
  /** Per-seller offers nested in an AggregateOffer (price aggregators). */
  sellerOffers: SellerOffer[];
}

export interface PageData {
  products: PageProduct[];
  /** Product page URLs listed by an ItemList (typical on search pages). */
  listedUrls: string[];
}

const LD_SCRIPT =
  /<script[^>]*type\s*=\s*["']application\/ld\+json["'][^>]*>([\s\S]*?)<\/script>/gi;

type Json = Record<string, unknown>;

export function extractPageData(html: string, pageUrl: string): PageData {
  const nodes: Json[] = [];
  for (const m of html.matchAll(LD_SCRIPT)) {
    try {
      collect(JSON.parse(m[1].trim()), nodes);
    } catch {
      // Malformed block on the page: skip it, other blocks may be fine.
    }
  }

  const products: PageProduct[] = [];
  const listedUrls: string[] = [];
  for (const n of nodes) {
    if (hasType(n, "Product")) {
      const p = toProduct(n, pageUrl);
      if (p) products.push(p);
    }
    if (hasType(n, "ItemList")) {
      for (const el of asArray(n.itemListElement)) {
        const item = isObj(el) && isObj(el.item) ? el.item : el;
        const url = isObj(item) ? str(item.url) : null;
        const abs = absolute(url, pageUrl);
        if (abs) listedUrls.push(abs);
      }
    }
  }
  return { products, listedUrls: [...new Set(listedUrls)] };
}

/**
 * Every object in the JSON-LD tree. Stores nest Products in @graph, in
 * ItemList entries or inside actions (MediaMarkt: BuyAction.object).
 */
function collect(value: unknown, out: Json[], depth = 0): void {
  if (depth > 12) return;
  if (Array.isArray(value)) {
    for (const v of value) collect(v, out, depth + 1);
    return;
  }
  if (!isObj(value)) return;
  out.push(value);
  for (const v of Object.values(value)) {
    if (typeof v === "object" && v !== null) collect(v, out, depth + 1);
  }
}

function toProduct(n: Json, pageUrl: string): PageProduct | null {
  const name = str(n.name);
  if (!name) return null;
  let price: number | null = null;
  let currency: string | null = null;
  let inStock = true;
  const sellerOffers: SellerOffer[] = [];
  for (const o of asArray(n.offers)) {
    if (isObj(o)) sellerOffers.push(...nestedOffers(o, pageUrl));
    if (!isObj(o)) continue;
    const p = num(o.price) ?? num(o.lowPrice);
    if (p === null || p <= 0) continue;
    if (price === null || p < price) {
      price = p;
      currency = str(o.priceCurrency);
      const availability = str(o.availability) ?? "";
      inStock = availability === "" ||
        /InStock|LimitedAvailability|OnlineOnly/i.test(availability);
    }
  }
  return {
    name,
    url: absolute(str(n.url) ?? str(n["@id"]) ?? firstOfferUrl(n), pageUrl) ??
      pageUrl,
    imageUrl: absolute(imageOf(n.image), pageUrl),
    brand: isObj(n.brand) ? str(n.brand.name) : str(n.brand),
    sku: str(n.sku),
    mpn: str(n.mpn),
    gtin: str(n.gtin13) ?? str(n.gtin) ?? str(n.gtin12) ?? str(n.gtin8),
    price,
    currency,
    inStock,
    ...ratingOf(n.aggregateRating),
    sellerOffers,
  };
}

/** Normalises aggregateRating to a 0..5 scale (bestRating may differ). */
export function ratingOf(v: unknown): { rating: number | null; reviewCount: number | null } {
  if (!isObj(v)) return { rating: null, reviewCount: null };
  const value = num(v.ratingValue);
  const best = num(v.bestRating) ?? 5;
  const count = num(v.reviewCount) ?? num(v.ratingCount);
  if (value === null || value <= 0 || best <= 0) {
    return { rating: null, reviewCount: null };
  }
  const rating = Math.round(Math.min(5, (value / best) * 5) * 10) / 10;
  return { rating, reviewCount: count === null ? null : Math.round(count) };
}

function nestedOffers(agg: Json, pageUrl: string): SellerOffer[] {
  const out: SellerOffer[] = [];
  for (const o of asArray(agg.offers)) {
    if (!isObj(o)) continue;
    const price = num(o.price);
    const url = absolute(str(o.url), pageUrl);
    const seller = isObj(o.seller) ? str(o.seller.name) : str(o.seller);
    if (price === null || price <= 0 || !url || !seller) continue;
    const availability = str(o.availability) ?? "";
    out.push({
      seller,
      price,
      url,
      inStock: availability === "" ||
        /InStock|LimitedAvailability|OnlineOnly/i.test(availability),
    });
  }
  return out;
}

/** `image` may be a URL, an ImageObject, or an array of either. */
function imageOf(v: unknown): string | null {
  for (const i of asArray(v)) {
    if (typeof i === "string" && i.trim()) return i.trim();
    if (isObj(i)) {
      const u = str(i.contentUrl) ?? str(i.url);
      if (u) return u;
    }
  }
  return null;
}

function firstOfferUrl(n: Json): string | null {
  for (const o of asArray(n.offers)) if (isObj(o) && str(o.url)) return str(o.url);
  return null;
}

function absolute(url: string | null, base: string): string | null {
  if (!url) return null;
  try {
    const u = new URL(url, base);
    return u.protocol === "https:" ? u.toString() : null;
  } catch {
    return null;
  }
}

function hasType(n: Json, type: string): boolean {
  return asArray(n["@type"]).some((t) => typeof t === "string" && t.endsWith(type));
}

const isObj = (v: unknown): v is Json =>
  typeof v === "object" && v !== null && !Array.isArray(v);
const asArray = (v: unknown): unknown[] =>
  v === undefined || v === null ? [] : Array.isArray(v) ? v : [v];
const str = (v: unknown): string | null =>
  typeof v === "string" && v.trim() !== ""
    ? decodeEntities(v).trim()
    : typeof v === "number"
    ? String(v)
    : null;

const NAMED: Record<string, string> = {
  amp: "&", quot: '"', apos: "'", lt: "<", gt: ">", nbsp: " ",
};

/** Some stores HTML-escape JSON-LD strings: "Ryzen&#x2122;" -> "Ryzen™". */
export function decodeEntities(s: string): string {
  return s.replace(/&(#x[0-9a-f]+|#\d+|[a-z]+);/gi, (m, code: string) => {
    if (code[0] === "#") {
      const n = code[1] === "x" || code[1] === "X"
        ? parseInt(code.slice(2), 16)
        : parseInt(code.slice(1), 10);
      return Number.isFinite(n) && n > 0 && n < 0x110000 ? String.fromCodePoint(n) : m;
    }
    return NAMED[code.toLowerCase()] ?? m;
  });
}

/** Accepts 12999.90, "12999.90", "12.999,90" (TR format). */
export function num(v: unknown): number | null {
  if (typeof v === "number") return Number.isFinite(v) ? v : null;
  if (typeof v !== "string") return null;
  let s = v.replace(/[^\d.,]/g, "");
  if (s === "") return null;
  if (s.includes(",") && s.lastIndexOf(",") > s.lastIndexOf(".")) {
    s = s.replace(/\./g, "").replace(",", ".");
  } else {
    s = s.replace(/,/g, "");
  }
  const n = Number(s);
  return Number.isFinite(n) ? n : null;
}
