import { ChangeDetectionStrategy, Component, DestroyRef, ElementRef, Injector, afterNextRender, inject, signal, viewChild } from '@angular/core';
import { MatTabLink, MatTabNav, MatTabNavPanel } from '@angular/material/tabs';
import { Router } from '@angular/router';

import { ApiService } from '../../core/api';
import { saveCsv } from '../../core/csv';
import { FormDirty } from '../../core/form-dirty';
import {
  DATA_BROWSER_SHORTCUTS,
  MAX_OFFSET,
  PAGE_SIZES,
  goToPageOffset,
  lastOffset,
  nextOffset,
  pageCount,
  pageOf,
  pageRangeLine,
  rowRangeMax,
  rowsLine,
  saveConsequenceText,
  shortcutFor,
  shortcutStep,
  type ShortcutAction,
  type ShortcutPlace,
  type SortState,
  waitingText,
} from '../../core/data-browser-model';
import { NavigationService, screenForDescriptor } from '../../core/navigation';
import { ScopeService, onScopeChange } from '../../core/scope';
import { ScreenStores, type ScreenStore } from '../../core/screen-store';
import type { ScreenDeclaration } from '../../core/screens.generated';
import { STRINGS } from '../../core/strings';
import { groupDigits } from '../../core/table-model';
import { Dialog } from '../../shell/dialog';
import { ScreenActionHandler } from '../../shell/screen-action-handler';
import { WarningDialog } from '../../shell/warning-dialog';
import { fillPlaceholders } from './code-list.store';
import { DataBrowserGrid, type CellEdit, type PageRequest } from './data-browser-grid';
import { DataBrowserTree } from './data-browser-tree';
import {
  DataBrowserState,
  type ActiveCell,
  type BrowseAnswer,
  type BrowseColumn,
  type DataBrowserDeps,
  type StagedRow,
  type TabView,
  type TreeObject,
  type TreeSchema,
} from './data-browser.store';

/** The three screens whose declared reads fill the tree (AD-5). */
export const TREE_DESCRIPTORS = {
  schemas: 'OcuPilot.Screen.Descriptor.ExplorerSqlSchemas',
  tables: 'OcuPilot.Screen.Descriptor.ExplorerSqlTables',
  views: 'OcuPilot.Screen.Descriptor.ExplorerSqlViews',
} as const;

/** One `DataBrowserState` per screen store, so a return to the screen finds the open tabs and their pages. */
const HELD = new WeakMap<ScreenStore, DataBrowserState>();

function heldFor(store: ScreenStore | null): DataBrowserState {
  const known = store === null ? undefined : HELD.get(store);
  if (known !== undefined) return known;
  const state = new DataBrowserState();
  if (store !== null) HELD.set(store, state);
  return state;
}

/** One tab of the strip as drawn: its accessible name adds what it stages, and its dot shows that it does. */
interface TabRender extends TabView {
  readonly name: string;
  readonly dot: boolean;
}

/** Where a closed tab's close came from, which decides where focus goes next. */
type CloseOrigin = 'strip' | 'button' | 'other';

/** Where the key `target` received was pressed, as the shortcuts read it. */
function shortcutPlace(target: EventTarget | null): ShortcutPlace {
  if (!(target instanceof Element)) return 'grid';
  if (target.closest('.ocu-data-browser-tab') !== null) return 'tab';
  if (target.closest('input, textarea, [contenteditable]') !== null) return 'text';
  return 'grid';
}

/** The tab of the strip `target` is in, or `null`. */
function tabIdOf(target: EventTarget | null): string | null {
  return target instanceof Element ? (target.closest('.ocu-data-browser-tab')?.getAttribute('data-tab') ?? null) : null;
}

/**
 * System Explorer's Data browser (Story 19.7): the schema tree beside the open tables, stacked when
 * the column is narrow, with the empty state until a table opens.
 *
 * **Tabs** (Story 19.16). Each table or view opened from the tree opens in a tab of its own, in
 * Material's tab nav bar named "Open tables" above the head, and is selected; one already open is
 * selected and reads nothing; past `MAX_TABS` nothing opens and the status line says so. Each tab
 * keeps its own filters, sort, page, page size, staged changes and active cell, restored through the
 * grid's `place` when it is selected again or the page opens again, and its grid is its own; a tab
 * chord pressed in the grid moves focus to the new tab's grid. A tab is named by its
 * `<schema>.<table>`, plus ", <n> changes waiting to be saved." while it stages rows, which a dot
 * shows. Its pointer-only close mark, Delete on the focused tab, Alt/Option+Shift+W and Close tab
 * close it, asking "Leave without saving?" through `FormDirty` first when it stages rows; focus then
 * moves to the selected tab when it was in the strip, stays on Close tab when it was there, and moves
 * to the tree when no tab is left. The tabs carry no route, so the URL never changes.
 *
 * Above the grid: the open object's name as a heading, Refresh, Clear filters, Download CSV, Go to
 * row, Keyboard shortcuts, Close tab and the filter hint. Below it: First, Previous, a Page field "of
 * N", Next and Last -- Last drawn disabled while the total is unknown -- and Rows per page; then the
 * polite status line, an SQL error's message as text, and a refusal as an alert banner. A control that
 * cannot act is drawn `aria-disabled` and answers nothing.
 *
 * **Editing** (Story 19.8). On a table whose key this account can list, the head adds Add row,
 * Duplicate row, Delete row (Restore row on a deleted row), Save changes (<n>) and Discard changes,
 * acting on the grid's active row; a view or a keyless table reads the read-only line instead. Save
 * opens the warning dialog naming the table and how many rows change, are added and are deleted;
 * Proceed sends the save for the selected tab, Cancel nothing. Leaving the route asks "Leave without
 * saving?" and drops every tab's staged rows, keeping the tabs; a namespace switch closes every tab.
 *
 * **Download CSV** writes the selected tab's page as the instance read it (`DataTab.exportPage`) to a
 * file built in this browser and announces it; it sends nothing. **Go to row** and **Keyboard
 * shortcuts** are the shell's dialog, which traps focus and returns it; no dialog opens over another.
 *
 * **Shortcuts** (`DATA_BROWSER_SHORTCUTS`). One capture-phase key handler on the page's host, which
 * holds only its section, acts while focus is inside it: each chord the table names does what its
 * control does, or nothing when that control is unavailable, and is kept from the browser and from
 * the grid either way. It is inert while a dialog is in the document, and while an editor is open but
 * for Ctrl/Cmd+S, which commits the editor first.
 *
 * **Everything shown is text** (AD-11), and the page lives in `DataBrowserState`, never in the
 * screen's store, so it never reaches screen context (AD-36, AD-39's sixth exception).
 *
 * Every control-flow condition is a paren-free member reference, for the reason `sign-in.ts`
 * records.
 */
