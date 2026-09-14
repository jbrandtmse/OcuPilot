import {
  CdkFixedSizeVirtualScroll,
  CdkVirtualForOf,
  CdkVirtualScrollViewport,
} from '@angular/cdk/scrolling';
import type { ListRange } from '@angular/cdk/collections';
import { LocationStrategy } from '@angular/common';
import {
  ChangeDetectionStrategy,
  Component,
  DestroyRef,
  ElementRef,
  InjectionToken,
  Injector,
  type OnInit,
  afterNextRender,
  computed,
  effect,
  inject,
  input,
  output,
  signal,
  viewChild,
} from '@angular/core';
import { Router } from '@angular/router';

import { encodeEntityId } from '../core/entity-id';
import { isBannerFault } from '../core/fault';
import { hasIdRoute, withQuery } from '../core/navigation';
import { OverlayStack } from '../core/overlay-stack';
import { RefreshService } from '../core/refresh';
import { ScopeService } from '../core/scope';
import { ScreenActions } from '../core/screen-actions';
import { applyView } from '../core/screen-read';
import type { ScreenStore } from '../core/screen-store';
import type { ScreenDeclaration, TableColumn } from '../core/screens.generated';
import { STRINGS, stringFor } from '../core/strings';
import {
  type CellView,
  cellView,
  emptyStateView,
  fieldOf,
  formatCapNotice,
  formatRowCount,
  isMoveKey,
  moveActive,
  parseMaxRows,
  reconcile,
  rowKey,
} from '../core/table-model';

/**
 * How the table resolves a descriptor's string keys. `stringFor` everywhere but a spec, which
 * supplies a string the source does not carry -- an empty-state title with a `<NAMESPACE>` span.
 */
export const TABLE_STRING_LOOKUP = new InjectionToken<(key: string) => string>('TABLE_STRING_LOOKUP', {
  providedIn: 'root',
  factory: () => stringFor,
});

/** A body row's height in pixels: `--ocu-row-height`, which the virtual scroll measures rows by. */
export const ROW_HEIGHT_PX = 36;

/** The pixels of rows kept rendered beyond the viewport, at least and at most. */
const MIN_BUFFER_PX = 360;
const MAX_BUFFER_PX = 720;

let tableCount = 0;

interface CellModel {
  readonly field: string;
  readonly id: string;
  readonly view: CellView;
  readonly link: boolean;
  readonly disc: boolean;
  readonly plain: boolean;
  readonly tag: boolean;
  readonly active: boolean;
}

interface RowModel {
  readonly key: string;
  readonly index: number;
  readonly id: string;
  readonly ariaRowIndex: number;
  readonly selected: boolean;
  readonly active: boolean;
  readonly changed: boolean;
  readonly href: string;
  readonly url: string;
  readonly cells: readonly CellModel[];
  readonly triggerId: string;
  readonly triggerActive: boolean;
  /** The row menu is open on this row. */
  readonly menuOpen: boolean;
}

interface HeaderModel {
  readonly field: string;
  readonly label: string;
  readonly numeric: boolean;
  readonly sort: string | null;
  readonly arrow: string;
}

/**
 * The data table every list screen renders (EXPERIENCE.md › data-table, DESIGN.md › data-table).
 *
 * **Its state is the store's** (AD-19): the view is `applyView` over the store's rows, sort,
 * direction and filter; selection, the active row and the changed marks are store slots. The
 * component holds only what is not screen state -- which cell of the active row is active and
 * which row's menu is open.
 *
 * **One Tab stop on the APG grid pattern.** DOM focus stays on the `role="grid"` element and
 * `aria-activedescendant` names the active row, or its active cell, once the virtual scroll has
 * rendered it, so a recycled row never holds focus. The keys are EXPERIENCE.md's Keyboard model.
 *
 * **What renders in the frame.** Skeleton rows until the first successful read since the bind or
 * the last scope switch; the empty state only once a successful read answered zero rows; "request
 * refused" with Retry for a fault the connectivity banner has no copy for (DW-172), which replaces
 * the skeleton on a first load and sits above the kept rows otherwise. A banner fault draws nothing
 * here.
 *
 * **The view changing reconciles** (DW-18, `reconcile`): the active key survives when it can, the
 * row taking its place becomes active when it cannot, a removed selection clears, and a focused
 * grid left with no row sends focus to the empty state or asks for the filter field
 * (`focusFilter`).
 *
 * Every control-flow condition is a paren-free member reference, for the reason `sign-in.ts`
 * records: `ui/tools/client-lint.mjs`'s blanker matches `@if` plus one parenthesised group.
 */
