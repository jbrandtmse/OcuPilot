/**
 * One screen's state, keyed by its descriptor (AD-19).
 *
 * A screen's data, sort, filter, selection, scroll, max rows and refresh setting live here and
 * never in a component field: the re-fetch framework writes three of those slots on every tick
 * while the component that renders them is being re-created by the router, and state that lived
 * in the component would be lost on the first navigation and fought over on the first tick.
 *
 * **Two lifetimes.** `rate`, `sort`, `direction`, `filter` and `maxRows` are what the user chose,
 * and survive leaving and returning to the screen (EXPERIENCE.md, Screen Synchronization): the
 * rate through `PreferenceStore`'s rate map and the other four through its view map, restored when
 * the store is created. `data`, `truncated`, `banner`, `lastUpdate`, `selection`, `active`,
 * `changed`, `refusal` and
 * `scroll` are what the instance last said and where the user last was, so they live for as long
 * as the tab holds the store and are never persisted -- a remembered scroll offset into rows that
 * have since changed is worse than none, and a remembered `lastUpdate` would claim a freshness the
 * screen does not have.
 *
 * **A tick writes exactly four of them** (`applyTick`): `data`, `truncated`, `banner` and
 * `lastUpdate`.
 * The rest are untouched by construction rather than by care, which is what makes "sort, filter,
 * selection, scroll and max rows survive every tick" a property of this method rather than of
 * every caller.
 *
 * **Framework-free, and read into signals by the component.** AD-19 calls this a signal store;
 * the client's translation of that, since `instance.ts`, is a plain subscribable service that a
 * component mirrors into `signal()`s in its constructor (`status-bar.ts` does it for five
 * fields). Keeping `core/` free of `@angular/core` is what lets `node --test` execute it, which
 * is where the refresh framework's own pins live.
 */

import type { PreferenceStore } from './preferences';

/** The sort directions a table view may hold; `''` takes the declared direction. */
export type SortDirection = '' | 'asc' | 'desc';

/** What a screen's read last returned. Rows are opaque here; the table (Story 2.4) types them. */
export type ScreenRow = unknown;

/** The default cap every read is bounded by (AD-36), until a screen's own control moves it. */
export const DEFAULT_MAX_ROWS = 1000;

/** Off, which is every screen's default refresh setting (EXPERIENCE.md "Auto-refresh off"). */
export const RATE_OFF = 0;

export interface ScreenStoreOptions {
  /** The descriptor class name this store is keyed by. */
  readonly descriptor: string;
  /** The rates the descriptor permits, so a stored rate outside them falls back. */
  readonly rates: readonly number[];
  /** Where the rate and the view choices are remembered (AD-47's carve-out). */
  readonly preferences: PreferenceStore;
}

export class ScreenStore {
  private readonly descriptor: string;
  private readonly permitted: readonly number[];
  private readonly preferences: PreferenceStore;

  private rows: readonly ScreenRow[] = [];
  private truncatedFlag = false;
  private bannerKey = '';
  private refusalText = '';
  private lastUpdateAt: Date | null = null;
  private selected: readonly string[] = [];
  private activeKey = '';
  private changedKeys: ReadonlySet<string> = new Set();
  private scrollTop = 0;
  private sortBy = '';
  private sortDirection: SortDirection = '';
  private filterText = '';
  private rowCap = DEFAULT_MAX_ROWS;
  private rateSeconds = RATE_OFF;

  private readonly listeners = new Set<() => void>();

  constructor(options: ScreenStoreOptions) {
    this.descriptor = options.descriptor;
    this.permitted = options.rates;
    this.preferences = options.preferences;
    this.rateSeconds = this.preferences.refreshRate(this.descriptor, this.permitted);
    const view = this.preferences.screenView(this.descriptor, DEFAULT_MAX_ROWS);
    if (view !== null) {
      this.sortBy = view.sort;
      this.sortDirection = view.direction === 'asc' || view.direction === 'desc' ? view.direction : '';
      this.filterText = view.filter;
      this.rowCap = view.maxRows;
    }
  }

  key(): string {
    return this.descriptor;
  }

  subscribe(listener: () => void): () => void {
    this.listeners.add(listener);
    return () => {
      this.listeners.delete(listener);
    };
  }

  // --- What the instance last said -----------------------------------------------------------

  data(): readonly ScreenRow[] {
    return this.rows;
  }

  truncated(): boolean {
    return this.truncatedFlag;
  }

  /**
   * The string key of the strip the last read raised above the table, `''` for none.
   *
   * It is what the instance answered, not something the client decided, and it is written by the
   * same `applyTick` the rows are -- so a tick re-evaluates it and the strip is gone the moment
   * the condition clears (EXPERIENCE.md "panel (top), form-pages, Task").
   */
  banner(): string {
    return this.bannerKey;
  }

  lastUpdate(): Date | null {
    return this.lastUpdateAt;
  }

  /**
   * The sentence the last refused row action answered with, `''` for none.
   *
   * **Server text, never client copy** (AD-39): a refused write answers a violation's own `reason`
   * or the envelope's, and this slot carries whichever the handler read. It is the screen's, not
   * the table's, because the action that raised it acts on the screen's selection and the row it
   * refused is still on screen.
   *
   * Written only by the action handler that issued the write -- never by `applyTick`, so a silent
   * re-fetch neither raises nor clears one -- and dropped by `clearAnswers`, because a refusal
   * about a row in a namespace the shell has left is about nothing.
   */
  refusal(): string {
    return this.refusalText;
  }

  /** Raise or clear the refusal sentence. A handler clears it before it issues its write. */
  setRefusal(text: string): void {
    if (this.refusalText === text) return;
    this.refusalText = text;
    this.notify();
  }

