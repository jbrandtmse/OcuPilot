import { ChangeDetectionStrategy, Component, ElementRef, computed, effect, input, output, signal, viewChild } from '@angular/core';

import {
  cellView,
  columnTrack,
  isCellMoveKey,
  isFilterable,
  moveCell,
  pageKey,
  type CellPosition,
  type SortState,
} from '../../core/data-browser-model';
import { STRINGS } from '../../core/strings';
import { fillPlaceholders } from './code-list.store';
import type { BrowseColumn } from './data-browser.store';

/** One header cell as drawn. */
interface HeaderView {
  readonly id: string;
  readonly name: string;
  readonly index: number;
  readonly numeric: boolean;
  readonly sortable: boolean;
  readonly key: boolean;
  readonly sort: 'ascending' | 'descending' | null;
  readonly arrow: string;
  readonly active: boolean;
}

/** One filter input as drawn, or a spacer for a column that takes none. */
interface FilterView {
  readonly column: string;
  readonly filterable: boolean;
  readonly label: string;
  readonly value: string;
}

/** One body cell as drawn. */
interface CellRender {
  readonly id: string;
  readonly text: string;
  readonly isNull: boolean;
  readonly numeric: boolean;
  readonly active: boolean;
}

/** One body row as drawn. */
interface RowView {
  readonly index: number;
  readonly ariaRowIndex: number;
  readonly cells: readonly CellRender[];
}

/** The page change Ctrl/Cmd+PageDown and PageUp ask for. */
export type PageRequest = 'next' | 'previous';

/** The rows PageUp and PageDown move by when the viewport cannot be measured. */
const FALLBACK_VISIBLE_ROWS = 10;

/**
 * Data browser's grid (Story 19.7): the filter row and one page of rows, drawn with the shared
 * data-table's classes and OcuPilot's tokens.
 *
 * **The filter row** is a group named "Column filters" with one input per column that is neither a
 * stream nor binary, each labeled "Filter <column>": Enter applies it and Escape clears it and
 * applies, the page returning to the first page.
 *
 * **The grid** is `role="grid"` with one Tab stop: focus stays on the grid and
 * `aria-activedescendant` names the active cell, the header row included. Arrows move without
 * wrapping, Home and End go to the row's first and last cell, Ctrl/Cmd+Home and End to the grid's
 * first and last, PageUp and PageDown by the rows in view, and Ctrl/Cmd+PageDown and PageUp ask for
 * the next and previous page. Enter, Space or a click on a sortable header cycles its sort, and the
 * sorted header carries `aria-sort`; a key column's header carries a marker named "Key column".
 * `aria-rowcount` is the total plus the header row, or -1 while the total is unknown, and each row's
 * `aria-rowindex` counts from the page's offset. Every cell is one line cut with an ellipsis, a NULL
 * muted and a number right-aligned in tabular figures.
 *
 * Ported from iris-table-editor v0.2.3 (MIT, `ui/licenses/iris-table-editor.txt`),
 * `packages/webview/src/grid.js`: `renderFilterRow` (:3685-3808), `applyFilter` (:3815-3843),
 * `clearAllFilters` (:3887-3905), the header's Enter and Space (:3664-3670), `selectCell`
 * (:3266-3302) and `handleCellKeydown`'s read-only keys (:3424-3515), re-expressed on
 * `aria-activedescendant` with one Tab stop. Its call sites are kept; its names are not.
 */