@Component({
  selector: 'app-data-table',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [CdkVirtualScrollViewport, CdkFixedSizeVirtualScroll, CdkVirtualForOf],
  template: `<div class="ocu-data-table-frame" [attr.aria-busy]="busy">
      @if (showSkeleton) {
        <div class="ocu-data-table-skeleton" aria-hidden="true">
          @for (bar of skeletonRows; track bar) {
            <div class="ocu-data-table-skeleton-row">
              <span class="ocu-skeleton-bar ocu-skeleton-bar-40"></span>
              <span class="ocu-skeleton-bar ocu-skeleton-bar-25"></span>
              <span class="ocu-skeleton-bar ocu-skeleton-bar-15"></span>
            </div>
          }
        </div>
      }
      @if (showRefusal) {
        <div class="ocu-data-table-refusal" role="alert">
          <span class="ocu-data-table-refusal-message">{{ STRINGS.connectivityRequestRefused }}</span>
          <button type="button" class="ocu-button-text" (click)="onRetry()">{{ STRINGS.actionRetry }}</button>
        </div>
      }
      @if (showEmpty) {
        <section #empty class="ocu-empty-state ocu-data-table-empty" tabindex="-1">
          <p class="ocu-data-table-empty-title">{{ emptyTitle }}</p>
          <p class="ocu-data-table-empty-next">{{ emptyNext }}</p>
          @if (hasPrimaryAction) {
            <button type="button" class="ocu-button-primary ocu-data-table-empty-action" (click)="onPrimaryAction()">
              {{ primaryActionLabel }}
            </button>
          }
        </section>
      }
      @if (showGrid) {
        <div
          #grid
          class="ocu-data-table-grid"
          role="grid"
          tabindex="0"
          [class.ocu-data-table-grid-no-active]="noActiveRow"
          [attr.aria-label]="gridLabel"
          [attr.aria-rowcount]="ariaRowCount"
          [attr.aria-colcount]="ariaColCount"
          [attr.aria-activedescendant]="activeDescendant"
          (keydown)="onGridKeydown($event)"
          (focusin)="onGridFocusIn($event)"
          (contextmenu)="onContextMenu($event)"
        >
          <div class="ocu-data-table-head" role="rowgroup">
            <div
              class="ocu-data-table-row ocu-data-table-header-row"
              role="row"
              aria-rowindex="1"
              [style.grid-template-columns]="columnTemplate"
            >
              @for (header of headers; track header.field) {
                <div
                  class="ocu-data-table-header-cell"
                  role="columnheader"
                  [class.ocu-data-table-cell-numeric]="header.numeric"
                  [attr.aria-sort]="header.sort"
                >
                  <span class="ocu-data-table-header-label">{{ header.label }}</span>
                  <span class="ocu-data-table-sort-arrow" aria-hidden="true">{{ header.arrow }}</span>
                </div>
              }
              @if (hasRowActions) {
                <div class="ocu-data-table-header-cell" role="columnheader">
                  <span class="ocu-data-table-header-label ocu-data-table-hidden-label">{{
                    STRINGS.commandBoxGroupActions
                  }}</span>
                </div>
              }
            </div>
          </div>
          <cdk-virtual-scroll-viewport
            class="ocu-data-table-viewport"
            tabindex="-1"
            [itemSize]="rowHeight"
            [minBufferPx]="minBufferPx"
            [maxBufferPx]="maxBufferPx"
          >
            <div class="ocu-data-table-body" role="rowgroup">
              <div
                *cdkVirtualFor="let row of rows; trackBy: trackRow"
                class="ocu-data-table-row"
                role="row"
                [id]="row.id"
                [attr.data-row-index]="row.index"
                [attr.aria-rowindex]="row.ariaRowIndex"
                [attr.aria-selected]="row.selected"
                [class.ocu-data-table-row-selected]="row.selected"
                [class.ocu-data-table-row-active]="row.active"
                [class.ocu-data-table-row-changed]="row.changed"
                [style.grid-template-columns]="columnTemplate"
                (click)="onRowClick(row)"
              >
                @for (cell of row.cells; track cell.field) {
                  <div
                    class="ocu-data-table-cell"
                    role="gridcell"
                    [id]="cell.id"
                    [class.ocu-data-table-cell-numeric]="cell.view.numeric"
                    [class.ocu-data-table-cell-active]="cell.active"
                  >
                    @if (cell.link) {
                      <a class="ocu-data-table-link" tabindex="-1" [href]="row.href" (click)="onLinkClick($event, row)">{{
                        cell.view.text
                      }}</a>
                    }
                    @if (cell.disc) {
                      <span class="ocu-data-table-disc" aria-hidden="true" [attr.data-disc]="cell.view.disc"></span>
                    }
                    @if (cell.plain) {
                      <span
                        class="ocu-data-table-text"
                        [class.ocu-data-table-code]="cell.view.code"
                        [class.ocu-data-table-empty-value]="cell.view.empty"
                        >{{ cell.view.text }}</span
                      >
                    }
                    @if (cell.tag) {
                      <span class="ocu-data-table-changed-tag">{{ STRINGS.tableChangedTag }}</span>
                    }
                  </div>
                }
                @if (hasRowActions) {
                  <div
                    class="ocu-data-table-cell ocu-data-table-cell-trigger"
                    role="gridcell"
                    [id]="row.triggerId"
                    [class.ocu-data-table-cell-active]="row.triggerActive"
                  >
                    <button
                      type="button"
                      class="ocu-data-table-trigger"
                      tabindex="-1"
                      aria-haspopup="menu"
                      [attr.aria-expanded]="row.menuOpen"
                      [attr.aria-controls]="row.menuOpen ? menuId : null"
                      [attr.aria-label]="STRINGS.commandBoxGroupActions"
                      (click)="onTriggerClick($event, row)"
                    >
                      <span aria-hidden="true">{{ menuGlyph }}</span>
                    </button>
                  </div>
                }
              </div>
            </div>
          </cdk-virtual-scroll-viewport>
        </div>
      }
      @if (menuOpen) {
        <div
          #menu
          class="ocu-data-table-menu"
          role="menu"
          [id]="menuId"
          [attr.aria-label]="STRINGS.commandBoxGroupActions"
          [style.top.px]="menuTopPx"
          (keydown)="onMenuKeydown($event)"
          (mousedown)="onMenuMouseDown($event)"
          (focusout)="onMenuFocusOut($event)"
        >
          @for (item of menuItems; track item) {
            <button type="button" class="ocu-data-table-menu-item" role="menuitem" tabindex="-1" (click)="onMenuItem(item)">
              {{ item }}
            </button>
          }
        </div>
      }
    </div>
    <div class="ocu-data-table-footer">
      <span class="ocu-data-table-count">{{ rowCountText }}</span>
      @if (showRowCount) {
        <span class="ocu-data-table-footer-separator" aria-hidden="true">{{ footerSeparator }}</span>
      }
      <label class="ocu-data-table-max-rows-label" [attr.for]="maxRowsId">{{ STRINGS.tableMaxRowsLabel }}</label>
      <input
        #maxRows
        class="ocu-data-table-max-rows"
        type="text"
        inputmode="numeric"
        autocomplete="off"
        [id]="maxRowsId"
        [value]="maxRowsValue"
        (keydown.enter)="onCommitMaxRows()"
        (blur)="onCommitMaxRows()"
      />
      @if (showCapNotice) {
        <p class="ocu-data-table-cap-notice">{{ capNotice }}</p>
      }
    </div>`,
})
export class DataTable implements OnInit {
  readonly screen = input.required<ScreenDeclaration>();
  readonly store = input.required<ScreenStore>();

