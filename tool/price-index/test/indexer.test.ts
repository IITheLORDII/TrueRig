import assert from "node:assert/strict";
import { describe, test } from "node:test";

import { type FetchDeps, PoliteFetcher } from "../../../supabase/functions/price-search/public/polite_fetch.ts";
import { decodeEntities } from "../../../supabase/functions/price-search/public/jsonld.ts";
import { buildIndex, offerFrom, parseUsdTry, plausible } from "../indexer.ts";
import { type IndexStore, parseSitemap } from "../sitemap.ts";
import { bestUrls, matchScore, type PriceItem, SlugIndex } from "../slug_match.ts";

const gpu: PriceItem = { key: "gpu:rtx-4060", kind: "gpu", brand: "NVIDIA", model: "GeForce RTX 4060", name: "NVIDIA GeForce RTX 4060" };
const iphone: PriceItem = { key: "phone:iphone-15", kind: "phone", brand: "Apple", model: "iPhone 15", name: "Apple iPhone 15" };
const g770: PriceItem = { key: "system:casper-g770", kind: "laptop", brand: "Casper", model: "Excalibur G770", name: "Casper Excalibur G770" };
const tuf: PriceItem = {
  key: "system:asus-tuf-f15", kind: "laptop", brand: "ASUS", model: "TUF Gaming F15 / FX50x", name: "ASUS TUF", aliases: ["FX507"],
};

describe("matchScore", () => {
  test("accepts the card, rejects tiers, laptops and accessories", () => {
    assert.notEqual(matchScore(gpu, "/msi-geforce-rtx-4060-ventus-2x-black-8g-oc-ekran-karti_u1"), null);
    assert.notEqual(matchScore(gpu, "/asus-dual-rtx4060-o8g.html"), null);
    assert.equal(matchScore(gpu, "/msi-geforce-rtx-4060-ti-gaming-x-8g.html"), null);
    assert.equal(matchScore(gpu, "/msi-summit-e16-flip-i7-1360p-32gb-rtx4060-laptop_u2"), null);
  });

  test("phones: exact model only, no cases", () => {
    assert.notEqual(matchScore(iphone, "/apple-iphone-15-128gb-siyah.html"), null);
    assert.equal(matchScore(iphone, "/apple-iphone-15-pro-max-256gb.html"), null);
    assert.equal(matchScore(iphone, "/iphone-15-silikon-kilif.html"), null);
  });

  test("systems need the brand; aliases and alternatives count", () => {
    assert.notEqual(matchScore(g770, "/casper-excalibur-g770-1245-i5-12450h-rtx3050.html"), null);
    assert.equal(matchScore(g770, "/excalibur-g770-cantasi.html"), null);
    assert.notEqual(matchScore(tuf, "/asus-tuf-fx507zc4-i5-12500h-rtx3050.html"), null);
    assert.notEqual(matchScore(tuf, "/asus-tuf-gaming-f15-i7.html"), null);
  });

  test("closest slugs win", () => {
    const urls = [
      "https://s.com/msi-geforce-rtx-4060-ventus-2x-white-8g-oc-gddr6-128bit-ekran-karti.html",
      "https://s.com/asus-rtx-4060.html",
      "https://s.com/rtx-4060-ti.html",
    ];
    assert.deepEqual(bestUrls(gpu, urls, 1), ["https://s.com/asus-rtx-4060.html"]);
  });
});

describe("sitemap and rate parsing", () => {
  test("index vs urlset", () => {
    const idx = parseSitemap(`<sitemapindex><sitemap><loc>https://a.com/p_0.xml</loc></sitemap></sitemapindex>`);
    assert.equal(idx.isIndex, true);
    assert.deepEqual(idx.locs, ["https://a.com/p_0.xml"]);
    const set = parseSitemap(`<urlset><url><loc><![CDATA[https://a.com/x?a=1&amp;b=2]]></loc></url><url><loc>http://a.com/insecure</loc></url></urlset>`);
    assert.equal(set.isIndex, false);
    assert.deepEqual(set.locs, ["https://a.com/x?a=1&b=2"]);
  });

  test("TCMB USD selling rate", () => {
    const xml = `<Tarih_Date><Currency CrossOrder="0" Kod="USD" CurrencyCode="USD"><Unit>1</Unit>
      <ForexBuying>41.1</ForexBuying><ForexSelling>41.25</ForexSelling></Currency></Tarih_Date>`;
    assert.equal(parseUsdTry(xml), 41.25);
    assert.equal(parseUsdTry("<x/>"), null);
  });
});

