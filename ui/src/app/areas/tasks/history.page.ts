import { ChangeDetectionStrategy, Component, DestroyRef, afterNextRender, inject, signal } from '@angular/core';
import { ActivatedRoute, Router } from '@angular/router';

import { ApiService } from '../../core/api';
import { decodeEntityId } from '../../core/entity-id';
import { NavigationService, withQuery } from '../../core/navigation';
import { RefreshService } from '../../core/refresh';
import { REFRESH_ACTION_ID, ScreenActions } from '../../core/screen-actions';
import { createScreenRead, textOf } from '../../core/screen-read';
import { ScreenStores, type ScreenStore } from '../../core/screen-store';
import { fieldOf, rowKey } from '../../core/table-model';
import type { ScreenDeclaration } from '../../core/screens.generated';
import { STRINGS, stringFor } from '../../core/strings';
import { COMMAND_BAR_FILTER_ID } from '../../shell/command-bar';
import { DataTable } from '../../shell/data-table';
import { Dialog } from '../../shell/dialog';
import { TaskHistorySearch } from './history.store';

/** The screen this page renders and the store its table reads. */
interface HistoryView {
  readonly screen: ScreenDeclaration;
  readonly store: ScreenStore;
}

/** One row of the detail dialog: a read field's own label and the row's value for it. */
interface DetailFieldView {
  readonly field: string;
  readonly label: string;
  readonly value: string;
}

/**
 * The label every read field of a task-run history row is shown under in the detail dialog
 * (AC3). `TaskHistoryList` declares thirteen fields; six are table columns and reuse that column's
 * own `labelKey`; `Routine`, `Pid` and `ErrNumber` reuse `processColumnRoutine`,
 * `processColumnPid` and `errorLogColumnNumber` -- the same "Error number" the application error
 * log already carries -- rather than repeating their text (`strings.ts`); and `TaskId`,
 * `ErrDate` and `LogDatetime` are new keys the story adds.
 */
const FIELD_LABEL_KEYS: Readonly<Record<string, string>> = {
  LastStart: 'taskHistoryColumnStarted',
  Completed: 'taskHistoryColumnCompleted',
  Name: 'tableColumnName',
  Status: 'taskHistoryColumnStatus',
  Result: 'taskHistoryColumnResult',
  TaskId: 'taskHistoryColumnTaskId',
  Namespace: 'headerNamespaceLabel',
  Routine: 'processColumnRoutine',
  Pid: 'processColumnPid',
  ErrDate: 'taskHistoryColumnErrDate',
  ErrNumber: 'errorLogColumnNumber',
  Username: 'processColumnUser',
  LogDatetime: 'taskHistoryColumnLogged',
};

/**
 * One `TaskHistorySearch` per screen store, dropped with it at sign-out -- the same
 * `WeakMap`-per-store pattern `upcoming.page.ts`'s `HELD_HORIZONS` uses, and for a second reason
 * here: the store also caches the one `RefreshRead` the page binds, which must survive the id
 * route's destroy-and-recreate cycle by reference for `RefreshService.bind` to treat it as a
 * no-op (see `history.store.ts`).
 */
const HELD_SEARCHES = new WeakMap<ScreenStore, TaskHistorySearch>();

/** The search held for `store`, created on first ask. */
function heldFor(store: ScreenStore | null): TaskHistorySearch {
  const known = store === null ? undefined : HELD_SEARCHES.get(store);
  if (known !== undefined) return known;
  const search = new TaskHistorySearch();
  if (store !== null) HELD_SEARCHES.set(store, search);
  return search;
}