  /** Asked when a focused grid is left with no row and no empty state: the filter takes focus. */
  readonly focusFilter = output<void>();

  private readonly refresh = inject(RefreshService);
  private readonly actions = inject(ScreenActions);
  private readonly scope = inject(ScopeService);
  private readonly overlays = inject(OverlayStack);
  private readonly router = inject(Router);
  private readonly locationStrategy = inject(LocationStrategy);
  private readonly lookup = inject(TABLE_STRING_LOOKUP);
  private readonly injector = inject(Injector);
  private readonly destroyRef = inject(DestroyRef);

  protected readonly STRINGS = STRINGS;
  protected readonly rowHeight = ROW_HEIGHT_PX;
  protected readonly minBufferPx = MIN_BUFFER_PX;
  protected readonly maxBufferPx = MAX_BUFFER_PX;
  protected readonly skeletonRows = [0, 1, 2, 3, 4, 5];

  /** The vertical ellipsis the row-overflow trigger draws, as an escape (Rule 14). */
  protected readonly menuGlyph = '\u22ee';

  /** The middle dot between the footer's row count and its max-rows field (EXPERIENCE.md). */
  protected readonly footerSeparator = '\u00b7';

  private readonly tableId = `ocu-data-table-${(tableCount += 1)}`;
  protected readonly maxRowsId = `${this.tableId}-max-rows`;
  private readonly overlayId = `${this.tableId}-menu`;
  protected readonly menuId = this.overlayId;