  /**
   * Record one read. The four slots a re-fetch owns, and no others: a tick that also cleared
   * the selection or reset the scroll would be visible to the user, which is what "refresh is
   * silent" forbids (EXPERIENCE.md "**Auto-refresh controls.** On Processes").
   */
  applyTick(rows: readonly ScreenRow[], truncated: boolean, banner: string, at: Date): void {
    this.rows = rows;
    this.truncatedFlag = truncated;
    this.bannerKey = banner;
    this.lastUpdateAt = at;
    this.notify();
  }

  /**
   * Drop what the instance last said and where the user was in it, keeping what the user chose.
   *
   * After a namespace switch (AD-44) the rows belong to a namespace the shell has left, a stamp
   * left behind would claim they are current, and a selection, active row, changed mark or scroll
   * offset points into rows that are gone (DW-18). Sort, direction, filter and max rows are the
   * user's and are still what they want from the new namespace.
   */
  clearAnswers(): void {
    this.rows = [];
    this.truncatedFlag = false;
    this.bannerKey = '';
    this.refusalText = '';
    this.lastUpdateAt = null;
    this.selected = [];
    this.activeKey = '';
    this.changedKeys = new Set();
    this.scrollTop = 0;
    this.notify();
  }

  // --- Where the user last was ---------------------------------------------------------------

  selection(): readonly string[] {
    return this.selected;
  }

  setSelection(ids: readonly string[]): void {
    this.selected = ids;
    this.notify();
  }

  /** The active row's key, or `''`. */
  active(): string {
    return this.activeKey;
  }

  setActive(key: string): void {
    if (key === this.activeKey) return;
    this.activeKey = key;
    this.notify();
  }

  /** The keys of the rows a change event marked, until each is clicked or becomes active. */
  changed(): ReadonlySet<string> {
    return this.changedKeys;
  }

  markChanged(key: string): void {
    if (key === '' || this.changedKeys.has(key)) return;
    this.changedKeys = new Set([...this.changedKeys, key]);
    this.notify();
  }

  clearChanged(key: string): void {
    if (!this.changedKeys.has(key)) return;
    const next = new Set(this.changedKeys);
    next.delete(key);
    this.changedKeys = next;
    this.notify();
  }

  scroll(): number {
    return this.scrollTop;
  }

  setScroll(offset: number): void {
    this.scrollTop = offset;
    this.notify();
  }

  // --- What the user chose, remembered per browser --------------------------------------------

  sort(): string {
    return this.sortBy;
  }

  setSort(sort: string): void {
    this.sortBy = sort;
    this.rememberView();
    this.notify();
  }

  direction(): SortDirection {
    return this.sortDirection;
  }

  setDirection(direction: SortDirection): void {
    this.sortDirection = direction;
    this.rememberView();
    this.notify();
  }

  filter(): string {
    return this.filterText;
  }

  setFilter(filter: string): void {
    this.filterText = filter;
    this.rememberView();
    this.notify();
  }

  maxRows(): number {
    return this.rowCap;
  }

  /**
   * Set the cap every read is bounded by (AD-36). Refused, changing and remembering nothing, for
   * anything but a positive safe integer (DW-17): a cap of 0 reads nothing and a fraction is not
   * a row count.
   */
  setMaxRows(cap: number): boolean {
    if (!Number.isSafeInteger(cap) || cap <= 0) return false;
    this.rowCap = cap;
    this.rememberView();
    this.notify();
    return true;
  }

  rate(): number {
    return this.rateSeconds;
  }

  /** The rates this screen's chip may advance through, off excluded. */
  rates(): readonly number[] {
    return this.permitted;
  }

  /**
   * Set the refresh rate. Refused -- and nothing written -- unless it is off or one of the rates
   * the descriptor permits: the rate decides a timer's delay, and the descriptor is the one
   * declaration of the delays a screen may run at.
   */
  setRate(seconds: number): boolean {
    if (seconds !== RATE_OFF && !this.permitted.includes(seconds)) return false;
    this.rateSeconds = seconds;
    this.preferences.setRefreshRate(this.descriptor, seconds);
    this.notify();
    return true;
  }

  private rememberView(): void {
    this.preferences.setScreenView(this.descriptor, {
      sort: this.sortBy,
      direction: this.sortDirection,
      filter: this.filterText,
      maxRows: this.rowCap,
    });
  }

  private notify(): void {
    for (const listener of [...this.listeners]) listener();
  }
}

/**
 * The one store per descriptor, for as long as the tab lives.
 *
 * Keyed by descriptor rather than by route so a detail screen's several URLs share one store,
 * and held across navigation so "the stored rate is restored" needs no re-read on the way back.
 */
export class ScreenStores {
  private readonly preferences: PreferenceStore;
  private readonly stores = new Map<string, ScreenStore>();

  constructor(options: { readonly preferences: PreferenceStore }) {
    this.preferences = options.preferences;
  }

  /** The store for `descriptor`, created on first ask. */
  for(descriptor: string, rates: readonly number[]): ScreenStore {
    const held = this.stores.get(descriptor);
    if (held !== undefined) return held;
    const store = new ScreenStore({ descriptor, rates, preferences: this.preferences });
    this.stores.set(descriptor, store);
    return store;
  }

  /**
   * Drop every store. Sign-out clears the tab in place without a reload, and a screen's rows are
   * data **this** principal was allowed to read (AD-8); the persisted choices are per browser and
   * are deliberately not cleared, being preferences rather than answers.
   */
  reset(): void {
    this.stores.clear();
  }
}
