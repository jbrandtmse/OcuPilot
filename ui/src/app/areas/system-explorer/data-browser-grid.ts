import {
  ChangeDetectionStrategy,
  Component,
  DestroyRef,
  ElementRef,
  Injector,
  afterNextRender,
  computed,
  effect,
  inject,
  input,
  output,
  signal,
  viewChild,
} from '@angular/core';

import {
  cellView,
  columnFloor,
  columnTrack,
  editable,
  insertable,
  isCellMoveKey,
  isFilterable,
  moveCell,
  nextBoolean,
  pageKey,
  parseCellInput,
  type CellPosition,
  type SortState,
} from '../../core/data-browser-model';
import { OverlayStack } from '../../core/overlay-stack';
import { afterTooltipDelay, nextFrame } from '../../core/tooltip-timing';
import { STRINGS } from '../../core/strings';
import { fillPlaceholders } from './code-list.store';
import type { ActiveCell, BrowseColumn, StagedRow } from './data-browser.store';

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
  readonly staged: boolean;
  readonly editing: boolean;
}

/** One body row as drawn. */
interface RowView {
  readonly id: string;
  readonly index: number;
  readonly ariaRowIndex: number;
  readonly deleted: boolean;
  readonly isNew: boolean;
  readonly statusId: string;
  readonly status: string;
  readonly statusActive: boolean;
  readonly cells: readonly CellRender[];
}

/**
 * The open editor: the row (its id, its identity and its place) and the grid column it edits, the text
 * it opened with, what it holds, its refusal, and whether it opened on a NULL it shows empty.
 */
interface EditorState {
  readonly rowId: string;
  readonly rowKey: string;
  readonly nullRead: boolean;
  readonly row: number;
  readonly column: number;
  readonly initial: string;
  readonly text: string;
  readonly problem: string;
}

/** The one cut-cell tooltip the grid draws (DW-2028, the shared data table's). */
interface CellTooltip {
  readonly cellId: string;
  readonly text: string;
  readonly source: 'pointer' | 'focus';
  readonly top: number;
  readonly left: number;
  readonly placed: boolean;
}

/** The page change Ctrl/Cmd+PageDown and PageUp ask for. */
export type PageRequest = 'next' | 'previous';

/** A staged edit: the grid row, the data column, and the value (`null` for NULL). */
export interface CellEdit {
  readonly row: string;
  readonly column: number;
  readonly value: string | null;
}

/** The rows PageUp and PageDown move by when the viewport cannot be measured. */
const FALLBACK_VISIBLE_ROWS = 10;

/** The Change column's floor in CSS pixels. */
const STATUS_FLOOR = 128;

/** The editor's hint element. */
const EDITOR_HINT_ID = 'ocu-data-edit-hint';

let gridCount = 0;

/**
 * Data browser's grid (Stories 19.7 and 19.8): the filter row and one page of rows, drawn with the
 * shared data-table's classes and OcuPilot's tokens, editable where the table may change.
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
 * `aria-rowcount` is the total and the new rows plus the header row, or -1 while the total is
 * unknown. Every cell is one line cut with an ellipsis, a NULL muted and a number right-aligned in
 * tabular figures.
 *
 * **Editing** (`editable`): a leading Change column reads each row's state as text, also while
 * `saving`, when no editor opens. On a cell that may change -- not a key, identity, generated, stream,
 * binary or cut cell of a row read, a text cell holding a line break, which a one-line editor would
 * drop, nor any cell of a deleted row; a key cell of a new row may -- F2 or Enter opens the editor at the end of the
 * value, a printable key opens it with that character and Backspace opens it empty; Delete stages
 * NULL on a column that takes it; on a BIT cell Enter, Space and F2 toggle the value instead. The
 * editor takes focus: Escape cancels, Ctrl/Cmd+Z restores the value it opened with, Enter and
 * Shift+Enter commit and move down and up, Tab and Shift+Tab commit and move right and left without
 * wrapping, and blur commits; a value the column refuses keeps it open, `aria-invalid`, its hint
 * linked by `aria-describedby`, and a key or press on the grid meanwhile returns focus to it. Focus
 * then returns to the grid on its cell. An editor opened by F2 or Enter on a NULL commits NULL while it
 * is left empty, and an editor whose row a re-read moved or replaced closes unstaged.
 *
 * **A cut cell shows its whole value in a tooltip** (DW-2028) when the pointer rests on it or it
 * becomes the active cell while the grid has focus; Escape, a scroll, a press in the grid, a resize
 * or an open editor hides it. Ported from `shell/data-table.ts`'s tooltip, its call sites kept.
 *
 * **For the page's tabs and shortcuts** (Story 19.16): `activeCell` reports each move of the active
 * cell, `place` restores a tab's cell without moving focus, and `editorOpen` and `commitInPlace` let
 * Ctrl/Cmd+S commit an open editor before it opens Save.
 *
 * Ported from iris-table-editor v0.2.3 (MIT, `ui/licenses/iris-table-editor.txt`),
 * `packages/webview/src/grid.js`: `renderFilterRow` (:3685-3808), `applyFilter` (:3815-3843),
 * `clearAllFilters` (:3887-3905), the header's Enter and Space (:3664-3670), `selectCell`
 * (:3266-3302) and `handleCellKeydown` (:3364-3552), re-expressed on `aria-activedescendant` with one
 * Tab stop; `handleEditInputKeydown` (:3059-3149) and `enterEditMode`/`exitEditMode` (:1474-1833) as
 * the editor; and the boolean toggle (:378-438). Its call sites are kept; its names are not.
 */
