import { ChangeDetectionStrategy, Component, DestroyRef, afterNextRender, inject, signal } from '@angular/core';
import { ActivatedRoute, Router } from '@angular/router';

import { ApiService } from '../../core/api';
import { decodeEntityId } from '../../core/entity-id';
import { NavigationService, screenForRoute, withQuery } from '../../core/navigation';
import { RefreshService, type RefreshRead } from '../../core/refresh';
import { ScopeService } from '../../core/scope';
import { REFRESH_ACTION_ID, ScreenActions } from '../../core/screen-actions';
import { ScreenArrivals, type ScreenArrival } from '../../core/screen-arrival';
import { createScreenRead, textOf, type ScreenReadCriteria } from '../../core/screen-read';
import { ScreenStores, type ScreenStore } from '../../core/screen-store';
import type { ScreenDeclaration } from '../../core/screens.generated';
import { STRINGS, stringFor } from '../../core/strings';
import { COMMAND_BAR_FILTER_ID } from '../../shell/command-bar';
import { DataTable } from '../../shell/data-table';
import { Dialog } from '../../shell/dialog';

/** Journals' route, whose declared read names the newest file on a cold open (AD-5). */
export const JOURNALS_ROUTE = 'os-management/journals';

/** The detail dialog's screen-only read (AD-36), absolute from the origin root (AD-20). */
export const JOURNAL_RECORD_PATH = '/api/ocupilot/journal/record';

/** The criteria the form carries, by their declared names. */
const PARAMS = ['file', 'offset', 'order', 'column', 'operator', 'value'] as const;

type Param = (typeof PARAMS)[number];

/** Each choice's option, by value, and the string key it is shown under. */
const OPTION_LABEL_KEYS: Readonly<Record<string, Readonly<Record<string, string>>>> = {
  order: { '0': 'journalRecordOldestFirst', '1': 'journalRecordNewestFirst' },
  column: {
    TimeStamp: 'auditColumnTime',
    ProcessID: 'proposalEntityProcess',
    TypeName: 'tableColumnType',
    ExtTypeName: 'journalRecordExtendedType',
    InTransaction: 'processDetailsInTransaction',
    GlobalNode: 'journalRecordGlobalNode',
    DatabaseName: 'systemInfoDatabase',
    MirrorDatabaseName: 'journalRecordMirrorDatabase',
  },
  operator: {
    '=': 'journalRecordOpEquals',
    "'=": 'journalRecordOpNotEquals',
    ']]': 'journalRecordOpSortsAfter',
    "']]": 'journalRecordOpNotSortsAfter',
    '[': 'journalRecordOpContains',
    "'[": 'journalRecordOpNotContains',
  },
};

/**
 * The record fields the dialog shows, in order, each under its own label; a field the record does
 * not carry (a record that is no set or kill carries no global) is left out. The three screen-only
 * values (AD-36) render preformatted.
 */
const DIALOG_FIELDS: readonly { readonly field: string; readonly labelKey: string; readonly pre: boolean }[] = [
  { field: 'TypeName', labelKey: 'tableColumnType', pre: false },
  { field: 'ExtTypeName', labelKey: 'journalRecordExtendedType', pre: false },
  { field: 'TimeStamp', labelKey: 'auditColumnTime', pre: false },
  { field: 'ProcessID', labelKey: 'proposalEntityProcess', pre: false },
  { field: 'InTransaction', labelKey: 'processDetailsInTransaction', pre: false },
  { field: 'DatabaseName', labelKey: 'systemInfoDatabase', pre: false },
  { field: 'MirrorDatabaseName', labelKey: 'journalRecordMirrorDatabase', pre: false },
  { field: 'GlobalNode', labelKey: 'journalRecordGlobalNode', pre: false },
  { field: 'GlobalReference', labelKey: 'journalRecordGlobalReference', pre: true },
  { field: 'OldValue', labelKey: 'journalRecordOldValue', pre: true },
  { field: 'NewValue', labelKey: 'journalRecordNewValue', pre: true },
  { field: 'PrevAddress', labelKey: 'journalRecordPrevious', pre: false },
  { field: 'NextAddress', labelKey: 'journalRecordNext', pre: false },
];