@Component({
  selector: 'app-data-browser-page',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [DataBrowserTree, DataBrowserGrid, WarningDialog, Dialog, MatTabNav, MatTabLink, MatTabNavPanel],
  template: `<section class="ocu-form-page ocu-data-browser" [attr.aria-busy]="loading">
    @if (hasRefusal) {
      <p class="ocu-banner ocu-banner-warning" role="alert" data-ocu-data="refusal">{{ refusal }}</p>
    }
    <div class="ocu-data-browser-split">
      <div class="ocu-data-browser-tree-pane">
        <h2 class="ocu-details-heading">{{ STRINGS.explorerSqlDataTree }}</h2>
        <app-data-browser-tree
          [schemas]="schemas"
          [current]="open"
          [busy]="schemasLoading"
          (toggled)="onToggle($event)"
          (opened)="onOpen($event)"
        />
        @if (schemasTruncated) {
          <p class="ocu-data-browser-tree-note" data-ocu-data="tree-cut">{{ STRINGS.explorerSqlDataTreeCut }}</p>
        }
        @if (hasSchemasFault) {
          <p class="ocu-data-browser-tree-note" data-ocu-data="tree-fault">{{ schemasFault }}</p>
        }
      </div>
      <div class="ocu-data-browser-main">
        @if (open; as object) {
          <nav
            mat-tab-nav-bar
            class="ocu-data-browser-tabs"
            data-ocu-data="tabs"
            [tabPanel]="panel"
            [disableRipple]="true"
            [attr.aria-label]="STRINGS.explorerSqlDataOpenTables"
          >
            @for (tab of tabList; track tab.id) {
              <button
                type="button"
                mat-tab-link
                class="ocu-data-browser-tab"
                data-ocu-data="tab"
                [active]="tab.active"
                [attr.aria-label]="tab.name"
                [attr.data-tab]="tab.id"
                (click)="onSelectTab(tab.id)"
              >
                <span class="ocu-data-browser-tab-label">{{ tab.label }}</span>
                @if (tab.dot) {
                  <span class="ocu-data-browser-tab-dot" aria-hidden="true" data-ocu-data="tab-dot"></span>
                }
                <span class="ocu-data-browser-tab-close" aria-hidden="true" data-ocu-data="tab-close" (click)="onTabCloseClick($event, tab.id)">{{ closeGlyph }}</span>
              </button>
            }
          </nav>
          <mat-tab-nav-panel #panel class="ocu-data-browser-panel" data-ocu-data="panel">
            <div class="ocu-data-browser-head">
              <h2 class="ocu-data-browser-heading" data-ocu-data="heading">{{ heading }}</h2>
              <div class="ocu-data-browser-actions">
                <button type="button" class="ocu-button-text" data-ocu-data="refresh" [attr.aria-disabled]="loading" (click)="onRefresh()">{{ STRINGS.actionRefresh }}</button>
                <button type="button" class="ocu-button-text" data-ocu-data="clear-filters" [attr.aria-disabled]="noFilters" (click)="onClearFilters()">{{ STRINGS.explorerSqlDataClearFilters }}</button>
                <button type="button" class="ocu-button-text" data-ocu-data="export" [attr.aria-disabled]="exportBlocked" (click)="onExport()">{{ STRINGS.tableDownloadCsv }}</button>
                <button type="button" class="ocu-button-text" data-ocu-data="go-to-row" [attr.aria-disabled]="goToRowBlocked" (click)="onOpenGoToRow()">{{ STRINGS.explorerSqlDataGoToRow }}</button>
                <button type="button" class="ocu-button-text" data-ocu-data="shortcuts" (click)="onOpenShortcuts()">{{ STRINGS.explorerSqlDataShortcuts }}</button>
                <button type="button" class="ocu-button-text" data-ocu-data="close-tab" (click)="onCloseTab()">{{ STRINGS.explorerSqlDataCloseTab }}</button>
              </div>
            </div>
            @if (writable) {
              <div class="ocu-data-browser-edit-actions" data-ocu-data="edit-actions">
                <button type="button" class="ocu-button-text" data-ocu-data="add-row" [attr.aria-disabled]="editBlocked" (click)="onAddRow()">{{ STRINGS.explorerSqlDataAddRow }}</button>
                <button type="button" class="ocu-button-text" data-ocu-data="duplicate-row" [attr.aria-disabled]="rowBlocked" (click)="onDuplicateRow()">{{ STRINGS.explorerSqlDataDuplicateRow }}</button>
                <button type="button" class="ocu-button-text" data-ocu-data="delete-row" [attr.aria-disabled]="rowBlocked" (click)="onDeleteRow()">{{ deleteLabel }}</button>
                <button type="button" class="ocu-button-primary" data-ocu-data="save" [attr.aria-disabled]="saveBlocked" (click)="onSave()">{{ saveLabel }}</button>
                <button type="button" class="ocu-button-text" data-ocu-data="discard" [attr.aria-disabled]="discardBlocked" (click)="onDiscard()">{{ STRINGS.explorerSqlDataDiscard }}</button>
              </div>
            }
            @if (readOnly) {
              <p class="ocu-data-browser-hint" data-ocu-data="read-only">{{ STRINGS.explorerSqlDataReadOnly }}</p>
            }
            <p class="ocu-data-browser-hint" data-ocu-data="hint">{{ STRINGS.explorerSqlDataFilterHint }}</p>
            @for (shown of shownTabs; track shown) {
              <app-data-browser-grid
                [label]="heading"
                [columns]="columns"
                [rows]="rows"
                [offset]="pageOffset"
                [total]="total"
                [sort]="sort"
                [drafts]="drafts"
                [editable]="writable"
                [saving]="savingNow"
                (sorted)="onSort($event)"
                (drafted)="onDraft($event)"
                (applied)="onApply($event)"
                (cleared)="onClear($event)"
                (paged)="onPaged($event)"
                (edited)="onEdited($event)"
                (announced)="onAnnounced($event)"
                (activeCell)="onActiveCell($event)"
              />
            }
            <div class="ocu-data-browser-pager" data-ocu-data="pager">
              <button type="button" class="ocu-button-text" data-ocu-data="first" [attr.aria-disabled]="atStart" (click)="onFirst()">{{ STRINGS.explorerSqlDataFirstPage }}</button>
              <button type="button" class="ocu-button-text" data-ocu-data="previous" [attr.aria-disabled]="atStart" (click)="onPrevious()">{{ STRINGS.explorerSqlDataPreviousPage }}</button>
              <label class="ocu-criteria-label" for="ocu-data-page">{{ STRINGS.explorerSqlDataPage }}</label>
              <input
                id="ocu-data-page"
                class="ocu-criteria-input ocu-data-browser-page-input"
                type="text"
                inputmode="numeric"
                autocomplete="off"
                data-ocu-data="page"
                [value]="pageText"
                [attr.aria-invalid]="hasPageProblem ? true : null"
                [attr.aria-describedby]="pageDescribedBy"
                (input)="onPageInput($event)"
                (keydown)="onPageKeydown($event)"
              />
              @if (hasPageCount) {
                <span class="ocu-data-browser-page-count" id="ocu-data-page-count" data-ocu-data="page-count">{{ pageCountText }}</span>
              }
              <button type="button" class="ocu-button-text" data-ocu-data="next" [attr.aria-disabled]="atEnd" (click)="onNext()">{{ STRINGS.explorerSqlDataNextPage }}</button>
              <button type="button" class="ocu-button-text" data-ocu-data="last" [attr.aria-disabled]="lastBlocked" (click)="onLast()">{{ STRINGS.explorerSqlDataLastPage }}</button>
              <label class="ocu-criteria-label" for="ocu-data-size">{{ STRINGS.explorerSqlDataRowsPerPage }}</label>
              <select id="ocu-data-size" class="ocu-criteria-input ocu-data-browser-size" data-ocu-data="size" (change)="onSize($event)">
                @for (size of sizes; track size) {
                  <option [value]="size" [selected]="size === pageSize">{{ size }}</option>
                }
              </select>
            </div>
            @if (hasPageProblem) {
              <p class="ocu-data-browser-page-problem" id="ocu-data-page-problem" data-ocu-data="page-problem">{{ pageProblem }}</p>
            }
            <p class="ocu-explorer-status" role="status" data-ocu-data="status">{{ statusLine }}</p>
            @if (hasMessage) {
              <pre class="ocu-source-text ocu-sql-query-message" tabindex="0" data-ocu-data="message" [attr.aria-label]="statusLine">{{ message }}</pre>
            }
          </mat-tab-nav-panel>
        } @else {
          <p class="ocu-explorer-status" role="status" data-ocu-data="status">{{ announcement }}</p>
          <div class="ocu-data-browser-empty" data-ocu-data="empty">
            <p class="ocu-data-browser-empty-text">{{ STRINGS.explorerSqlDataPick }}</p>
          </div>
        }
      </div>
    </div>
    @if (leavePending) {
      <app-dialog [heading]="STRINGS.formLeaveWithoutSaving" [closeLabel]="STRINGS.actionCancel" (closed)="answerLeave(false)">
        <button dialogAction type="button" class="ocu-button-primary" data-ocu-data="leave" (click)="answerLeave(true)">
          {{ STRINGS.actionConfirm }}
        </button>
      </app-dialog>
    }
    @if (confirmDialog) {
      <app-warning-dialog [verb]="saveTitle" [consequence]="saveConsequence" (confirmed)="onProceed()" (cancelled)="onCancelSave()" />
    }
    @if (shortcutsDialog) {
      <app-dialog [heading]="STRINGS.explorerSqlDataShortcuts" [closeLabel]="STRINGS.auditDialogClose" (closed)="onCloseShortcuts()">
        <p class="ocu-data-browser-hint" data-ocu-data="shortcuts-scope">{{ STRINGS.explorerSqlDataShortcutsScope }}</p>
        <dl class="ocu-data-browser-shortcuts" data-ocu-data="shortcut-list">
          @for (row of shortcutRows; track row.action) {
            <dt data-ocu-data="shortcut-label">{{ row.label }}</dt>
            <dd data-ocu-data="shortcut-keys"><kbd>{{ row.keys }}</kbd></dd>
          }
        </dl>
      </app-dialog>
    }
    @if (rowDialog) {
      <app-dialog [heading]="STRINGS.explorerSqlDataGoToRow" [closeLabel]="STRINGS.actionCancel" (closed)="onCloseGoToRow()">
        <div class="ocu-data-browser-row-field">
          <label class="ocu-criteria-label" for="ocu-data-row">{{ STRINGS.explorerSqlDataRowNumber }}</label>
          <input
            id="ocu-data-row"
            class="ocu-criteria-input"
            type="text"
            inputmode="numeric"
            autocomplete="off"
            data-ocu-data="row-number"
            aria-describedby="ocu-data-row-range"
            [value]="rowText"
            [attr.aria-invalid]="rowRefused ? true : null"
            (input)="onRowInput($event)"
            (keydown)="onRowKeydown($event)"
          />
          <p class="ocu-data-browser-hint" id="ocu-data-row-range" data-ocu-data="row-range" [class.ocu-data-browser-row-refused]="rowRefused">{{ rowRangeText }}</p>
        </div>
        <button dialogAction type="button" class="ocu-button-primary" data-ocu-data="go" (click)="onGoToRow()">{{ STRINGS.explorerSqlDataGo }}</button>
      </app-dialog>
    }
  </section>`,
})
export class DataBrowserPage {
  private readonly navigation = inject(NavigationService);
  private readonly router = inject(Router);
  private readonly stores = inject(ScreenStores);
  private readonly scope = inject(ScopeService);
  private readonly formDirty = inject(FormDirty);
  private readonly injector = inject(Injector);
  private readonly host = inject<ElementRef<HTMLElement>>(ElementRef).nativeElement;