const page = (name: string, price: number) =>
  `<script type="application/ld+json">${JSON.stringify({
    "@type": "Product",
    name,
    offers: { "@type": "Offer", price, priceCurrency: "TRY", availability: "https://schema.org/InStock" },
    aggregateRating: { ratingValue: 4.6, reviewCount: 31 },
  })}</script>`;

describe("offerFrom", () => {
  test("keeps the price only when the title is the item", () => {
    const now = new Date("2026-10-08T00:00:00Z");
    const ok = offerFrom("İtopya", gpu, "https://s.com/a", page("ASUS Dual GeForce RTX 4060 OC 8GB", 12999), now);
    assert.equal(ok?.price, 12999);
    assert.equal(ok?.rating, 4.6);
    assert.equal(offerFrom("İtopya", gpu, "https://s.com/b", page("RTX 4060 Ti 16GB", 18999), now), null);
  });
});

describe("buildIndex", () => {
  test("crawls sitemap -> product page, keeps cheapest, respects the limit", async () => {
    const pages: Record<string, string> = {
      "https://www.store.com/robots.txt": "User-agent: *\nAllow: /",
      "https://www.store.com/sitemap.xml":
        `<urlset><url><loc>https://www.store.com/asus-rtx-4060.html</loc></url>` +
        `<url><loc>https://www.store.com/msi-rtx-4060-ventus.html</loc></url>` +
        `<url><loc>https://www.store.com/apple-iphone-15-128gb.html</loc></url></urlset>`,
      "https://www.store.com/asus-rtx-4060.html": page("ASUS Dual RTX 4060", 13500),
      "https://www.store.com/msi-rtx-4060-ventus.html": page("MSI RTX 4060 Ventus", 12900),
      "https://www.store.com/apple-iphone-15-128gb.html": page("Apple iPhone 15 128 GB", 52999),
    };
    const requested: string[] = [];
    let t = 0;
    const deps: FetchDeps = {
      fetch: (async (input: string | URL) => {
        const url = String(input);
        requested.push(url);
        const body = pages[url];
        return new Response(body ?? "", { status: body === undefined ? 404 : 200 });
      }) as typeof fetch,
      now: () => t,
      sleep: async (ms) => {
        t += ms;
      },
      takeBudget: async () => true,
      userAgent: "TrueRigBot/1.0",
    };
    const store: IndexStore = {
      name: "Test",
      origin: "https://www.store.com",
      sitemaps: ["https://www.store.com/sitemap.xml"],
      productFilter: /\.html$/,
    };
    const index = await buildIndex({
      items: [gpu, iphone],
      stores: [store],
      fetcher: new PoliteFetcher(deps),
      now: () => new Date("2026-10-08T00:00:00Z"),
      requestsPerStore: 3,
    });
    assert.equal(index.items["gpu:rtx-4060"].offers[0].price, 12900);
    assert.equal(index.items["gpu:rtx-4060"].offers.length, 1);
    // Limit of 3 product pages: 2 for the GPU, 1 for the phone.
    assert.equal(index.items["phone:iphone-15"].offers[0].price, 52999);
    assert.equal(index.stores[0].requests, 3);
    assert.ok(!requested.some((u) => u.includes("/arama")), "never touches search pages");
  });
});

describe("guards from the first live run", () => {
  const cpu: PriceItem = { key: "cpu:r9-9950x", kind: "cpu", brand: "AMD", model: "Ryzen 9 9950X", name: "AMD Ryzen 9 9950X", ref_usd: 649 };
  test("9950X does not match 9950X3D, KF still matches K", () => {
    assert.equal(matchScore(cpu, "AMD 4.3GHZ 170W AM5 AMD Ryzen 9 9950X3D İşlemci"), null);
    assert.notEqual(matchScore(cpu, "AMD Ryzen 9 9950X 4.3GHz 64MB Tray İşlemci"), null);
    const k: PriceItem = { key: "cpu:i5-14600k", kind: "cpu", brand: "Intel", model: "Core i5-14600K", name: "Intel Core i5-14600K" };
    assert.notEqual(matchScore(k, "INTEL Core i5 14600KF 3.5GHz Tray İşlemci"), null);
  });

  test("prices far from list price x rate are dropped", () => {
    const offer = (price: number) => ({
      store: "X", price, currency: "TRY", url: "https://x", in_stock: true,
      rating: null, review_count: null, title: "", fetched_at: "",
    });
    assert.equal(plausible(offer(30000), cpu, 49), true);
    assert.equal(plausible(offer(2499), cpu, 49), false);
    assert.equal(plausible(offer(2499), { ...cpu, ref_usd: undefined }, 49), true);
  });
});

