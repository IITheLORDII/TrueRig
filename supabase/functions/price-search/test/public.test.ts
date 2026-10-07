// Run: node --test supabase/functions/price-search/test/
import assert from "node:assert/strict";
import { describe, test } from "node:test";

import { collect } from "../public/collector.ts";
import { extractPageData, num, ratingOf } from "../public/jsonld.ts";
import { looksLikePartNumber, matchKind } from "../public/match.ts";
import { type FetchDeps, PoliteFetcher } from "../public/polite_fetch.ts";
import { isAllowed, parseRobots, rulesForStatus } from "../public/robots.ts";
import type { StoreConfig } from "../public/stores.ts";
import { validateQuery } from "../query.ts";

const ld = (obj: unknown) => `<script type="application/ld+json">${JSON.stringify(obj)}</script>`;

const ramProduct = {
  "@context": "https://schema.org",
  "@type": "Product",
  name: "Corsair Vengeance 32GB (2x16GB) DDR5 6000MHz CL30",
  mpn: "CMK32GX5M2B6000Z30",
  image: [{ "@type": "ImageObject", contentUrl: "/img/cmk32.jpg" }],
  url: "https://shop.example/p/cmk32",
  offers: { "@type": "Offer", price: "3.499,90", priceCurrency: "TRY", availability: "https://schema.org/InStock" },
};

describe("robots", () => {
  const txt = [
    "User-agent: *",
    "Disallow: /ara",
    "Allow: /ara/urun$",
    "Disallow: /*?sort=",
    "Crawl-delay: 5",
    "",
    "User-agent: TrueRigBot",
    "Disallow: /",
  ].join("\n");

  test("generic group: longest match wins, $ anchors, * wildcard", () => {
    const r = parseRobots(txt, "OtherBot");
    assert.equal(isAllowed(r, "/ara?q=rtx"), false);
    assert.equal(isAllowed(r, "/ara/urun"), true);
    assert.equal(isAllowed(r, "/ara/urun2"), false);
    assert.equal(isAllowed(r, "/kategori?sort=price"), false);
    assert.equal(isAllowed(r, "/kategori"), true);
    assert.equal(r.crawlDelaySec, 5);
  });

  test("a group naming our bot overrides *", () => {
    const r = parseRobots(txt, "TrueRigBot/1.0");
    assert.equal(isAllowed(r, "/kategori"), false);
  });

  test("status handling per RFC 9309", () => {
    assert.equal(isAllowed(rulesForStatus(404, "", "x"), "/a"), true);
    assert.equal(isAllowed(rulesForStatus(403, "", "x"), "/a"), false);
    assert.equal(isAllowed(rulesForStatus(503, "", "x"), "/a"), false);
    assert.equal(isAllowed(rulesForStatus(0, "", "x"), "/a"), false);
  });
});

describe("jsonld", () => {
  test("extracts product, TR price, absolute image", () => {
    const d = extractPageData(`<html>${ld(ramProduct)}</html>`, "https://shop.example/ara");
    assert.equal(d.products.length, 1);
    const p = d.products[0];
    assert.equal(p.price, 3499.9);
    assert.equal(p.currency, "TRY");
    assert.equal(p.imageUrl, "https://shop.example/img/cmk32.jpg");
    assert.equal(p.inStock, true);
  });

  test("reads @graph, ItemList urls, lowest AggregateOffer; skips bad JSON", () => {
    const html = `<script type="application/ld+json">{bad json</script>` + ld({
      "@graph": [
        { "@type": "ItemList", itemListElement: [{ "@type": "ListItem", item: { url: "/p/1" } }, { item: { url: "/p/1" } }] },
        { "@type": "Product", name: "X", offers: [{ "@type": "AggregateOffer", lowPrice: 120 }, { price: 99, availability: "OutOfStock" }] },
      ],
    });
    const d = extractPageData(html, "https://shop.example/s");
    assert.deepEqual(d.listedUrls, ["https://shop.example/p/1"]);
    assert.equal(d.products[0].price, 99);
    assert.equal(d.products[0].inStock, false);
  });

  test("num parses common formats", () => {
    assert.equal(num("12.999,90 TL"), 12999.9);
    assert.equal(num("1,299.50"), 1299.5);
    assert.equal(num(42), 42);
    assert.equal(num("—"), null);
  });
});

describe("match", () => {
  const base = { url: null, imageUrl: null, brand: null, sku: null, gtin: null, price: 1, currency: "TRY", inStock: true, sellerOffers: [] };
  test("identifier match on MPN ignoring separators", () => {
    assert.equal(matchKind({ ...base, name: "x", mpn: "CMK32GX5M2B6000Z30" }, "cmk32gx5m2b6000z30"), "identifier");
  });
  test("name match rejects higher tiers", () => {
    const ti = { ...base, mpn: null, name: "MSI GeForce RTX 4070 Ti Super 16G" };
    const plain = { ...base, mpn: null, name: "MSI GeForce RTX 4070 Ventus 12G" };
    assert.equal(matchKind(ti, "RTX 4070"), "none");
    assert.equal(matchKind(plain, "RTX 4070"), "name");
    assert.equal(matchKind(ti, "rtx 4070 ti super"), "name");
  });
});

