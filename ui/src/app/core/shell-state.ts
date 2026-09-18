/**
 * The shell's own state, shared by the components that make up the frame: which area's screen
 * list is on screen, whether it is showing, and whether the routed screen may mount yet.
 *
 * Framework-free like the rest of `core/`, provided as a value in `main.ts`, so `node --test`
 * executes it and no component owns state another has to read out of it.
 *
 * The first three are the areas, and the distinction between the first two is what makes the
 * rail's behaviour expressible at all (EXPERIENCE.md "The VS Code-shaped shell", "`{spacing.side-bar-width}` (240 px, fixed — no drag)", "Click opens the side-bar listing"):
 *
 * - `activeArea` -- the area of the route currently open. It follows the router and nothing
 *   else, and it is what carries `aria-current="page"`.
 * - `visibleArea` -- the area whose side bar is listed. A rail click sets it **without
 *   navigating**, which is the whole point of the rail: you can look at one area's screens
 *   while another area's screen is open.
 * - `open` -- whether the side bar is showing. Remembered per browser through
 *   `PreferenceStore`, which is the only module that touches persistent storage.
 *
 * The fourth is `holdScreen`/`screenHeld`, which is about the routed screen rather than the chrome
 * around it: while the shell is still deciding where this browser belongs, `ScreenOutlet` mounts
 * no page. It lives here rather than in either component because the router creates
 * `ScreenOutlet`, so `App` -- which takes the hold for the first-login gate -- has no input to
 * bind it through.
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

  /** How many holds are outstanding on the routed screen; see `holdScreen`. */
  private holds = 0;

  /**
   * The most recent agent-navigation arrival (Story 4.7, AD-11 rule 3): the route it landed on
   * and the heading announcement `locator-bar.ts` reads as that screen's `aria-label`, so the
   * label is present only on the arrival it describes and never on an ordinary, user-initiated
   * one. `null` route means no arrival is standing.
   */
  private arrivalRoute: string | null = null;
  private arrivalAnnouncementValue = '';

  /** Bumped on every `announceArrival`, so `arrivalToken` can tell two arrivals at the same
   * screen apart even when they carry the identical announcement text -- the title is the only
   * thing the heading announcement names, so opening the same screen twice in a row produces the
   * same string both times. */
  private arrivalSeq = 0;

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

  /** Whether a hold is outstanding, so `ScreenOutlet` must mount no page yet. */
  screenHeld(): boolean {
    return this.holds > 0;
  }

  /**
   * Record that the agent's own navigation just landed on `route`, carrying the heading
   * announcement `locator-bar.ts` reads for that route's segment (Story 4.7).
   */
  announceArrival(route: string, announcement: string): void {
    this.arrivalRoute = route;
    this.arrivalAnnouncementValue = announcement;
    this.arrivalSeq += 1;
    this.notify();
  }

  /** The standing arrival announcement for `route`, or `null` when none is standing there. */
  arrivalAnnouncement(route: string): string | null {
    return this.arrivalRoute === route ? this.arrivalAnnouncementValue : null;
  }

  /**
   * A token that changes on every fresh arrival at `route`, or `null` when none is standing
   * there -- a reader that needs to tell two arrivals apart (to focus the heading again on a
   * second, identical announcement) compares this rather than the announcement text.
   */
  arrivalToken(route: string): number | null {
    return this.arrivalRoute === route ? this.arrivalSeq : null;
  }

  /**
   * Drop the standing arrival, so it does not survive the navigation that follows it -- the
   * announcement is for the one screen the agent opened, not for whatever the user goes to next.
   * `app.ts` calls this on every `NavigationStart`, agent-initiated or not.
   */
  clearArrival(): void {
    if (this.arrivalRoute === null) return;
    this.arrivalRoute = null;
    this.arrivalAnnouncementValue = '';
    this.notify();
  }

  /**
   * Hold the routed screen off the outlet until the returned function is called.
   *
   * The caller is a decision that may move this browser somewhere else -- the first-login gate
   * (FR-28) -- and the point of the hold is that mounting a screen issues that screen's declared
   * read (AD-36) against a store the navigation then throws away. It is the same rule the outlet
   * already applies to a navigation map that has not answered.
   *
   * A count rather than a flag, and a release rather than a setter: a sign-out and a second
   * sign-in can start a second decision while the first is still running, and a flag either of
   * them cleared would release the screen under the other.
   */
  holdScreen(): () => void {
    this.holds += 1;
    this.notify();
    let released = false;
    return () => {
      if (released) return;
      released = true;
      this.holds -= 1;
      this.notify();
    };
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
   * (EXPERIENCE.md "rail-items in daily-use order: Home"). Clicking the item whose list is already showing collapses it.
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
