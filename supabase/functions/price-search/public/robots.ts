// Minimal robots.txt (RFC 9309) evaluator: user-agent groups, Allow/Disallow
// with `*` and `$` wildcards, longest-match wins (Allow wins ties), plus the
// non-standard Crawl-delay directive. Pure: no I/O.

export interface RobotsRules {
  allow: string[];
  disallow: string[];
  crawlDelaySec: number | null;
}

export const ALLOW_ALL: RobotsRules = { allow: [], disallow: [], crawlDelaySec: null };
export const DISALLOW_ALL: RobotsRules = { allow: [], disallow: ["/"], crawlDelaySec: null };

interface Group {
  agents: string[];
  rules: RobotsRules;
}

/** Parses robots.txt and returns the rules that apply to `botToken`. */
export function parseRobots(text: string, botToken: string): RobotsRules {
  const groups: Group[] = [];
  let current: Group | null = null;
  let lastWasAgent = false;

  for (const rawLine of text.split(/\r?\n/)) {
    const line = rawLine.replace(/#.*$/, "").trim();
    const sep = line.indexOf(":");
    if (sep < 0) continue;
    const key = line.slice(0, sep).trim().toLowerCase();
    const value = line.slice(sep + 1).trim();

    if (key === "user-agent") {
      if (!current || !lastWasAgent) {
        current = { agents: [], rules: { allow: [], disallow: [], crawlDelaySec: null } };
        groups.push(current);
      }
      current.agents.push(value.toLowerCase());
      lastWasAgent = true;
      continue;
    }
    lastWasAgent = false;
    if (!current) continue;
    if (key === "allow" && value) current.rules.allow.push(value);
    else if (key === "disallow" && value) current.rules.disallow.push(value);
    else if (key === "crawl-delay") {
      const n = Number(value);
      if (Number.isFinite(n) && n >= 0) current.rules.crawlDelaySec = n;
    }
  }

  const token = botToken.toLowerCase();
  const specific = groups.filter((g) => g.agents.some((a) => a !== "*" && token.includes(a)));
  const chosen = specific.length > 0 ? specific : groups.filter((g) => g.agents.includes("*"));
  if (chosen.length === 0) return ALLOW_ALL;
  return {
    allow: chosen.flatMap((g) => g.rules.allow),
    disallow: chosen.flatMap((g) => g.rules.disallow),
    crawlDelaySec: chosen.map((g) => g.rules.crawlDelaySec).find((d) => d !== null) ?? null,
  };
}

/** `pathAndQuery` is e.g. "/arama?q=rtx". */
export function isAllowed(rules: RobotsRules, pathAndQuery: string): boolean {
  if (pathAndQuery === "/robots.txt") return true;
  const allowLen = longestMatch(rules.allow, pathAndQuery);
  const disallowLen = longestMatch(rules.disallow, pathAndQuery);
  if (disallowLen < 0) return true;
  return allowLen >= disallowLen;
}

function longestMatch(patterns: string[], path: string): number {
  let best = -1;
  for (const p of patterns) {
    if (patternToRegex(p).test(path)) best = Math.max(best, p.length);
  }
  return best;
}

function patternToRegex(pattern: string): RegExp {
  const anchored = pattern.endsWith("$");
  const body = (anchored ? pattern.slice(0, -1) : pattern)
    .split("*")
    .map((part) => part.replace(/[.+?^${}()|[\]\\]/g, "\\$&"))
    .join(".*");
  return new RegExp("^" + body + (anchored ? "$" : ""));
}

/**
 * Maps a robots.txt HTTP status to rules. Follows RFC 9309 §2.3.1 (missing
 * file => no restrictions, 5xx / network error => full disallow) with one
 * deliberate, stricter deviation: 401/403 means the site refuses bots, so we
 * treat it as full disallow rather than "unrestricted".
 */
export function rulesForStatus(status: number, text: string, botToken: string): RobotsRules {
  if (status >= 200 && status < 300) return parseRobots(text, botToken);
  if (status === 401 || status === 403) return DISALLOW_ALL;
  if (status >= 400 && status < 500) return ALLOW_ALL;
  return DISALLOW_ALL;
}