/** One criterion's control, resolved for drawing. */
interface CriterionView {
  readonly param: string;
  readonly id: string;
  readonly label: string;
  readonly choice: boolean;
  readonly options: readonly { readonly value: string; readonly label: string }[];
  readonly value: string;
}

/** One field of the record dialog, resolved for drawing. */
interface RecordFieldView {
  readonly field: string;
  readonly label: string;
  readonly value: string;
  readonly pre: boolean;
}

/** The screen this page renders and the store its table reads. */
interface RecordsView {
  readonly screen: ScreenDeclaration;
  readonly store: ScreenStore;
}

/**
 * The next offset after `rows` (Story 18.19): the highest `Address` plus 1 in file order, the lowest
 * minus 1 in reverse order, read from the read's own rows rather than the table's sorted view; `''`
 * when no row carries a numeric `Address`. The instance reads an offset inclusively and moves one
 * that names no record to the nearest record in the order's direction (measured at Task 0).
 */
export function nextOffset(rows: readonly unknown[], order: string): string {
  const addresses = rows
    .map((row) => (row !== null && typeof row === 'object' ? (row as Record<string, unknown>)['Address'] : undefined))
    .filter((address): address is number => typeof address === 'number' && Number.isSafeInteger(address));
  if (addresses.length === 0) return '';
  return order === '1' ? String(Math.min(...addresses) - 1) : String(Math.max(...addresses) + 1);
}

/**
 * Journal records' own search state (AD-19): the file and the five criteria the form holds, held
 * beside the screen's store in `HELD_SEARCHES` so it outlives the page across the detail dialog's
 * route and is dropped with the store at sign-out. It also caches the one `RefreshRead` the page
 * binds, which must survive the dialog's destroy-and-recreate cycle by reference for
 * `RefreshService.bind` to treat the re-bind as a no-op.
 */
class JournalRecordSearch {
  private readonly values: Record<Param, string> = { file: '', offset: '', order: '0', column: 'GlobalNode', operator: '[', value: '' };

  /** Each criterion's declared default, which an arrival starts from. */
  private readonly defaults: Record<Param, string>;

  private cachedRead: RefreshRead | null = null;

  private pageGeneration = 0;

  private gridFocusWanted = false;

  private readonly listeners = new Set<() => void>();

  constructor(screen: ScreenDeclaration | null) {
    for (const field of screen?.read?.criteria?.fields ?? []) {
      if ((PARAMS as readonly string[]).includes(field.param) && field.default !== undefined) {
        this.values[field.param as Param] = field.default;
      }
    }
    this.defaults = { ...this.values };
  }

  subscribe(listener: () => void): () => void {
    this.listeners.add(listener);
    return () => {
      this.listeners.delete(listener);
    };
  }

  value(param: string): string {
    return (PARAMS as readonly string[]).includes(param) ? this.values[param as Param] : '';
  }

  setValue(param: string, value: string): void {
    if (!(PARAMS as readonly string[]).includes(param)) return;
    this.values[param as Param] = value;
    this.notify();
  }

  /** Take an arrival's criteria exactly: each criterion it carries, and its declared default for the rest. */
  useArrival(arrival: ScreenArrival): void {
    for (const param of PARAMS) {
      const value = arrival.criteria[param];
      this.values[param] = typeof value === 'string' ? value : this.defaults[param];
    }
    this.notify();
  }

  /** Every criterion as the form holds it; an empty one is sent empty, which the read leaves unset. */
  criteria(): ScreenReadCriteria {
    return { ...this.values };
  }

  takeGeneration(): number {
    this.pageGeneration += 1;
    return this.pageGeneration;
  }

  isCurrentGeneration(generation: number): boolean {
    return this.pageGeneration === generation;
  }

  requestGridFocus(): void {
    this.gridFocusWanted = true;
  }

  takeGridFocusRequest(): boolean {
    const wanted = this.gridFocusWanted;
    this.gridFocusWanted = false;
    return wanted;
  }

  readFor(create: () => RefreshRead): RefreshRead {
    if (this.cachedRead === null) this.cachedRead = create();
    return this.cachedRead;
  }

  private notify(): void {
    for (const listener of [...this.listeners]) listener();
  }
}

