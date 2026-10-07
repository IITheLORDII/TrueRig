// Pre-fills price + image caches for catalog MPNs by calling the deployed
// price-search function slowly (the function itself enforces robots.txt,
// crawl delays and the per-host hourly budget).
//
// Usage:
//   dart run packages/perf_engine/tool/export_mpns.dart > mpns.txt
//   PRICE_API_URL=https://<ref>.supabase.co/functions/v1/price-search \
//   SUPABASE_ANON_KEY=... node supabase/scripts/warm_images.mts mpns.txt

import { readFileSync } from "node:fs";

const GAP_MS = 20_000;
const api = process.env.PRICE_API_URL ?? "";
const anon = process.env.SUPABASE_ANON_KEY ?? "";
const file = process.argv[2];

if (!api.startsWith("https://") || !anon || !file) {
  console.error("PRICE_API_URL (https), SUPABASE_ANON_KEY and an MPN file are required.");
  process.exit(1);
}

const mpns = readFileSync(file, "utf8").split(/\r?\n/).map((s) => s.trim()).filter(Boolean);
let withImage = 0;

for (const [i, mpn] of mpns.entries()) {
  const url = new URL(api);
  url.searchParams.set("q", mpn);
  try {
    const res = await fetch(url, { headers: { apikey: anon, Authorization: `Bearer ${anon}` } });
    const body = await res.json();
    const img = body?.meta?.image_url ?? null;
    if (img) withImage++;
    console.log(`[${i + 1}/${mpns.length}] ${mpn}: ${res.status} offers=${body?.data?.length ?? 0} image=${img ? "yes" : "no"}`);
  } catch (e) {
    console.error(`[${i + 1}/${mpns.length}] ${mpn}: failed`, String(e));
  }
  if (i < mpns.length - 1) await new Promise((r) => setTimeout(r, GAP_MS));
}

console.log(`done: ${withImage}/${mpns.length} parts have an MPN-matched image`);
