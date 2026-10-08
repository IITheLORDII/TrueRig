// Matches catalog items to store product URLs / titles. Pure, no I/O.
//
// Search pages are closed to bots on most Turkish stores, so the indexer
// finds products through sitemaps: the URL slug is the only thing known
// before fetching, and the product title confirms the match afterwards.

import { normalize } from "../../supabase/functions/price-search/public/match.ts";

export type ItemKind = "cpu" | "gpu" | "laptop" | "desktop" | "phone" | "watch";

export interface PriceItem {
  key: string;
  kind: ItemKind;
  brand: string;
  model: string;
  name: string;
  mpn?: string;
  ref_usd?: number;
  aliases?: string[];
}

/** Words that change the product tier when they are not asked for. */
const TIER_WORDS = new Set(["ti", "super", "xt", "xtx", "x3d", "pro", "max", "plus", "ultra", "mini", "lite", "fe"]);

/** Suffixes that name the same chip (Intel F = graphics disabled). */
const SAME_CHIP_SUFFIX = new Set(["f"]);

const TIER_SUFFIX = new Set(["ti", "super", "xt", "xtx", "x3d", "s"]);

/** Vendor words that stores often leave out of slugs. */
const GENERIC = new Set(["geforce", "radeon", "nvidia", "amd", "intel", "core", "apple", "gaming", "laptop", "gpu"]);

const ACCESSORY = [
  "kilif", "kapak", "canta", "koruyucu", "cam", "kablo", "sarj", "adaptor",
  "kordon", "kayis", "stand", "sticker", "batarya", "film", "tutucu", "dock",
  "yedek", "parca", "bileklik", "kasa",
];

const KIND_REJECT: Record<ItemKind, string[]> = {
  cpu: [
    "laptop", "notebook", "dizustu", "bilgisayar", "anakart", "sogutucu", "fan", "rtx", "gtx", "rx", "ekran",
    // Whole systems: "Acer ... i7-1255U 16GB 512GB SSD 15.6 FHD Dos".
    "ssd", "fhd", "inc", "windows", "dos", "gb",
  ],
  gpu: [
    "laptop", "notebook", "dizustu", "bilgisayar", "monitor", "i3", "i5", "i7", "i9", "ryzen", "tablet",
    "ssd", "fhd", "inc", "windows", "dos",
  ],
  laptop: ACCESSORY,
  desktop: ACCESSORY,
  phone: [...ACCESSORY, "saat", "watch", "tablet", "kulaklik"],
  watch: [...ACCESSORY, "telefon"],
};

/** Tokens with letter/digit runs split too: "rtx4060" -> rtx4060, rtx, 4060. */
export function tokensOf(text: string): Set<string> {
  const out = new Set<string>();
  for (const t of normalize(text).split(" ")) {
    if (!t) continue;
    out.add(t);
    for (const part of t.match(/[a-z]+|[0-9]+/g) ?? []) out.add(part);
  }
  return out;
}

/** "TUF Gaming F15 / FX50x" -> two alternatives; "(2. nesil)" dropped. */
export function alternatives(item: PriceItem): string[][] {
  const names = [
    ...item.model.replace(/\([^)]*\)/g, " ").split("/"),
    ...(item.aliases ?? []),
  ];
  const out: string[][] = [];
  for (const n of names) {
    const toks = normalize(n).split(" ").filter((t) => t && !GENERIC.has(t));
    if (toks.length > 0) out.push(toks);
  }
  return out;
}

function brandTokens(item: PriceItem): string[] {
  return normalize(item.brand).split(" ").filter((t) => t && !GENERIC.has(t));
}

/** Text of a URL path, e.g. "/msi-geforce-rtx-4060.html" -> "msi geforce rtx 4060 html". */
export function slugText(url: string): string {
  try {
    return decodeURIComponent(new URL(url).pathname);
  } catch {
    return url;
  }
}

/**
 * Score (lower is better: fewer unrelated words) when `text` names the
 * item, otherwise null. Used on URL slugs and on product titles.
 */