  protected readonly STRINGS = STRINGS;

  protected readonly sizes = PAGE_SIZES;

  /** A tab's close mark, drawn for the pointer only. */
  protected readonly closeGlyph = '\u00d7';

  /** The Keyboard shortcuts dialog's rows, each `DATA_BROWSER_SHORTCUTS` row's label and keys. */
  protected readonly shortcutRows = DATA_BROWSER_SHORTCUTS.map((shortcut) => ({ action: shortcut.action, label: STRINGS[shortcut.labelKey], keys: STRINGS[shortcut.keysKey] }));

  private readonly grid = viewChild(DataBrowserGrid);

  protected readonly screen: ScreenDeclaration | null;

  private readonly state: DataBrowserState;

  private readonly deps: DataBrowserDeps;

  /** Bumped by the state, so the page re-renders under `OnPush`. */
  private readonly generation = signal(0);

  /** What the Page field holds while it is being typed, or `null` to show the current page. */
  private readonly pageDraft = signal<string | null>(null);

  /** The Page field's range line after a page outside it, or `''`. */
  private readonly pageProblemText = signal('');

  /** Whether the save dialog is open. */
  private readonly confirmOpen = signal(false);

  /** Whether the Keyboard shortcuts dialog is open. */
  private readonly shortcutsShown = signal(false);