describe("validateQuery", () => {
  test("accepts model numbers, rejects injection-ish input", () => {
    assert.equal(validateQuery("  RTX   4090 "), "RTX 4090");
    assert.equal(validateQuery("<script>"), null);
    assert.equal(validateQuery("a".repeat(101)), null);
    assert.equal(validateQuery(null), null);
  });
});

// --- PoliteFetcher + collector with a fake network --------------------------

function fakeNet(pages: Record<string, { status?: number; body: string }>) {
  const calls: string[] = [];
  let clock = 0;
  const slept: number[] = [];
  const deps: FetchDeps = {
    fetch: (async (input: string | URL) => {
      const url = String(input);
      calls.push(url);
      const page = pages[url];
      if (!page) return new Response("not found", { status: 404 });
      return new Response(page.body, { status: page.status ?? 200 });
    }) as typeof fetch,
    now: () => clock,
    sleep: async (ms: number) => {
      slept.push(ms);
      clock += ms;
    },
    takeBudget: async () => true,
    userAgent: "TrueRigBot/1.0 (+https://example/bot)",
  };
  return { deps, calls, slept };
}

describe("PoliteFetcher", () => {
  test("never fetches a robots-disallowed page", async () => {
    const net = fakeNet({ "https://a.example/robots.txt": { body: "User-agent: *\nDisallow: /ara" } });
    const f = new PoliteFetcher(net.deps);
    const r = await f.get("https://a.example/ara?q=x");
    assert.equal(r.kind, "blocked-by-robots");
    assert.deepEqual(net.calls, ["https://a.example/robots.txt"]);
  });

  test("honours crawl-delay between requests to the same host", async () => {
    const net = fakeNet({
      "https://a.example/robots.txt": { body: "User-agent: *\nCrawl-delay: 3" },
      "https://a.example/1": { body: "one" },
      "https://a.example/2": { body: "two" },
    });
    const f = new PoliteFetcher(net.deps);
    await f.get("https://a.example/1");
    await f.get("https://a.example/2");
    assert.deepEqual(net.slept, [3000]);
  });

  test("backs off after 429 instead of retrying", async () => {
    const net = fakeNet({
      "https://a.example/robots.txt": { body: "" },
      "https://a.example/x": { status: 429, body: "" },
    });
    const f = new PoliteFetcher(net.deps);
    assert.equal((await f.get("https://a.example/x")).kind, "http-error");
    assert.equal((await f.get("https://a.example/x")).kind, "backing-off");
    assert.equal(net.calls.filter((c) => c.endsWith("/x")).length, 1);
  });

  test("respects the hourly budget", async () => {
    const net = fakeNet({ "https://a.example/robots.txt": { body: "" } });
    const f = new PoliteFetcher({ ...net.deps, takeBudget: async () => false });
    assert.equal((await f.get("https://a.example/x")).kind, "over-budget");
  });
});