export function matchScore(item: PriceItem, text: string): number | null {
  const toks = tokensOf(text);
  if (KIND_REJECT[item.kind].some((w) => toks.has(w))) return null;
  const needsBrand = item.kind === "laptop" || item.kind === "desktop";
  if (needsBrand && !brandTokens(item).every((b) => toks.has(b))) return null;

  // Model codes grow in listings: "FX507" -> "fx507zc4", "G770" -> "g770".
  // Not when the rest is a tier ("9950x" + "3d", "4070" + "ti").
  const grows = (x: string, t: string) => {
    const rest = x.slice(t.length);
    return x.startsWith(t) && !/^[0-9]/.test(rest) && !TIER_SUFFIX.has(rest);
  };
  const has = (t: string) =>
    toks.has(t) ||
    (t.length >= 4 && /[a-z]/.test(t) && /[0-9]/.test(t) && [...toks].some((x) => grows(x, t)));

  // A model number written with an extra letter is another model:
  // "7600" -> "7600x", "5600" -> "5600x"/"5600g". Intel's F (no graphics,
  // same chip) is accepted: "12400" -> "12400f".
  const otherModel = (alt: string[]) =>
    alt.some((t) =>
      /^[0-9]{3,}$/.test(t) &&
      [...toks].some((x) => {
        if (!x.startsWith(t) || x === t) return false;
        const rest = x.slice(t.length);
        return /^[a-z]+$/.test(rest) && !SAME_CHIP_SUFFIX.has(rest) && !alt.includes(rest);
      })
    );

  let best: number | null = null;
  for (const alt of alternatives(item)) {
    if (!alt.every(has)) continue;
    if (otherModel(alt)) continue;
    const asked = new Set(alt);
    const extraTier = [...toks].some((t) => TIER_WORDS.has(t) && !asked.has(t));
    if (extraTier) continue;
    const score = toks.size - alt.length;
    if (best === null || score < best) best = score;
  }
  return best;
}

/** Best `limit` product URLs for an item, closest names first. */
export function bestUrls(item: PriceItem, urls: string[], limit: number): string[] {
  const scored: [number, string][] = [];
  for (const u of urls) {
    const s = matchScore(item, slugText(u));
    if (s !== null) scored.push([s, u]);
  }
  scored.sort((a, b) => a[0] - b[0] || a[1].length - b[1].length);
  return scored.slice(0, limit).map(([, u]) => u);
}

/**
 * Token -> URLs lookup over a store's product URLs, so each catalog item
 * only scores the URLs that contain one of its words instead of every URL
 * (Pazarama alone lists over a million).
 */
export class SlugIndex {
  private readonly postings = new Map<string, number[]>();
  private readonly texts: string[];
  readonly urls: string[];

  constructor(urls: string[]) {
    this.urls = urls;
    this.texts = urls.map(slugText);
    this.texts.forEach((t, i) => {
      for (const tok of tokensOf(t)) {
        let list = this.postings.get(tok);
        if (!list) this.postings.set(tok, (list = []));
        list.push(i);
      }
    });
  }

  /** URLs worth scoring: those containing the rarest exact word of an
   * alternative. Model codes that may grow ("fx507" -> "fx507zc4") are
   * skipped as anchors; with no usable anchor every URL is a candidate. */
  candidates(item: PriceItem): number[] {
    const out = new Set<number>();
    for (const alt of alternatives(item)) {
      const anchors = alt
        .filter((t) => !(/[a-z]/.test(t) && /[0-9]/.test(t)))
        .map((t) => this.postings.get(t) ?? []);
      if (anchors.length === 0) return this.urls.map((_, i) => i);
      const rarest = anchors.reduce((a, b) => (a.length <= b.length ? a : b));
      for (const i of rarest) out.add(i);
    }
    return [...out];
  }

  /** Same result as [bestUrls] over all URLs, much faster. */
  best(item: PriceItem, limit: number): string[] {
    const scored: [number, string][] = [];
    for (const i of this.candidates(item)) {
      const s = matchScore(item, this.texts[i]);
      if (s !== null) scored.push([s, this.urls[i]]);
    }
    scored.sort((a, b) => a[0] - b[0] || a[1].length - b[1].length);
    return scored.slice(0, limit).map(([, u]) => u);
  }
}