  private readonly viewport = viewChild(CdkVirtualScrollViewport);
  private readonly gridElement = viewChild<ElementRef<HTMLElement>>('grid');
  private readonly emptyElement = viewChild<ElementRef<HTMLElement>>('empty');
  private readonly menuElement = viewChild<ElementRef<HTMLElement>>('menu');
  private readonly maxRowsElement = viewChild<ElementRef<HTMLInputElement>>('maxRows');

  /** Bumped by the store, the framework, the scope, the action registry and the router. */
  private readonly generation = signal(0);
  private readonly renderedRange = signal<ListRange>({ start: 0, end: 0 });
  private readonly activeColumn = signal(-1);
  private readonly menuIsOpen = signal(false);
  private readonly menuKey = signal('');
  private readonly menuTop = signal(0);

  /** The view's keys when the table last reconciled. */
  private lastKeys: readonly string[] = [];

  /** Changed keys already scrolled into view once. */
  private readonly scrolledChanged = new Set<string>();

  private readonly view = computed(() => {
    this.generation();
    const store = this.store();
    const read = this.screen().read;
    if (read === null) return [];
    return applyView(store.data(), read, {
      filter: store.filter(),
      sort: store.sort(),
      direction: store.direction(),
    });
  });

  private readonly columns = computed<readonly TableColumn[]>(() => this.screen().table?.columns ?? []);

  private readonly rowModels = computed<readonly RowModel[]>(() => {
    this.generation();
    const screen = this.screen();
    const store = this.store();
    const columns = this.columns();
    const active = store.active();
    const selected = store.selection()[0] ?? '';
    const changed = store.changed();
    const activeColumn = this.activeColumn();
    const menuKey = this.menuIsOpen() ? this.menuKey() : null;
    const linkable = hasIdRoute(screen);
    const currentUrl = this.router.url;
    return this.view().map((row, index) => {
      const key = rowKey(row, screen);
      const id = `${this.tableId}-row-${index}`;
      const isActive = key !== '' && key === active;
      const isChanged = changed.has(key);
      const url = linkable && key !== '' ? withQuery(`${screen.route}/${encodeEntityId(key)}`, currentUrl) : '';
      return {
        key,
        index,
        id,
        ariaRowIndex: index + 2,
        selected: key !== '' && key === selected,
        active: isActive,
        changed: isChanged,
        url,
        href: url === '' ? '' : this.locationStrategy.prepareExternalUrl(url),
        cells: columns.map((column, columnIndex) => {
          const view = cellView(fieldOf(row, column.field), column.kind);
          const link = view.link && url !== '';
          return {
            field: column.field,
            id: `${id}-cell-${columnIndex}`,
            view,
            link,
            disc: view.disc !== null,
            plain: !link,
            tag: isChanged && column.kind === 'name',
            active: isActive && activeColumn === columnIndex,
          };
        }),
        triggerId: `${id}-cell-${columns.length}`,
        triggerActive: isActive && activeColumn === columns.length,
        menuOpen: key === menuKey,
      };
    });
  });