  /** Whether the Go to row dialog is open, what its field holds, and whether that was refused. */
  private readonly rowShown = signal(false);

  private readonly rowDraft = signal('');

  private readonly rowRefusedValue = signal(false);

  /** Whether a Go is on its way, so a second press sends nothing. */
  private rowBusy = false;

  /** Whether the page has been destroyed, so an answer arriving after it acts on nothing. */
  private destroyed = false;

  constructor() {
    this.screen = this.navigation.screenForUrl(this.router.url);
    this.state = heldFor(this.screen === null ? null : this.stores.for(this.screen.descriptor, this.screen.refreshRates));
    this.deps = {
      api: inject(ApiService),
      scope: () => this.scope.namespace(),
      schemas: screenForDescriptor(TREE_DESCRIPTORS.schemas),
      tables: screenForDescriptor(TREE_DESCRIPTORS.tables),
      views: screenForDescriptor(TREE_DESCRIPTORS.views),
      sender: inject(ScreenActionHandler),
      descriptor: this.screen?.descriptor ?? '',
      formDirty: this.formDirty,
    };
    const stop = this.state.subscribe(() => this.bump());
    const stopDirty = this.formDirty.subscribe(() => this.bump());
    // The tree is read once the scope has resolved, and a namespace switch reads it again (AD-44):
    // the old namespace's tree and tabs leave now.
    const stopScope = onScopeChange(this.scope, () => {
      this.resetPageField();
      void this.state.scopeTo(this.deps, this.scope.namespace());
    });
    if (this.scope.loaded()) void this.state.scopeTo(this.deps, this.scope.namespace());
    // The shortcuts: one capture-phase handler on the host, so a chord is read before the grid or a
    // tab acts on it, and only while focus is inside the page.
    const onKeydown = (event: KeyboardEvent): void => this.onShortcutKeydown(event);
    this.host.addEventListener('keydown', onKeydown, true);
    // Leaving the route asked first (the form-page guard), so every tab's staged rows go with the page;
    // the tabs stay for a return.
    inject(DestroyRef).onDestroy(() => {
      this.destroyed = true;
      this.host.removeEventListener('keydown', onKeydown, true);
      stop();
      stopDirty();
      stopScope();
      this.state.discardAll(this.deps);
      this.formDirty.setDirty(false);
    });
    // A return to the route draws the selected tab's active cell again.
    this.afterTabChange();
  }

