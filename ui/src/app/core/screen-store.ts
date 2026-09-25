/**
 * One screen's state, keyed by its descriptor (AD-19).
 *
 * A screen's data, sort, filter, selection, scroll, max rows and refresh setting live here and
 * never in a component field: the re-fetch framework writes three of those slots on every tick
 * while the component that renders them is being re-created by the router, and state that lived
 * in the component would be lost on the first navigation and fought over on the first tick.
 *
 * **Two lifetimes.** `rate`, `sort`, `direction`, `filter`, `maxRows` and the column widths are what the user chose,
 * and survive leaving and returning to the screen -- and a sign-out (Story 15.5, AD-50): the rate
 * and the others are two rows on the instance, keyed by this screen's route, adopted on the
 * first answered read of `AccountPreferences`. `data`, `truncated`, `banner`, `lastUpdate`, `selection`, `active`,
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

import { AccountPreferences, REFRESH_KIND, VIEW_KIND } from './account-preferences.ts';
import { screenForDescriptor } from './navigation.ts';
import { isColumnWidth } from './table-model.ts';

/** The sort directions a table view may hold; `''` takes the declared direction. */
export type SortDirection = '' | 'asc' | 'desc';

/** What a screen's read last returned. Rows are opaque here; the table (Story 2.4) types them. */
export type ScreenRow = unknown;

/** The default cap every read is bounded by (AD-36), until a screen's own control moves it. */
export const DEFAULT_MAX_ROWS = 1000;

/** Off, which is every screen's default refresh setting (EXPERIENCE.md "Auto-refresh off"). */
export const RATE_OFF = 0;

/**
 * What a screen remembers of its table's view: its sort, direction, filter, max rows and the
 * column widths the user set (Story 15.8), keyed by field.
 */
export interface ScreenViewPreference {
  readonly sort: string;
  readonly direction: string;
  readonly filter: string;
  readonly maxRows: number;
  readonly widths: ReadonlyMap<string, number>;
}

/**
 * The longest remembered value the instance keeps, equal to
 * `OcuPilot.Kernel.State.Pref.VALUEMAXLENGTH`. A serialized view longer than this is refused by
 * the handler, so `rememberView` does not send it -- the in-memory filter is unaffected and only
 * the remembering is skipped, the way `setMaxRows` refuses a cap that is not a row count.
 */
export const PREFERENCE_VALUE_MAX = 256;

export interface ScreenStoreOptions {
  /** The descriptor class name this store is keyed by. */
  readonly descriptor: string;
  /**
   * The route the remembered rate and view are stored under, `''` for a screen with none.
   *
   * **Keyed by route, not by descriptor** (Story 15.5): the stored row is a weak reference to a
   * screen (AD-37), and a route is what the instance can gate with the screen registry, exactly as
   * it gates a favorite. The store itself is still keyed by descriptor, which is the identity AD-5
   * makes stable.
   */
  readonly route: string;
  /** The rates the descriptor permits, so a stored rate outside them falls back. */
  readonly rates: readonly number[];
  /** Where the rate and the view choices are remembered (AD-50). */
  readonly account: AccountPreferences;
}

export class ScreenStore {
  private readonly descriptor: string;
  private readonly route: string;
  private readonly permitted: readonly number[];
  private readonly account: AccountPreferences;

  /** Whether the instance's answer has been adopted since the last sign-in; `ShellState`'s flag. */
  private adopted = false;

  /** Released by `ScreenStores.reset()`, so a dropped store stops listening to the account store. */
  private stopAccount: () => void = () => {};

  private rows: readonly ScreenRow[] = [];
  private truncatedFlag = false;
  private bannerKey = '';
  private refusalText = '';
  private lastUpdateAt: Date | null = null;
  private selected: readonly string[] = [];
  private activeKey = '';
  private changedKeys: ReadonlySet<string> = new Set();
  private changedActions: ReadonlyMap<string, string> = new Map();
  private pendingSelectionKey = '';
  private scrollTop = 0;
  private sortBy = '';
  private sortDirection: SortDirection = '';
  private filterText = '';
  private rowCap = DEFAULT_MAX_ROWS;
  private widths: ReadonlyMap<string, number> = new Map();
  private rateSeconds = RATE_OFF;

  private readonly listeners = new Set<() => void>();

  constructor(options: ScreenStoreOptions) {
    this.descriptor = options.descriptor;
    this.route = options.route;
    this.permitted = options.rates;
    this.account = options.account;
    this.stopAccount = this.account.subscribe(() => this.adoptRemembered());
    this.adoptRemembered();
  }