@Component({
  selector: 'app-data-browser-grid',
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `<div class="ocu-data-table-frame ocu-data-browser-frame">
    <div class="ocu-data-browser-scroll" #scroll>
      <div
        class="ocu-data-browser-filters"
        role="group"
        data-ocu-data="filters"
        [attr.aria-label]="STRINGS.explorerSqlDataFilters"
        [style.grid-template-columns]="template()"
      >
        @for (filter of filterList; track filter.column) {
          @if (filter.filterable) {
            <input
              class="ocu-criteria-input ocu-data-browser-filter"
              type="text"
              autocomplete="off"
              spellcheck="false"
              maxlength="1000"
              data-ocu-data="filter"
              [attr.aria-label]="filter.label"
              [attr.data-column]="filter.column"
              [value]="filter.value"
              (input)="onFilterInput(filter.column, $event)"
              (keydown)="onFilterKeydown(filter.column, $event)"
            />
          } @else {
            <span class="ocu-data-browser-filter-spacer" aria-hidden="true"></span>
          }
        }
      </div>
      <div
        class="ocu-data-table-grid ocu-data-browser-grid"
        role="grid"
        tabindex="0"
        data-ocu-data="grid"
        [attr.aria-label]="label()"
        [attr.aria-rowcount]="ariaRowCount()"
        [attr.aria-colcount]="columns().length"
        [attr.aria-activedescendant]="activeDescendant()"
        (keydown)="onGridKeydown($event)"
      >
        <div class="ocu-data-table-head ocu-data-browser-head-group" role="rowgroup">
          <div class="ocu-data-table-row ocu-data-table-header-row" role="row" aria-rowindex="1" [style.grid-template-columns]="template()">
            @for (header of headerList; track header.id) {
              <div
                class="ocu-data-table-header-cell ocu-data-browser-header-cell"
                role="columnheader"
                data-ocu-data="header"
                [id]="header.id"
                [attr.data-column]="header.name"
                [attr.aria-sort]="header.sort"
                [class.ocu-data-table-cell-numeric]="header.numeric"
                [class.ocu-data-browser-cell-active]="header.active"
                [class.ocu-data-browser-header-sortable]="header.sortable"
                (click)="onHeaderClick(header.index)"
              >
                @if (header.key) {
                  <span class="ocu-data-browser-key-mark" aria-hidden="true"></span>
                  <span class="ocu-data-table-hidden-label">{{ STRINGS.explorerSqlDataKeyColumn }}</span>
                }
                <span class="ocu-data-table-header-label">{{ header.name }}</span>
                <span class="ocu-data-table-sort-arrow" aria-hidden="true">{{ header.arrow }}</span>
              </div>
            }
          </div>
        </div>
        <div class="ocu-data-table-body" role="rowgroup">
          @for (row of rowList; track row.index) {
            <div class="ocu-data-table-row" role="row" data-ocu-data="row" [attr.aria-rowindex]="row.ariaRowIndex" [style.grid-template-columns]="template()">
              @for (cell of row.cells; track $index) {
                <div
                  class="ocu-data-table-cell"
                  role="gridcell"
                  data-ocu-data="cell"
                  [id]="cell.id"
                  [class.ocu-data-table-cell-numeric]="cell.numeric"
                  [class.ocu-data-browser-cell-active]="cell.active"
                  (click)="onCellClick(row.index, $index)"
                >
                  <span class="ocu-data-table-text ocu-data-browser-cell" [class.ocu-data-browser-null]="cell.isNull">{{ cell.text }}</span>
                </div>
              }
            </div>
          }
        </div>
      </div>
    </div>
  </div>`,
})
export class DataBrowserGrid {
  protected readonly STRINGS = STRINGS;

  /** The open table's or view's name, the grid's accessible name. */
  readonly label = input('');

  readonly columns = input<readonly BrowseColumn[]>([]);

  /** The page's rows, a cell `null` for SQL NULL. */
  readonly rows = input<readonly (readonly (string | null)[])[]>([]);

  readonly offset = input(0);

  /** The total, or `null` while the instance gave none. */
  readonly total = input<number | null>(null);

  readonly sort = input<SortState | null>(null);

  /** What each column's filter input holds. */
  readonly drafts = input<Readonly<Record<string, string>>>({});

  /** A sortable header was activated. */
  readonly sorted = output<string>();

  /** A filter input changed. */
  readonly drafted = output<{ readonly column: string; readonly value: string }>();

  /** Enter in a filter input: apply it. */
  readonly applied = output<string>();

  /** Escape in a filter input: clear it and apply. */
  readonly cleared = output<string>();

  /** Ctrl/Cmd+PageDown or PageUp. */
  readonly paged = output<PageRequest>();

  private readonly scroll = viewChild<ElementRef<HTMLElement>>('scroll');

  /** The active cell; row -1 is the header row. */
  protected readonly active = signal<CellPosition>({ row: -1, column: 0 });

  constructor() {
    // A new page keeps the active cell inside what it shows.
    effect(() => {
      const rows = this.rows().length;
      const columns = this.columns().length;
      const current = this.active();
      const row = Math.min(current.row, rows - 1);
      const column = Math.min(current.column, Math.max(0, columns - 1));
      if (row !== current.row || column !== current.column) this.active.set({ row, column });
    });
  }

  protected readonly template = computed(() => {
    const columns = this.columns();
    return columns.length === 0 ? 'minmax(0, 1fr)' : columns.map((column) => columnTrack(column.kind)).join(' ');
  });

  protected readonly ariaRowCount = computed(() => {
    const total = this.total();
    return total === null ? -1 : total + 1;
  });

