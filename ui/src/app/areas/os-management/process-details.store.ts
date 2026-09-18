/**
 * Process details' own state (Story 6.8): which of a process's declared fields render under which
 * of the page's three group headings, and the word `InTransaction` reads as.
 *
 * Framework-free, like the rest of `core/` and `areas/tasks/details.store.ts`, so
 * `ui/tools/process-details-store.test.mjs` executes it under `node --test` without an Angular
 * test bed.
 */

import { fieldOf } from '../../core/table-model.ts';
import { STRINGS } from '../../core/strings.ts';

/** The page's three group headings. */
export type ProcessDetailsGroup = 'general' | 'execution' | 'client';

/**
 * The Execution group's own columns (Design Notes). Any declared column not named here and not in
 * `CLIENT_FIELDS` renders in General, so nothing a future field adds is silently hidden.
 */
const EXECUTION_FIELDS: ReadonlySet<string> = new Set([
  'State',
  'InTransaction',
  'Routine',
  'CurrentLineAndRoutine',
  'Location',
]);

/** The Client application group's own columns (Design Notes). */
const CLIENT_FIELDS: ReadonlySet<string> = new Set(['ClientNodeName', 'ClientExecutableName', 'ClientIPAddress']);

/**
 * The group `field` renders under. `execution` and `client` are this page's own constants naming
 * their columns; every other declared column, present or future, falls to `general`.
 */
export function groupFor(field: string): ProcessDetailsGroup {
  if (EXECUTION_FIELDS.has(field)) return 'execution';
  if (CLIENT_FIELDS.has(field)) return 'client';
  return 'general';
}

/**
 * `InTransaction`'s own word: "Yes" for a non-zero value, "No" for zero, absent or unparseable
 * (EXPERIENCE.md's `tableStatusYes` / `tableStatusNo`, read directly rather than through
 * `cellView`, whose own boolean rule does not apply to a vendor value that arrives as text).
 */
export function inTransactionText(row: unknown): string {
  const value = fieldOf(row, 'InTransaction');
  if (typeof value === 'boolean') return value ? STRINGS.tableStatusYes : STRINGS.tableStatusNo;
  const numeric = Number(value);
  const nonZero = Number.isFinite(numeric) && numeric !== 0;
  return nonZero ? STRINGS.tableStatusYes : STRINGS.tableStatusNo;
}