  /**
   * Take the instance's remembered rate and view, once, on the first answer that carries them.
   *
   * Until the read settles the published defaults render -- off, and a cap of `DEFAULT_MAX_ROWS`
   * -- and a read that failed keeps them rather than clearing anything. A rate the descriptor no
   * longer permits falls back to off, which is the published default and a state the chip can
   * name; a view member of the wrong shape falls back field by field.
   */
  private adoptRemembered(): void {
    if (!this.account.loaded()) {
      this.adopted = false;
      return;
    }
    if (this.adopted || this.route === '') return;
    this.adopted = true;
    let moved = false;
    const rate = Number(this.account.refreshRates().get(this.route) ?? '');
    if (Number.isFinite(rate) && this.permitted.includes(rate) && rate !== this.rateSeconds) {
      this.rateSeconds = rate;
      moved = true;
    }
    const view = this.storedView();
    if (view !== null) {
      this.sortBy = view.sort;
      this.sortDirection = view.direction === 'asc' || view.direction === 'desc' ? view.direction : '';
      this.filterText = view.filter;
      this.rowCap = view.maxRows;
      this.widths = view.widths;
      moved = true;
    }
    if (moved) this.notify();
  }

  /** The remembered view, or `null` when nothing usable is stored. */
  private storedView(): ScreenViewPreference | null {
    const raw = this.account.views().get(this.route);
    if (raw === undefined) return null;
    let parsed: unknown;
    try {
      parsed = JSON.parse(raw) as unknown;
    } catch {
      return null;
    }
    if (typeof parsed !== 'object' || parsed === null || Array.isArray(parsed)) return null;
    const view = parsed as Record<string, unknown>;
    const text = (value: unknown): string => (typeof value === 'string' ? value : '');
    const cap = view['maxRows'];
    return {
      sort: text(view['sort']),
      direction: text(view['direction']),
      filter: text(view['filter']),
      maxRows: typeof cap === 'number' && Number.isSafeInteger(cap) && cap > 0 ? cap : DEFAULT_MAX_ROWS,
      widths: storedWidths(view['widths']),
    };
  }

  key(): string {
    return this.descriptor;
  }

