/**
 * The one piece of state the rail and the side bar share: which area's screen list is on
 * screen, and whether it is showing.
 *
 * Framework-free like the rest of `core/`, provided as a value in `main.ts`, so `node --test`
 * executes it and neither component owns state the other has to read out of it.
 *
 * Three values, and the distinction between the first two is what makes the rail's behaviour
 * expressible at all (EXPERIENCE.md `:48`, `:51`, `:312`):
 *
 * - `activeArea` -- the area of the route currently open. It follows the router and nothing
 *   else, and it is what carries `aria-current="page"`.
 * - `visibleArea` -- the area whose side bar is listed. A rail click sets it **without
 *   navigating**, which is the whole point of the rail: you can look at one area's screens
 *   while another area's screen is open.
 * - `open` -- whether the side bar is showing. Remembered per browser through
 *   `PreferenceStore`, which is the only module that touches persistent storage.
 */

// The `.ts` extension is what lets `node --test` resolve this at runtime; see
// `tsconfig.json`'s `allowImportingTsExtensions`.
import { PreferenceStore } from './preferences.ts';

/** The side bar starts open, so a first-time visitor sees the screen list exists. */
export const SIDE_BAR_OPEN_DEFAULT = true;

export interface ShellStateOptions {
  readonly preferences: PreferenceStore;
}

export class ShellState {
  private readonly preferences: PreferenceStore;

  private currentActiveArea = '';
  private currentVisibleArea = '';
  private currentOpen: boolean;

  private readonly listeners = new Set<() => void>();

  constructor(options: ShellStateOptions) {
    this.preferences = options.preferences;
    this.currentOpen = this.preferences.sideBarOpen(SIDE_BAR_OPEN_DEFAULT);
  }

  subscribe(listener: () => void): () => void {
    this.listeners.add(listener);
    return () => {
      this.listeners.delete(listener);
    };
  }

  activeArea(): string {
    return this.currentActiveArea;
  }

  visibleArea(): string {
    return this.currentVisibleArea;
  }

  open(): boolean {
    return this.currentOpen;
  }

  /**
   * The router moved. The active area follows it, and so does the side bar's contents unless
   * the user is deliberately looking at another area's list -- which they are exactly when the
   * side bar is open on a different area.
   */
  setActiveArea(areaKey: string): void {
    if (this.currentActiveArea === areaKey) return;
    this.currentActiveArea = areaKey;
    if (!this.currentOpen || this.currentVisibleArea === '') this.currentVisibleArea = areaKey;
    this.notify();
  }

  /**
   * A rail item was activated. Opening an area's list is not navigating to it: only Home's
   * item navigates, and its own side bar does not exist, so it collapses instead
   * (EXPERIENCE.md `:48`). Clicking the item whose list is already showing collapses it.
   *
   * **Home's collapse is not the user's preference (DW-134).** Home has no screen list, so
   * the bar goes away because there is nothing to show -- the user never asked for it to be
   * closed. Writing that through to storage made the next area they opened start collapsed,
   * which is why this branch moves the visible state without touching `PreferenceStore`,
   * while `toggleOpen()`, where the user did ask, still persists.
   *
   * Returns whether the caller should navigate, so the routing half stays in the component
   * that has a `Router` and this class stays framework-free.
   */
  activateArea(areaKey: string, navigates: boolean): boolean {
    if (navigates) {
      this.currentVisibleArea = areaKey;
      this.currentOpen = false;
      this.notify();
      return true;
    }
    if (this.currentOpen && this.currentVisibleArea === areaKey) {
      this.setOpen(false);
      this.notify();
      return false;
    }
    this.currentVisibleArea = areaKey;
    this.setOpen(true);
    this.notify();
    return false;
  }

  /**
   * Show this area's screen list, open, whatever was showing before -- Home's area tiles
   * (Story 1.12).
   *
   * Deliberately **not** `activateArea`: that method's click-to-collapse branch is the rail's
   * own behaviour, where clicking the item whose list is already showing closes it. A tile is
   * not a rail item, it is not where the list already is, and activating one twice must leave
   * the area open rather than toggling it shut. Persisting is right here for the same reason it
   * is right in `activateArea`'s opening branch: opening an area is the user asking.
   */
  showArea(areaKey: string): void {
    this.currentVisibleArea = areaKey;
    this.setOpen(true);
    this.notify();
  }

  /**
   * Collapse the side bar **without** remembering it (**DW-144**).
   *
   * Escape is a dismissal, not an answer: it says "not this, now", where Ctrl/Cmd+B says "keep
   * it closed". Routing Escape through `toggleOpen()` wrote the dismissal into
   * `PreferenceStore`, so the next area the user opened -- and the next tab they loaded --
   * started collapsed against a preference they had set to open and never changed. This moves
   * the visible state alone, the way `activateArea`'s Home branch already does.
   */
  collapse(): void {
    if (!this.currentOpen) return;
    this.currentOpen = false;
    this.notify();
  }

  /** Ctrl/Cmd+B, and the side bar's own collapse. */
  toggleOpen(): void {
    if (this.currentVisibleArea === '') this.currentVisibleArea = this.currentActiveArea;
    this.setOpen(!this.currentOpen);
    this.notify();
  }

  private setOpen(next: boolean): void {
    this.currentOpen = next;
    this.preferences.setSideBarOpen(next);
  }

  private notify(): void {
    for (const listener of this.listeners) listener();
  }
}
