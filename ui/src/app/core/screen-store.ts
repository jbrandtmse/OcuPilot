/**
 * One screen's state, keyed by its descriptor (AD-19).
 *
 * A screen's data, sort, filter, selection, scroll, max rows and refresh setting live here and
 * never in a component field: the re-fetch framework writes three of those slots on every tick
 * while the component that renders them is being re-created by the router, and state that lived
 * in the component would be lost on the first navigation and fought over on the first tick.
 *
 * **Nine slots, two lifetimes.** `rate`, `sort`, `filter` and `maxRows` are what the user chose,
 * and are meant to survive leaving and returning to the screen (EXPERIENCE.md `:561`). `data`,
 * `selection`, `scroll`, `truncated` and `lastUpdate` are what the instance last said and where
 * the user last was, so they live for as long as the tab holds the store and are never persisted
 * -- a remembered scroll offset into rows that have since changed is worse than none, and a
 * remembered `lastUpdate` would claim a freshness the screen does not have.
 *
 * **Of the four, only `rate` is written to `PreferenceStore` here.** It is the one this story
 * produces; sort, filter and max rows arrive with the data table (Story 2.4) that gives a user a
 * way to set them, and a key written for a control nobody can reach yet would be an allow-list
 * entry with no subject. All four live in the store now so a screen reads one object rather than
 * two, and so the tick's "three slots and no others" claim has the rest to be true about. Every
 * store in the tab survives navigation regardless (`ScreenStores`), so within one tab all four
 * already return with the screen.
 *
 * **A tick writes exactly three of them** (`applyTick`): `data`, `truncated` and `lastUpdate`.
 * The other six are untouched by construction rather than by care, which is what makes
 * "sort, filter, selection, scroll and max rows survive every tick" a property of this method
 * rather than of every caller.
 *
 * **Framework-free, and read into signals by the component.** AD-19 calls this a signal store;
 * the client's translation of that, since `instance.ts`, is a plain subscribable service that a
 * component mirrors into `signal()`s in its constructor (`status-bar.ts` does it for five
 * fields). Keeping `core/` free of `@angular/core` is what lets `node --test` execute it, which
 * is where the refresh framework's own pins live.
 */

import type { PreferenceStore } from './preferences';

/** What a screen's read last returned. Rows are opaque here; the table (Story 2.4) types them. */
export type ScreenRow = unknown;

/** The default cap every read is bounded by (AD-36), until a screen's own control moves it. */
export const DEFAULT_MAX_ROWS = 1000;

/** Off, which is every screen's default refresh setting (EXPERIENCE.md `:439`). */
export const RATE_OFF = 0;

export interface ScreenStoreOptions {
  /** The descriptor class name this store is keyed by. */
  readonly descriptor: string;
  /** The rates the descriptor permits, so a stored rate outside them falls back. */
  readonly rates: readonly number[];
  /** Where `rate` -- the one slot this story persists -- is written (AD-47's carve-out). */
  readonly preferences: PreferenceStore;
}

export class ScreenStore {
  private readonly descriptor: string;
  private readonly permitted: readonly number[];
  private readonly preferences: PreferenceStore;

  private rows: readonly ScreenRow[] = [];
  private truncatedFlag = false;
  private lastUpdateAt: Date | null = null;
  private selected: readonly string[] = [];
  private scrollTop = 0;
  private sortBy = '';
  private filterText = '';
  private rowCap = DEFAULT_MAX_ROWS;
  private rateSeconds = RATE_OFF;

  private readonly listeners = new Set<() => void>();

  constructor(options: ScreenStoreOptions) {
    this.descriptor = options.descriptor;
    this.permitted = options.rates;
    this.preferences = options.preferences;
    this.rateSeconds = this.preferences.refreshRate(this.descriptor, this.permitted);
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

  lastUpdate(): Date | null {
    return this.lastUpdateAt;
  }

  /**
   * Record one read. The three slots a re-fetch owns, and no others: a tick that also cleared
   * the selection or reset the scroll would be visible to the user, which is what "refresh is
   * silent" forbids (EXPERIENCE.md `:561`).
   */
  applyTick(rows: readonly ScreenRow[], truncated: boolean, at: Date): void {
    this.rows = rows;
    this.truncatedFlag = truncated;
    this.lastUpdateAt = at;
    this.notify();
  }

  /**
   * Drop what the instance last said, keeping what the user chose and where they were.
   *
   * The same three slots `applyTick` writes, and for the same reason it writes only those: after
   * a namespace switch (AD-44) the rows belong to a namespace the shell has left, and a stamp
   * left behind would claim they are current. Sort, filter and max rows are the user's and are
   * still what they want from the new namespace.
   */
  clearAnswers(): void {
    this.rows = [];
    this.truncatedFlag = false;
    this.lastUpdateAt = null;
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
    this.notify();
  }

  filter(): string {
    return this.filterText;
  }

  setFilter(filter: string): void {
    this.filterText = filter;
    this.notify();
  }

  maxRows(): number {
    return this.rowCap;
  }

  setMaxRows(cap: number): void {
    this.rowCap = cap;
    this.notify();
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

  private notify(): void {
    for (const listener of this.listeners) listener();
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
   * data **this** principal was allowed to read (AD-8); the persisted four are per browser and
   * are deliberately not cleared, being preferences rather than answers.
   */
  reset(): void {
    this.stores.clear();
  }
}