/**
 * The read Journal records binds: when the search names no file, Journals' own declared read with
 * `maxRows` 1 names the newest one first (AD-5), so every read names the file it reads, the
 * framework's own first read on a reload included; then the screen's declared read over the search's
 * criteria. A refused Journals read is that read's refusal.
 */
function recordsRead(api: Pick<ApiService, 'requestJson'>, screen: ScreenDeclaration, search: JournalRecordSearch): RefreshRead {
  const read = createScreenRead(api, screen, () => search.criteria());
  return async (options) => {
    if (search.value('file') === '') {
      const journals = screenForRoute(JOURNALS_ROUTE);
      if (journals !== null && journals.read !== null) {
        const named = await createScreenRead(api, journals)({ maxRows: 1 });
        if (named.kind === 'fault') return named;
        const first = named.rows[0];
        const name = first !== null && typeof first === 'object' ? (first as Record<string, unknown>)['Name'] : undefined;
        if (typeof name === 'string') search.setValue('file', name);
      }
    }
    return read(options);
  };
}

/** One `JournalRecordSearch` per screen store, dropped with it at sign-out. */
const HELD_SEARCHES = new WeakMap<ScreenStore, JournalRecordSearch>();

/** The search held for `store`, created on first ask. */
function heldFor(store: ScreenStore | null, screen: ScreenDeclaration | null): JournalRecordSearch {
  const known = store === null ? undefined : HELD_SEARCHES.get(store);
  if (known !== undefined) return known;
  const search = new JournalRecordSearch(screen);
  if (store !== null) HELD_SEARCHES.set(store, search);
  return search;
}

/**
 * Journal records (Story 18.19): one journal file's records, a criteria form above the shared table,
 * and the journal record detail dialog its `/:id` route opens.
 *
 * **Opening.** An arrival (Journal file details' View records, or the agent) names the file and
 * runs one search. Without a file -- a reload, a deep link -- the page first issues Journals' own
 * declared read with `maxRows` 1 (AD-5) and reads that file, so the page always names the file it
 * reads. A return re-runs the held search; the dialog's round trip reads nothing.
 *
 * **Next records** continues from the read's own rows (`nextOffset`) and searches again; it is
 * offered whenever the page holds a row.
 *
 * **The dialog** fetches the record through the screen-only route, keeps it in a page-local
 * signal cleared when it closes -- never in the screen's store, which screen context reads (AD-36)
 * -- and renders every value as text. A refusal shows its reason. Close returns to the list route
 * with the criteria kept.
 *
 * Every control-flow condition is a paren-free member reference, for the reason `sign-in.ts`
 * records.
 */
@Component({
  selector: 'app-journal-records-page',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [DataTable, Dialog],
  template: `<section class="ocu-list-page">
    @if (list; as view) {
      <form class="ocu-criteria-form" (submit)="onSearch($event)">
        <h2 class="ocu-details-heading" data-journal-records="heading">{{ heading }}</h2>
        <div class="ocu-criteria-fields">
          @for (field of criteria; track field.param) {
            <div class="ocu-criteria-field">
              <label class="ocu-criteria-label" [attr.for]="field.id">{{ field.label }}</label>
              @if (field.choice) {
                <select class="ocu-criteria-select" [id]="field.id" [value]="field.value" (change)="onCriterion(field.param, $event)">
                  @for (option of field.options; track option.value) {
                    <option [value]="option.value" [selected]="option.value === field.value">{{ option.label }}</option>
                  }
                </select>
              } @else {
                <input
                  class="ocu-criteria-input"
                  type="text"
                  [id]="field.id"
                  [value]="field.value"
                  (input)="onCriterion(field.param, $event)"
                />
              }
            </div>
          }
        </div>
        <div class="ocu-criteria-controls">
          <button type="submit" class="ocu-button-primary">{{ STRINGS.auditCriteriaSearch }}</button>
          @if (hasRows) {
            <button type="button" class="ocu-button-secondary" data-journal-records="next" (click)="onNext()">
              {{ STRINGS.journalRecordsNext }}
            </button>
          }
        </div>
      </form>
      <app-data-table [screen]="view.screen" [store]="view.store" (focusFilter)="onFocusFilter()" />
      @if (dialogOpen) {
        <app-dialog [heading]="dialogTitle" [closeLabel]="STRINGS.auditDialogClose" (closed)="onCloseDetail()">
          @if (recordRefusal) {
            <p class="ocu-dialog-value" role="alert" data-journal-records="refusal">{{ recordRefusal }}</p>
          }
          @for (row of recordFields; track row.field) {
            <p class="ocu-dialog-field">{{ row.label }}</p>
            @if (row.pre) {
              <pre class="ocu-dialog-payload" [attr.data-field]="row.field">{{ row.value }}</pre>
            } @else {
              <p class="ocu-dialog-value" [attr.data-field]="row.field">{{ row.value }}</p>
            }
          }
        </app-dialog>
      }
    }
  </section>`,
})
export class JournalRecordsPage {
  private readonly navigation = inject(NavigationService);
  private readonly router = inject(Router);
  private readonly route = inject(ActivatedRoute);
  private readonly stores = inject(ScreenStores);
  private readonly refresh = inject(RefreshService);
  private readonly api = inject(ApiService);
  private readonly scope = inject(ScopeService);
  private readonly actions = inject(ScreenActions);

