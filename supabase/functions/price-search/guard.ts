// Abuse protection for the price endpoint.
// - RateLimiter: sliding-window caps per client (requests per minute, new
//   crawls per hour) and a global cap on crawls per hour, so unique queries
//   cannot be used to hammer the stores or run up costs.
// - allowedOrigin: CORS only for the configured web origins.
// - clientKey: salted hash of the caller's IP (the IP itself is never kept).

export interface RateLimits {
  perMinute: number;
  crawlsPerHour: number;
  globalCrawlsPerHour: number;
  now: () => number;
}

const MINUTE = 60_000;
const HOUR = 3_600_000;

export class RateLimiter {
  private readonly hits = new Map<string, number[]>();
  private readonly crawls = new Map<string, number[]>();
  private globalCrawls: number[] = [];
  private readonly limits: RateLimits;

  constructor(limits: RateLimits) {
    this.limits = limits;
  }

  /** Records a request; false when the client is over its per-minute cap. */
  request(client: string): boolean {
    return this.take(this.hits, client, MINUTE, this.limits.perMinute);
  }

  /** Records a crawl (cache miss); false when a cap is reached. */
  crawl(client: string): boolean {
    const now = this.limits.now();
    this.globalCrawls = this.globalCrawls.filter((t) => now - t < HOUR);
    if (this.globalCrawls.length >= this.limits.globalCrawlsPerHour) return false;
    if (!this.take(this.crawls, client, HOUR, this.limits.crawlsPerHour)) return false;
    this.globalCrawls.push(now);
    return true;
  }

  /** Seconds until the client's oldest counted request leaves its window. */
  retryAfterSec(client: string): number {
    const now = this.limits.now();
    const times = [...(this.hits.get(client) ?? []), ...(this.crawls.get(client) ?? [])];
    if (times.length === 0) return 60;
    return Math.max(1, Math.ceil((Math.min(...times) + MINUTE - now) / 1000));
  }

  private take(map: Map<string, number[]>, key: string, window: number, cap: number): boolean {
    const now = this.limits.now();
    const recent = (map.get(key) ?? []).filter((t) => now - t < window);
    if (recent.length >= cap) {
      map.set(key, recent);
      return false;
    }
    recent.push(now);
    map.set(key, recent);
    if (map.size > 50_000) map.clear(); // bound memory under attack
    return true;
  }
}

/**
 * The value for Access-Control-Allow-Origin: the caller's origin if it is
 * allowed, "*" while no origins are configured, otherwise null (no header).
 */
export function allowedOrigin(origin: string | null, allowed: string[]): string | null {
  if (allowed.length === 0) return "*";
  if (origin && allowed.includes(origin)) return origin;
  return null;
}

/** Salted SHA-256 of the client address, hex. */
export async function clientKey(ip: string, salt: string): Promise<string> {
  const data = new TextEncoder().encode(`${salt}:${ip}`);
  const digest = await crypto.subtle.digest("SHA-256", data);
  return [...new Uint8Array(digest)].map((b) => b.toString(16).padStart(2, "0")).join("");
}