  protected get schemas(): readonly TreeSchema[] | null {
    this.generation();
    return this.state.schemas();
  }

  protected get schemasLoading(): boolean {
    this.generation();
    return this.state.schemasLoading();
  }

  protected get schemasTruncated(): boolean {
    this.generation();
    return this.state.schemasTruncated();
  }

  protected get schemasFault(): string {
    this.generation();
    return this.state.schemasFault();
  }

  protected get hasSchemasFault(): boolean {
    return this.schemasFault !== '';
  }

  protected get open(): TreeObject | null {
    this.generation();
    return this.state.open();
  }

  /** The strip's tabs, each named by its table and what it stages. */
  protected get tabList(): readonly TabRender[] {
    this.generation();
    return this.state.tabs().map((tab) => ({
      ...tab,
      name: tab.staged > 0 ? `${tab.label}, ${waitingText(tab.staged)}` : tab.label,
      dot: tab.staged > 0,
    }));
  }

  /** The selected tab's id alone, so each tab draws a grid of its own. */
  protected get shownTabs(): readonly string[] {
    this.generation();
    const tab = this.state.activeTab();
    return tab === null ? [] : [tab.id];
  }

  protected get heading(): string {
    const open = this.open;
    return open === null ? '' : `${open.schema}.${open.name}`;
  }

  protected get loading(): boolean {
    this.generation();
    return this.state.loading();
  }

  protected get refusal(): string {
    this.generation();
    return this.state.refusal();
  }

  protected get hasRefusal(): boolean {
    return this.refusal !== '';
  }

  private get answer(): BrowseAnswer | null {
    this.generation();
    return this.state.answer();
  }

  protected get columns(): readonly BrowseColumn[] {
    return this.answer?.columns ?? [];
  }

  /** The grid's rows: each new row, then the page's, with what is staged on them. */
  protected get rows(): readonly StagedRow[] {
    this.generation();
    return this.state.rows();
  }

  /** An answer is on screen for a view or a keyless table, whose rows do not change here. */
  protected get readOnly(): boolean {
    return this.answer !== null && !this.writable;
  }

  /** Whether the open table's rows may change here (Story 19.8). */
  protected get writable(): boolean {
    this.generation();
    return this.state.writable();
  }

  /** Whether a save is on its way: the grid keeps its Change column and opens no editor. */
  protected get savingNow(): boolean {
    this.generation();
    return this.state.saving();
  }

  /** Whether the grid offers its editors: a writable table, with no save on its way. */
  protected get editing(): boolean {
    this.generation();
    return this.state.writable() && !this.state.saving();
  }

  protected get editBlocked(): boolean {
    return !this.editing;
  }

  /** The grid row the selected tab's active cell is on, which Duplicate and Delete act on. */
  private get activeRowId(): string | null {
    this.generation();
    return this.state.activeCell()?.row ?? null;
  }

  /** No row to act on: none active, or editing is off. */
  protected get rowBlocked(): boolean {
    return !this.editing || this.activeRowId === null;
  }

  protected get deleteLabel(): string {
    const id = this.activeRowId;
    return id !== null && this.state.deleted(id) ? STRINGS.explorerSqlDataRestoreRow : STRINGS.explorerSqlDataDeleteRow;
  }

  protected get stagedCount(): number {
    this.generation();
    return this.state.stagedCount();
  }

  protected get saveLabel(): string {
    return fillPlaceholders(STRINGS.explorerSqlDataSaveChanges, { n: this.stagedCount });
  }

  protected get saveBlocked(): boolean {
    return !this.editing || this.stagedCount === 0;
  }

  protected get discardBlocked(): boolean {
    return this.state.saving() || this.stagedCount === 0;
  }

  /** No page to write: none answered, no row on it, or a read on its way. */
  protected get exportBlocked(): boolean {
    this.generation();
    return !this.state.canExport();
  }

  /** No range to go in: no rows answered, a total of 0, or a read on its way. */
  protected get goToRowBlocked(): boolean {
    this.generation();
    return !this.state.canGoToRow();
  }

  /** The save dialog, unless "Leave without saving?" stands: no dialog opens over another. */
  protected get confirmDialog(): boolean {
    return this.confirmOpen() && !this.leavePending;
  }

  /** The Keyboard shortcuts dialog, unless another stands. */
  protected get shortcutsDialog(): boolean {
    return this.shortcutsShown() && !this.leavePending && !this.confirmOpen();
  }

