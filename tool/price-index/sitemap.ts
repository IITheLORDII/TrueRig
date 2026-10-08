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
  /** Child sitemaps read per run (large marketplaces). */
  maxChildSitemaps?: number;
}

// Only stores whose robots.txt allows product pages, that publish
// sitemaps and put a schema.org price on product pages (surveyed 2026-10).
// Not crawlable: Hepsiburada, n11, Teknosa (robots.txt 403), Akakçe, Cimri,
// Epey (bot protection), İncehesap, Sinerji (sitemap 403), Trendyol,
// Amazon (no public sitemap, search closed to bots).
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
    name: "Gaming.gen.tr",
    origin: "https://www.gaming.gen.tr",
    sitemaps: ["https://www.gaming.gen.tr/sitemap.xml"],
    productFilter: /\/urun\/\d+\//,
    maxChildSitemaps: 60,
  },
  {
    name: "Monster Notebook",
    origin: "https://www.monsternotebook.com.tr",
    sitemaps: ["https://www.monsternotebook.com.tr/sitemap.xml"],
    productFilter: /^https:\/\/www\.monsternotebook\.com\.tr\/[a-z0-9-]+\/[a-z0-9-]+\/$/,
  },
  {
    name: "Troyestore",
    origin: "https://www.troyestore.com",
    sitemaps: ["https://www.troyestore.com/sitemap.xml"],
    productFilter: /_\d+$/,
  },
  {
    name: "Pazarama",
    origin: "https://www.pazarama.com",
    sitemaps: ["https://www.pazarama.com/sitemaps/sitemap.xml"],
    childFilter: /urunler/,
    productFilter: /-p-[a-z0-9]+$/i,
    maxChildSitemaps: 30,
  },
  {
    name: "MediaMarkt",
    origin: "https://www.mediamarkt.com.tr",
    sitemaps: ["https://www.mediamarkt.com.tr/sitemaps/sitemap-index.xml"],
    childFilter: /productdetailspages/,
    productFilter: /\/tr\/product\//,
  },
];
