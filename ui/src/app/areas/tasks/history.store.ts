/**
 * Task history's own state (AD-19): what the search field, the user-defined-only checkbox and the
 * logged-since field hold, whether Search has been pressed at all, what the next read sends, and
 * the one `RefreshRead` the page binds.
 *
 * **Framework-free, held beside the screen's store.** It imports nothing from Angular, so it runs
 * under `node --test` (`ui/tools/history-store.test.mjs`), the same shape `UpcomingHorizon` takes
 * and for the same reason -- `history.page.ts` holds one instance per `ScreenStore`, in a
 * `WeakMap`, so it outlives the page as the rows do.
 *
 * **It is load-bearing across the detail dialog.** `TaskHistoryList`'s row detail opens on its own
 * `/:id` route (AD-13), a different route config from the bare route, so Angular destroys and
 * re-creates the page around every dialog open and close. `readFor` hands back the *same*
 * `RefreshRead` object every time, which is what makes the page's re-bind on that round trip a
 * no-op (`RefreshService.bind` compares the read by reference) -- without it, closing the dialog
 * would look like a fresh navigation and re-issue the search the user already ran.
 */

import type { RefreshRead } from '../../core/refresh';
import type { ScreenArrival } from '../../core/screen-arrival';
import type { ScreenReadCriteria } from '../../core/screen-read';

/** The three criteria the Task history form carries, by their declared names. */
const PARAMS = ['search', 'userOnly', 'since'] as const;

/**
 * What the next read sends (Story 11.11): the default (nothing, so the instance applies `since`'s
 * seven days), the form as shown, or an agent arrival's criteria exactly.
 */
type RequestMode = 'default' | 'form' | 'arrival';

export class TaskHistorySearch {
  private searchValue = '';

  private userOnlyValue = false;

  private sinceValue = '';

  private searchedOnce = false;

  private mode: RequestMode = 'default';

  private arrivalSent: Record<string, string> = {};

  /** Set when a closing dialog asks the next page instance to put focus back on the grid. */
  private gridFocusWanted = false;

  private cachedRead: RefreshRead | null = null;

  /**
   * Bumped whenever a page instance is created, so a destroyed instance can tell "the user left
   * this screen" from "another instance of this screen took over" -- the same reason
   * `AuditSearch.pageGeneration` exists: the detail dialog's route is a second config over this
   * screen, so Angular can construct the next instance before it destroys this one.
   */
  private pageGeneration = 0;

  private readonly listeners = new Set<() => void>();

  subscribe(listener: () => void): () => void {
    this.listeners.add(listener);
    return () => {
      this.listeners.delete(listener);
    };
  }

  search(): string {
    return this.searchValue;
  }

  setSearch(value: string): void {
    this.searchValue = value;
    this.notify();
  }

  userOnly(): boolean {
    return this.userOnlyValue;
  }

  setUserOnly(value: boolean): void {
    this.userOnlyValue = value;
    this.notify();
  }

  /** The logged-since bound the form shows: the applied default on open, or what was typed. */
  since(): string {
    return this.sinceValue;
  }

  setSince(value: string): void {
    this.sinceValue = value;
    this.notify();
  }

  /** Whether Search has been pressed since this screen store was created. */
  searched(): boolean {
    return this.searchedOnce;
  }

  noteSearched(): void {
    this.searchedOnce = true;
    this.notify();
  }

  /** A page instance's own generation, taken in its constructor. */
  takeGeneration(): number {
    this.pageGeneration += 1;
    return this.pageGeneration;
  }

  /** Whether `generation` is still the newest page instance's. */
  isCurrentGeneration(generation: number): boolean {
    return this.pageGeneration === generation;
  }

  /** Ask the page instance the next navigation creates to put focus back on the grid. */
  requestGridFocus(): void {
    this.gridFocusWanted = true;
  }

  /** Whether a grid focus was asked for, clearing the request either way. */
  takeGridFocusRequest(): boolean {
    const wanted = this.gridFocusWanted;
    this.gridFocusWanted = false;
    return wanted;
  }

  /** Open on the default read: nothing is sent, and every field is then filled from the answer. */
  useDefault(): void {
    this.mode = 'default';
    this.searchValue = '';
    this.userOnlyValue = false;
    this.sinceValue = '';
    this.notify();
  }

  /** Send the form as shown from the next read on: Search, and a return after one. */
  useForm(): void {
    this.mode = 'form';
    this.notify();
  }

  /**
   * Run an agent arrival's search exactly (Story 11.11): the criteria it carries and nothing else,
   * shown in the form, with the fields it left absent filled from the answer.
   */
  useArrival(arrival: ScreenArrival): void {
    const sent: Record<string, string> = {};
    for (const param of PARAMS) {
      const value = arrival.criteria[param];
      if (typeof value === 'string') sent[param] = value;
    }
    this.searchValue = sent['search'] ?? '';
    this.userOnlyValue = sent['userOnly'] === '1';
    this.sinceValue = sent['since'] ?? '';
    this.arrivalSent = sent;
    this.mode = 'arrival';
    this.notify();
  }

  /**
   * What the next read sends, read at call time: nothing on the default read, an arrival's criteria
   * exactly, or the form as shown -- `search` and `since` as typed, an emptied one sent empty so its
   * bound is unset, and `userOnly` as `'1'` checked or empty unchecked, the vendor's own
   * `DescendingTaskHistoryFilter(filter, userOnly)` distinction.
   */
  criteria(): ScreenReadCriteria {
    if (this.mode === 'default') return {};
    if (this.mode === 'arrival') return { ...this.arrivalSent };
    return { search: this.searchValue, userOnly: this.userOnlyValue ? '1' : '', since: this.sinceValue };
  }

  /**
   * Fill each field the request `sent` left absent from the answer's `applied` criteria (AD-36), so
   * the form shows the values the instance used -- `since` above all, whose default the browser
   * never computes. An answer to a request since replaced changes nothing.
   */
  applyEcho(applied: Readonly<Record<string, string>>, sent: ScreenReadCriteria): void {
    if (JSON.stringify(sent) !== JSON.stringify(this.criteria())) return;
    let changed = false;
    if (sent['search'] === undefined) {
      this.searchValue = applied['search'] ?? '';
      changed = true;
    }
    if (sent['userOnly'] === undefined) {
      this.userOnlyValue = applied['userOnly'] === '1';
      changed = true;
    }
    if (sent['since'] === undefined) {
      this.sinceValue = applied['since'] ?? '';
      changed = true;
    }
    if (changed) this.notify();
  }

  /**
   * The one `RefreshRead` this store holds, built by `create` on first ask and handed back
   * unchanged afterwards -- `create` is the page's own `createScreenRead` over `criteria()` and
   * `applyEcho`, kept out of this class so it stays free of `ApiService` and therefore of Angular's
   * injector.
   */
  readFor(create: () => RefreshRead): RefreshRead {
    if (this.cachedRead === null) this.cachedRead = create();
    return this.cachedRead;
  }

  private notify(): void {
    for (const listener of [...this.listeners]) listener();
  }
}
