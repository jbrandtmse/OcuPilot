import { ChangeDetectionStrategy, Component, DestroyRef, inject, signal, viewChild } from '@angular/core';
import { Router } from '@angular/router';

import { ApiService } from '../../core/api';
import { FormDirty } from '../../core/form-dirty';
import {
  MAX_OFFSET,
  PAGE_SIZES,
  goToPageOffset,
  lastOffset,
  nextOffset,
  pageCount,
  pageOf,
  pageRangeLine,
  rowsLine,
  type SortState,
} from '../../core/data-browser-model';
import { NavigationService, screenForDescriptor } from '../../core/navigation';
import { ScopeService, onScopeChange } from '../../core/scope';
import { ScreenStores, type ScreenStore } from '../../core/screen-store';
import type { ScreenDeclaration } from '../../core/screens.generated';
import { STRINGS } from '../../core/strings';
import { Dialog } from '../../shell/dialog';
import { ScreenActionHandler } from '../../shell/screen-action-handler';
import { WarningDialog } from '../../shell/warning-dialog';
import { fillPlaceholders } from './code-list.store';
import { DataBrowserGrid, type CellEdit, type PageRequest } from './data-browser-grid';
import { DataBrowserTree } from './data-browser-tree';
import {
  DataBrowserState,
  type BrowseAnswer,
  type BrowseColumn,
  type DataBrowserDeps,
  type StagedRow,
  type TreeObject,
  type TreeSchema,
} from './data-browser.store';

/** The three screens whose declared reads fill the tree (AD-5). */
export const TREE_DESCRIPTORS = {
  schemas: 'OcuPilot.Screen.Descriptor.ExplorerSqlSchemas',
  tables: 'OcuPilot.Screen.Descriptor.ExplorerSqlTables',
  views: 'OcuPilot.Screen.Descriptor.ExplorerSqlViews',
} as const;

/** One `DataBrowserState` per screen store, so a return to the screen finds the open table and its page. */
const HELD = new WeakMap<ScreenStore, DataBrowserState>();

function heldFor(store: ScreenStore | null): DataBrowserState {
  const known = store === null ? undefined : HELD.get(store);
  if (known !== undefined) return known;
  const state = new DataBrowserState();
  if (store !== null) HELD.set(store, state);
  return state;
}