@Component({
  selector: 'app-data-browser-grid',
  changeDetection: ChangeDetectionStrategy.OnPush,
  host: { '(window:resize)': 'hideTooltip()' },
  template: `<div class="ocu-data-table-frame ocu-data-browser-frame">
    <div class="ocu-data-browser-scroll" #scroll (scroll)="hideTooltip()">
      <div
        class="ocu-data-browser-filters"
        role="group"
        data-ocu-data="filters"
        [attr.aria-label]="STRINGS.explorerSqlDataFilters"
        [style.grid-template-columns]="template()"
        [style.min-width.px]="minWidth()"
      >
        @if (statusColumn) {
          <span class="ocu-data-browser-filter-spacer" aria-hidden="true"></span>
        }
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
        #grid
        class="ocu-data-table-grid ocu-data-browser-grid"
        role="grid"
        tabindex="0"
        data-ocu-data="grid"
        [attr.aria-label]="label()"
        [attr.aria-rowcount]="ariaRowCount()"
        [attr.aria-colcount]="columnCount()"
        [attr.aria-activedescendant]="activeDescendant()"
        [style.min-width.px]="minWidth()"
        (keydown)="onGridKeydown($event)"
        (focus)="onGridFocus()"
        (pointerover)="onCellPointerOver($event)"
        (pointerout)="onCellPointerOut($event)"
        (pointerdown)="hideTooltip()"
      >
        <div class="ocu-data-table-head ocu-data-browser-head-group" role="rowgroup">
          <div class="ocu-data-table-row ocu-data-table-header-row" role="row" aria-rowindex="1" [style.grid-template-columns]="template()">
            @if (statusColumn) {
              <div
                class="ocu-data-table-header-cell ocu-data-browser-header-cell ocu-data-browser-status-head"
                role="columnheader"
                data-ocu-data="status-head"
                [id]="statusHeadId"
                [class.ocu-data-browser-cell-active]="statusHeadActive()"
                (click)="onStatusHeadClick()"
              >
                <span class="ocu-data-table-header-label">{{ STRINGS.databaseDirectoryChange }}</span>
              </div>
            }
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
          @for (row of rowList; track row.id) {
            <div
              class="ocu-data-table-row"
              role="row"
              data-ocu-data="row"
              [attr.data-row]="row.id"
              [attr.aria-rowindex]="row.ariaRowIndex"
              [class.ocu-data-browser-row-new]="row.isNew"
              [class.ocu-data-browser-row-deleted]="row.deleted"
              [style.grid-template-columns]="template()"
            >
              @if (statusColumn) {
                <div
                  class="ocu-data-table-cell ocu-data-browser-status"
                  role="gridcell"
                  data-ocu-data="status-cell"
                  [id]="row.statusId"
                  [class.ocu-data-browser-cell-active]="row.statusActive"
                  (click)="onCellClick(row.index, 0)"
                >
                  <span class="ocu-data-table-text ocu-data-browser-cell">{{ row.status }}</span>
                </div>
              }
              @for (cell of row.cells; track $index) {
                <div
                  class="ocu-data-table-cell"
                  role="gridcell"
                  data-ocu-data="cell"
                  [id]="cell.id"
                  [class.ocu-data-table-cell-numeric]="cell.numeric"
                  [class.ocu-data-browser-cell-active]="cell.active"
                  [class.ocu-data-browser-staged]="cell.staged"
                  [class.ocu-data-browser-editing]="cell.editing"
                  (click)="onCellClick(row.index, $index + firstData())"
                >
                  @if (cell.editing) {
                    <input
                      #editor
                      class="ocu-criteria-input ocu-data-browser-editor"
                      type="text"
                      autocomplete="off"
                      spellcheck="false"
                      data-ocu-data="editor"
                      [attr.aria-labelledby]="editorLabel()"
                      [attr.aria-invalid]="editorInvalid() ? true : null"
                      [attr.aria-describedby]="editorInvalid() ? editorHintId : null"
                      [value]="editorText()"
                      (input)="onEditorInput($event)"
                      (keydown)="onEditorKeydown($event)"
                      (blur)="onEditorBlur()"
                    />
                    @if (invalidNow) {
                      <span class="ocu-data-browser-edit-hint" data-ocu-data="editor-hint" [id]="editorHintId">{{ editorProblem() }}</span>
                    }
                  } @else {
                    <span class="ocu-data-table-text ocu-data-browser-cell" [class.ocu-data-browser-null]="cell.isNull">{{ cell.text }}</span>
                  }
                </div>
              }
            </div>
          }
        </div>
      </div>
    </div>
    @if (tooltipShown) {
      <div
        #tooltip
        class="ocu-data-table-tooltip"
        aria-hidden="true"
        data-ocu-data="tooltip"
        [class.ocu-data-table-tooltip-placed]="tooltipPlaced"
        [style.top.px]="tooltipTop"
        [style.left.px]="tooltipLeft"
        (pointerleave)="onTooltipLeave($event)"
      >{{ tooltipText }}</div>
    }
  </div>`,
})
export class DataBrowserGrid {
  protected readonly STRINGS = STRINGS;