/**
 * Task history, across every task (Story 6.6): a search field and a user-defined-only checkbox
 * above the table, the table itself once Search has run, and the row detail dialog the `/:id`
 * route opens -- the same shape `AuditPage` gives `list (server criteria)`, registered for this
 * one descriptor because `ARCHETYPE_PAGES` can hand that archetype only one page
 * (`screen-outlet.ts`).
 *
 * **It renders nothing until Search is pressed** (Boundaries), for the reason `AuditPage` gives:
 * the API searches on the server, so a read on navigation would be an unbounded search nobody
 * asked for.
 *
 * **The dialog lists every declared read field**, not two named ones -- a task run carries no
 * single free-text field the way an audit event's `Description`/`EventData` pair does, so the
 * dialog is the row's whole declared shape, in `read.fields` order, each under `FIELD_LABEL_KEYS`.
 *
 * Every control-flow condition is a paren-free member reference, for the reason `sign-in.ts`
 * records.
 */
@Component({
  selector: 'app-task-history-page',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [DataTable, Dialog],
  template: `<section class="ocu-list-page">
    @if (list; as view) {
      <form class="ocu-criteria-form" (submit)="onSearch($event)">
        <div class="ocu-criteria-fields">
          <div class="ocu-criteria-field">
            <label class="ocu-criteria-label" for="ocu-task-history-search">{{ STRINGS.taskHistorySearch }}</label>
            <input
              class="ocu-criteria-input"
              type="text"
              id="ocu-task-history-search"
              [value]="search"
              (input)="onSearchInput($event)"
            />
          </div>
        </div>
        <div class="ocu-criteria-controls">
          <label class="ocu-criteria-marker">
            <input
              type="checkbox"
              data-ocu-user-only="1"
              [checked]="userOnly"
              (change)="onUserOnly($event)"
            />
            {{ STRINGS.taskHistoryUserOnly }}
          </label>
          <button type="submit" class="ocu-button-primary">{{ STRINGS.auditCriteriaSearch }}</button>
        </div>
      </form>
      @if (searched) {
        <app-data-table [screen]="view.screen" [store]="view.store" (focusFilter)="onFocusFilter()" />
      }
      @if (detail; as fields) {
        <app-dialog
          [heading]="STRINGS.taskHistoryLabel"
          [closeLabel]="STRINGS.auditDialogClose"
          (closed)="onCloseDetail()"
        >
          @for (row of fields; track row.field) {
            <p class="ocu-dialog-field">{{ row.label }}</p>
            <p class="ocu-dialog-value">{{ row.value }}</p>
          }
        </app-dialog>
      }
    }
  </section>`,
})
export class HistoryPage {
  private readonly navigation = inject(NavigationService);
  private readonly router = inject(Router);
  private readonly route = inject(ActivatedRoute);
  private readonly stores = inject(ScreenStores);
  private readonly refresh = inject(RefreshService);
  private readonly api = inject(ApiService);

  private readonly actions = inject(ScreenActions);

  protected readonly STRINGS = STRINGS;

  protected readonly list: HistoryView | null;

  /** This screen's own state, held for as long as its `ScreenStore` is. */
  private readonly searchStore: TaskHistorySearch;

  /** Bumped by the two stores, so the form and the table re-render under `OnPush`. */
  private readonly generation = signal(0);

  /** The id segment the route carries, decoded once (AD-13). */
  private readonly entityId = signal('');

