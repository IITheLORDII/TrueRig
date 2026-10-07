// Polite HTTP fetching for public pages:
// - obeys robots.txt (cached per origin) and Crawl-delay,
// - identifies itself honestly (no browser impersonation),
// - spaces requests per host and respects a shared hourly budget,
// - backs off from a host after 403/429/503 instead of retrying around it.
// I/O is injected so the logic is testable without network.

import { isAllowed, type RobotsRules, rulesForStatus } from "./robots.ts";

export const BOT_TOKEN = "TrueRigBot";

export interface FetchDeps {
  fetch: typeof fetch;
  now: () => number;
  sleep: (ms: number) => Promise<void>;
  /** Returns false when the host's hourly request budget is used up. */
  takeBudget: (host: string) => Promise<boolean>;
  userAgent: string;
}

export type FetchOutcome =
  | { kind: "ok"; html: string }
  | { kind: "blocked-by-robots" }
  | { kind: "over-budget" }
  | { kind: "backing-off" }
  | { kind: "http-error"; status: number }
  | { kind: "network-error"; message: string };

const DEFAULT_DELAY_MS = 2000;
const MAX_DELAY_MS = 30_000;
const ROBOTS_TTL_MS = 24 * 3600_000;
const BACKOFF_MS = 6 * 3600_000;
const TIMEOUT_MS = 8000;
const MAX_BODY_BYTES = 3_000_000;
const BACKOFF_STATUSES = new Set([403, 429, 503]);

export class PoliteFetcher {
  private readonly robots = new Map<string, { rules: RobotsRules; at: number }>();
  private readonly lastHit = new Map<string, number>();
  private readonly backoffUntil = new Map<string, number>();
  private readonly deps: FetchDeps;

  constructor(deps: FetchDeps) {
    this.deps = deps;
  }

  async get(url: string): Promise<FetchOutcome> {
    const u = new URL(url);
    if (u.protocol !== "https:") return { kind: "http-error", status: 0 };
    const host = u.host;

    if ((this.backoffUntil.get(host) ?? 0) > this.deps.now()) {
      return { kind: "backing-off" };
    }
    const rules = await this.rulesFor(u.origin);
    if (!isAllowed(rules, u.pathname + u.search)) return { kind: "blocked-by-robots" };
    if (!(await this.deps.takeBudget(host))) return { kind: "over-budget" };

    await this.waitTurn(host, rules);
    return this.request(url, host);
  }

  private async rulesFor(origin: string): Promise<RobotsRules> {
    const cached = this.robots.get(origin);
    if (cached && this.deps.now() - cached.at < ROBOTS_TTL_MS) return cached.rules;
    let rules: RobotsRules;
    try {
      const res = await this.deps.fetch(`${origin}/robots.txt`, {
        headers: { "User-Agent": this.deps.userAgent },
        signal: AbortSignal.timeout(TIMEOUT_MS),
      });
      rules = rulesForStatus(res.status, res.ok ? await res.text() : "", BOT_TOKEN);
    } catch {
      rules = rulesForStatus(0, "", BOT_TOKEN); // unreachable => disallow
    }
    this.robots.set(origin, { rules, at: this.deps.now() });
    return rules;
  }

  private async waitTurn(host: string, rules: RobotsRules): Promise<void> {
    const delay = Math.min(
      MAX_DELAY_MS,
      rules.crawlDelaySec !== null ? rules.crawlDelaySec * 1000 : DEFAULT_DELAY_MS,
    );
    const last = this.lastHit.get(host);
    const wait = last === undefined ? 0 : last + delay - this.deps.now();
    if (wait > 0) await this.deps.sleep(wait);
    this.lastHit.set(host, this.deps.now());
  }

  private async request(url: string, host: string): Promise<FetchOutcome> {
    try {
      const res = await this.deps.fetch(url, {
        headers: {
          "User-Agent": this.deps.userAgent,
          "Accept": "text/html,application/xhtml+xml",
          "Accept-Language": "tr-TR,tr;q=0.9",
        },
        redirect: "follow",
        signal: AbortSignal.timeout(TIMEOUT_MS),
      });
      if (BACKOFF_STATUSES.has(res.status)) {
        this.backoffUntil.set(host, this.deps.now() + BACKOFF_MS);
        return { kind: "http-error", status: res.status };
      }
      if (!res.ok) return { kind: "http-error", status: res.status };
      const html = await res.text();
      return { kind: "ok", html: html.slice(0, MAX_BODY_BYTES) };
    } catch (e) {
      return { kind: "network-error", message: String(e) };
    }
  }
}
