// Public store search pages. Whether each is actually crawled is decided at
// runtime by that site's robots.txt (and by how it answers our honest bot
// User-Agent) — nothing here overrides it.

export interface StoreConfig {
  name: string;
  origin: string;
  searchUrl: (query: string) => string;
  /**
   * Fallback when the search page has no JSON-LD ItemList: matches relative
   * product links in the HTML. Group 1 must capture the path.
   */
  productLinkPattern?: RegExp;
}

const enc = encodeURIComponent;

export const STORES: StoreConfig[] = [
  {
    name: "Akakçe",
    origin: "https://www.akakce.com",
    searchUrl: (q) => `https://www.akakce.com/arama/?q=${enc(q)}`,
    productLinkPattern: /href="(\/[a-z0-9-]+\/en-ucuz-[a-z0-9-]+-fiyati,\d+\.html)"/g,
  },
  { name: "Cimri", origin: "https://www.cimri.com", searchUrl: (q) => `https://www.cimri.com/arama?q=${enc(q)}` },
  { name: "Epey", origin: "https://www.epey.com", searchUrl: (q) => `https://www.epey.com/ara/${enc(q)}/` },
  { name: "Hepsiburada", origin: "https://www.hepsiburada.com", searchUrl: (q) => `https://www.hepsiburada.com/ara?q=${enc(q)}` },
  { name: "Trendyol", origin: "https://www.trendyol.com", searchUrl: (q) => `https://www.trendyol.com/sr?q=${enc(q)}` },
  { name: "n11", origin: "https://www.n11.com", searchUrl: (q) => `https://www.n11.com/arama?q=${enc(q)}` },
  { name: "Vatan Bilgisayar", origin: "https://www.vatanbilgisayar.com", searchUrl: (q) => `https://www.vatanbilgisayar.com/arama/${enc(q)}/` },
  { name: "İtopya", origin: "https://www.itopya.com", searchUrl: (q) => `https://www.itopya.com/ara?bul=${enc(q)}` },
  { name: "İncehesap", origin: "https://www.incehesap.com", searchUrl: (q) => `https://www.incehesap.com/q/${enc(q)}/` },
  { name: "Teknosa", origin: "https://www.teknosa.com", searchUrl: (q) => `https://www.teknosa.com/arama/?s=${enc(q)}` },
  { name: "MediaMarkt", origin: "https://www.mediamarkt.com.tr", searchUrl: (q) => `https://www.mediamarkt.com.tr/tr/search.html?query=${enc(q)}` },
];
