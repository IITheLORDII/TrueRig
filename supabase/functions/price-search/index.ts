// Supabase Edge Function: GET /price-search?q=<model | MPN | EAN>
//
// Serves cached results (< CACHE_HOURS old). On a miss it reads PUBLIC store
// pages politely (robots.txt, crawl delay, hourly budget, honest UA) and
// extracts schema.org JSON-LD offers and an MPN/GTIN-matched product image.
// Response envelope: { success, data, meta: { image_url, image_source }, error }.
//
// Abuse protection: per-client request and crawl caps (salted hash of the
// IP, never the IP itself), a global crawl cap, and CORS limited to the
// origins in ALLOWED_ORIGINS (comma separated; open while unset).

import { createClient, type SupabaseClient } from "jsr:@supabase/supabase-js@2";
import { collect } from "./public/collector.ts";
import { BOT_TOKEN, PoliteFetcher } from "./public/polite_fetch.ts";
import { STORES } from "./public/stores.ts";
import { validateQuery } from "./query.ts";
import { allowedOrigin, clientKey, RateLimiter } from "./guard.ts";

const CACHE_HOURS = 6;
const IMAGE_CACHE_DAYS = 30;
const HOURLY_BUDGET_PER_HOST = 60;
const BOT_INFO_URL = Deno.env.get("BOT_INFO_URL") ?? "https://truerig.app/bot";

const REQUESTS_PER_MINUTE = 20;
const CRAWLS_PER_CLIENT_HOUR = 10;
const GLOBAL_CRAWLS_HOUR = 200;

const ALLOWED_ORIGINS = (Deno.env.get("ALLOWED_ORIGINS") ?? "")
  .split(",").map((s) => s.trim()).filter(Boolean);
// A per-isolate random salt when none is configured (keys then only live as
// long as the isolate, which is fine for rate limiting).
const RATE_SALT = Deno.env.get("RATE_SALT") ?? crypto.randomUUID();

const limiter = new RateLimiter({
  perMinute: REQUESTS_PER_MINUTE,
  crawlsPerHour: CRAWLS_PER_CLIENT_HOUR,
  globalCrawlsPerHour: GLOBAL_CRAWLS_HOUR,
  now: Date.now,
});

function corsHeaders(req: Request): Record<string, string> {
  const origin = allowedOrigin(req.headers.get("origin"), ALLOWED_ORIGINS);
  return {
    ...(origin ? { "Access-Control-Allow-Origin": origin } : {}),
    "Access-Control-Allow-Methods": "GET, OPTIONS",
    "Access-Control-Allow-Headers": "authorization, apikey, content-type",
    "Vary": "Origin",
  };
}

function json(req: Request, status: number, body: unknown, extra: Record<string, string> = {}): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders(req),
      "Content-Type": "application/json; charset=utf-8",
      "X-Content-Type-Options": "nosniff",
      "Cache-Control": "no-store",
      ...extra,
    },
  });
}

const fail = (req: Request, status: number, error: string, extra?: Record<string, string>) =>
  json(req, status, { success: false, data: null, meta: null, error }, extra);

/** First address in X-Forwarded-For (set by the platform's proxy). */
function clientIp(req: Request): string {
  const fwd = req.headers.get("x-forwarded-for") ?? "";
  return fwd.split(",")[0].trim() || "unknown";
}

let db: SupabaseClient | null = null;
let fetcher: PoliteFetcher | null = null;

/** Lazily created per isolate so robots.txt and delays persist across calls. */
function services(): { db: SupabaseClient; fetcher: PoliteFetcher } | null {
  const url = Deno.env.get("SUPABASE_URL");
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !key) return null;
  db ??= createClient(url, key, { auth: { persistSession: false } });
  const client = db;
  fetcher ??= new PoliteFetcher({
    fetch,
    now: Date.now,
    sleep: (ms) => new Promise((r) => setTimeout(r, ms)),
    userAgent: `${BOT_TOKEN}/1.0 (+${BOT_INFO_URL})`,
    takeBudget: (host) => takeBudget(client, host),
  });
  return { db: client, fetcher };
}