describe("collect", () => {
  const store: StoreConfig = {
    name: "Shop",
    origin: "https://shop.example",
    searchUrl: (q) => `https://shop.example/ara?q=${encodeURIComponent(q)}`,
  };
  const blocked: StoreConfig = {
    name: "Blocked",
    origin: "https://blocked.example",
    searchUrl: () => "https://blocked.example/search?q=x",
  };

  test("follows ItemList to product page, returns offer and MPN-matched image", async () => {
    const net = fakeNet({
      "https://shop.example/robots.txt": { body: "User-agent: *\nAllow: /" },
      "https://shop.example/ara?q=CMK32GX5M2B6000Z30": {
        body: ld({ "@type": "ItemList", itemListElement: [{ item: { url: "/p/cmk32" } }] }),
      },
      "https://shop.example/p/cmk32": { body: ld(ramProduct) },
      "https://blocked.example/robots.txt": { body: "User-agent: *\nDisallow: /" },
    });
    const r = await collect("CMK32GX5M2B6000Z30", [store, blocked], new PoliteFetcher(net.deps));
    assert.equal(r.offers.length, 1);
    assert.equal(r.offers[0].price, 3499.9);
    assert.equal(r.image?.url, "https://shop.example/img/cmk32.jpg");
    assert.deepEqual(r.skipped, [{ store: "Blocked", reason: "blocked-by-robots" }]);
    assert.ok(!net.calls.some((c) => c.startsWith("https://blocked.example/search")));
  });

  test("aggregator: HTML links -> product page with per-seller offers and MPN-in-title image", async () => {
    const agg: StoreConfig = {
      name: "Agg",
      origin: "https://agg.example",
      searchUrl: (q) => `https://agg.example/arama/?q=${encodeURIComponent(q)}`,
      productLinkPattern: /href="(\/[a-z0-9-]+\/en-ucuz-[a-z0-9-]+-fiyati,\d+\.html)"/g,
    };
    const searchHtml = [
      '<a href="/ekran-karti/en-ucuz-pny-rtx-4070-ti-super-xlr8-fiyati,1.html">',
      '<a href="/ekran-karti/en-ucuz-gigabyte-rtx-4070-super-windforce-oc-gv-n407swf3oc-12gd-fiyati,2.html">',
    ].join("");
    const product = {
      "@type": "Product",
      "@id": "https://agg.example/ekran-karti/en-ucuz-gigabyte-rtx-4070-super-windforce-oc-gv-n407swf3oc-12gd-fiyati,2.html",
      name: "Gigabyte RTX 4070 Super Windforce OC 12G GV-N407SWF3OC-12GD",
      sku: "2",
      image: [{ "@type": "ImageObject", contentUrl: "https://cdn.agg.example/gv.jpg" }],
      offers: {
        "@type": "AggregateOffer",
        priceCurrency: "TRY",
        lowPrice: "27547.00",
        offers: [
          { "@type": "Offer", price: "27547.00", url: "https://seller-a.example/p/1", seller: { name: "Satıcı A" } },
          { "@type": "Offer", price: "28999.00", url: "https://seller-b.example/p/9", seller: { name: "Satıcı B" }, availability: "https://schema.org/OutOfStock" },
        ],
      },
    };
    const net = fakeNet({
      "https://agg.example/robots.txt": { body: "User-agent: *\nDisallow: /admin" },
      "https://agg.example/arama/?q=GV-N407SWF3OC-12GD": { body: searchHtml },
      "https://agg.example/ekran-karti/en-ucuz-gigabyte-rtx-4070-super-windforce-oc-gv-n407swf3oc-12gd-fiyati,2.html": { body: ld(product) },
    });
    const r = await collect("GV-N407SWF3OC-12GD", [agg], new PoliteFetcher(net.deps));
    assert.deepEqual(r.offers.map((o) => [o.store, o.price, o.in_stock]), [["Satıcı A", 27547, true], ["Satıcı B", 28999, false]]);
    assert.equal(r.image?.url, "https://cdn.agg.example/gv.jpg");
    // The Ti Super link was never followed.
    assert.ok(!net.calls.some((c) => c.includes("4070-ti-super")));
  });

  test("looksLikePartNumber", () => {
    assert.equal(looksLikePartNumber("GV-N407SWF3OC-12GD"), true);
    assert.equal(looksLikePartNumber("BX8071514900K"), true);
    assert.equal(looksLikePartNumber("RTX 4070"), false);
    assert.equal(looksLikePartNumber("4070"), false);
  });

  test("name-only match gives offers but no image", async () => {
    const net = fakeNet({
      "https://shop.example/robots.txt": { body: "" },
      "https://shop.example/ara?q=vengeance%2032gb": { body: ld(ramProduct) },
    });
    const r = await collect("vengeance 32gb", [store], new PoliteFetcher(net.deps));
    assert.equal(r.offers.length, 1);
    assert.equal(r.image, null);
  });
});

describe("ratingOf", () => {
  test("normalises to 5 stars and keeps review count", () => {
    assert.deepEqual(ratingOf({ ratingValue: "9", bestRating: 10, reviewCount: "120" }), {
      rating: 4.5,
      reviewCount: 120,
    });
    assert.deepEqual(ratingOf({ ratingValue: 4.26, ratingCount: 8 }), { rating: 4.3, reviewCount: 8 });
  });

  test("missing or invalid rating yields nulls", () => {
    assert.deepEqual(ratingOf(undefined), { rating: null, reviewCount: null });
    assert.deepEqual(ratingOf({ ratingValue: 0 }), { rating: null, reviewCount: null });
  });
});

describe("nested JSON-LD", () => {
  test("Product inside a BuyAction is found (MediaMarkt)", () => {
    const html = `<script data-rh="true" type="application/ld+json">${JSON.stringify({
      "@context": "https://schema.org/",
      "@type": "BuyAction",
      object: {
        "@type": "Product",
        name: "HP Victus 15 RTX4060",
        gtin13: "0757279207455",
        offers: { "@type": "Offer", price: 42999, priceCurrency: "TRY" },
      },
    })}</script>`;
    const p = extractPageData(html, "https://www.mediamarkt.com.tr/tr/product/_x.html").products;
    assert.equal(p.length, 1);
    assert.equal(p[0].price, 42999);
    assert.equal(p[0].gtin, "0757279207455");
  });
});