  constructor() {
    const stopRefresh = this.refresh.subscribe(() => this.sync());
    const stopActions = this.actions.subscribe(() => this.bump());
    const stopScope = this.scope.subscribe(() => this.bump());
    const stopRouter = this.router.events.subscribe(() => this.bump());
    this.destroyRef.onDestroy(() => {
      stopRefresh();
      stopActions();
      stopScope();
      stopRouter.unsubscribe();
      this.overlays.remove(this.overlayId);
    });

    effect((onCleanup) => {
      const viewport = this.viewport();
      if (viewport === undefined) return;
      const subscription = viewport.renderedRangeStream.subscribe((range) => this.renderedRange.set(range));
      onCleanup(() => subscription.unsubscribe());
    });
  }

  ngOnInit(): void {
    const stopStore = this.store().subscribe(() => this.sync());
    this.destroyRef.onDestroy(stopStore);
    this.lastKeys = this.viewKeys();
  }

  // --- What renders ------------------------------------------------------------------------------

  private get boundHere(): boolean {
    this.generation();
    return this.refresh.descriptor() === this.screen().descriptor;
  }

  private get loaded(): boolean {
    return this.boundHere && this.refresh.hasLoaded();
  }

  private get fault() {
    return this.boundHere ? this.refresh.fault() : null;
  }

  protected get showRefusal(): boolean {
    const fault = this.fault;
    return fault !== null && !isBannerFault(fault);
  }

  protected get showSkeleton(): boolean {
    return !this.loaded && !this.showRefusal;
  }

  protected get busy(): string | null {
    return this.showSkeleton ? 'true' : null;
  }

  protected get showEmpty(): boolean {
    return this.loaded && this.fault === null && this.store().data().length === 0;
  }

  protected get showGrid(): boolean {
    return this.loaded && !this.showEmpty;
  }

  protected get emptyTitle(): string {
    return emptyStateView(this.screen(), this.scope.namespace(), this.lookup).title;
  }

  protected get emptyNext(): string {
    return emptyStateView(this.screen(), this.scope.namespace(), this.lookup).next;
  }

  protected get hasPrimaryAction(): boolean {
    this.generation();
    const screen = this.screen();
    return this.actions.has(screen.descriptor, screen.primaryAction.id);
  }

  protected get primaryActionLabel(): string {
    return this.screen().primaryAction.id;
  }

  /** The grid's accessible name: the screen's own label. */
  protected get gridLabel(): string {
    return this.lookup(this.screen().labelKey);
  }

  protected get hasRowActions(): boolean {
    return this.menuItems.length > 0;
  }

  protected get menuItems(): readonly string[] {
    return this.screen()
      .rowActions.map((action) => action.id)
      .filter((id) => id !== '');
  }

  protected get headers(): readonly HeaderModel[] {
    this.generation();
    const screen = this.screen();
    const store = this.store();
    const read = screen.read;
    const sortField = read === null ? '' : read.sort.fields.includes(store.sort()) ? store.sort() : read.sort.default;
    const direction = store.direction() === '' ? read?.sort.direction ?? 'asc' : store.direction();
    return this.columns().map((column) => {
      const sorted = column.field === sortField;
      return {
        field: column.field,
        label: this.lookup(column.labelKey),
        numeric: column.kind === 'number',
        sort: sorted ? (direction === 'desc' ? 'descending' : 'ascending') : null,
        arrow: sorted ? (direction === 'desc' ? '\u2193' : '\u2191') : '',
      };
    });
  }

  protected get columnTemplate(): string {
    const tracks: string[] = this.columns().map((column) =>
      column.kind === 'number' || column.kind === 'status' ? 'minmax(0, 1fr)' : 'minmax(0, 2fr)'
    );
    if (this.hasRowActions) tracks.push('calc(28px + 2 * var(--ocu-space-3))');
    return tracks.join(' ');
  }

  protected get rows(): readonly RowModel[] {
    return this.rowModels();
  }

