import { LocationStrategy } from '@angular/common';
import { ChangeDetectionStrategy, Component, DestroyRef, inject, signal } from '@angular/core';
import { NavigationEnd, Router } from '@angular/router';

import { ApiService } from '../../core/api';
import { NavigationService, parentCriteria, screenForRoute, withQuery } from '../../core/navigation';
import { RefreshService } from '../../core/refresh';
import { ScopeService } from '../../core/scope';
import { REFRESH_ACTION_ID, ScreenActions } from '../../core/screen-actions';
import { ScreenArrivals } from '../../core/screen-arrival';
import { createScreenRead, textOf } from '../../core/screen-read';
import { ScreenStores, type ScreenStore } from '../../core/screen-store';
import type { ScreenDeclaration } from '../../core/screens.generated';
import { fieldOf } from '../../core/table-model';
import { STRINGS, stringFor } from '../../core/strings';
import { JOURNAL_DATABASES_MAX_ROWS, JOURNAL_DATABASES_ROUTE, isUnlisted, rowCells, type CellText } from './journal-file-details.store';

/** Journal records' route, which View records opens (Story 18.19). */
export const JOURNAL_RECORDS_ROUTE = 'os-management/journal-records';

/** A screen this page renders, and the store its rows land in. */
interface DetailsView {
  readonly screen: ScreenDeclaration;
  readonly store: ScreenStore;
}

/** One rendered summary field: its label and its value. */
interface FieldView {
  readonly field: string;
  readonly label: string;
  readonly value: string;
}

/** One rendered database row. */
interface DatabaseRowView {
  readonly key: string;
  readonly cells: readonly CellText[];
}

/**
 * Journal file details (Story 18.5, AD-5): one journal file's summary, read through the vendor's
 * `Journal.File` `GET` on the route's one criterion, `file` (`parentCriteria`), and below it the
 * databases that file holds records for.
 *
 * **The databases are another built screen's declared read** (the `database-details.page.ts`
 * model): this page resolves `JournalFileDatabaseList` by its route and issues its read with the
 * same `file` criterion, once on open, on a different file and on Refresh, into that screen's own
 * store, and draws its declared columns through the shared `cellView` rule.
 *
 * **States.** Skeleton fields on first load; a refused read shows the refusal with Retry; a file the
 * instance no longer lists -- refused `JOURNAL.FILE.UNLISTED`, or answering no row -- shows "This
 * journal file is no longer listed." in place of the fields.
 *
 * **View records** (Story 18.19) opens Journal records on this file: a page-local link that hands
 * the file over as a screen arrival (`ScreenArrivals`) and navigates; a modified click is left to the
 * browser, whose new page reads the newest file. The page carries no other action.
 *
 * Every control-flow condition is a paren-free member reference, for the reason `sign-in.ts`
 * records.
 */
@Component({
  selector: 'app-journal-file-details-page',
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `<section class="ocu-details-page" [attr.aria-busy]="busy">
    @if (showRefusal) {
      <div class="ocu-data-table-refusal" role="alert">
        <span class="ocu-data-table-refusal-message">{{ STRINGS.connectivityRequestRefused }}</span>
        <button type="button" class="ocu-button-text" (click)="onRetry()">{{ STRINGS.actionRetry }}</button>
      </div>
    }
    @if (showSkeleton) {
      <div class="ocu-data-table-skeleton" aria-hidden="true">
        @for (bar of skeletonRows; track bar) {
          <div class="ocu-data-table-skeleton-row">
            <span class="ocu-skeleton-bar ocu-skeleton-bar-40"></span>
            <span class="ocu-skeleton-bar ocu-skeleton-bar-15"></span>
          </div>
        }
      </div>
    }
    @if (showGone) {
      <section class="ocu-empty-state" tabindex="-1">
        <p class="ocu-data-table-empty-title" data-journal="gone">{{ STRINGS.journalFileDetailsGone }}</p>
      </section>
    }
    @if (showFields) {
      <section class="ocu-details-group">
        <h2 class="ocu-details-heading">{{ STRINGS.processDetailsGroupGeneral }}</h2>
        <div class="ocu-details-fields" data-journal="summary">
          @for (field of fieldViews; track field.field) {
            <div class="ocu-details-field" [attr.data-field]="field.field">
              <span class="ocu-details-field-label">{{ field.label }}</span>
              <span class="ocu-details-field-value">{{ field.value }}</span>
            </div>
          }
        </div>
        <nav class="ocu-details-links">
          <a class="ocu-details-link" data-journal="view-records" [href]="recordsHref" (click)="onViewRecords($event)">{{
            STRINGS.journalFileDetailsViewRecords
          }}</a>
        </nav>
      </section>
      <section class="ocu-details-group" data-journal="databases">
        <h2 class="ocu-details-heading">{{ STRINGS.databaseListLabel }}</h2>
        @if (databasesFault) {
          <div class="ocu-data-table-refusal" role="alert">
            <span class="ocu-data-table-refusal-message">{{ STRINGS.connectivityRequestRefused }}</span>
            <button type="button" class="ocu-button-text" (click)="onRetryDatabases()">{{ STRINGS.actionRetry }}</button>
          </div>
        }
        @if (hasDatabaseRows) {
          <table class="ocu-details-volumes-table" role="table">
            <thead>
              <tr role="row">
                @for (column of databaseColumns; track column.field) {
                  <th role="columnheader" scope="col">{{ column.label }}</th>
                }
              </tr>
            </thead>
            <tbody>
              @for (row of databaseRows; track row.key) {
                <tr role="row">
                  @for (cell of row.cells; track cell.field) {
                    <td role="cell">{{ cell.text }}</td>
                  }
                </tr>
              }
            </tbody>
          </table>
        }
        @if (showDatabasesEmpty) {
          <p class="ocu-data-table-empty-title">{{ STRINGS.journalFileDatabaseListEmpty }}</p>
        }
      </section>
    }
  </section>`,
})
export class JournalFileDetailsPage {
  private readonly navigation = inject(NavigationService);
  private readonly router = inject(Router);
  private readonly stores = inject(ScreenStores);
  private readonly refresh = inject(RefreshService);
  private readonly api = inject(ApiService);
  private readonly scope = inject(ScopeService);
  private readonly actions = inject(ScreenActions);
  private readonly locationStrategy = inject(LocationStrategy);