  /** The Go to row dialog, unless another stands. */
  protected get rowDialog(): boolean {
    return this.rowShown() && !this.leavePending && !this.confirmOpen() && !this.shortcutsShown();
  }

  protected get rowText(): string {
    return this.rowDraft();
  }

  protected get rowRefused(): boolean {
    return this.rowRefusedValue();
  }

  /** The Row number field's range line: 1 to the total, or to the furthest row the route reads. */
  protected get rowRangeText(): string {
    return fillPlaceholders(STRINGS.explorerSqlDataRowRange, { n: groupDigits(rowRangeMax(this.total, this.pageSize)) });
  }

  protected get saveTitle(): string {
    return fillPlaceholders(STRINGS.explorerSqlDataSaveTitle, { table: this.heading });
  }

  protected get saveConsequence(): string {
    this.generation();
    const counts = this.state.stagedCounts();
    return saveConsequenceText(counts, this.heading);
  }

  /** Whether "Leave without saving?" waits on an answer. */
  protected get leavePending(): boolean {
    this.generation();
    return this.formDirty.pending();
  }

  protected get pageOffset(): number {
    const answer = this.answer;
    return answer !== null && answer.outcome === 'rows' ? answer.offset : this.state.offset();
  }

  protected get total(): number | null {
    const answer = this.answer;
    return answer !== null && answer.outcome === 'rows' ? answer.total : null;
  }

  protected get sort(): SortState | null {
    this.generation();
    return this.state.sort();
  }

  protected get drafts(): Readonly<Record<string, string>> {
    this.generation();
    return this.state.drafts();
  }

  protected get noFilters(): boolean {
    this.generation();
    return Object.keys(this.state.filters()).length === 0 && Object.values(this.state.drafts()).every((value) => value === '');
  }

  protected get pageSize(): number {
    this.generation();
    return this.state.size();
  }

  protected get atStart(): boolean {
    return this.loading || this.pageOffset === 0;
  }

  /** No next page: none is known to exist, or it would start past the furthest offset the route takes. */
  protected get atEnd(): boolean {
    const answer = this.answer;
    return this.loading || answer === null || answer.outcome !== 'rows' || !answer.more || nextOffset(answer.offset, answer.rows.length) > MAX_OFFSET;
  }

  /** No Last: the total is unknown, the last page is on screen, or it starts past the furthest offset the route takes. */
  protected get lastBlocked(): boolean {
    const last = lastOffset(this.total, this.pageSize);
    return this.loading || last === null || last === this.pageOffset || last > MAX_OFFSET;
  }

  protected get pageText(): string {
    const draft = this.pageDraft();
    return draft !== null ? draft : String(pageOf(this.pageOffset, this.pageSize));
  }

  protected get hasPageCount(): boolean {
    return this.total !== null;
  }

  protected get pageCountText(): string {
    const count = pageCount(this.total, this.pageSize);
    return count === null ? '' : fillPlaceholders(STRINGS.explorerSqlDataOfPages, { n: count });
  }

  protected get pageProblem(): string {
    return this.pageProblemText();
  }

  protected get hasPageProblem(): boolean {
    return this.pageProblem !== '';
  }

  /** What describes the Page field: its range line while one shows, and "of N" while the total is known. */
  protected get pageDescribedBy(): string | null {
    const ids = [...(this.hasPageProblem ? ['ocu-data-page-problem'] : []), ...(this.hasPageCount ? ['ocu-data-page-count'] : [])];
    return ids.length === 0 ? null : ids.join(' ');
  }

  protected get statusLine(): string {
    this.generation();
    if (this.state.loading()) return '';
    const answer = this.state.answer();
    if (answer === null) return '';
    let line = '';
    if (answer.outcome === 'rows') {
      line = rowsLine(answer.offset, answer.rows.length, answer.total, Object.keys(this.state.filters()).length > 0);
    } else if (answer.outcome === 'stopped') {
      line = fillPlaceholders(STRINGS.explorerSqlStopped, { s: answer.seconds });
    } else if (answer.sqlcode !== null) {
      line = fillPlaceholders(STRINGS.explorerSqlCode, { code: answer.sqlcode });
    }
    const announcement = this.state.announcement();
    return announcement === '' ? line : `${announcement} ${line}`.trim();
  }

  /** What the status line says while no tab is open, such as why staged rows went. */
  protected get announcement(): string {
    this.generation();
    return this.state.announcement();
  }

  /** An SQL error's message, shown as text below its code. */
  protected get message(): string {
    const answer = this.answer;
    return answer !== null && answer.outcome === 'error' ? answer.message : '';
  }

  protected get hasMessage(): boolean {
    return this.message !== '';
  }

  protected onToggle(name: string): void {
    void this.state.toggle(this.deps, name);
  }

  /** Open `object` in a tab, or select its tab when it is open; nothing staged is dropped. */
  protected onOpen(object: TreeObject): void {
    void this.state.openObject(this.deps, object);
    this.afterTabChange();
  }

  protected answerLeave(leave: boolean): void {
    this.formDirty.answer(leave);
  }

  protected onSelectTab(id: string): void {
    if (this.state.selectTab(id)) this.afterTabChange();
  }

  /** A tab's close mark: close that tab without selecting it. */
  protected onTabCloseClick(event: Event, id: string): void {
    event.preventDefault();
    event.stopPropagation();
    void this.closeTab(id, 'strip');
  }

  protected onCloseTab(): void {
    const tab = this.state.activeTab();
    if (tab !== null) void this.closeTab(tab.id, 'button');
  }