  protected get ariaRowCount(): number {
    return this.view().length + 1;
  }

  protected get ariaColCount(): number {
    return this.columns().length + (this.hasRowActions ? 1 : 0);
  }

  protected get noActiveRow(): boolean {
    return this.activeIndex() < 0;
  }

  /**
   * The active row's id, or its active cell's, once the virtual scroll has rendered it; `null`
   * otherwise, so the attribute never names an element that is not there.
   */
  protected get activeDescendant(): string | null {
    const index = this.activeIndex();
    if (index < 0) return null;
    const range = this.renderedRange();
    if (index < range.start || index >= range.end) return null;
    const row = this.rowModels()[index];
    const column = this.activeColumn();
    if (column < 0) return row.id;
    return column < row.cells.length ? row.cells[column].id : row.triggerId;
  }

  protected get menuOpen(): boolean {
    return this.menuIsOpen();
  }

  protected get menuTopPx(): number {
    return this.menuTop();
  }

  protected get showRowCount(): boolean {
    return this.loaded;
  }

  protected get rowCountText(): string {
    return this.loaded ? formatRowCount(STRINGS.tableRowCount, this.view().length) : '';
  }

  protected get maxRowsValue(): string {
    this.generation();
    return String(this.store().maxRows());
  }

  protected get showCapNotice(): boolean {
    this.generation();
    return this.loaded && this.store().truncated();
  }

  protected get capNotice(): string {
    return formatCapNotice(STRINGS.tableRowCapNotice, this.store().maxRows());
  }

  protected trackRow = (_index: number, row: RowModel): string => row.key;

  // --- Keyboard ------------------------------------------------------------------------------------

  protected onGridKeydown(event: KeyboardEvent): void {
    const keys = this.lastKeys;
    if (event.altKey && event.key === 'ArrowDown') {
      if (!this.hasRowActions || this.activeIndex() < 0) return;
      event.preventDefault();
      this.openMenu(this.activeIndex());
      return;
    }
    if (isMoveKey(event.key)) {
      event.preventDefault();
      const next = moveActive(this.activeIndex(), event.key, keys.length, this.pageSize());
      if (next >= 0) this.moveTo(next);
      return;
    }
    const index = this.activeIndex();
    if (index < 0) return;
    const cells = this.ariaColCount;
    if (event.key === 'ArrowRight') {
      event.preventDefault();
      this.scrollIntoRange(index);
      this.activeColumn.set(Math.min(this.activeColumn() + 1, cells - 1));
      return;
    }
    if (event.key === 'ArrowLeft') {
      event.preventDefault();
      this.scrollIntoRange(index);
      this.activeColumn.set(Math.max(this.activeColumn() - 1, -1));
      return;
    }
    if (event.key === 'Enter') {
      event.preventDefault();
      if (this.hasRowActions && this.activeColumn() === this.columns().length) {
        this.openMenu(index);
        return;
      }
      const url = this.rowModels()[index]?.url ?? '';
      if (url !== '') void this.router.navigateByUrl(url);
    }
  }

  /**
   * Keep DOM focus on the grid. The viewport is out of the Tab order (`tabindex="-1"`) but still
   * focusable, so a click on a cell would otherwise focus it and leave `aria-activedescendant` on an
   * element that does not hold focus.
   */
  protected onGridFocusIn(event: FocusEvent): void {
    if (event.target !== this.viewport()?.elementRef.nativeElement) return;
    this.gridElement()?.nativeElement.focus({ preventScroll: true });
  }

  /**
   * A row's own `contextmenu` opens that row's menu; one fired at the grid itself -- the keyboard's
   * menu key, with the grid focused -- opens the active row's. Anywhere else, such as the header,
   * opens nothing.
   */
  protected onContextMenu(event: MouseEvent): void {
    if (!this.hasRowActions) return;
    const target = event.target instanceof Element ? event.target.closest('[data-row-index]') : null;
    const onGrid = event.target === this.gridElement()?.nativeElement;
    const index = target !== null ? Number(target.getAttribute('data-row-index')) : onGrid ? this.activeIndex() : -1;
    if (index < 0) return;
    event.preventDefault();
    this.openMenu(index);
  }