  private readonly injector = inject(Injector);

  private readonly overlays = inject(OverlayStack);

  private readonly instance = ++gridCount;

  /** The open table's or view's name, the grid's accessible name. */
  readonly label = input('');

  readonly columns = input<readonly BrowseColumn[]>([]);

  /** The rows drawn: the new rows, then the page's, each with what is staged on it. */
  readonly rows = input<readonly StagedRow[]>([]);

  readonly offset = input(0);

  /** The total, or `null` while the instance gave none. */
  readonly total = input<number | null>(null);

  readonly sort = input<SortState | null>(null);

  /** What each column's filter input holds. */
  readonly drafts = input<Readonly<Record<string, string>>>({});

  /** Whether the table's rows may change here, which draws the Change column and the editors. */
  readonly editable = input(false);

  /** Whether a save is on its way: the Change column stays and no editor opens. */
  readonly saving = input(false);

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

  /** A cell's value to stage. */
  readonly edited = output<CellEdit>();

  /** A line for the page's status line: an editor opened or undone, or an edit refused. */
  readonly announced = output<string>();

  /** The row the active cell is on, or `null` on the header row. */
  readonly activeRow = output<string | null>();

  /** The active cell, as its row's id (`null` on the header row) and its data column (-1 the Change column), each time it moves. */
  readonly activeCell = output<ActiveCell>();

  private readonly scroll = viewChild<ElementRef<HTMLElement>>('scroll');

  private readonly gridElement = viewChild<ElementRef<HTMLElement>>('grid');

  private readonly editorElement = viewChild<ElementRef<HTMLInputElement>>('editor');

  private readonly tooltipElement = viewChild<ElementRef<HTMLElement>>('tooltip');

  /** The active cell; row -1 is the header row, and with `editable` column 0 is the Change column. */
  protected readonly active = signal<CellPosition>({ row: -1, column: 0 });

  /** The open editor, or `null`. */
  private readonly editor = signal<EditorState | null>(null);

  private readonly tooltip = signal<CellTooltip | null>(null);

  protected readonly statusHeadId = `ocu-data-head-status-${this.instance}`;

  protected readonly editorHintId = `${EDITOR_HINT_ID}-${this.instance}`;

  private readonly tooltipOverlayId = `ocu-data-browser-${this.instance}-tooltip`;

  /** The active row last emitted. */
  private emittedRow: string | null = null;

  /** The active cell last emitted, or `null` before the first read of it, which is not emitted. */
  private emittedCell: string | null = null;

  private hoverCellId = '';

  /** Cancels the tooltip waiting on the pointer's rest, or `null`. */
  private hoverWait: (() => void) | null = null;

