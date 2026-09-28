/**
 * The turns-an-hour refusal (Story 14.6, AD-41), as the panel renders it. Framework-free, like the
 * rest of `core/` (AD-19), so `ui/tools/turn-limit.test.mjs` executes it under `node --test`.
 *
 * **The instance decides; the browser only displays.** A start past the Switches limit is refused
 * `403 TURN.LIMITHOUR` with `detail` `{limit, retryAt}`, `retryAt` ISO-8601 UTC. The client never
 * counts turns and never withholds a Send; it renders the published banner with `retryAt` as a
 * zero-padded 24-hour `hh:mm` in the browser's own time zone (Conventions > Dates), and the
 * refused turn's transcript line.
 */

import { STRINGS } from './strings.ts';

/** The machine code a start refused for the limit carries (`OcuPilot.Api.Error.TURNLIMITHOUR`). */
export const TURN_LIMIT_CODE = 'TURN.LIMITHOUR';

/** What the refusal's `detail` carries: the limit in force and when the user may send again. */
export interface TurnLimit {
  readonly limit: number;
  readonly retryAt: string;
}

/**
 * The refusal's `detail` as a `TurnLimit`, or `null` when it is not one -- a limit that is not a
 * whole number of at least 1, or a `retryAt` that is not a date. A caller holding `null` renders
 * the envelope's own `reason` instead, which the instance wrote in UTC.
 */
export function turnLimitOf(detail: Readonly<Record<string, unknown>> | null): TurnLimit | null {
  if (detail === null || typeof detail !== 'object') return null;
  const limit = detail['limit'];
  const retryAt = detail['retryAt'];
  if (typeof limit !== 'number' || !Number.isInteger(limit) || limit < 1) return null;
  if (typeof retryAt !== 'string' || Number.isNaN(Date.parse(retryAt))) return null;
  return { limit, retryAt };
}

function twoDigits(value: number): string {
  return String(value).padStart(2, '0');
}

/** The published turn-limit banner with `<n>` filled and `<hh:mm>` as the browser's local time. */
export function turnLimitBanner(limit: number, retryAt: string): string {
  const at = new Date(retryAt);
  const time = `${twoDigits(at.getHours())}:${twoDigits(at.getMinutes())}`;
  return STRINGS.agentTurnLimitBanner.split('<n>').join(String(limit)).split('<hh:mm>').join(time);
}

/** The refused turn's published transcript line with `<n>` filled. */
export function turnLimitLine(limit: number): string {
  return STRINGS.agentTurnLimitLine.split('<n>').join(String(limit));
}