  // --- Mouse ---------------------------------------------------------------------------------------

  protected onRowClick(row: RowModel): void {
    this.select(row.index);
  }

  protected onLinkClick(event: MouseEvent, row: RowModel): void {
    event.stopPropagation();
    if (event.ctrlKey || event.metaKey || event.shiftKey || event.button !== 0) return;
    event.preventDefault();
    void this.router.navigateByUrl(row.url);
  }

  protected onTriggerClick(event: MouseEvent, row: RowModel): void {
    event.stopPropagation();
    this.openMenu(row.index);
  }

  // --- The row menu --------------------------------------------------------------------------------

  protected onMenuKeydown(event: KeyboardEvent): void {
    const items = this.menuButtons();
    if (items.length === 0) return;
    const at = items.indexOf(document.activeElement as HTMLElement);
    let next = -1;
    if (event.key === 'ArrowDown') next = (at + 1) % items.length;
    else if (event.key === 'ArrowUp') next = (at - 1 + items.length) % items.length;
    else if (event.key === 'Home') next = 0;
    else if (event.key === 'End') next = items.length - 1;
    if (next < 0) return;
    event.preventDefault();
    items[next].focus();
  }

  /**
   * Keep focus where it is while a menu item is pressed: a browser that does not focus a button on
   * click would otherwise move focus out of the menu, close it, and lose the click.
   */
  protected onMenuMouseDown(event: MouseEvent): void {
    event.preventDefault();
  }

  protected onMenuFocusOut(event: FocusEvent): void {
    const menu = this.menuElement()?.nativeElement;
    const next = event.relatedTarget;
    if (menu === undefined || (next instanceof Node && menu.contains(next))) return;
    this.closeMenu(false);
  }

  protected onMenuItem(actionId: string): void {
    this.closeMenu(true);
    this.actions.run(this.screen().descriptor, actionId);
  }

  // --- Footer, empty state, refusal ------------------------------------------------------------------

  protected onCommitMaxRows(): void {
    const field = this.maxRowsElement()?.nativeElement;
    if (field === undefined) return;
    const store = this.store();
    const cap = parseMaxRows(field.value);
    if (cap === null) {
      field.value = String(store.maxRows());
      return;
    }
    if (cap === store.maxRows()) return;
    if (store.setMaxRows(cap)) void this.refresh.readNow();
  }

  protected onRetry(): void {
    void this.refresh.readNow();
  }

  protected onPrimaryAction(): void {
    const screen = this.screen();
    this.actions.run(screen.descriptor, screen.primaryAction.id);
  }

  // --- Internals -------------------------------------------------------------------------------------

  private bump(): void {
    this.generation.update((value) => value + 1);
  }

  private viewKeys(): readonly string[] {
    const screen = this.screen();
    return this.view().map((row) => rowKey(row, screen));
  }

  private activeIndex(): number {
    this.generation();
    const active = this.store().active();
    return active === '' ? -1 : this.lastKeys.indexOf(active);
  }

  /** Follow the store and the framework, and reconcile when the view's keys moved (DW-18). */
  private sync(): void {
    this.bump();
    const keys = this.viewKeys();
    const store = this.store();
    if (!sameKeys(keys, this.lastKeys)) {
      const previous = this.lastKeys;
      this.lastKeys = keys;
      const focused = document.activeElement;
      const hadFocus =
        focused !== null &&
        ((this.gridElement()?.nativeElement.contains(focused) ?? false) ||
          (this.menuElement()?.nativeElement.contains(focused) ?? false));
      if (this.menuIsOpen() && !keys.includes(this.menuKey())) this.closeMenu(keys.length > 0);
      const selected = store.selection()[0] ?? '';
      const result = reconcile({
        previousKeys: previous,
        nextKeys: keys,
        active: store.active(),
        selected,
        gridFocused: hadFocus,
        emptyStateShown: this.showEmpty,
      });
      if (result.active !== store.active()) {
        this.activeColumn.set(-1);
        store.setActive(result.active);
        store.clearChanged(result.active);
      }
      if (result.selected !== selected) store.setSelection(result.selected === '' ? [] : [result.selected]);
      if (result.focus === 'empty') {
        afterNextRender(() => this.emptyElement()?.nativeElement.focus(), { injector: this.injector });
      } else if (result.focus === 'filter') {
        this.focusFilter.emit();
      }
    }
    this.scrollChangedIntoView();
  }