  protected onEdited(edit: CellEdit): void {
    this.state.edit(this.deps, edit.row, edit.column, edit.value);
  }

  protected onAnnounced(text: string): void {
    this.state.announce(text);
  }

  protected onActiveCell(cell: ActiveCell): void {
    this.state.setActiveCell(cell);
  }

  protected onAddRow(): void {
    if (this.editBlocked) return;
    const id = this.state.addRow(this.deps);
    if (id !== null) this.grid()?.activate(id);
  }

  protected onDuplicateRow(): void {
    const id = this.activeRowId;
    if (this.rowBlocked || id === null) return;
    const copy = this.state.duplicate(this.deps, id);
    if (copy !== null) this.grid()?.activate(copy);
  }

  protected onDeleteRow(): void {
    const id = this.activeRowId;
    if (this.rowBlocked || id === null) return;
    this.state.toggleDelete(this.deps, id);
  }

  protected onSave(): void {
    if (this.saveBlocked) return;
    this.confirmOpen.set(true);
  }

  protected onProceed(): void {
    this.confirmOpen.set(false);
    void this.state.save(this.deps);
  }

  protected onCancelSave(): void {
    this.confirmOpen.set(false);
  }

  protected onDiscard(): void {
    if (this.discardBlocked) return;
    this.state.discard(this.deps);
  }

  /** Save the selected tab's page, as the instance read it, to a file built here, and say so. */
  protected onExport(): void {
    const file = this.state.exportPage(new Date());
    if (file === null) return;
    saveCsv(document, file.text, file.fileName);
    this.state.announce(fillPlaceholders(STRINGS.explorerSqlDataExported, { first: groupDigits(file.first), last: groupDigits(file.last), file: file.fileName }));
  }

  protected onOpenShortcuts(): void {
    this.shortcutsShown.set(true);
  }

  protected onCloseShortcuts(): void {
    this.shortcutsShown.set(false);
  }

  protected onOpenGoToRow(): void {
    if (this.goToRowBlocked) return;
    this.rowDraft.set('');
    this.rowRefusedValue.set(false);
    this.rowShown.set(true);
  }

  protected onCloseGoToRow(): void {
    this.rowShown.set(false);
  }

  protected onRowInput(event: Event): void {
    this.rowDraft.set((event.target as HTMLInputElement).value);
    this.rowRefusedValue.set(false);
  }

  /** Enter in the Row number field is Go. */
  protected onRowKeydown(event: KeyboardEvent): void {
    if (event.key !== 'Enter') return;
    event.preventDefault();
    void this.onGoToRow();
  }

  /**
   * Go: a number outside the range keeps the dialog open, `aria-invalid`, with focus on the field;
   * otherwise the page holding it is read, the dialog closes, and the active cell moves to that row in
   * the column it was in, with focus on the grid. An answer arriving after another tab was selected,
   * or after the page was left, changes nothing here.
   */
  protected async onGoToRow(): Promise<void> {
    if (this.rowBusy) return;
    this.rowBusy = true;
    const tab = this.state.activeTab();
    const column = this.state.activeCell()?.column ?? 0;
    const jump = await this.state.goToRowNumber(this.deps, this.rowDraft());
    this.rowBusy = false;
    if (this.destroyed || this.state.activeTab() !== tab) return;
    if (jump !== null && 'problem' in jump) {
      this.rowRefusedValue.set(true);
      this.host.querySelector<HTMLElement>('[data-ocu-data="row-number"]')?.focus();
      return;
    }
    if (!this.rowShown()) return;
    this.rowShown.set(false);
    this.resetPageField();
    if (jump === null) return;
    const id = `p${jump.index}`;
    afterNextRender(() => this.grid()?.activate(id, column), { injector: this.injector });
  }

  protected onRefresh(): void {
    if (this.loading) return;
    void this.state.refresh(this.deps);
  }

  protected onClearFilters(): void {
    if (this.noFilters) return;
    this.resetPageField();
    void this.state.clearFilters(this.deps);
  }

  protected onSort(column: string): void {
    this.resetPageField();
    void this.state.cycleSort(this.deps, column);
  }

  protected onDraft(change: { readonly column: string; readonly value: string }): void {
    this.state.setDraft(change.column, change.value);
  }

  protected onApply(column: string): void {
    this.resetPageField();
    void this.state.applyFilter(this.deps, column);
  }

  protected onClear(column: string): void {
    this.resetPageField();
    void this.state.clearFilter(this.deps, column);
  }

  protected onPaged(request: PageRequest): void {
    if (request === 'next') this.onNext();
    else this.onPrevious();
  }

  protected onFirst(): void {
    if (this.atStart) return;
    this.resetPageField();
    void this.state.firstPage(this.deps);
  }

  protected onPrevious(): void {
    if (this.atStart) return;
    this.resetPageField();
    void this.state.previousPage(this.deps);
  }

  protected onNext(): void {
    if (this.atEnd) return;
    this.resetPageField();
    void this.state.nextPage(this.deps);
  }

  protected onLast(): void {
    if (this.lastBlocked) return;
    this.resetPageField();
    void this.state.lastPage(this.deps);
  }

  protected onPageInput(event: Event): void {
    this.pageDraft.set((event.target as HTMLInputElement).value);
  }

