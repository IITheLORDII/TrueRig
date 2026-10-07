const MAX_QUERY_LENGTH = 100;
const QUERY_PATTERN = /^[\p{L}\p{N} ._\-/+()]+$/u;

/** Trims, collapses whitespace, enforces length and a safe character set. */
export function validateQuery(raw: string | null): string | null {
  if (!raw) return null;
  const q = raw.trim().replace(/\s+/g, " ");
  if (q.length === 0 || q.length > MAX_QUERY_LENGTH) return null;
  return QUERY_PATTERN.test(q) ? q : null;
}