  /** Journal records' hand-off (Story 18.19). Optional, so a spec that needs none provides none. */
  private readonly arrivals = inject(ScreenArrivals, { optional: true });

  protected readonly STRINGS = STRINGS;

  protected readonly skeletonRows = [0, 1, 2];

  private readonly view: DetailsView | null;

  private readonly databases: DetailsView | null;

  /** Bumped by the store and the refresh service, so the fields re-render under `OnPush`. */
  private readonly generation = signal(0);

  /** Whether the databases read has completed, so an empty table draws its empty state. */
  private readonly databasesLoaded = signal(false);

  /** Whether the databases read was refused, so the section says so rather than claiming none. */
  private readonly databasesFaultSignal = signal(false);

  constructor() {
    const screen = this.navigation.screenForUrl(this.router.url);
    const databasesScreen = screenForRoute(JOURNAL_DATABASES_ROUTE);
    if (screen === null || screen.read === null || screen.table === null) {
      this.view = null;
      this.databases = null;
      return;
    }
    const store = this.stores.for(screen.descriptor, screen.refreshRates);
    this.view = { screen, store };
    store.clearAnswers();
    this.databases =
      databasesScreen === null || databasesScreen.read === null
        ? null
        : { screen: databasesScreen, store: this.stores.for(databasesScreen.descriptor, databasesScreen.refreshRates) };
    // The databases store outlives the page: what it holds may be the file an earlier page showed.
    this.databases?.store.clearAnswers();

    const criteria = () => parentCriteria(screen, this.router.url);
    this.refresh.bind(screen, createScreenRead(this.api, screen, criteria));
    if (this.scope.loaded()) {
      void this.refresh.readNow();
      void this.loadDatabases(criteria());
    }

    let readFor = JSON.stringify(criteria());
    const stopIdChange = this.router.events.subscribe((event) => {
      if (!(event instanceof NavigationEnd)) return;
      if (this.navigation.screenForUrl(this.router.url)?.descriptor !== screen.descriptor) return;
      const next = criteria();
      if (JSON.stringify(next) === readFor) return;
      readFor = JSON.stringify(next);
      // A different file: the databases belong to the file this page has left.
      this.databases?.store.clearAnswers();
      this.databasesLoaded.set(false);
      this.databasesFaultSignal.set(false);
      if (this.scope.loaded()) {
        this.refresh.noteScopeChanged();
        void this.loadDatabases(next);
      }
    });

    const stopRefreshAction = this.actions.register(screen.descriptor, REFRESH_ACTION_ID, () => {
      void this.refresh.readNow();
      void this.loadDatabases(criteria());
    });

    const stopStore = store.subscribe(() => this.generation.update((value) => value + 1));
    const stopRefresh = this.refresh.subscribe(() => this.generation.update((value) => value + 1));

    inject(DestroyRef).onDestroy(() => {
      stopIdChange.unsubscribe();
      stopStore();
      stopRefresh();
      stopRefreshAction();
      if (this.refresh.descriptor() === screen.descriptor) this.refresh.unbind();
    });
  }

