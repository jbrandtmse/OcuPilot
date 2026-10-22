import { ChangeDetectionStrategy, Component, input } from '@angular/core';

import type { SqlRows } from '../core/sql-answer';

/** One row of the grid as drawn. */
interface RowView {
  readonly key: number;
  readonly cells: readonly string[];
}

/** One even track per column of `shown`, each at least wide enough to read. */
function trackTemplate(shown: SqlRows | null): string {
  const count = Math.max(1, shown?.columns.length ?? 1);
  return `repeat(${count}, minmax(10rem, 1fr))`;
}

/**
 * A listing of text cells on the shared `.ocu-data-table-*` classes: the SQL console's rows (Story
 * 19.6) and the MDX query's drill-through listing (Story 20.33), one template for both.
 *
 * `answer` is the listing, `label` its accessible name, and `slot` a prefix for the `data-ocu-sql`
 * values its table (`<slot>results`) and its cells (`<slot>cell`) carry, so a page that draws two
 * listings tells them apart. A cell is interpolated text, never markup (AD-11), cut to its track.
 *
 * The host element draws nothing of its own (`display: contents`), so a page's layout is what its
 * own `<div class="ocu-data-table-frame">` would have been.
 *
 * Every control-flow condition is a paren-free member reference, for the reason `sign-in.ts` records.
 */
@Component({
  selector: 'app-result-grid',
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `<div class="ocu-data-table-frame">
    <div
      class="ocu-data-table-grid ocu-sql-query-results"
      role="table"
      [attr.data-ocu-sql]="slot() + 'results'"
      [attr.aria-label]="label()"
      [attr.aria-rowcount]="rowCount"
    >
      <div class="ocu-data-table-head" role="rowgroup">
        <div class="ocu-data-table-row ocu-data-table-header-row" role="row" aria-rowindex="1" [style.grid-template-columns]="template">
          @for (column of columns; track $index) {
            <div class="ocu-data-table-header-cell" role="columnheader">
              <span class="ocu-data-table-header-label">{{ column }}</span>
            </div>
          }
        </div>
      </div>
      <div class="ocu-data-table-viewport">
        <div class="ocu-data-table-body" role="rowgroup">
          @for (row of rows; track row.key) {
            <div class="ocu-data-table-row" role="row" [attr.aria-rowindex]="row.key + 2" [style.grid-template-columns]="template">
              @for (cell of row.cells; track $index) {
                <div class="ocu-data-table-cell" role="cell">
                  <span class="ocu-data-table-text ocu-sql-query-cell" [attr.data-ocu-sql]="slot() + 'cell'">{{ cell }}</span>
                </div>
              }
            </div>
          }
        </div>
      </div>
    </div>
  </div>`,
})
export class ResultGrid {
  /** The listing: its column headers and its rows of text cells. */
  readonly answer = input.required<SqlRows>();

  /** The table's accessible name. */
  readonly label = input.required<string>();

  /** Prefix of the `data-ocu-sql` values: `''` for the console's own, `'background-'` for its Background run's. */
  readonly slot = input('');

  protected get columns(): readonly string[] {
    return this.answer().columns;
  }

  protected get rows(): readonly RowView[] {
    return this.answer().rows.map((cells, key) => ({ key, cells }));
  }

  protected get rowCount(): number {
    return this.answer().rows.length + 1;
  }

  /** One even track per column, each at least wide enough to read. */
  protected get template(): string {
    return trackTemplate(this.answer());
  }
}
