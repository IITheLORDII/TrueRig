// Security tests: redirects (SSRF), offer URLs, private hosts, rate limits,
// CORS. Fake network only.
import assert from "node:assert/strict";
import { describe, test } from "node:test";

import { collect } from "../public/collector.ts";
import { type FetchDeps, PoliteFetcher } from "../public/polite_fetch.ts";
import type { StoreConfig } from "../public/stores.ts";
import { isPrivateHost, isTrustedStoreUrl, sameSite } from "../public/url_safety.ts";
import { allowedOrigin, RateLimiter } from "../guard.ts";

type Page = { status?: number; body?: string; location?: string };

function fakeNet(pages: Record<string, Page>) {
  const calls: string[] = [];
  const deps: FetchDeps = {
    fetch: (async (input: string | URL) => {
      const url = String(input);
      calls.push(url);
      const page = pages[url];
      if (!page) return new Response("not found", { status: 404 });
      const headers = page.location ? { location: page.location } : undefined;
      return new Response(page.body ?? "", { status: page.status ?? 200, headers });
    }) as typeof fetch,
    now: () => 0,
    sleep: async () => {},
    takeBudget: async () => true,
    userAgent: "TrueRigBot/1.0",
  };
  return { deps, calls };
}

const robots = { body: "User-agent: *\nAllow: /" };

describe("url safety", () => {
  test("private and internal hosts are recognised", () => {
    for (const h of [
      "localhost", "api.localhost", "127.0.0.1", "10.1.2.3", "172.16.0.1",
      "192.168.1.1", "169.254.169.254", "0.0.0.0", "100.64.0.1",
      "[::1]", "::1", "[fd00::1]", "fe80::1", "printer.local", "db.internal",
    ]) assert.equal(isPrivateHost(h), true, h);
    for (const h of ["www.itopya.com", "8.8.8.8", "172.32.0.1", "shop.example"]) {
      assert.equal(isPrivateHost(h), false, h);
    }
  });

  test("same site allows www and subdomains, not look-alikes", () => {
    assert.equal(sameSite("https://itopya.com/x", "https://www.itopya.com"), true);
    assert.equal(sameSite("https://m.itopya.com/x", "https://www.itopya.com"), true);
    assert.equal(sameSite("https://itopya.com.evil.example/x", "https://www.itopya.com"), false);
    assert.equal(sameSite("https://evilitopya.com/x", "https://www.itopya.com"), false);
  });

  test("trusted store list", () => {
    assert.equal(isTrustedStoreUrl("https://www.vatanbilgisayar.com/p"), true);
    assert.equal(isTrustedStoreUrl("http://www.vatanbilgisayar.com/p"), false);
    assert.equal(isTrustedStoreUrl("https://vatan.example/p"), false);
  });
});

describe("PoliteFetcher redirects", () => {
  test("follows a redirect inside the same site", async () => {
    const net = fakeNet({
      "https://shop.example/robots.txt": robots,
      "https://shop.example/a": { status: 301, location: "/b" },
      "https://shop.example/b": { body: "ok" },
    });
    const r = await new PoliteFetcher(net.deps).get("https://shop.example/a");
    assert.deepEqual(r, { kind: "ok", html: "ok" });
  });

  test("refuses a redirect to another site or an internal address", async () => {
    for (const target of [
      "https://evil.example/steal",
      "http://shop.example/plain",
      "https://169.254.169.254/latest/meta-data",
      "https://localhost/admin",
    ]) {
      const net = fakeNet({
        "https://shop.example/robots.txt": robots,
        "https://shop.example/a": { status: 302, location: target },
      });
      const r = await new PoliteFetcher(net.deps).get("https://shop.example/a");
      assert.equal(r.kind, "redirect-refused", target);
      assert.ok(!net.calls.includes(target), `fetched ${target}`);
    }
  });

  test("stops after too many redirects", async () => {
    const net = fakeNet({
      "https://shop.example/robots.txt": robots,
      "https://shop.example/1": { status: 301, location: "/2" },
      "https://shop.example/2": { status: 301, location: "/3" },
      "https://shop.example/3": { status: 301, location: "/4" },
      "https://shop.example/4": { status: 301, location: "/5" },
      "https://shop.example/5": { body: "never" },
    });
    const r = await new PoliteFetcher(net.deps).get("https://shop.example/1");
    assert.equal(r.kind, "redirect-refused");
    assert.ok(!net.calls.includes("https://shop.example/5"));
  });

  test("never contacts an internal address directly", async () => {
    const net = fakeNet({});
    const r = await new PoliteFetcher(net.deps).get("https://127.0.0.1/x");
    assert.equal(r.kind, "redirect-refused");
    assert.equal(net.calls.length, 0);
  });
});

