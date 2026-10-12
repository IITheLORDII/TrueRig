// URL safety for anything fetched or handed to the app.
// - isPrivateHost: never contact loopback / private / link-local / metadata
//   addresses (server-side request forgery).
// - sameSite: a URL stays on the store's own site (www and subdomains ok,
//   look-alike domains not).
// - isTrustedStoreUrl: known store domains an offer may point to. Keep in
//   sync with app/lib/core/net/trusted_hosts.dart.

export const TRUSTED_STORE_DOMAINS = [
  // Turkey
  "akakce.com", "cimri.com", "epey.com", "hepsiburada.com", "trendyol.com",
  "n11.com", "amazon.com.tr", "vatanbilgisayar.com", "itopya.com",
  "incehesap.com", "teknosa.com", "mediamarkt.com.tr", "gaming.gen.tr",
  "monsternotebook.com.tr", "troyestore.com", "pazarama.com", "sinerji.gen.tr",
  // Global
  "amazon.com", "newegg.com", "pcpartpicker.com",
];

const stripBrackets = (h: string) => h.replace(/^\[|\]$/g, "").toLowerCase();

function ipv4(host: string): number[] | null {
  const m = /^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$/.exec(host);
  if (!m) return null;
  const parts = m.slice(1).map(Number);
  return parts.every((p) => p <= 255) ? parts : null;
}

/** Loopback, private, link-local, CGNAT, unspecified and internal names. */
export function isPrivateHost(rawHost: string): boolean {
  const host = stripBrackets(rawHost);
  if (
    host === "localhost" || host.endsWith(".localhost") ||
    host.endsWith(".local") || host.endsWith(".internal") || host === ""
  ) return true;
  const v4 = ipv4(host);
  if (v4) {
    const [a, b] = v4;
    return a === 0 || a === 10 || a === 127 ||
      (a === 169 && b === 254) ||
      (a === 172 && b >= 16 && b <= 31) ||
      (a === 192 && b === 168) ||
      (a === 100 && b >= 64 && b <= 127);
  }
  if (host.includes(":")) {
    // IPv6 literal.
    if (host === "::1" || host === "::") return true;
    if (/^f[cd][0-9a-f]{2}:/.test(host)) return true; // fc00::/7
    if (/^fe[89ab][0-9a-f]:/.test(host)) return true; // fe80::/10
    const mapped = /^::ffff:(\d+\.\d+\.\d+\.\d+)$/.exec(host);
    if (mapped) return isPrivateHost(mapped[1]);
  }
  return false;
}

function hostOf(url: string): string | null {
  try {
    return new URL(url).hostname.toLowerCase();
  } catch {
    return null;
  }
}

const bare = (h: string) => h.replace(/^www\./, "");

/** [url] is on the same site as [origin] (www and subdomains allowed). */
export function sameSite(url: string, origin: string): boolean {
  const a = hostOf(url);
  const b = hostOf(origin);
  if (!a || !b) return false;
  const site = bare(b);
  return bare(a) === site || a.endsWith(`.${site}`);
}

/** https page on a known store domain, default port, no credentials. */
export function isTrustedStoreUrl(url: string): boolean {
  let u: URL;
  try {
    u = new URL(url);
  } catch {
    return false;
  }
  if (u.protocol !== "https:" || u.username || u.password) return false;
  if (u.port && u.port !== "443") return false;
  const host = u.hostname.toLowerCase();
  return TRUSTED_STORE_DOMAINS.some((d) => host === d || host.endsWith(`.${d}`));
}