/** Records a request and reports whether the host is within its budget. */
async function takeBudget(client: SupabaseClient, host: string): Promise<boolean> {
  const since = new Date(Date.now() - 3600_000).toISOString();
  const { count, error } = await client
    .from("crawl_requests")
    .select("id", { count: "exact", head: true })
    .eq("host", host)
    .gte("requested_at", since);
  if (error) {
    console.error("price-search: budget check failed", error);
    return false; // fail closed: never crawl without accounting
  }
  if ((count ?? 0) >= HOURLY_BUDGET_PER_HOST) return false;
  const { error: insertError } = await client.from("crawl_requests").insert({ host });
  if (insertError) console.error("price-search: budget insert failed", insertError);
  return !insertError;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { headers: corsHeaders(req) });
  if (req.method !== "GET") return fail(req, 405, "Method not allowed");

  const client = await clientKey(clientIp(req), RATE_SALT);
  if (!limiter.request(client)) {
    return fail(req, 429, "Too many requests", {
      "Retry-After": String(limiter.retryAfterSec(client)),
    });
  }

  const q = validateQuery(new URL(req.url).searchParams.get("q"));
  if (!q) return fail(req, 400, "Invalid query");
  const key = q.toLowerCase();

  const svc = services();
  if (!svc) {
    console.error("price-search: missing Supabase env");
    return fail(req, 500, "Server misconfigured");
  }

  try {
    const cached = await readCache(svc.db, key);
    if (cached) return json(req, 200, { success: true, ...cached, error: null });

    // A cache miss crawls stores: capped per client and overall.
    if (!limiter.crawl(client) || !(await takeCrawl(svc.db, client))) {
      return fail(req, 429, "Too many new searches, try again later", {
        "Retry-After": "600",
      });
    }
    const result = await collect(q, STORES, svc.fetcher);
    if (result.skipped.length > 0) {
      console.log("price-search skipped stores", { q, skipped: result.skipped });
    }
    await writeCache(svc.db, key, result);
    const now = new Date().toISOString();
    return json(req, 200, {
      success: true,
      data: result.offers.map((o) => ({ ...o, fetched_at: now })),
      meta: {
        image_url: result.image?.url ?? null,
        image_source: result.image?.sourceUrl ?? null,
      },
      error: null,
    });
  } catch (e) {
    console.error("price-search failed", { q, error: String(e) });
    return fail(req, 502, "Price lookup failed");
  }
});

/**
 * Shared (all isolates) crawl caps, kept in the database: per client per
 * hour and overall per hour. Fails closed. Old rows are pruned now and then.
 */
async function takeCrawl(db: SupabaseClient, client: string): Promise<boolean> {
  const since = new Date(Date.now() - 3600_000).toISOString();
  const [mine, all] = await Promise.all([
    db.from("api_crawls").select("id", { count: "exact", head: true })
      .eq("client", client).gte("requested_at", since),
    db.from("api_crawls").select("id", { count: "exact", head: true })
      .gte("requested_at", since),
  ]);
  if (mine.error || all.error) {
    console.error("price-search: crawl cap check failed", mine.error ?? all.error);
    return false;
  }
  if ((mine.count ?? 0) >= CRAWLS_PER_CLIENT_HOUR) return false;
  if ((all.count ?? 0) >= GLOBAL_CRAWLS_HOUR) return false;
  const { error } = await db.from("api_crawls").insert({ client });
  if (error) {
    console.error("price-search: crawl cap insert failed", error);
    return false;
  }
  if (Math.random() < 0.02) void prune(db);
  return true;
}

async function prune(db: SupabaseClient) {
  const dayAgo = new Date(Date.now() - 86400_000).toISOString();
  const results = await Promise.all([
    db.from("api_crawls").delete().lt("requested_at", dayAgo),
    db.from("crawl_requests").delete().lt("requested_at", dayAgo),
  ]);
  for (const r of results) if (r.error) console.error("price-search: prune failed", r.error);
}

async function readCache(client: SupabaseClient, key: string) {
  const since = new Date(Date.now() - CACHE_HOURS * 3600_000).toISOString();
  const { data: offers, error } = await client
    .from("price_offers")
    .select("store, price, currency, url, in_stock, rating, review_count, fetched_at")
    .eq("query", key)
    .gte("fetched_at", since)
    .order("price", { ascending: true })
    .limit(30);
  if (error) throw error;
  if (!offers || offers.length === 0) return null;
  const image = await readImage(client, key);
  return { data: offers, meta: image };
}

async function readImage(client: SupabaseClient, key: string) {
  const since = new Date(Date.now() - IMAGE_CACHE_DAYS * 86400_000).toISOString();
  const { data, error } = await client
    .from("part_images")
    .select("image_url, source_url")
    .eq("query", key)
    .gte("fetched_at", since)
    .maybeSingle();
  if (error) console.error("price-search: image read failed", error);
  return { image_url: data?.image_url ?? null, image_source: data?.source_url ?? null };
}

async function writeCache(
  client: SupabaseClient,
  key: string,
  result: Awaited<ReturnType<typeof collect>>,
) {
  if (result.offers.length > 0) {
    const { error } = await client.from("price_offers").insert(
      result.offers.map((o) => ({ ...o, query: key })),
    );
    if (error) console.error("price-search: offer cache insert failed", error);
  }
  if (result.image) {
    const { error } = await client.from("part_images").upsert({
      query: key,
      image_url: result.image.url,
      source_url: result.image.sourceUrl,
      store: result.image.store,
      fetched_at: new Date().toISOString(),
    });
    if (error) console.error("price-search: image cache upsert failed", error);
  }
}