describe("collect: offer URLs", () => {
  const ld = (o: unknown) => `<script type="application/ld+json">${JSON.stringify(o)}</script>`;

  test("a shop's offer pointing to another site uses the shop page instead", async () => {
    const store: StoreConfig = {
      name: "Shop",
      origin: "https://shop.example",
      searchUrl: () => "https://shop.example/ara?q=x",
    };
    const net = fakeNet({
      "https://shop.example/robots.txt": robots,
      "https://shop.example/ara?q=x": {
        body: ld({
          "@type": "Product",
          name: "Corsair Vengeance 32GB DDR5 CMK32GX5M2B6000Z30",
          mpn: "CMK32GX5M2B6000Z30",
          url: "https://phish.example/pay",
          offers: { "@type": "Offer", price: "3499", priceCurrency: "TRY" },
        }),
      },
    });
    const r = await collect("CMK32GX5M2B6000Z30", [store], new PoliteFetcher(net.deps));
    assert.equal(r.offers.length, 1);
    assert.equal(r.offers[0].url, "https://shop.example/ara?q=x");
  });

  test("aggregator seller links to unknown sites become the aggregator page", async () => {
    const agg: StoreConfig = {
      name: "Agg",
      origin: "https://agg.example",
      searchUrl: () => "https://agg.example/p,1.html",
    };
    const net = fakeNet({
      "https://agg.example/robots.txt": robots,
      "https://agg.example/p,1.html": {
        body: ld({
          "@type": "Product",
          name: "Gigabyte RTX 4070 Super GV-N407SWF3OC-12GD",
          mpn: "GV-N407SWF3OC-12GD",
          url: "https://agg.example/p,1.html",
          offers: {
            "@type": "AggregateOffer",
            priceCurrency: "TRY",
            offers: [
              { "@type": "Offer", price: "27547", url: "https://unknown-seller.example/p", seller: { name: "A" } },
              { "@type": "Offer", price: "28000", url: "https://www.itopya.com/p", seller: { name: "İtopya" } },
            ],
          },
        }),
      },
    });
    const r = await collect("GV-N407SWF3OC-12GD", [agg], new PoliteFetcher(net.deps));
    assert.deepEqual(
      r.offers.map((o) => o.url),
      ["https://agg.example/p,1.html", "https://www.itopya.com/p"],
    );
  });
});

describe("guard", () => {
  test("rate limiter: per-client and global caps", () => {
    let t = 0;
    const rl = new RateLimiter({ perMinute: 3, crawlsPerHour: 2, globalCrawlsPerHour: 3, now: () => t });
    assert.equal(rl.request("a"), true);
    assert.equal(rl.request("a"), true);
    assert.equal(rl.request("a"), true);
    assert.equal(rl.request("a"), false); // 4th in a minute
    assert.equal(rl.request("b"), true); // other client unaffected
    t += 61_000;
    assert.equal(rl.request("a"), true); // window moved on

    assert.equal(rl.crawl("a"), true);
    assert.equal(rl.crawl("a"), true);
    assert.equal(rl.crawl("a"), false); // client crawl cap
    assert.equal(rl.crawl("b"), true); // global now 3
    assert.equal(rl.crawl("c"), false); // global cap
    assert.ok(rl.retryAfterSec("a") > 0);
  });

  test("CORS only echoes allowed origins", () => {
    const allowed = ["https://truerig.app"];
    assert.equal(allowedOrigin("https://truerig.app", allowed), "https://truerig.app");
    assert.equal(allowedOrigin("https://evil.example", allowed), null);
    assert.equal(allowedOrigin(null, allowed), null);
    // Not configured yet: stays open, as before.
    assert.equal(allowedOrigin("https://any.example", []), "*");
  });
});
