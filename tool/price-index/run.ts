// CLI: node --experimental-strip-types tool/price-index/run.ts \
//   --items items.json --out prices.json [--previous prices.json] [--limit 250]
//   [--only "İtopya"] [--max-items 20]
// Runs once (GitHub Actions does it daily) and writes the public price index.

import { existsSync, readFileSync, writeFileSync } from "node:fs";
import { BOT_TOKEN, PoliteFetcher } from "../../supabase/functions/price-search/public/polite_fetch.ts";
import { buildIndex, type PriceIndex } from "./indexer.ts";
import { INDEX_STORES } from "./sitemap.ts";
import type { PriceItem } from "./slug_match.ts";

function arg(name: string): string | undefined {
  const i = process.argv.indexOf(`--${name}`);
  return i >= 0 ? process.argv[i + 1] : undefined;
}

const itemsPath = arg("items") ?? "items.json";
const outPath = arg("out") ?? "prices.json";
const previousPath = arg("previous");
const limit = Number(arg("limit") ?? 250);
const only = arg("only");
const maxItems = arg("max-items") ? Number(arg("max-items")) : undefined;

const readJson = (p: string) => JSON.parse(readFileSync(p, "utf8").replace(/^﻿/, ""));

let items: PriceItem[] = readJson(itemsPath);
if (maxItems) items = items.slice(0, maxItems);
const previous: PriceIndex | null = previousPath && existsSync(previousPath) ? readJson(previousPath) : null;
const stores = only ? INDEX_STORES.filter((s) => s.name === only) : INDEX_STORES;
const minDelay = new Map(stores.map((s) => [new URL(s.origin).host, s.minDelayMs ?? 0]));

const fetcher = new PoliteFetcher({
  fetch: globalThis.fetch,
  now: () => Date.now(),
  sleep: (ms) => new Promise((r) => setTimeout(r, ms)),
  takeBudget: async () => true,
  userAgent: `${BOT_TOKEN}/1.0 (+https://github.com/IITheLORDII/TrueRig)`,
  minDelayMs: (host) => minDelay.get(host) ?? 0,
});

const index = await buildIndex({
  items,
  stores,
  fetcher,
  previous,
  now: () => new Date(),
  requestsPerStore: limit,
  log: (m) => console.log(m),
});

writeFileSync(outPath, JSON.stringify(index));
const priced = Object.values(index.items).filter((e) => e.offers.length > 0).length;
console.log(`wrote ${outPath}: ${priced}/${items.length} items with prices · USD/TRY ${index.usd_try}`);
for (const s of index.stores) console.log(`  ${s.name}: ${s.status} · ${s.product_urls} urls · ${s.requests} requests ${s.reason ?? ""}`);