  constructor() {
    // A new page keeps the active cell inside what it shows, and an editor whose row left closes.
    effect(() => {
      const rows = this.rows().length;
      const columns = this.columnCount();
      const current = this.active();
      const row = Math.min(current.row, rows - 1);
      const column = Math.min(current.column, Math.max(0, columns - 1));
      if (row !== current.row || column !== current.column) this.active.set({ row, column });
    });
    effect(() => {
      const open = this.editor();
      if (open === null) return;
      if (!this.editorRowHolds(open) || !this.editable() || this.saving()) this.editor.set(null);
    });
    // Emitted only when it changes: a listener marks the page dirty, which hands the grid new rows.
    effect(() => {
      const { row } = this.active();
      const entry = row >= 0 ? this.rows()[row] : undefined;
      const id = entry === undefined ? null : entry.id;
      if (id === this.emittedRow) return;
      this.emittedRow = id;
      this.activeRow.emit(id);
    });
    // Emitted when the active cell moves, never for where a new grid starts, so a tab switch cannot
    // hand the tab the cell it is about to restore over.
    effect(() => {
      const { row, column } = this.active();
      const entry = row >= 0 ? this.rows()[row] : undefined;
      const cell: ActiveCell = { row: entry === undefined ? null : entry.id, column: column - this.firstData() };
      const key = JSON.stringify(cell);
      if (key === this.emittedCell) return;
      const first = this.emittedCell === null;
      this.emittedCell = key;
      if (!first) this.activeCell.emit(cell);
    });
    // A chord belongs to the shell; a scroll of any element holding the grid moves the cell out
    // from under the fixed tooltip.
    const onChord = (event: KeyboardEvent): void => {
      if (event.ctrlKey || event.metaKey) this.hideTooltip();
    };
    const onAncestorScroll = (event: Event): void => {
      const grid = this.gridElement()?.nativeElement;
      const target = event.target;
      if (target instanceof Document || (grid !== undefined && target instanceof Node && target.contains(grid))) this.hideTooltip();
    };
    if (typeof document !== 'undefined') {
      document.addEventListener('keydown', onChord, true);
      document.addEventListener('scroll', onAncestorScroll, true);
    }
    inject(DestroyRef).onDestroy(() => {
      if (typeof document !== 'undefined') {
        document.removeEventListener('keydown', onChord, true);
        document.removeEventListener('scroll', onAncestorScroll, true);
      }
      this.clearHoverTimer();
      this.overlays.remove(this.tooltipOverlayId);
    });
  }

  /** The grid column the first data column sits in: 1 behind the Change column, else 0. */
  protected readonly firstData = computed(() => (this.editable() ? 1 : 0));

  protected readonly columnCount = computed(() => this.columns().length + this.firstData());

  protected readonly template = computed(() => {
    const columns = this.columns();
    const status = this.editable() ? [`minmax(${STATUS_FLOOR}px, 1fr)`] : [];
    return columns.length === 0 ? 'minmax(0, 1fr)' : [...status, ...columns.map((column) => columnTrack(column.kind))].join(' ');
  });

  /**
   * The grid's least width, its columns' floors summed: it takes the frame's width and no less, so a
   * column shares the rest and never grows to a long value, which it cuts instead.
   */
  protected readonly minWidth = computed(() => this.columns().reduce((sum, column) => sum + columnFloor(column.kind), this.editable() ? STATUS_FLOOR : 0));

  private readonly newCount = computed(() => this.rows().filter((row) => row.isNew).length);

  protected readonly ariaRowCount = computed(() => {
    const total = this.total();
    return total === null ? -1 : total + this.newCount() + 1;
  });

  protected readonly statusHeadActive = computed(() => this.editable() && this.active().row === -1 && this.active().column === 0);