  /**
   * The databases section's one-shot read: `JournalFileDatabaseList`'s declared read narrowed by the
   * same `file` criterion, applied into that screen's own store.
   */
  private async loadDatabases(criteria: Readonly<Record<string, string>>): Promise<void> {
    const databases = this.databases;
    if (databases === null) return;
    const read = createScreenRead(this.api, databases.screen, () => criteria);
    const result = await read({ maxRows: JOURNAL_DATABASES_MAX_ROWS });
    if (result.kind !== 'ok') {
      this.databasesFaultSignal.set(true);
    } else {
      this.databasesFaultSignal.set(false);
      databases.store.applyTick(result.rows, result.truncated, result.banner ?? '', new Date());
    }
    this.databasesLoaded.set(true);
    this.generation.update((value) => value + 1);
  }

  private get boundHere(): boolean {
    this.generation();
    return this.view !== null && this.refresh.descriptor() === this.view.screen.descriptor;
  }

  private get loaded(): boolean {
    return this.boundHere && this.refresh.hasLoaded();
  }

  private get row(): unknown {
    this.generation();
    return this.view?.store.data()[0];
  }

  /** The instance refused the file as no longer listed (AD-21's eighth case). */
  private get unlisted(): boolean {
    this.generation();
    return this.boundHere && isUnlisted(this.refresh.fault());
  }

  protected get busy(): boolean {
    return !this.loaded && !this.unlisted;
  }

  protected get showRefusal(): boolean {
    this.generation();
    return this.boundHere && this.refresh.fault() !== null && !this.unlisted;
  }

  protected get showSkeleton(): boolean {
    return !this.loaded && !this.showRefusal && !this.unlisted;
  }

  protected get showGone(): boolean {
    return this.unlisted || (this.loaded && !this.showRefusal && this.row === undefined);
  }

  protected get showFields(): boolean {
    return this.loaded && !this.unlisted && this.row !== undefined;
  }

  /** Every declared column of the summary, in declared order. */
  protected get fieldViews(): readonly FieldView[] {
    this.generation();
    const view = this.view;
    const row = this.row;
    if (view === null || row === undefined) return [];
    const columns = view.screen.table?.columns ?? [];
    return rowCells(columns, row).map((cell, index) => ({ field: cell.field, label: stringFor(columns[index].labelKey), value: cell.text }));
  }

  protected onRetry(): void {
    void this.refresh.readNow();
    const view = this.view;
    if (view !== null) void this.loadDatabases(parentCriteria(view.screen, this.router.url));
  }

  protected get databasesFault(): boolean {
    this.generation();
    return this.databasesFaultSignal();
  }

  /** The databases section's declared columns, labelled through the one string source. */
  protected get databaseColumns(): readonly { readonly field: string; readonly label: string }[] {
    return this.databases?.screen.table?.columns.map((column) => ({ field: column.field, label: stringFor(column.labelKey) })) ?? [];
  }

  /** The databases section's rows, rendered through the shared `cellView` rule. */
  protected get databaseRows(): readonly DatabaseRowView[] {
    this.generation();
    const databases = this.databases;
    if (databases === null || this.databasesFaultSignal()) return [];
    const columns = databases.screen.table?.columns ?? [];
    return databases.store.data().map((row, index) => ({ key: String(index), cells: rowCells(columns, row) }));
  }

  protected get hasDatabaseRows(): boolean {
    return this.databaseRows.length > 0;
  }

  protected get showDatabasesEmpty(): boolean {
    this.generation();
    return this.databasesLoaded() && !this.databasesFaultSignal() && !this.hasDatabaseRows;
  }

  /** Journal records' address in this namespace. */
  protected get recordsHref(): string {
    return this.locationStrategy.prepareExternalUrl(withQuery(JOURNAL_RECORDS_ROUTE, this.router.url));
  }

  /**
   * View records: hand Journal records this file as an arrival and open it. A modified click is left
   * to the browser.
   */
  protected onViewRecords(event: MouseEvent): void {
    if (event.ctrlKey || event.metaKey || event.shiftKey || event.button !== 0) return;
    event.preventDefault();
    const file = textOf(fieldOf(this.row, 'Name'));
    this.arrivals?.set({ route: JOURNAL_RECORDS_ROUTE, criterion: '', criteria: { file } });
    void this.router.navigateByUrl(withQuery(JOURNAL_RECORDS_ROUTE, this.router.url));
  }

  protected onRetryDatabases(): void {
    const view = this.view;
    if (view !== null) void this.loadDatabases(parentCriteria(view.screen, this.router.url));
  }
}