  /** Journal file details' and the agent's hand-off. Optional, so a spec that needs none provides none. */
  private readonly arrivals = inject(ScreenArrivals, { optional: true });

  protected readonly STRINGS = STRINGS;

  protected readonly list: RecordsView | null;

  private readonly search: JournalRecordSearch;

  /** Bumped by the stores, so the form and the table re-render under `OnPush`. */
  private readonly generation = signal(0);

  /** The record address the route carries, decoded once (AD-13). */
  private readonly entityId = signal('');

  /** The open dialog's record: page-local, cleared on close, never in the screen store (AD-36). */
  private readonly record = signal<Readonly<Record<string, unknown>> | null>(null);

  /** The open dialog's refusal reason, or `''`. */
  private readonly refusal = signal('');

  /** Bumped per dialog fetch, so a late answer for a dialog since closed or moved is dropped. */
  private recordRequest = 0;

  constructor() {
    const screen = this.navigation.screenForUrl(this.router.url);
    if (screen === null || screen.read === null || screen.table === null) {
      this.search = heldFor(null, null);
      this.list = null;
      return;
    }
    const store = this.stores.for(screen.descriptor, screen.refreshRates);
    this.search = heldFor(store, screen);
    this.list = { screen, store };

    this.refresh.bind(screen, this.boundRead(screen));
    const arrival = this.arrivals?.take(screen.route) ?? null;
    if (arrival !== null) {
      this.search.useArrival(arrival);
      this.open();
    } else if (!this.refresh.hasLoaded()) {
      this.open();
    }

    const stopRefreshAction = this.actions.register(screen.descriptor, REFRESH_ACTION_ID, () => {
      this.refresh.bind(screen, this.boundRead(screen));
      void this.refresh.readNow();
    });

    const stopArrivals =
      this.arrivals?.subscribe(() => {
        const next = this.arrivals?.take(screen.route) ?? null;
        if (next === null) return;
        this.search.useArrival(next);
        this.open();
      }) ?? null;

    const stopStore = store.subscribe(() => this.bump());
    const stopSearch = this.search.subscribe(() => this.bump());
    const stopParams = this.route.paramMap.subscribe((params) => {
      const raw = params.get('id');
      const id = raw === null ? '' : decodeEntityId(raw);
      this.entityId.set(id);
      void this.loadRecord(id);
    });

    afterNextRender(() => {
      if (!this.search.takeGridFocusRequest()) return;
      document.querySelector<HTMLElement>('[role="grid"]')?.focus();
    });

    const generation = this.search.takeGeneration();
    inject(DestroyRef).onDestroy(() => {
      stopStore();
      stopSearch();
      stopRefreshAction();
      stopArrivals?.();
      stopParams.unsubscribe();
      this.record.set(null);
      if (!this.search.isCurrentGeneration(generation)) return;
      if (this.navigation.screenForUrl(this.router.url)?.descriptor === screen.descriptor) return;
      if (this.refresh.descriptor() === screen.descriptor) this.refresh.unbind();
    });
  }