  protected readonly headers = computed<readonly HeaderView[]>(() => {
    const sort = this.sort();
    const active = this.active();
    const first = this.firstData();
    return this.columns().map((column, index) => {
      const sorted = sort !== null && sort.column === column.name ? sort.direction : null;
      return {
        id: this.headId(index + first),
        name: column.name,
        index,
        numeric: column.kind === 'number',
        sortable: isFilterable(column.kind),
        key: column.key,
        sort: sorted === 'asc' ? 'ascending' : sorted === 'desc' ? 'descending' : null,
        arrow: sorted === 'asc' ? '\u2191' : sorted === 'desc' ? '\u2193' : '',
        active: active.row === -1 && active.column === index + first,
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
    const first = this.firstData();
    const open = this.editor();
    return this.rows().map((row, index) => ({
      id: row.id,
      index,
      ariaRowIndex: row.isNew ? index + 2 : offset + index + 2,
      deleted: row.deleted,
      isNew: row.isNew,
      statusId: this.cellId(index, 0),
      status: row.status,
      statusActive: first === 1 && active.row === index && active.column === 0,
      cells: columns.map((column, at) => {
        const view = cellView(column.kind, row.cells[at] ?? null);
        return {
          id: this.cellId(index, at + first),
          text: view.text,
          isNull: view.isNull,
          numeric: view.numeric,
          active: active.row === index && active.column === at + first,
          staged: row.staged[at] === true,
          editing: open !== null && open.row === index && open.column === at + first,
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
    if (row === -1) return this.headId(column);
    return row < this.rows().length ? this.cellId(row, column) : null;
  });

  protected readonly editorText = computed(() => this.editor()?.text ?? '');

  protected readonly editorProblem = computed(() => this.editor()?.problem ?? '');

  protected readonly editorInvalid = computed(() => this.editorProblem() !== '');

  /** The editor is named by its column's header. */
  protected readonly editorLabel = computed(() => {
    const open = this.editor();
    return open === null ? null : this.headId(open.column);
  });

  /** Whether the Change column is drawn, as a paren-free member (see `sign-in.ts`). */
  protected get statusColumn(): boolean {
    return this.editable();
  }

  /** Whether the open editor holds a refused value, as a paren-free member. */
  protected get invalidNow(): boolean {
    return this.editorInvalid();
  }

  protected get tooltipShown(): boolean {
    return this.tooltip() !== null;
  }

  protected get tooltipPlaced(): boolean {
    return this.tooltip()?.placed === true;
  }

  protected get tooltipTop(): number {
    return this.tooltip()?.top ?? 0;
  }

  protected get tooltipLeft(): number {
    return this.tooltip()?.left ?? 0;
  }

  protected get tooltipText(): string {
    return this.tooltip()?.text ?? '';
  }

  /** Make the cell at data column `column` of grid row `id` the active cell, scroll it into view and focus the grid. */
  activate(id: string, column = 0): void {
    const row = this.rows().findIndex((entry) => entry.id === id);
    if (row < 0) return;
    this.active.set({ row, column: Math.max(0, column + this.firstData()) });
    this.revealActive();
    this.focusGrid();
  }

  /**
   * Make the cell at data column `column` of grid row `id`, or of the header row for `null`, the
   * active cell and scroll it into view without moving focus: a tab switch restores the tab's cell
   * this way. `false`, changing nothing, for a row the grid does not draw.
   */
  place(id: string | null, column: number): boolean {
    const row = id === null ? -1 : this.rows().findIndex((entry) => entry.id === id);
    if (id !== null && row < 0) return false;
    this.active.set({ row, column: Math.min(Math.max(0, column + this.firstData()), Math.max(0, this.columnCount() - 1)) });
    this.revealActive();
    return true;
  }

  /** Whether a cell editor is open. */
  editorOpen(): boolean {
    return this.editor() !== null;
  }

  /**
   * Commit the open editor where it is, without moving the active cell, and put focus on the grid;
   * `true` when no editor is left open. A value the column refuses keeps the editor open, marked
   * invalid, and answers `false`.
   */
  commitInPlace(): boolean {
    if (this.editor() === null) return true;
    this.commit(null, false);
    if (this.editor() !== null) return false;
    this.gridElement()?.nativeElement.focus();
    return true;
  }

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
    this.active.set({ row: -1, column: index + this.firstData() });
    this.sortColumn(index);
  }

  protected onStatusHeadClick(): void {
    this.active.set({ row: -1, column: 0 });
  }

  protected onCellClick(row: number, column: number): void {
    if (this.editor() !== null) {
      this.focusEditor();
      return;
    }
    this.active.set({ row, column });
    this.afterActiveCellMoved();
  }

  protected onGridFocus(): void {
    this.afterActiveCellMoved();
  }

  protected onGridKeydown(event: KeyboardEvent): void {
    if (this.editor() !== null) {
      if (event.key !== 'Tab') {
        event.preventDefault();
        this.focusEditor();
      }
      return;
    }
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
      const data = current.column - this.firstData();
      if (data >= 0) this.sortColumn(data);
      return;
    }
    if (current.row >= 0 && this.onEditKey(event, current)) return;
    if (!isCellMoveKey(event.key, control)) return;
    const next = moveCell(current, event.key, control, this.rows().length, this.columnCount(), this.visibleRows());
    if (next === null) return;
    event.preventDefault();
    this.moveTo(next);
  }

  protected onEditorInput(event: Event): void {
    const open = this.editor();
    if (open === null) return;
    this.editor.set({ ...open, text: (event.target as HTMLInputElement).value, problem: '' });
  }

  /** The editor's own keys; none reaches the grid, so a commit never acts again on the cell it moves to. */
  protected onEditorKeydown(event: KeyboardEvent): void {
    event.stopPropagation();
    const open = this.editor();
    if (open === null || event.isComposing) return;
    if (event.key === 'Escape') {
      event.preventDefault();
      this.editor.set(null);
      this.focusGrid();
      return;
    }
    if ((event.ctrlKey || event.metaKey) && event.key.toLowerCase() === 'z') {
      event.preventDefault();
      this.editor.set({ ...open, text: open.initial, problem: '' });
      const element = this.editorElement()?.nativeElement;
      if (element !== undefined) {
        element.value = open.initial;
        element.setSelectionRange(open.initial.length, open.initial.length);
      }
      this.announced.emit(STRINGS.explorerSqlDataUndone);
      return;
    }
    if (event.key === 'Enter') {
      event.preventDefault();
      this.commit(event.shiftKey ? 'ArrowUp' : 'ArrowDown');
      return;
    }
    if (event.key === 'Tab') {
      event.preventDefault();
      this.commit(event.shiftKey ? 'ArrowLeft' : 'ArrowRight');
    }
  }

  protected onEditorBlur(): void {
    if (this.editor() === null) return;
    this.commit(null);
  }

  /**
   * The editing keys on body cell `current`: F2, Enter, a printable key, Backspace and Delete, and on
   * a BIT cell Space. `true` when the key was this grid's.
   */
  private onEditKey(event: KeyboardEvent, current: CellPosition): boolean {
    const key = event.key;
    const printable = key.length === 1 && !event.ctrlKey && !event.metaKey && !event.altKey;
    const editKey = key === 'F2' || key === 'Enter' || key === 'Backspace' || key === 'Delete' || printable;
    if (!editKey || !this.editable() || this.saving()) return false;
    const target = this.editTarget(current);
    if (target === null) {
      event.preventDefault();
      this.announced.emit(STRINGS.explorerSqlDataNotEditable);
      return true;
    }
    const { row, column, data } = target;
    event.preventDefault();
    if (column.kind === 'boolean') {
      if (key === 'Enter' || key === 'F2' || key === ' ') this.edited.emit({ row: row.id, column: data, value: nextBoolean(row.cells[data] ?? null, column.nullable) });
      else if (key === 'Delete') this.stageNull(row, column, data);
      return true;
    }
    if (key === 'Delete') {
      this.stageNull(row, column, data);
      return true;
    }
    const value = row.cells[data] ?? null;
    const atValue = key === 'F2' || key === 'Enter';
    const text = atValue ? (value ?? '') : key === 'Backspace' ? '' : key;
    this.openEditor(current, row, text, value ?? '', atValue && value === null);
    return true;
  }

  /** Stage NULL on `column` where it takes it, else say it does not. */
  private stageNull(row: StagedRow, column: BrowseColumn, data: number): void {
    if (column.nullable) this.edited.emit({ row: row.id, column: data, value: null });
    else this.announced.emit(STRINGS.explorerSqlDataNotNull);
  }

  /** The row, column and data index body cell `position` edits, or `null` where it may not change. */
  private editTarget(position: CellPosition): { readonly row: StagedRow; readonly column: BrowseColumn; readonly data: number } | null {
    const row = this.rows()[position.row];
    const data = position.column - this.firstData();
    const column = this.columns()[data];
    if (row === undefined || column === undefined || row.deleted) return null;
    if (row.isNew ? !insertable(column) : !editable(column) || row.cut[data] === true) return null;
    if (column.kind === 'text' && /[\r\n]/.test(row.cells[data] ?? '')) return null;
    return { row, column, data };
  }

  /**
   * Open the editor on `position` of `row` holding `text`, caret at its end, with `initial` the value it
   * opened with; `nullRead` when it shows a NULL as empty.
   */
  private openEditor(position: CellPosition, row: StagedRow, text: string, initial: string, nullRead: boolean): void {
    this.hideTooltip();
    this.editor.set({ rowId: row.id, rowKey: row.key, nullRead, row: position.row, column: position.column, initial, text, problem: '' });
    const column = this.columns()[position.column - this.firstData()];
    if (column !== undefined) this.announced.emit(fillPlaceholders(STRINGS.explorerSqlDataEditing, { column: column.name }));
    afterNextRender(
      () => {
        const element = this.editorElement()?.nativeElement;
        if (element === undefined) return;
        element.focus();
        element.setSelectionRange(text.length, text.length);
      },
      { injector: this.injector }
    );
  }

  /**
   * Commit the editor: a value the column takes is staged and the editor closes, the active cell moving
   * by `move` and focus returning to the grid after the next render unless `deferFocus` is `false`,
   * when the caller places focus itself; one it refuses keeps the editor open, marked invalid.
   */
  private commit(move: 'ArrowUp' | 'ArrowDown' | 'ArrowLeft' | 'ArrowRight' | null, deferFocus = true): void {
    const open = this.editor();
    if (open === null) return;
    const data = open.column - this.firstData();
    const column = this.columns()[data];
    if (column === undefined || !this.editorRowHolds(open)) {
      this.editor.set(null);
      return;
    }
    const parsed = open.nullRead && open.text === '' ? { value: null } : parseCellInput(column, open.text);
    if ('problem' in parsed) {
      this.editor.set({ ...open, problem: parsed.problem });
      return;
    }
    this.editor.set(null);
    this.edited.emit({ row: open.rowId, column: data, value: parsed.value });
    const position = { row: open.row, column: open.column };
    const next = move === null ? null : moveCell(position, move, false, this.rows().length, this.columnCount(), this.visibleRows());
    this.active.set(next === null || next.row < 0 ? position : next);
    if (deferFocus) this.focusGrid();
  }

  /** Scroll the active cell into the scrolling frame's view once it is drawn. */
  private revealActive(): void {
    afterNextRender(
      () => {
        const { row, column } = this.active();
        const id = row === -1 ? this.headId(column) : this.cellId(row, column);
        document.getElementById(id)?.scrollIntoView?.({ block: 'nearest', inline: 'nearest' });
      },
      { injector: this.injector }
    );
  }

  /** Move the active cell to `next`, reveal it, and show or hide the tooltip for it. */
  private moveTo(next: CellPosition): void {
    this.active.set(next);
    const id = next.row === -1 ? this.headId(next.column) : this.cellId(next.row, next.column);
    document.getElementById(id)?.scrollIntoView?.({ block: 'nearest', inline: 'nearest' });
    this.afterActiveCellMoved();
  }

  private focusGrid(): void {
    afterNextRender(() => this.gridElement()?.nativeElement.focus(), { injector: this.injector });
  }

  /** Return focus to the open editor, which holds a value to fix or cancel. */
  private focusEditor(): void {
    this.editorElement()?.nativeElement.focus();
  }

  /** Whether the row `open` edits is still the one at its place: same id and same identity. */
  private editorRowHolds(open: EditorState): boolean {
    const row = this.rows()[open.row];
    return row !== undefined && row.id === open.rowId && row.key === open.rowKey;
  }

  /** Cycle the sort of data column `index`, when it is sortable. */
  private sortColumn(index: number): void {
    const column = this.columns()[index];
    if (column === undefined || !isFilterable(column.kind)) return;
    this.sorted.emit(column.name);
  }

  private headId(column: number): string {
    return this.editable() && column === 0 ? this.statusHeadId : `ocu-data-head-c${column}`;
  }

  private cellId(row: number, column: number): string {
    return `ocu-data-cell-r${row}-c${column}`;
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

  // --- The cut-cell tooltip (DW-2028, ported from the shared data table) ---------------------------

  /**
   * After the active cell moves: once any scroll the move caused has been dispatched, so it does not
   * take the tooltip straight back, show or hide the tooltip for it.
   */
  private afterActiveCellMoved(): void {
    afterNextRender(() => nextFrame(() => this.updateFocusTooltip()), { injector: this.injector });
  }

  /**
   * The active cell's tooltip while the grid has focus: shown at once on a cut body cell, gone on any
   * other. A tooltip the pointer showed is left alone unless the active cell's replaces it.
   */
  private updateFocusTooltip(): void {
    const grid = this.gridElement()?.nativeElement;
    const id = grid !== undefined && document.activeElement === grid && this.editor() === null ? this.activeDescendant() : null;
    const cell = id === null ? null : document.getElementById(id);
    const text = cell === null || !cell.matches('.ocu-data-table-body .ocu-data-table-cell') ? '' : cutText(cell);
    if (cell === null || text === '') {
      if (this.tooltip()?.source === 'focus') this.hideTooltip();
      return;
    }
    this.showTooltip(cell, text, 'focus');
  }

  /** The pointer resting on a cut cell shows its whole value. */
  protected onCellPointerOver(event: PointerEvent): void {
    const cell = bodyCellOf(event.target);
    if (cell === null || cell.id === this.hoverCellId) return;
    this.hoverCellId = cell.id;
    this.clearHoverTimer();
    const shown = this.tooltip();
    if (shown?.cellId === cell.id) return;
    if (shown?.source === 'pointer') this.hideTooltip();
    const cellId = cell.id;
    this.hoverWait = afterTooltipDelay(() => {
      this.hoverWait = null;
      const target = this.hoverCellId === cellId && this.editor() === null ? document.getElementById(cellId) : null;
      const text = target === null ? '' : cutText(target);
      if (target !== null && text !== '') this.showTooltip(target, text, 'pointer');
    });
  }

  protected onCellPointerOut(event: PointerEvent): void {
    const cell = bodyCellOf(event.target);
    if (cell === null) return;
    const next = event.relatedTarget;
    if (next instanceof Node && cell.contains(next)) return;
    if (this.hoverCellId === cell.id) {
      this.hoverCellId = '';
      this.clearHoverTimer();
    }
    if (next instanceof Node && (this.tooltipElement()?.nativeElement.contains(next) ?? false)) return;
    const shown = this.tooltip();
    if (shown?.source === 'pointer' && shown.cellId === cell.id) this.hideTooltip();
  }

  /** The pointer left the tooltip for anywhere but the cell it belongs to. */
  protected onTooltipLeave(event: PointerEvent): void {
    const shown = this.tooltip();
    if (shown === null || shown.source !== 'pointer') return;
    const cell = document.getElementById(shown.cellId);
    const next = event.relatedTarget;
    if (cell !== null && next instanceof Node && cell.contains(next)) return;
    this.hideTooltip();
  }

  private showTooltip(cell: HTMLElement, text: string, source: CellTooltip['source']): void {
    this.tooltip.set({ cellId: cell.id, text, source, top: 0, left: 0, placed: false });
    this.overlays.push(this.tooltipOverlayId, () => this.hideTooltip());
    afterNextRender(() => this.placeTooltip(), { injector: this.injector });
  }

  /** Put the tooltip under its cell, or above it where there is no room below, inside the window. */
  private placeTooltip(): void {
    const shown = this.tooltip();
    const element = this.tooltipElement()?.nativeElement;
    const cell = shown === null ? null : document.getElementById(shown.cellId);
    if (shown === null || element === undefined) return;
    if (cell === null) {
      this.hideTooltip();
      return;
    }
    const box = cell.getBoundingClientRect();
    const size = element.getBoundingClientRect();
    const width = document.documentElement.clientWidth;
    const height = document.documentElement.clientHeight;
    const top = box.bottom + size.height <= height ? box.bottom : box.top - size.height;
    this.tooltip.set({ ...shown, top: clamp(top, 0, height - size.height), left: clamp(box.left, 0, width - size.width), placed: true });
  }

  protected hideTooltip(): void {
    this.clearHoverTimer();
    if (this.tooltip() === null) return;
    this.tooltip.set(null);
    this.overlays.remove(this.tooltipOverlayId);
  }

  private clearHoverTimer(): void {
    if (this.hoverWait === null) return;
    this.hoverWait();
    this.hoverWait = null;
  }
}

/** The body gridcell `target` is in, or `null`. */
function bodyCellOf(target: EventTarget | null): HTMLElement | null {
  if (!(target instanceof Element)) return null;
  return target.closest<HTMLElement>('.ocu-data-table-body .ocu-data-table-cell');
}

/** A cell's whole value when its text is cut (`scrollWidth > clientWidth`, read now), else `''`. */
function cutText(cell: HTMLElement): string {
  const element = cell.querySelector<HTMLElement>('.ocu-data-table-text');
  if (element === null || element.scrollWidth <= element.clientWidth) return '';
  return (element.textContent ?? '').trim();
}

function clamp(value: number, low: number, high: number): number {
  return Math.min(Math.max(value, low), Math.max(low, high));
}
