// Decides whether a scraped product really is the part the user asked for,
// so a "RTX 4070" search does not return a "RTX 4070 Ti Super". Pure.

import type { PageProduct } from "./jsonld.ts";

const FOLD: Record<string, string> = {
  "ı": "i", "İ": "i", "ş": "s", "Ş": "s", "ğ": "g", "Ğ": "g",
  "ü": "u", "Ü": "u", "ö": "o", "Ö": "o", "ç": "c", "Ç": "c",
};

/** Same normalisation as the Dart PartCatalog.normalize. */
export function normalize(s: string): string {
  return [...s].map((c) => FOLD[c] ?? c).join("").toLowerCase()
    .replace(/[^a-z0-9]+/g, " ").trim().replace(/\s+/g, " ");
}

export const compact = (s: string): string => normalize(s).replace(/ /g, "");

/** Words that change the product tier when present in the title. */
const TIER_WORDS = ["ti", "super", "xt", "xtx", "x3d", "pro", "max", "plus"];

export type MatchKind = "identifier" | "name" | "none";

/**
 * A single token of 10+ chars mixing letters and 4+ digits, e.g.
 * "GV-N407SWF3OC-12GD", "CMK32GX5M2B6000Z30", "BX8071514900K".
 */
export function looksLikePartNumber(query: string): boolean {
  const q = query.trim();
  if (/\s/.test(q)) return false;
  const c = compact(q);
  const letters = (c.match(/[a-z]/g) ?? []).length;
  const digits = (c.match(/[0-9]/g) ?? []).length;
  return c.length >= 10 && letters >= 2 && digits >= 4;
}

/**
 * "identifier": MPN/SKU/GTIN equals the query — safe for linking images.
 * "name": every query token is in the title and no extra tier word is.
 */
export function matchKind(p: PageProduct, query: string): MatchKind {
  const q = compact(query);
  if (!q) return "none";
  for (const id of [p.mpn, p.sku, p.gtin]) {
    if (id && compact(id) === q) return "identifier";
  }
  // Aggregators often embed the MPN in the title instead of an `mpn` field.
  if (looksLikePartNumber(query) && compact(p.name).includes(q)) {
    return "identifier";
  }
  const qTokens = normalize(query).split(" ");
  const nameTokens = normalize(p.name).split(" ");
  const nameCompact = nameTokens.join("");
  const allPresent = qTokens.every((t) =>
    nameTokens.includes(t) || nameCompact.includes(t)
  );
  if (!allPresent) return "none";
  const extraTier = TIER_WORDS.some((w) =>
    nameTokens.includes(w) && !qTokens.includes(w)
  );
  return extraTier ? "none" : "name";
}
