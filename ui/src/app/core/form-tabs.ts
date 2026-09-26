/**
 * Which tab of a tabbed `form-page` a refusal belongs on (Story 9.1, Epic 9's editor contract).
 *
 * **One form spans every tab, so a Save's refusals can land on any of them.** The tab that holds the
 * first refused field, in the form's own field order, is the one the page opens; each tab with
 * refusals carries a `destructive` dot and appends its count to its accessible name ("General, 1
 * error"). This file answers those three questions from a field-to-tab map and the refusals, and
 * decides nothing about rendering.
 *
 * Framework-free, like the rest of `core/` (AD-19), so `ui/tools/form-tabs.test.mjs` drives it
 * under `node --test`.
 */

import type { Violation } from './violations.ts';
import { STRINGS } from './strings.ts';

/** The placeholder the tab error names leave for the tab's own label. */
export const TAB_PLACEHOLDER = '<tab>';

/** The placeholder the plural tab error name leaves for the count. */
export const COUNT_PLACEHOLDER = '<n>';

/** Which tab each field is drawn on, by field name. */
export type FieldTabs = Readonly<Record<string, string>>;

/**
 * How many refusals each tab holds, by tab key. A refusal on a field `fieldTabs` does not place is
 * counted nowhere: it has no tab to open, and the error summary still lists it.
 */
export function tabErrorCounts(fieldTabs: FieldTabs, violations: readonly Violation[]): Readonly<Record<string, number>> {
  const counts: Record<string, number> = {};
  for (const violation of violations) {
    const tab = Object.hasOwn(fieldTabs, violation.field) ? fieldTabs[violation.field] : undefined;
    if (tab === undefined) continue;
    counts[tab] = (counts[tab] ?? 0) + 1;
  }
  return counts;
}

/**
 * The tab to open after a refused Save: the one holding the refused field that comes first in
 * `fieldOrder`, the form's own order. A refused field `fieldOrder` does not list comes after every
 * one it does, in the order the refusals arrived. `null` when no refusal is on a placed field.
 */
export function tabToOpen(fieldTabs: FieldTabs, fieldOrder: readonly string[], violations: readonly Violation[]): string | null {
  const placed = violations.filter((violation) => Object.hasOwn(fieldTabs, violation.field));
  if (placed.length === 0) return null;
  const rank = (field: string): number => {
    const index = fieldOrder.indexOf(field);
    return index === -1 ? fieldOrder.length : index;
  };
  const first = placed.reduce((best, violation) => (rank(violation.field) < rank(best.field) ? violation : best));
  return fieldTabs[first.field];
}

/**
 * A tab's accessible name: its own label while it holds no refusal, and "<label>, 1 error" or
 * "<label>, <n> errors" while it does.
 */
export function tabAccessibleName(label: string, count: number): string {
  if (count <= 0) return label;
  if (count === 1) return STRINGS.formTabErrorOne.split(TAB_PLACEHOLDER).join(label);
  return STRINGS.formTabErrorMany.split(TAB_PLACEHOLDER).join(label).split(COUNT_PLACEHOLDER).join(String(count));
}