/**
 * System Explorer's Data browser (Story 19.7): the schema tree beside the open table's or view's
 * grid, stacked when the column is narrow, with the empty state until a table opens.
 *
 * Above the grid: the open object's name as a heading, Refresh, Clear filters and the filter hint.
 * Below it: First, Previous, a Page field "of N", Next and Last -- Last drawn disabled while the
 * total is unknown -- and Rows per page; then the polite status line, an SQL error's message as text,
 * and a refusal as an alert banner. A control that cannot act is drawn `aria-disabled` and answers
 * nothing.
 *
 * **Editing** (Story 19.8). On a table whose key this account can list, the head adds Add row,
 * Duplicate row, Delete row (Restore row on a deleted row), Save changes (<n>) and Discard changes,
 * acting on the grid's active row; a view or a keyless table reads the read-only line instead. Save
 * opens the warning dialog naming the table and how many rows change, are added and are deleted;
 * Proceed sends the save, Cancel nothing. Opening another table over staged rows, like leaving the
 * route, asks "Leave without saving?" through `FormDirty`; a namespace switch discards them.
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
  imports: [DataBrowserTree, DataBrowserGrid, WarningDialog, Dialog],
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
          <div class="ocu-data-browser-head">
            <h2 class="ocu-data-browser-heading" data-ocu-data="heading">{{ heading }}</h2>
            <div class="ocu-data-browser-actions">
              <button type="button" class="ocu-button-text" data-ocu-data="refresh" [attr.aria-disabled]="loading" (click)="onRefresh()">{{ STRINGS.actionRefresh }}</button>
              <button type="button" class="ocu-button-text" data-ocu-data="clear-filters" [attr.aria-disabled]="noFilters" (click)="onClearFilters()">{{ STRINGS.explorerSqlDataClearFilters }}</button>
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
            (activeRow)="onActiveRow($event)"
          />
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
        } @else {
          <p class="ocu-explorer-status" role="status" data-ocu-data="status">{{ announcement }}</p>
          <div class="ocu-data-browser-empty" data-ocu-data="empty">
            <p class="ocu-data-browser-empty-text">{{ STRINGS.explorerSqlDataPick }}</p>
          </div>
        }
      </div>
    </div>
    @if (confirming) {
      <app-warning-dialog [verb]="saveTitle" [consequence]="saveConsequence" (confirmed)="onProceed()" (cancelled)="onCancelSave()" />
    }
    @if (leavePending) {
      <app-dialog [heading]="STRINGS.formLeaveWithoutSaving" [closeLabel]="STRINGS.actionCancel" (closed)="answerLeave(false)">
        <button dialogAction type="button" class="ocu-button-primary" data-ocu-data="leave" (click)="answerLeave(true)">
          {{ STRINGS.actionConfirm }}
        </button>
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

  protected readonly STRINGS = STRINGS;

  protected readonly sizes = PAGE_SIZES;

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

  /** The grid row the active cell is on, which Duplicate and Delete act on. */
  private readonly activeRowId = signal<string | null>(null);

  /** Whether the save dialog is open. */
  private readonly confirmOpen = signal(false);

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
    // the old namespace's tree, open table and page leave now.
    const stopScope = onScopeChange(this.scope, () => {
      this.resetPageField();
      void this.state.scopeTo(this.deps, this.scope.namespace());
    });
    if (this.scope.loaded()) void this.state.scopeTo(this.deps, this.scope.namespace());
    // Leaving the route asked first (the form-page guard), so what is staged goes with the page.
    inject(DestroyRef).onDestroy(() => {
      stop();
      stopDirty();
      stopScope();
      if (this.state.stagedCount() > 0) this.state.discard(this.deps);
      this.formDirty.setDirty(false);
    });
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

  /** No row to act on: none active, or editing is off. */
  protected get rowBlocked(): boolean {
    return !this.editing || this.activeRowId() === null;
  }

  protected get deleteLabel(): string {
    this.generation();
    const id = this.activeRowId();
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

  protected get confirming(): boolean {
    return this.confirmOpen();
  }

  protected get saveTitle(): string {
    return fillPlaceholders(STRINGS.explorerSqlDataSaveTitle, { table: this.heading });
  }

  protected get saveConsequence(): string {
    this.generation();
    const counts = this.state.stagedCounts();
    return fillPlaceholders(STRINGS.explorerSqlDataSaveConsequence, { u: counts.update, i: counts.insert, d: counts.delete, table: this.heading });
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

  /** What the status line says while no object is open, such as why staged rows went. */
  protected get announcement(): string {
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

  /** Open `object`, asking first when rows are staged; a declined answer keeps the open table. */
  protected async onOpen(object: TreeObject): Promise<void> {
    if (this.state.stagedCount() > 0 && !(await this.formDirty.requestLeave())) return;
    this.resetPageField();
    this.activeRowId.set(null);
    void this.state.openObject(this.deps, object);
  }

  protected answerLeave(leave: boolean): void {
    this.formDirty.answer(leave);
  }

  protected onEdited(edit: CellEdit): void {
    this.state.edit(this.deps, edit.row, edit.column, edit.value);
  }

  protected onAnnounced(text: string): void {
    this.state.announce(text);
  }

  protected onActiveRow(id: string | null): void {
    this.activeRowId.set(id);
  }

  protected onAddRow(): void {
    if (this.editBlocked) return;
    const id = this.state.addRow(this.deps);
    if (id !== null) this.grid()?.activate(id);
  }

  protected onDuplicateRow(): void {
    const id = this.activeRowId();
    if (this.rowBlocked || id === null) return;
    const copy = this.state.duplicate(this.deps, id);
    if (copy !== null) this.grid()?.activate(copy);
  }

  protected onDeleteRow(): void {
    const id = this.activeRowId();
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

  private resetPageField(): void {
    this.pageDraft.set(null);
    this.pageProblemText.set('');
  }

  private bump(): void {
    this.generation.update((value) => value + 1);
  }
}
