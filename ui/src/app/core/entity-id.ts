/**
 * The client mirror of `OcuPilot.Kernel.EntityId` (AD-13) and the single place the
 * client encodes or decodes an entity id.
 *
 * The wire contract is encode-twice, decode-once. A path segment reaches a
 * `%CSP.REST` class already percent-decoded exactly once and UTF-8 decoded, so a
 * singly-encoded id arrives with its encoding already consumed and the server's
 * one decode would corrupt it; `%2F` never arrives at all, because the front web
 * server refuses an encoded slash before IRIS sees the request, while `%252F`
 * passes and decodes to `%2F` in transit.
 *
 * `encodeURIComponent` already UTF-8-encodes before percent-encoding, which is the
 * conversion the ObjectScript side does explicitly, so applying it twice produces a
 * segment `Kernel.EntityId.Decode` reads back byte-for-byte. It is not necessarily the
 * same segment `Kernel.EntityId.Encode` emits: the two percent-encoders disagree on a
 * few unreserved characters (`~` survives `encodeURIComponent` and becomes `%7E` under
 * `$ZConvert(...,"O","URL")`), so the same id can have two spellings on the wire, both
 * of which decode correctly. Nothing may compare two encoded segments for equality.
 * On the way back the router has already decoded the segment once, so one
 * `decodeURIComponent` completes the pair.
 *
 * **The dot is escaped in both passes** (DW-97), which `encodeURIComponent` leaves alone.
 * An id such as `a..b` would otherwise reach the wire carrying a literal `..`, which the
 * static handler refuses outright before it resolves a path (AD-21) -- so the deep link would
 * answer 400 instead of the shell document. Escaping it means the segment carries
 * `%252E%252E`, the one decode in transit turns that into the text `%2E%2E`, and no layer sees
 * a literal `..`. `OcuPilot.Kernel.EntityId.PercentEncode` does the same thing on the same
 * pass, so the two sides still produce the same bytes; `ui/tools/entity-id.test.mjs` and
 * `OcuPilot.Test.EntityId` both carry dotted rows so neither can drift alone.
 */

/**
 * The character separating the parts of a composite id, mirroring
 * `OcuPilot.Kernel.EntityId.COMPOSITESEPARATOR`. A composite id is still ONE path segment
 * (AD-13): the descriptor names the parts and this codec joins them, so no screen invents a
 * second composite grammar. Authored as an escape, never a literal byte (Rule 14).
 */
export const COMPOSITE_SEPARATOR = '\u0001';

/** Join the parts of a composite id into the single value `encodeEntityId` takes. */
export function joinCompositeId(parts: readonly string[]): string {
  return parts.join(COMPOSITE_SEPARATOR);
}

/** Split a composite id back into its parts, in declaration order. */
export function splitCompositeId(value: string): string[] {
  return value.split(COMPOSITE_SEPARATOR);
}

/** One percent-encoding pass, with the dot escaped so no `..` survives into a path segment. */
function percentEncodeOnce(value: string): string {
  return encodeURIComponent(value).split('.').join('%2E');
}

/** Encode `id` into exactly one URL path segment (encode twice). */
export function encodeEntityId(id: string): string {
  return percentEncodeOnce(percentEncodeOnce(id));
}

/**
 * Decode one route parameter back into the original entity id (decode once).
 * Call this on the value the router hands the component, never on
 * `encodeEntityId`'s own output. A segment the browser never encoded is returned
 * unchanged rather than throwing, so a malformed URL renders an empty screen
 * instead of a blank page.
 */
export function decodeEntityId(segment: string): string {
  try {
    return decodeURIComponent(segment);
  } catch {
    return segment;
  }
}
