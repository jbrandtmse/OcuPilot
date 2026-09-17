/**
 * System usage's own state (Story 6.9): which of the row's eighteen fields feed the counters
 * group, and how the other nine become the screen's seven meters.
 *
 * Framework-free, like the rest of `core/` and `process-details.store.ts`, so
 * `ui/tools/system-usage-store.test.mjs` executes it under `node --test`.
 *
 * **The fault-keeps-last-value rule needs no code here.** `ScreenStore.applyTick` is the only
 * thing that ever writes `data()`, and a fault never calls it (`refresh.ts`'s `tick`/`readNow`),
 * so `store.data()[0]` is already the last successful row through any later fault -- the same
 * mechanism `process-details.page.ts` relies on for its own "keeps the last values" behavior. This
 * module's job is only to turn that row, plus the page's current fault text, into each meter's
 * `MeterView`.
 *
 * **A track meter's `state` is never `null` before its first value.** `meter.ts` reads
 * `state === null` as "this is a value meter, draw no track" -- a structural fact, not a loading
 * state -- so `percentMeterView` and `statusMeterView` fall back to an inert `'normal'` placeholder
 * until a real word or percentage exists. Nothing paints that placeholder as a color: `meter.ts`'s
 * `showColoredFill` and `showWord` both require actual content (a value or a word), which is
 * `null` on every field until the first successful read.
 */

import { meterStateFromPercent, meterStateFromWord, type MeterSeverity } from '../../core/meter-state.ts';
import { STRINGS } from '../../core/strings.ts';
import { fieldOf } from '../../core/table-model.ts';

/** The severity a track meter carries before its first answer -- never shown as a color. */
const PENDING_STATE: MeterSeverity = 'normal';

/** One meter's resolved props, the shape `system-usage.page.ts` binds straight onto `app-meter`. */
export interface MeterView {
  readonly label: string;
  readonly value: number | null;
  readonly unit: string;
  readonly percent: number | null;
  readonly state: MeterSeverity | null;
  readonly word: string | null;
  readonly error: string | null;
}

/** One rendered counter: a label and its formatted text. */
export interface CounterView {
  readonly field: string;
  readonly label: string;
  readonly value: string;
}

/** The three shapes a meter on this screen takes. */
export type MeterKind = 'percent' | 'status' | 'value';

/** One meter's declaration: its label and kind, and the row field(s) it reads. */
export interface MeterConfig {
  readonly kind: MeterKind;
  readonly label: string;
  /** A percent meter's numerator, a status meter's word field, or a value meter's own field. */
  readonly field: string;
  /** A percent meter's denominator. Unused by the other two kinds. */
  readonly denominatorField?: string;
}

/**
 * The screen's seven meters, in the order EXPERIENCE.md and the spec's Boundaries declare them:
 * Shared memory, the four status meters, then the two value meters. No unit is authorized for any
 * of them in the Fixed strings table, so every one declares none (an assumption named in the
 * story's own report, not invented copy).
 */
export const METER_CONFIGS: readonly MeterConfig[] = [
  {
    kind: 'percent',
    label: STRINGS.systemUsageSharedMemory,
    field: 'SharedMemory.SMHUsed',
    denominatorField: 'SharedMemory.SMHAllocated',
  },
  { kind: 'status', label: STRINGS.systemUsageDatabaseSpace, field: 'Dashboard.SystemUsage.DatabaseSpace' },
  { kind: 'status', label: STRINGS.systemUsageJournalSpace, field: 'Dashboard.SystemUsage.JournalSpace' },
  { kind: 'status', label: STRINGS.systemUsageLockTable, field: 'Dashboard.SystemUsage.LockTable' },
  { kind: 'status', label: STRINGS.systemUsageWriteDaemon, field: 'Dashboard.SystemUsage.WriteDaemon' },
  { kind: 'value', label: STRINGS.systemUsageGlobalRefsPerSecond, field: 'Dashboard.Performance.GlobalRefsPerSecond' },
  { kind: 'value', label: STRINGS.systemUsageCacheEfficiency, field: 'Dashboard.Performance.CacheEfficiency' },
];

/** A numeric field off `row`, or `null` when the row carries none, or it did not answer a number. */
export function numberField(row: unknown, field: string): number | null {
  const value = fieldOf(row, field);
  return typeof value === 'number' ? value : null;
}

/** A string field off `row`, or `null`. */
export function stringField(row: unknown, field: string): string | null {
  const value = fieldOf(row, field);
  return typeof value === 'string' ? value : null;
}

/**
 * A percent meter's numerator (`field`) over its `denominatorField`, as a percentage -- `null`,
 * read as still pending, never as zero -- when either figure has not arrived, `denominatorField`
 * is undeclared, or the denominator reads zero, which a percentage of it cannot express.
 */
function percentFromFields(row: unknown, field: string, denominatorField: string | undefined): number | null {
  if (denominatorField === undefined) return null;
  const numerator = numberField(row, field);
  const denominator = numberField(row, denominatorField);
  if (numerator === null || denominator === null || denominator === 0) return null;
  return (numerator / denominator) * 100;
}

/**
 * Shared memory's percentage: `used / allocated * 100`, or `null` -- read as still pending, never
 * as zero -- when either figure has not arrived or the allocation reads zero, which a percentage
 * of it cannot express.
 */
export function sharedMemoryPercent(row: unknown): number | null {
  return percentFromFields(row, 'SharedMemory.SMHUsed', 'SharedMemory.SMHAllocated');
}

/** One meter's resolved view from `config`, the last-good `row` (or `undefined`), and the page's current fault text. */
export function meterViewFor(config: MeterConfig, row: unknown, faultText: string | null): MeterView {
  const base = { label: config.label, unit: '', error: faultText };
  if (config.kind === 'value') {
    return { ...base, value: numberField(row, config.field), percent: null, state: null, word: null };
  }
  if (config.kind === 'percent') {
    const percent = percentFromFields(row, config.field, config.denominatorField);
    const known = percent === null ? null : meterStateFromPercent(percent);
    return {
      ...base,
      value: numberField(row, config.field),
      percent,
      state: known?.state ?? PENDING_STATE,
      word: known?.word ?? null,
    };
  }
  // 'status'
  const word = stringField(row, config.field);
  const known = word === null ? null : meterStateFromWord(word);
  return { ...base, value: null, percent: null, state: known?.state ?? PENDING_STATE, word: known?.word ?? null };
}

/** Whether a declared column belongs to the counters group -- every `Usage.*` field, in order. */
export function isCounterField(field: string): boolean {
  return field.startsWith('Usage.');
}