  /** The one `RefreshRead` this screen's search holds, created on first ask (`recordsRead`). */
  private boundRead(screen: ScreenDeclaration): RefreshRead {
    const api = this.api;
    const search = this.search;
    return search.readFor(() => recordsRead(api, screen, search));
  }

  /** Run the held search once the scope has resolved; before then the framework's own read is the one. */
  private open(): void {
    if (this.scope.loaded()) void this.refresh.readNow();
  }

  /** Fetch the record the route names, or clear the dialog when it names none. */
  private async loadRecord(id: string): Promise<void> {
    this.recordRequest += 1;
    const request = this.recordRequest;
    this.record.set(null);
    this.refusal.set('');
    this.bump();
    if (id === '') return;
    const path =
      JOURNAL_RECORD_PATH +
      '?file=' +
      encodeURIComponent(this.search.value('file')) +
      '&address=' +
      encodeURIComponent(id);
    const result = await this.api.requestJson<{ record?: unknown }>(path);
    if (request !== this.recordRequest) return;
    const body = result.kind === 'ok' ? result.body : null;
    if (body !== null && typeof body === 'object' && body.record !== null && typeof body.record === 'object') {
      this.record.set(body.record as Readonly<Record<string, unknown>>);
    } else {
      this.refusal.set(result.kind === 'error' && result.reason !== null ? result.reason : STRINGS.connectivityRequestRefused);
    }
    this.bump();
  }

  /** "Records of <file>", naming the file the page reads. */
  protected get heading(): string {
    this.generation();
    return STRINGS.journalRecordsHeading.replace('<file>', this.search.value('file'));
  }

  /** The criteria form's controls, in declaration order, but the file, which the heading names. */
  protected get criteria(): readonly CriterionView[] {
    this.generation();
    const screen = this.list?.screen;
    return (screen?.read?.criteria?.fields ?? [])
      .filter((field) => field.param !== 'file')
      .map((field) => ({
        param: field.param,
        id: `ocu-journal-records-${field.param}`,
        label: stringFor(field.labelKey),
        choice: field.kind === 'choice',
        options: (field.options ?? []).map((option) => ({ value: option, label: stringFor(OPTION_LABEL_KEYS[field.param]?.[option] ?? '') })),
        value: this.search.value(field.param),
      }));
  }

  protected get hasRows(): boolean {
    this.generation();
    return (this.list?.store.data().length ?? 0) > 0;
  }

  protected get dialogOpen(): boolean {
    this.generation();
    return this.entityId() !== '';
  }

  /** "Journal record <offset>", naming the record the route names. */
  protected get dialogTitle(): string {
    this.generation();
    return STRINGS.journalRecordDialogTitle.replace('<offset>', this.entityId());
  }

  protected get recordRefusal(): string {
    this.generation();
    return this.refusal();
  }

  /** The open record's fields the dialog shows, each as text. */
  protected get recordFields(): readonly RecordFieldView[] {
    this.generation();
    const record = this.record();
    if (record === null) return [];
    return DIALOG_FIELDS.filter((entry) => entry.field in record).map((entry) => ({
      field: entry.field,
      label: stringFor(entry.labelKey),
      value: textOf(record[entry.field]),
      pre: entry.pre,
    }));
  }

  protected onCriterion(param: string, event: Event): void {
    this.search.setValue(param, (event.target as HTMLInputElement | HTMLSelectElement).value);
  }

  /** Search: send the form as shown and read now. */
  protected onSearch(event: Event): void {
    event.preventDefault();
    this.open();
  }

  /** Next records: the offset after the read's own rows, in the form's order, then search again. */
  protected onNext(): void {
    const view = this.list;
    if (view === null) return;
    const next = nextOffset(view.store.data(), this.search.value('order'));
    if (next === '') return;
    this.search.setValue('offset', next);
    this.open();
  }

  /** Close the dialog by returning to the bare route, the criteria kept. */
  protected onCloseDetail(): void {
    const screen = this.list?.screen;
    if (screen === undefined) return;
    this.record.set(null);
    this.search.requestGridFocus();
    void this.router.navigateByUrl(withQuery(screen.route, this.router.url));
  }

  protected onFocusFilter(): void {
    document.getElementById(COMMAND_BAR_FILTER_ID)?.focus();
  }

  private bump(): void {
    this.generation.update((value) => value + 1);
  }
}
