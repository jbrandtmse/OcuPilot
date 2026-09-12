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
 * conversion the ObjectScript side does explicitly, so applying it twice produces
 * exactly the segment `Encode` produces. On the way back the router has already
 * decoded the segment once, so one `decodeURIComponent` completes the pair.
 */

/** Encode `id` into exactly one URL path segment (encode twice). */
export function encodeEntityId(id: string): string {
  return encodeURIComponent(encodeURIComponent(id));
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