  /** Enter in the Page field goes to that page, or says the range it must fall in: to N, or to the furthest page the route takes while the total is unknown. */
  protected onPageKeydown(event: KeyboardEvent): void {
    if (event.key !== 'Enter') return;
    event.preventDefault();
    const offset = goToPageOffset(this.pageText, this.pageSize, this.total);
    if (offset === null) {
      this.pageProblemText.set(pageRangeLine(pageCount(this.total, this.pageSize) ?? pageOf(MAX_OFFSET, this.pageSize)));
      return;
    }
    this.resetPageField();
    void this.state.goTo(this.deps, offset);
  }

  protected onSize(event: Event): void {
    const size = Number((event.target as HTMLSelectElement).value);
    this.resetPageField();
    void this.state.setSize(this.deps, size);
  }

  /**
   * The shortcuts' one key handler: inert while a dialog is in the document; with an editor open only
   * Save is read; otherwise the chord is read where focus is. A chord the table names is kept from the
   * browser and from the grid, and does what its control does.
   */
  private onShortcutKeydown(event: KeyboardEvent): void {
    if (document.querySelector('[role="dialog"]') !== null) return;
    const place: ShortcutPlace = this.grid()?.editorOpen() === true ? 'editor' : shortcutPlace(event.target);
    const action = shortcutFor(event, place);
    if (action === null) return;
    event.preventDefault();
    event.stopPropagation();
    this.runShortcut(action, event, place);
  }

  /** Do what `action`'s control does, when that control is available. */
  private runShortcut(action: ShortcutAction, event: KeyboardEvent, place: ShortcutPlace): void {
    switch (action) {
      case 'help':
        this.onOpenShortcuts();
        return;
      case 'save':
        if (place === 'editor' && !(this.grid()?.commitInPlace() ?? true)) return;
        this.onSave();
        return;
      case 'goToRow':
        this.onOpenGoToRow();
        return;
      case 'export':
        this.onExport();
        return;
      case 'addRow':
        this.onAddRow();
        return;
      case 'duplicateRow':
        this.onDuplicateRow();
        return;
      case 'deleteRow':
        this.onDeleteRow();
        return;
      case 'page':
        if (shortcutStep(event) > 0) this.onNext();
        else this.onPrevious();
        return;
      case 'tab': {
        // The old tab's grid leaves with the switch, so focus it held moves to the new tab's grid.
        const fromGrid = event.target instanceof Element && event.target.closest('app-data-browser-grid') !== null;
        if (this.state.nextTab(shortcutStep(event))) this.afterTabChange(fromGrid);
        return;
      }
      case 'closeTab': {
        const id = event.key === 'Delete' ? tabIdOf(event.target) : (this.state.activeTab()?.id ?? null);
        if (id !== null) void this.closeTab(id, this.focusInStrip() ? 'strip' : 'other');
        return;
      }
    }
  }

  /**
   * Close tab `id`, asking "Leave without saving?" first when it stages rows; a declined answer keeps
   * the tab and its rows. Focus then goes where `origin` says.
   */
  private async closeTab(id: string, origin: CloseOrigin): Promise<void> {
    const tab = this.state.tabs().find((entry) => entry.id === id);
    if (tab === undefined) return;
    if (tab.staged > 0 && !(await this.formDirty.requestLeave())) return;
    this.state.closeTab(this.deps, id);
    if (tab.active) this.afterTabChange();
    afterNextRender(() => this.focusAfterClose(origin), { injector: this.injector });
  }

  /**
   * Focus after a close: the tree when no tab is left; Close tab when the close came from it; the
   * selected tab when it came from the strip, or when focus was on something the close removed.
   */
  private focusAfterClose(origin: CloseOrigin): void {
    if (this.state.tabs().length === 0) {
      this.host.querySelector<HTMLElement>('[data-ocu-data="tree"]')?.focus();
      return;
    }
    if (origin === 'button') {
      this.host.querySelector<HTMLElement>('[data-ocu-data="close-tab"]')?.focus();
      return;
    }
    const now = document.activeElement;
    if (origin === 'strip' || now === null || now === document.body || !now.isConnected) this.focusSelectedTab();
  }

  private focusSelectedTab(): void {
    const id = this.state.activeTab()?.id;
    if (id !== undefined) this.host.querySelector<HTMLElement>(`.ocu-data-browser-tab[data-tab="${id}"]`)?.focus();
  }

  private focusInStrip(): boolean {
    const strip = this.host.querySelector('.ocu-data-browser-tabs');
    return strip !== null && strip.contains(document.activeElement);
  }

  /**
   * After another tab is selected, or the page opens again: the Page field starts over and the
   * selected tab's own active cell is drawn again in its grid, or let go when its row is no longer
   * drawn, so the row actions never act on a row the grid does not show active; with `focusGrid`,
   * focus moves to that grid.
   */
  private afterTabChange(focusGrid = false): void {
    this.resetPageField();
    afterNextRender(
      () => {
        const cell = this.state.activeCell();
        if (cell !== null && this.grid()?.place(cell.row, cell.column) === false) this.state.setActiveCell({ row: null, column: cell.column });
        if (focusGrid) this.host.querySelector<HTMLElement>('[data-ocu-data="grid"]')?.focus();
      },
      { injector: this.injector }
    );
  }

  private resetPageField(): void {
    this.pageDraft.set(null);
    this.pageProblemText.set('');
  }

  private bump(): void {
    this.generation.update((value) => value + 1);
  }
}
