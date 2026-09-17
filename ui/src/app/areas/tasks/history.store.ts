/**
 * Task history's own state (AD-19): what the search field and the user-defined-only checkbox
 * hold, whether Search has been pressed at all, and the one `RefreshRead` the page binds.
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
import type { ScreenReadCriteria } from '../../core/screen-read';

export class TaskHistorySearch {
  private searchValue = '';

  private userOnlyValue = false;

  private searchedOnce = false;

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

  /**
   * What the read sends: `search` when the field holds text, `userOnly` `'1'` when the checkbox is
   * checked, and nothing for either otherwise -- the checkbox's unchecked state is `false`, not
   * `''`, so it is translated here rather than left to the generic empty-value omission
   * `createScreenRead` already applies.
   */
  criteria(): ScreenReadCriteria {
    const sent: Record<string, string> = {};
    if (this.searchValue !== '') sent['search'] = this.searchValue;
    if (this.userOnlyValue) sent['userOnly'] = '1';
    return sent;
  }

  /**
   * The one `RefreshRead` this store holds, built by `create` on first ask and handed back
   * unchanged afterwards -- `create` is the page's own `() => createScreenRead(api, screen, () =>
   * this.criteria())`, kept out of this class so it stays free of `ApiService` and therefore of
   * Angular's injector.
   */
  readFor(create: () => RefreshRead): RefreshRead {
    if (this.cachedRead === null) this.cachedRead = create();
    return this.cachedRead;
  }

  private notify(): void {
    for (const listener of [...this.listeners]) listener();
  }
}
