/**
 * The Dashboard's two statistics drill-downs' own state (Story 18.36): which group a declared field belongs to,
 * the heading each group is drawn under, and how the one read row becomes the groups the page lists.
 *
 * Framework-free, like `system-usage.store.ts`, so it runs under `node --test`. The fault-keeps-last-value rule
 * needs no code here, for the reason `system-usage.store.ts` gives: a fault never writes the store, so the row
 * passed in is the last successful one.
 *
 * **A field's group is its second path segment** -- `Statistics.Globals.RefLocal` is in `Globals`,
 * `Ecp.DataServer.ByteSent` in `DataServer` -- and the groups come in the order their first field is declared.
 */

import type { TableColumn } from '../../core/screens.generated.ts';
import { stringFor } from '../../core/strings.ts';
import { cellView, fieldOf } from '../../core/table-model.ts';

/** The string key of each group's heading, by the group's name in the field path. */
export const STATISTICS_GROUPS: Readonly<Record<string, string>> = {
  Globals: 'processColumnGlobals',
  Routines: 'explorerRoutineListLabel',
  AppServer: 'statsGroupAppServer',
  DataServer: 'remoteDatabaseServer',
};

/** One rendered field: its read field, label and formatted value. */
export interface StatisticsFieldView {
  readonly field: string;
  readonly label: string;
  readonly value: string;
}

/** One rendered group: its name, heading and fields in declared order. */
export interface StatisticsGroupView {
  readonly key: string;
  readonly heading: string;
  readonly headingId: string;
  readonly fields: readonly StatisticsFieldView[];
}

/** The group a declared field belongs to: its second path segment, or `''` for a field of fewer than three. */
export function statisticsGroupOf(field: string): string {
  const segments = field.split('.');
  return segments.length < 3 ? '' : segments[1];
}

/** The groups `columns` declare over the read row `row` (or `undefined`), in declared order. */
export function statisticsGroups(columns: readonly TableColumn[], row: unknown): readonly StatisticsGroupView[] {
  const groups: { key: string; fields: StatisticsFieldView[] }[] = [];
  for (const column of columns) {
    const key = statisticsGroupOf(column.field);
    if (key === '') continue;
    let group = groups.find((candidate) => candidate.key === key);
    if (group === undefined) {
      group = { key, fields: [] };
      groups.push(group);
    }
    group.fields.push({
      field: column.field,
      label: stringFor(column.labelKey),
      value: cellView(fieldOf(row, column.field), column.kind, column.emptyKey ?? '').text,
    });
  }
  return groups.map((group) => ({
    key: group.key,
    heading: stringFor(STATISTICS_GROUPS[group.key] ?? '') || group.key,
    headingId: `ocu-statistics-heading-${group.key}`,
    fields: group.fields,
  }));
}