  /**
   * Stop listening to the account store. Called only by `ScreenStores.reset()`: a store the map
   * has dropped is unreachable, and one still subscribed would be notified for the life of the tab
   * -- one leaked listener per screen the departed principal opened.
   */
  release(): void {
    this.stopAccount();
    this.stopAccount = () => {};
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
    this.changedActions = new Map();
    this.pendingSelectionKey = '';
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

  /**
   * Mark `key` changed, recording what the event said happened to it (AD-14's closed action set).
   *
   * `action` is kept beside the mark rather than inside it because `changed()` answers a question
   * the table asks per row -- "is this one highlighted" -- and widening its return type would make
   * every reader unpack a pair to ask it. The action has exactly one reader: the polite
   * announcement, which names what happened.
   */
  markChanged(key: string, action: string = ''): void {
    if (key === '') return;
    if (this.changedKeys.has(key) && (this.changedActions.get(key) ?? '') === action) return;
    this.changedKeys = new Set([...this.changedKeys, key]);
    this.changedActions = new Map([...this.changedActions, [key, action]]);
    this.notify();
  }

  /** What the change event that marked `key` said happened, or `''`. */
  changedAction(key: string): string {
    return this.changedActions.get(key) ?? '';
  }

  clearChanged(key: string): void {
    if (!this.changedKeys.has(key)) return;
    const next = new Set(this.changedKeys);
    next.delete(key);
    this.changedKeys = next;
    const actions = new Map(this.changedActions);
    actions.delete(key);
    this.changedActions = actions;
    this.notify();
  }

  /**
   * The key of a row that is to become the selection as soon as a read returns it, or `''`.
   *
   * **Two callers write it.** A `created` change (AD-14): a row that did not exist a moment ago
   * is the one thing a re-fetch can bring that the user has not seen, so the screen puts the caret
   * on it -- an `updated` or `deleted` change writes nothing here, because the row is already
   * where the user left it, or it is gone and `reconcile` clears the selection. And a list opened
   * on its own route id (`ListPage`, DW-1419), where the id names the row the agent's navigation
   * or a change toast asked to be shown.
   *
   * It is a request, not a selection: the key is not in the row set yet, and the table consumes
   * it on the tick that brings it. A read that never brings it leaves it standing until the next
   * `clearAnswers`, which is correct -- a create the instance has not finished is still a create.
   */
  pendingSelection(): string {
    return this.pendingSelectionKey;
  }

  setPendingSelection(key: string): void {
    if (key === '' || key === this.pendingSelectionKey) return;
    this.pendingSelectionKey = key;
    this.notify();
  }

  clearPendingSelection(): void {
    if (this.pendingSelectionKey === '') return;
    this.pendingSelectionKey = '';
    this.notify();
  }

  scroll(): number {
    return this.scrollTop;
  }

  setScroll(offset: number): void {
    this.scrollTop = offset;
    this.notify();
  }

  // --- What the user chose, remembered per user on the instance -------------------------------

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

  /**
   * The column widths the user set, in CSS px keyed by field (Story 15.8). A column absent here
   * takes its kind's default; a field the table does not declare is the table's to ignore.
   */
  columnWidths(): ReadonlyMap<string, number> {
    return this.widths;
  }

  /**
   * Set one column's width. Refused, changing and remembering nothing, for an empty field or a
   * width that is not a positive safe integer of at most `COLUMN_WIDTH_MAX`, as `setMaxRows`
   * refuses a cap that is not a row count.
   */
  setColumnWidth(field: string, px: number): boolean {
    if (field === '' || !isColumnWidth(px)) return false;
    if (this.widths.get(field) === px) return true;
    this.widths = new Map([...this.widths, [field, px]]);
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
    if (this.route !== '') void this.account.setValue(REFRESH_KIND, this.route, String(seconds));
    this.notify();
    return true;
  }

  /**
   * Send this screen's view to the instance. Never awaited: the table has already moved, and a
   * refusal is recorded as a fault the shell's surfaces announce (DW-1326).
   */
  private rememberView(): void {
    if (this.route === '') return;
    const view: Record<string, unknown> = {
      sort: this.sortBy,
      direction: this.sortDirection,
      filter: this.filterText,
      maxRows: this.rowCap,
    };
    // Only a screen whose columns the user sized carries `widths`, so every other view is the
    // value it was before column widths existed.
    if (this.widths.size > 0) view['widths'] = Object.fromEntries(this.widths);
    const value = JSON.stringify(view);
    if (value.length > PREFERENCE_VALUE_MAX) return;
    void this.account.setValue(VIEW_KIND, this.route, value);
  }

  private notify(): void {
    for (const listener of [...this.listeners]) listener();
  }
}

/**
 * The widths a remembered view carries: an object of field to width, each entry of any other shape
 * dropped on its own. Anything but a plain object reads as no widths.
 */
function storedWidths(raw: unknown): ReadonlyMap<string, number> {
  const widths = new Map<string, number>();
  if (typeof raw !== 'object' || raw === null || Array.isArray(raw)) return widths;
  for (const [field, px] of Object.entries(raw as Record<string, unknown>)) {
    if (field !== '' && isColumnWidth(px)) widths.set(field, px);
  }
  return widths;
}

/**
 * The one store per descriptor, for as long as the tab lives.
 *
 * Keyed by descriptor rather than by route so a detail screen's several URLs share one store,
 * and held across navigation so "the stored rate is restored" needs no re-read on the way back.
 */
export class ScreenStores {
  private readonly account: AccountPreferences;
  private readonly stores = new Map<string, ScreenStore>();

  constructor(options: { readonly account: AccountPreferences }) {
    this.account = options.account;
  }

  /**
   * The store for `descriptor`, created on first ask.
   *
   * `route` is what the store's remembered rate and view are keyed by (Story 15.5). A caller
   * holding the screen declaration passes its own, which is what lets a declaration the mirror
   * does not carry -- a test's, a fixture's -- be remembered too; every other caller lets it
   * resolve from the mirror, so no page has to hold both identities. A descriptor with neither,
   * and Home, whose route is the empty string, remember nothing.
   */
  for(descriptor: string, rates: readonly number[], route?: string): ScreenStore {
    const held = this.stores.get(descriptor);
    if (held !== undefined) return held;
    const keyedBy = route ?? screenForDescriptor(descriptor)?.route ?? '';
    const store = new ScreenStore({ descriptor, route: keyedBy, rates, account: this.account });
    this.stores.set(descriptor, store);
    return store;
  }

  /**
   * Drop every store. Sign-out clears the tab in place without a reload, and a screen's rows are
   * data **this** principal was allowed to read (AD-8). The remembered choices are the departing
   * principal's own rows on the instance and are not touched: dropping the stores is what makes
   * the next principal's own answer the one the next store adopts.
   */
  reset(): void {
    for (const store of this.stores.values()) store.release();
    this.stores.clear();
  }
}
