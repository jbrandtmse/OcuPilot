/**
 * Database details' own state (Story 6.11): the one value meter its page draws for
 * `AvailableSpace`.
 *
 * Framework-free, like `process-details.store.ts` and `system-usage.store.ts`, so
 * `ui/tools/database-details-store.test.mjs` executes it under `node --test` without an Angular
 * test bed.
 *
 * **One value meter, no percentage and no state.** `AvailableSpace` and `Size` are not published
 * in the same unit (Boundaries), so this screen declares no percentage meter the way System usage's
 * Shared memory does -- it reuses `meterViewFor` and its `MeterConfig`/`MeterView` shapes from
 * `system-usage.store.ts` rather than re-deriving them, since the meter's resolution rule does not
 * change screen to screen.
 */

import { meterViewFor, type MeterConfig, type MeterView } from './system-usage.store.ts';
import { STRINGS } from '../../core/strings.ts';

/** The one meter this screen draws. */
export const DATABASE_METER_CONFIG: MeterConfig = {
  kind: 'value',
  label: STRINGS.databaseColumnAvailable,
  field: 'AvailableSpace',
};

/** The Available-space meter's resolved view from the last-good `row` and the page's fault text. */
export function availableSpaceMeterView(row: unknown, faultText: string | null): MeterView {
  return meterViewFor(DATABASE_METER_CONFIG, row, faultText);
}

/**
 * Whether a declared column renders in the flat properties group rather than as the meter:
 * every column but `AvailableSpace`, which the meter draws instead. `Directory`, the name field,
 * renders as an ordinary property like `process-details.page.ts` renders `Pid`.
 */
export function isPropertyField(field: string): boolean {
  return field !== 'AvailableSpace';
}
