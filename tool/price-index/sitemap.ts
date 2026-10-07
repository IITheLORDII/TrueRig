// Sitemap (sitemaps.org) reading: index files and URL sets. Pure.

export interface Sitemap {
  isIndex: boolean;
  locs: string[];
}

export function parseSitemap(xml: string): Sitemap {
  const locs = [...xml.matchAll(/<loc>\s*(?:<!\[CDATA\[)?\s*([^<\s\]]+)\s*(?:\]\]>)?\s*<\/loc>/g)]
    .map((m) => m[1].replace(/&amp;/g, "&"))
    .filter((u) => u.startsWith("https://"));
  return { isIndex: /<sitemapindex[\s>]/i.test(xml), locs };
}

/** A store's sitemap entry points and which URLs are product pages. */
export interface IndexStore {
  name: string;
  origin: string;
  sitemaps: string[];
  /** Child sitemaps of an index worth reading. */
  childFilter?: RegExp;
  /** Product page URLs. */
  productFilter: RegExp;
  /** Extra spacing for hosts that asked us to slow down before. */
  minDelayMs?: number;
}

// Only stores whose robots.txt allows product pages and that publish
// sitemaps (checked 2026-10). Search-only stores are not crawled.
export const INDEX_STORES: IndexStore[] = [
  {
    name: "İtopya",
    origin: "https://www.itopya.com",
    sitemaps: ["https://www.itopya.com/sitemap.xml"],
    childFilter: /products/,
    productFilter: /_u\d+$/,
  },
  {
    name: "Vatan Bilgisayar",
    origin: "https://www.vatanbilgisayar.com",
    sitemaps: ["https://www.vatanbilgisayar.com/sitemap.axd"],
    productFilter: /\.html$/,
    minDelayMs: 5000,
  },
  {
    name: "MediaMarkt",
    origin: "https://www.mediamarkt.com.tr",
    sitemaps: ["https://www.mediamarkt.com.tr/sitemaps/sitemap-index.xml"],
    childFilter: /productdetailspages/,
    productFilter: /\/tr\/product\//,
  },
];