  constructor() {
    const screen = this.navigation.screenForUrl(this.router.url);
    if (screen === null || screen.read === null || screen.table === null) {
      this.searchStore = heldFor(null);
      this.list = null;
      return;
    }
    const store = this.stores.for(screen.descriptor, screen.refreshRates);
    this.searchStore = heldFor(store);
    this.list = { screen, store };

    // Bind with no read until the first Search, for the reason `AuditPage` binds this way: an
    // unsearched screen must issue nothing, on first render or on a namespace switch.
    this.refresh.bind(screen, this.searchStore.searched() ? this.boundRead(screen) : null);

    if (this.searchStore.searched() && !this.refresh.hasLoaded()) void this.refresh.readNow();

    // Manual Refresh, offered only once Search has run and withdrawn the moment it has not
    // (the same rule and the same reason `AuditPage`'s own toggle gives).
    let stopRefreshAction: (() => void) | null = null;
    const syncRefreshAction = (): void => {
      const offered = this.searchStore.searched();
      if (offered && stopRefreshAction === null) {
        stopRefreshAction = this.actions.register(screen.descriptor, REFRESH_ACTION_ID, () => {
          this.refresh.bind(screen, this.boundRead(screen));
          void this.refresh.readNow();
        });
      } else if (!offered && stopRefreshAction !== null) {
        stopRefreshAction();
        stopRefreshAction = null;
      }
    };
    syncRefreshAction();

    const stopStore = store.subscribe(() => this.bump());
    const stopSearch = this.searchStore.subscribe(() => {
      this.bump();
      syncRefreshAction();
    });
    const stopParams = this.route.paramMap.subscribe((params) => {
      const raw = params.get('id');
      this.entityId.set(raw === null ? '' : decodeEntityId(raw));
    });

    // The dialog's route is a second route config over the same screen, so this component is
    // destroyed and re-created on every dialog open and close (see `AuditPage`'s own comment).
    afterNextRender(() => {
      if (!this.searchStore.takeGridFocusRequest()) return;
      document.querySelector<HTMLElement>('[role="grid"]')?.focus();
    });

    const generation = this.searchStore.takeGeneration();
    inject(DestroyRef).onDestroy(() => {
      stopStore();
      stopSearch();
      stopRefreshAction?.();
      stopParams.unsubscribe();
      if (!this.searchStore.isCurrentGeneration(generation)) return;
      if (this.navigation.screenForUrl(this.router.url)?.descriptor === screen.descriptor) return;
      if (this.refresh.descriptor() === screen.descriptor) this.refresh.unbind();
    });
  }

  /** The one `RefreshRead` this screen's store holds, created on first ask. */
  private boundRead(screen: ScreenDeclaration) {
    return this.searchStore.readFor(() => createScreenRead(this.api, screen, () => this.searchStore.criteria()));
  }

  protected get search(): string {
    this.generation();
    return this.searchStore.search();
  }

  protected get userOnly(): boolean {
    this.generation();
    return this.searchStore.userOnly();
  }

  protected get searched(): boolean {
    this.generation();
    return this.searchStore.searched();
  }

  /**
   * The row the id route names, as every declared read field in order, or `null`. Resolved out of
   * the rows the last read returned, by the same `rowKey` the table linked with -- a key that
   * matches nothing renders no dialog rather than an empty one, for the reason `AuditPage` gives.
   */
  protected get detail(): readonly DetailFieldView[] | null {
    this.generation();
    const view = this.list;
    const id = this.entityId();
    if (view === null || id === '') return null;
    const row = view.store.data().find((candidate) => rowKey(candidate, view.screen) === id);
    if (row === undefined) return null;
    return (
      view.screen.read?.fields.map((field) => ({
        field,
        label: stringFor(FIELD_LABEL_KEYS[field] ?? ''),
        value: textOf(fieldOf(row, field)),
      })) ?? []
    );
  }

  protected onSearchInput(event: Event): void {
    this.searchStore.setSearch((event.target as HTMLInputElement).value);
  }

  protected onUserOnly(event: Event): void {
    this.searchStore.setUserOnly((event.target as HTMLInputElement).checked);
  }

  /** Search: bind the read if this is the first one, then read now whatever the rate. */
  protected onSearch(event: Event): void {
    event.preventDefault();
    const screen = this.list?.screen;
    if (screen === undefined) return;
    this.searchStore.noteSearched();
    this.refresh.bind(screen, this.boundRead(screen));
    void this.refresh.readNow();
  }

  /** Close the dialog by returning to the bare route (see `AuditPage.onCloseDetail`). */
  protected onCloseDetail(): void {
    const screen = this.list?.screen;
    if (screen === undefined) return;
    this.searchStore.requestGridFocus();
    void this.router.navigateByUrl(withQuery(screen.route, this.router.url));
  }

  protected onFocusFilter(): void {
    document.getElementById(COMMAND_BAR_FILTER_ID)?.focus();
  }

  private bump(): void {
    this.generation.update((value) => value + 1);
  }
}
