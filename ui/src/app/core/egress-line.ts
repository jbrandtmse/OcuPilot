/**
 * The data-egress line beneath a turn's message (Story 16.15), as the panel renders it.
 * Framework-free, like the rest of `core/` (AD-19), so `ui/tools/turn-egress.test.mjs` executes it
 * under `node --test`.
 *
 * **The instance decides; the browser only words it.** Every term comes from the turn's own
 * recorded egress fact (AD-42), never from the current default or the context chip's read, so an
 * earlier turn keeps its own line after the default moves. The line is text: `<provider>` and
 * `<host>` are filled by split and join, as the chip fills its tooltip (AD-11 rule 4).
 */

import { STRINGS } from './strings.ts';
import type { TurnEgress } from './turn.ts';

/** One rendered line: its sentence, and whether the screen context left the instance. */
export interface EgressLine {
  readonly text: string;
  readonly leaves: boolean;
}

/**
 * The line for `egress`, or `null` when there is none to draw. A turn that sent no screen context
 * says so and names the provider whatever its call's verdict, since the claim is about screen data
 * only; otherwise the line names the provider and host and says whether the data left.
 */
export function egressLine(egress: TurnEgress | null): EgressLine | null {
  if (egress === null) return null;
  if (!egress.contextSent) return { text: fill(STRINGS.egressLineNone, egress), leaves: false };
  if (egress.leavesInstance) return { text: fill(STRINGS.egressLineLeft, egress), leaves: true };
  return { text: fill(STRINGS.egressLineStayed, egress), leaves: false };
}

function fill(template: string, egress: TurnEgress): string {
  return template.split('<provider>').join(egress.provider).split('<host>').join(egress.endpointHost);
}
