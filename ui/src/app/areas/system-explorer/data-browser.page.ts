import { ChangeDetectionStrategy, Component, DestroyRef, inject, signal } from '@angular/core';
import { Router } from '@angular/router';

import { ApiService } from '../../core/api';
import {
  PAGE_SIZES,
  goToPageOffset,
  lastOffset,
  pageCount,
  pageOf,
  pageRangeLine,
  rowsLine,
  type SortState,
} from '../../core/data-browser-model';
import { NavigationService, screenForDescriptor } from '../../core/navigation';
import { ScopeService } from '../../core/scope';
import { ScreenStores, type ScreenStore } from '../../core/screen-store';
import type { ScreenDeclaration } from '../../core/screens.generated';
import { STRINGS } from '../../core/strings';
import { fillPlaceholders } from './code-list.store';
import { DataBrowserGrid, type PageRequest } from './data-browser-grid';
import { DataBrowserTree } from './data-browser-tree';
import { DataBrowserState, type BrowseAnswer, type BrowseColumn, type DataBrowserDeps, type TreeObject, type TreeSchema } from './data-browser.store';

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
 * **Everything shown is text** (AD-11), and the page lives in `DataBrowserState`, never in the
 * screen's store, so it never reaches screen context (AD-36, AD-39's sixth exception).
 *
 * Every control-flow condition is a paren-free member reference, for the reason `sign-in.ts`
 * records.
 */
@Component({
  selector: 'app-data-browser-page',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [DataBrowserTree, DataBrowserGrid],
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
          <p class="ocu-data-browser-hint" data-ocu-data="hint">{{ STRINGS.explorerSqlDataFilterHint }}</p>
          <app-data-browser-grid
            [label]="heading"
            [columns]="columns"
            [rows]="rows"
            [offset]="pageOffset"
            [total]="total"
            [sort]="sort"
            [drafts]="drafts"
            (sorted)="onSort($event)"
            (drafted)="onDraft($event)"
            (applied)="onApply($event)"
            (cleared)="onClear($event)"
            (paged)="onPaged($event)"
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
              [attr.aria-describedby]="hasPageProblem ? 'ocu-data-page-problem' : null"
              (input)="onPageInput($event)"
              (keydown)="onPageKeydown($event)"
            />
            @if (hasPageCount) {
              <span class="ocu-data-browser-page-count" data-ocu-data="page-count">{{ pageCountText }}</span>
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
          <div class="ocu-data-browser-empty" data-ocu-data="empty">
            <p class="ocu-data-browser-empty-text">{{ STRINGS.explorerSqlDataPick }}</p>
          </div>
        }
      </div>
    </div>
  </section>`,
})
export class DataBrowserPage {
  private readonly navigation = inject(NavigationService);
  private readonly router = inject(Router);
  private readonly stores = inject(ScreenStores);
  private readonly scope = inject(ScopeService);

  protected readonly STRINGS = STRINGS;

  protected readonly sizes = PAGE_SIZES;

  protected readonly screen: ScreenDeclaration | null;

  private readonly state: DataBrowserState;

  private readonly deps: DataBrowserDeps;

  /** Bumped by the state, so the page re-renders under `OnPush`. */
  private readonly generation = signal(0);

  /** What the Page field holds while it is being typed, or `null` to show the current page. */
  private readonly pageDraft = signal<string | null>(null);

  /** The Page field's range line after a page outside it, or `''`. */
  private readonly pageProblemText = signal('');

  constructor() {
    this.screen = this.navigation.screenForUrl(this.router.url);
    this.state = heldFor(this.screen === null ? null : this.stores.for(this.screen.descriptor, this.screen.refreshRates));
    this.deps = {
      api: inject(ApiService),
      scope: () => this.scope.namespace(),
      schemas: screenForDescriptor(TREE_DESCRIPTORS.schemas),
      tables: screenForDescriptor(TREE_DESCRIPTORS.tables),
      views: screenForDescriptor(TREE_DESCRIPTORS.views),
    };
    const stop = this.state.subscribe(() => this.bump());
    void this.state.loadSchemas(this.deps);
    inject(DestroyRef).onDestroy(() => stop());
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

  protected get rows(): readonly (readonly (string | null)[])[] {
    const answer = this.answer;
    return answer !== null && answer.outcome === 'rows' ? answer.rows : [];
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

  protected get atEnd(): boolean {
    const answer = this.answer;
    return this.loading || answer === null || answer.outcome !== 'rows' || !answer.more;
  }

  protected get lastBlocked(): boolean {
    const last = lastOffset(this.total, this.pageSize);
    return this.loading || last === null || last === this.pageOffset;
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

  protected onOpen(object: TreeObject): void {
    this.resetPageField();
    void this.state.openObject(this.deps, object);
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

  /** Enter in the Page field goes to that page, or says the range it must fall in. */
  protected onPageKeydown(event: KeyboardEvent): void {
    if (event.key !== 'Enter') return;
    event.preventDefault();
    const offset = goToPageOffset(this.pageText, this.pageSize, this.total);
    if (offset === null) {
      this.pageProblemText.set(pageRangeLine(pageCount(this.total, this.pageSize)));
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