describe("SlugIndex", () => {
  test("gives the same best URLs as a full scan", () => {
    const urls = [
      "https://s.com/msi-geforce-rtx-4060-ventus-2x-ekran-karti.html",
      "https://s.com/asus-rtx-4060.html",
      "https://s.com/rtx-4060-ti.html",
      "https://s.com/apple-iphone-15-128gb.html",
      "https://s.com/asus-tuf-fx507zc4-i5.html",
      "https://s.com/bebek-arabasi.html",
    ];
    const idx = new SlugIndex(urls);
    for (const item of [gpu, iphone, tuf]) {
      assert.deepEqual(idx.best(item, 2), bestUrls(item, urls, 2), item.key);
    }
    // Only URLs sharing a word are scored.
    assert.ok(idx.candidates(iphone).length < urls.length);
  });
});

describe("live run fixes", () => {
  const r5: PriceItem = { key: "cpu:r5-7600", kind: "cpu", brand: "AMD", model: "Ryzen 5 7600", name: "AMD Ryzen 5 7600" };
  const i5: PriceItem = { key: "cpu:i5-12400", kind: "cpu", brand: "Intel", model: "Core i5-12400", name: "Intel Core i5-12400" };
  const r5x: PriceItem = { key: "cpu:r5-7600x", kind: "cpu", brand: "AMD", model: "Ryzen 5 7600X", name: "AMD Ryzen 5 7600X" };

  test("7600 is not 7600X, but 7600X still matches itself", () => {
    assert.equal(matchScore(r5, "AMD Ryzen 5 7600X Soket AM5 4.7GHz Tray İşlemci"), null);
    assert.notEqual(matchScore(r5, "AMD Ryzen 5 7600 Tray 5.1GHz 6 Çekirdek"), null);
    assert.notEqual(matchScore(r5x, "AMD Ryzen 5 7600X Soket AM5 4.7GHz Tray İşlemci"), null);
  });

  test("Intel F is the same chip", () => {
    assert.notEqual(matchScore(i5, "Intel Core i5 12400F Soket 1700 12. Nesil"), null);
  });

  test("a laptop listing is not a processor", () => {
    const u: PriceItem = { key: "cpu:i5-12500h", kind: "cpu", brand: "Intel", model: "Core i5-12500H", name: "Intel Core i5-12500H" };
    assert.equal(matchScore(u, "Acer EX215 i5-12500H 16GB 512GB SSD 15.6 FHD Dos"), null);
  });

  test("HTML entities in titles are decoded", () => {
    assert.equal(decodeEntities("AMD Ryzen&#x2122; 7 &#xD6;nbellek &amp; &#252;"), "AMD Ryzen™ 7 Önbellek & ü");
  });
});

describe("previous offers", () => {
  test("old offers that no longer match are dropped", async () => {
    const r5: PriceItem = { key: "cpu:r5-7600", kind: "cpu", brand: "AMD", model: "Ryzen 5 7600", name: "AMD Ryzen 5 7600" };
    const offer = (title: string) => ({
      store: "Vatan", price: 9999, currency: "TRY", url: "https://x", in_stock: true,
      rating: null, review_count: null, title, fetched_at: "2026-10-08T00:00:00Z",
    });
    const deps: FetchDeps = {
      fetch: (async () => new Response("", { status: 404 })) as typeof fetch,
      now: () => 0, sleep: async () => {}, takeBudget: async () => true, userAgent: "TrueRigBot/1.0",
    };
    const index = await buildIndex({
      items: [r5], stores: [], fetcher: new PoliteFetcher(deps),
      previous: {
        version: 1, generated_at: "", usd_try: null, stores: [],
        items: {
          "cpu:r5-7600": {
            name: r5.name, kind: "cpu", checked: {},
            offers: [offer("AMD Ryzen 5 7600X Tray"), offer("AMD Ryzen 5 7600 Tray")],
          },
        },
      },
      now: () => new Date("2026-10-08T01:00:00Z"),
      requestsPerStore: 0,
    });
    assert.deepEqual(index.items["cpu:r5-7600"].offers.map((o) => o.title), ["AMD Ryzen 5 7600 Tray"]);
  });
});