  private scrollChangedIntoView(): void {
    const changed = this.store().changed();
    for (const key of [...this.scrolledChanged]) {
      if (!changed.has(key)) this.scrolledChanged.delete(key);
    }
    for (const key of changed) {
      if (this.scrolledChanged.has(key)) continue;
      const index = this.lastKeys.indexOf(key);
      if (index < 0) continue;
      this.scrolledChanged.add(key);
      this.scrollIntoRange(index);
    }
  }

  private select(index: number): void {
    const key = this.lastKeys[index];
    if (key === undefined) return;
    const store = this.store();
    if (key !== store.active()) this.activeColumn.set(-1);
    store.setActive(key);
    store.setSelection([key]);
    store.clearChanged(key);
  }

  /** Move the active row to `index`, select it, and bring it into the rendered range. */
  private moveTo(index: number): void {
    this.select(index);
    this.scrollIntoRange(index);
  }

  private pageSize(): number {
    const size = this.viewport()?.getViewportSize() ?? 0;
    return Math.max(1, Math.floor(size / ROW_HEIGHT_PX));
  }

  private scrollIntoRange(index: number): void {
    const viewport = this.viewport();
    if (viewport === undefined) return;
    viewport.checkViewportSize();
    const size = viewport.getViewportSize();
    if (size > 0) {
      const top = viewport.measureScrollOffset('top');
      const rowTop = index * ROW_HEIGHT_PX;
      const rowBottom = rowTop + ROW_HEIGHT_PX;
      if (rowTop < top) viewport.scrollToOffset(rowTop);
      else if (rowBottom > top + size) viewport.scrollToOffset(rowBottom - size);
    }
    this.renderedRange.set(viewport.getRenderedRange());
  }

  private openMenu(index: number): void {
    this.select(index);
    this.scrollIntoRange(index);
    this.menuKey.set(this.lastKeys[index] ?? '');
    this.menuIsOpen.set(true);
    this.overlays.push(this.overlayId, () => this.closeMenu(true));
    afterNextRender(
      () => {
        this.placeMenu(index);
        this.menuButtons()[0]?.focus();
      },
      { injector: this.injector }
    );
  }

  /**
   * Put the menu under its row, or above it when the frame has no room below, so the frame's
   * clipping never hides an item.
   */
  private placeMenu(index: number): void {
    const viewport = this.viewport();
    const menu = this.menuElement()?.nativeElement;
    const frame = this.gridElement()?.nativeElement.closest('.ocu-data-table-frame');
    if (viewport === undefined || menu === undefined || !(frame instanceof HTMLElement)) return;
    const frameTop = frame.getBoundingClientRect().top;
    const viewportTop = viewport.elementRef.nativeElement.getBoundingClientRect().top - frameTop;
    const rowTop = viewportTop + index * ROW_HEIGHT_PX - viewport.measureScrollOffset('top');
    const below = rowTop + ROW_HEIGHT_PX;
    const height = menu.getBoundingClientRect().height;
    this.menuTop.set(below + height <= frame.clientHeight ? below : Math.max(0, rowTop - height));
  }

  private closeMenu(returnFocus: boolean): void {
    if (!this.menuIsOpen()) return;
    this.menuIsOpen.set(false);
    this.menuKey.set('');
    this.overlays.remove(this.overlayId);
    if (returnFocus) this.gridElement()?.nativeElement.focus();
  }

  private menuButtons(): HTMLElement[] {
    const menu = this.menuElement()?.nativeElement;
    return menu === undefined ? [] : Array.from(menu.querySelectorAll<HTMLElement>('[role="menuitem"]'));
  }
}

function sameKeys(a: readonly string[], b: readonly string[]): boolean {
  if (a.length !== b.length) return false;
  for (let index = 0; index < a.length; index += 1) {
    if (a[index] !== b[index]) return false;
  }
  return true;
}