  protected readonly headers = computed<readonly HeaderView[]>(() => {
    const sort = this.sort();
    const active = this.active();
    return this.columns().map((column, index) => {
      const sorted = sort !== null && sort.column === column.name ? sort.direction : null;
      return {
        id: `ocu-data-head-c${index}`,
        name: column.name,
        index,
        numeric: column.kind === 'number',
        sortable: isFilterable(column.kind),
        key: column.key,
        sort: sorted === 'asc' ? 'ascending' : sorted === 'desc' ? 'descending' : null,
        arrow: sorted === 'asc' ? '\u2191' : sorted === 'desc' ? '\u2193' : '',
        active: active.row === -1 && active.column === index,
      };
    });
  });

  protected readonly filterViews = computed<readonly FilterView[]>(() => {
    const drafts = this.drafts();
    return this.columns().map((column) => ({
      column: column.name,
      filterable: isFilterable(column.kind),
      label: fillPlaceholders(STRINGS.explorerSqlDataFilterColumn, { column: column.name }),
      value: Object.hasOwn(drafts, column.name) ? drafts[column.name] : '',
    }));
  });

  protected readonly rowViews = computed<readonly RowView[]>(() => {
    const columns = this.columns();
    const offset = this.offset();
    const active = this.active();
    return this.rows().map((row, index) => ({
      index,
      ariaRowIndex: offset + index + 2,
      cells: columns.map((column, at) => {
        const view = cellView(column.kind, row[at] ?? null);
        return {
          id: `ocu-data-cell-r${index}-c${at}`,
          text: view.text,
          isNull: view.isNull,
          numeric: view.numeric,
          active: active.row === index && active.column === at,
        };
      }),
    }));
  });

  /** The three lists the template walks, as paren-free members (see `sign-in.ts`). */
  protected get filterList(): readonly FilterView[] {
    return this.filterViews();
  }

  protected get headerList(): readonly HeaderView[] {
    return this.headers();
  }

  protected get rowList(): readonly RowView[] {
    return this.rowViews();
  }

  protected readonly activeDescendant = computed(() => {
    const { row, column } = this.active();
    if (this.columns().length === 0) return null;
    if (row === -1) return `ocu-data-head-c${column}`;
    return row < this.rows().length ? `ocu-data-cell-r${row}-c${column}` : null;
  });

  protected onFilterInput(column: string, event: Event): void {
    this.drafted.emit({ column, value: (event.target as HTMLInputElement).value });
  }

  protected onFilterKeydown(column: string, event: KeyboardEvent): void {
    if (event.key === 'Enter') {
      event.preventDefault();
      this.applied.emit(column);
    } else if (event.key === 'Escape') {
      event.preventDefault();
      this.cleared.emit(column);
    }
  }

  protected onHeaderClick(index: number): void {
    this.active.set({ row: -1, column: index });
    this.sortColumn(index);
  }

  protected onCellClick(row: number, column: number): void {
    this.active.set({ row, column });
  }

  protected onGridKeydown(event: KeyboardEvent): void {
    const control = event.ctrlKey || event.metaKey;
    const page = pageKey(event.key, control);
    if (page !== null) {
      event.preventDefault();
      this.paged.emit(page);
      return;
    }
    const current = this.active();
    if ((event.key === 'Enter' || event.key === ' ') && current.row === -1) {
      event.preventDefault();
      this.sortColumn(current.column);
      return;
    }
    if (!isCellMoveKey(event.key, control)) return;
    const next = moveCell(current, event.key, control, this.rows().length, this.columns().length, this.visibleRows());
    if (next === null) return;
    event.preventDefault();
    this.active.set(next);
    const id = next.row === -1 ? `ocu-data-head-c${next.column}` : `ocu-data-cell-r${next.row}-c${next.column}`;
    document.getElementById(id)?.scrollIntoView?.({ block: 'nearest', inline: 'nearest' });
  }

  /** Cycle the sort of column `index`, when it is sortable. */
  private sortColumn(index: number): void {
    const column = this.columns()[index];
    if (column === undefined || !isFilterable(column.kind)) return;
    this.sorted.emit(column.name);
  }

  /** The rows the scrolling frame shows at once, measured, or a fallback where nothing is laid out. */
  private visibleRows(): number {
    const frame = this.scroll()?.nativeElement;
    const row = frame?.querySelector<HTMLElement>('.ocu-data-table-body .ocu-data-table-row');
    const height = frame?.clientHeight ?? 0;
    const rowHeight = row?.offsetHeight ?? 0;
    if (height <= 0 || rowHeight <= 0) return FALLBACK_VISIBLE_ROWS;
    return Math.max(1, Math.floor(height / rowHeight) - 2);
  }
}
