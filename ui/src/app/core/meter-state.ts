/**
 * The meter state rule (Story 6.9, AD-19): the same word-to-state and percent-to-state mapping
 * `shell/meter.ts` colors by and `areas/os-management/system-usage.store.ts` computes from a read
 * row. Reused by 6.11 (Database details' free-space meter).
 *
 * Framework-free, like the rest of `core/`, so `ui/tools/meter-state.test.mjs` executes it under
 * `node --test`.
 */

/** The three severities a meter's fill, value text and word can carry. */
export type MeterSeverity = 'normal' | 'warning' | 'error';

/** A meter's resolved severity and the word shown beside its value. */
export interface MeterStateResult {
  readonly state: MeterSeverity;
  readonly word: string;
}

/**
 * The dashboard's own word, read as a severity: `Normal` -> normal, `Warning` -> warning,
 * `Troubled` -> error. Any other word -- a vendor string this closed vocabulary does not name --
 * is read as `warning` rather than silently as `normal`, so an unrecognized value still draws
 * attention; the word itself is always the vendor's own, verbatim -- EXPERIENCE.md's meter row: "shown as a word",
 * this is vendor data rendered as reported, never a translated string, the severity-chip precedent.
 */
export function meterStateFromWord(word: string): MeterStateResult {
  if (word === 'Normal') return { state: 'normal', word };
  if (word === 'Warning') return { state: 'warning', word };
  if (word === 'Troubled') return { state: 'error', word };
  return { state: 'warning', word };
}

/**
 * A percentage read as a severity, with the same cut-offs the vendor's own lock-table meter uses
 * (DESIGN.md's labeled assumption, AC4): at or above 95 is `Troubled`, at or above 85 is
 * `Warning`, and everything below that is `Normal`. Both bounds are inclusive of the transition --
 * 85.0 reads `Warning`, 95.0 reads `Troubled` -- and the word is minted here rather than read from
 * a vendor answer, since no vendor value backs a computed percentage.
 */
export function meterStateFromPercent(percent: number): MeterStateResult {
  if (percent >= 95) return { state: 'error', word: 'Troubled' };
  if (percent >= 85) return { state: 'warning', word: 'Warning' };
  return { state: 'normal', word: 'Normal' };
}
