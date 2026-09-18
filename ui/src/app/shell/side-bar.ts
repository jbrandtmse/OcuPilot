import {
  ChangeDetectionStrategy,
  Component,
  DestroyRef,
  ElementRef,
  computed,
  effect,
  inject,
  signal,
} from '@angular/core';
import { Router } from '@angular/router';

import {
  NavigationService,
  areaByKey,
  formatArea,
  formatRequires,
  screenForUrl,
  tabGroupFor,
  withQuery,
} from '../core/navigation';
import { OverlayStack } from '../core/overlay-stack';
import { PanelState } from '../core/panel-layout';
import { ShellState } from '../core/shell-state';
import { STRINGS, stringFor } from '../core/strings';
import { railItemDomId } from './rail';

/** The side bar's name on the overlay stack. It is the stack's bottom-most member (DW-137). */
export const SIDE_BAR_OVERLAY_ID = 'side-bar';

/** One side-bar entry, resolved for rendering. */
interface SideBarEntry {
  readonly route: string;
  readonly label: string;
  readonly reason: string;
  readonly reasonId: string;
  /** The reason element's id, but only when one is rendered — a gated entry alone has one. */
  readonly describedBy: string | null;
  readonly gated: boolean;
  readonly ariaDisabled: string | null;
  readonly ariaCurrent: string | null;
  readonly tabIndex: number;
}

/**
 * The chord that toggles the side bar, on both platforms (EXPERIENCE.md "toggle the side-bar; with focus").
 *
 * `shiftKey` is excluded (**DW-134**): Ctrl+Shift+B is a different chord, and on Chrome it is
 * the bookmarks-bar toggle, so treating it as this one both fires on a key press the user
 * aimed elsewhere and writes a preference they never set.
 */
export function isSideBarChord(event: KeyboardEvent): boolean {
  return (
    (event.ctrlKey || event.metaKey) &&
    !event.altKey &&
    !event.shiftKey &&
    event.key.toLowerCase() === 'b'
  );
}

/**
 * The primary side bar: the current area's screens, at a fixed 240px with no resize affordance
 * -- the panel is the only resizable edge in the shell (DESIGN.md `:258-271`).
 *
 * **It lists only screens that are built** (EXPERIENCE.md "Entries in daily-use order."). At the end of Epic 1 that is
 * every area's empty list, because the six areas' first screens are Epic 2's: an area's side bar
 * opens, names the area, and lists nothing. That is the correct rendering of the rule, not a
 * missing empty state.
 *
 * **Absent on Home** (EXPERIENCE.md "`{spacing.side-bar-width}` (240 px, fixed — no drag)"), which has no screen list at all -- its rail item
 * navigates and collapses instead.
 *
 * **Gated entries stay listed and focusable** with `aria-disabled="true"` and the failed
 * `(resource, permission)` pair **inline after the label**, which is what the side bar does
 * instead of relying on a tooltip (EXPERIENCE.md "Fixed at `{spacing.side-bar-width}`"); the same element is the entry's
 * `aria-describedby`, so the reason is announced on focus as well as read on screen.
 *
 * **Keyboard.** Arrow keys move between entries and Enter opens, through the same roving
 * tabindex the rail uses. Ctrl/Cmd+B toggles the side bar from anywhere, and with focus already
 * inside it moves focus to that area's rail item (EXPERIENCE.md "Fixed at `{spacing.side-bar-width}`", "toggle the side-bar; with focus", "**Focus destinations.** No control"). The
 * chord is ignored while a dialog is open (`:530-532`) and while anything else is stacked over
 * the bar, which is the same rule stated over the one authority that knows what is open.
 *
 * **Escape reaches the bar only when nothing is over it (DW-137).** The bar registers with the
 * overlay stack while it is showing, as the stack's bottom-most member, so an Escape with the
 * command box open closes the box and leaves the bar alone, and the next Escape collapses the
 * bar. The shell's one Escape handler is what asks; this component only says what closing
 * means -- including moving focus to the area's rail item first when focus is inside, because
 * nothing may be removed while it holds focus.
 *
 * **Escape does not write the preference (DW-144).** It is a dismissal, so it takes
 * `ShellState.collapse()`; Ctrl/Cmd+B is the user answering the question, so it keeps
 * `toggleOpen()`, which persists.
 *
 * Open state is remembered per browser through `PreferenceStore`, the one module permitted to
 * touch persistent storage.
 */
@Component({
  selector: 'app-side-bar',
  changeDetection: ChangeDetectionStrategy.OnPush,
  host: { '(document:keydown)': 'onGlobalKeydown($event)' },
  template: `@if (visible) {
    <nav class="ocu-side-bar" [attr.aria-label]="landmark">
      <p class="ocu-side-bar-eyebrow">{{ areaLabel }}</p>
      @for (entry of entries; track entry.route) {
        <button
          type="button"
          class="ocu-side-bar-item"
          [attr.aria-current]="entry.ariaCurrent"
          [attr.aria-disabled]="entry.ariaDisabled"
          [attr.aria-describedby]="entry.describedBy"
          [attr.tabindex]="entry.tabIndex"
          [class.ocu-side-bar-item-selected]="entry.ariaCurrent"
          [class.ocu-side-bar-item-gated]="entry.gated"
          (click)="open(entry)"
          (keydown)="onKeydown($event)"
        >
          <span class="ocu-side-bar-label">{{ entry.label }}</span>
          @if (entry.gated) {
            <span class="ocu-side-bar-reason" [id]="entry.reasonId">{{ entry.reason }}</span>
          }
        </button>
      }
    </nav>
  }`,
})
export class SideBar {
  private readonly navigation = inject(NavigationService);
  private readonly shell = inject(ShellState);
  private readonly overlays = inject(OverlayStack);
  private readonly panel = inject(PanelState);
  private readonly router = inject(Router);
  private readonly host: ElementRef<HTMLElement> = inject(ElementRef);

  private readonly generation = signal(0);

  private readonly focusedIndex = signal(0);

  private readonly area = computed(() => {
    this.generation();
    return this.shell.visibleArea();
  });

  private readonly resolved = computed<readonly SideBarEntry[]>(() => {
    this.generation();
    const active = this.shell.activeArea();
    const areaKey = this.area();
    const screens = this.navigation.screensForArea(areaKey);
    // Clamped, not read raw: the index survives a change of visible area, and an area with
    // fewer entries than the last one would otherwise leave every entry at -1 -- a side bar
    // with no tab stop at all, unreachable by keyboard.
    const focused = Math.min(this.focusedIndex(), Math.max(0, screens.length - 1));
    // Every tab of a tabbed screen marks its group's one entry current (AD-5).
    const current = screenForUrl(this.router.url);
    const groupRoute = current === null ? '' : tabGroupFor(current)?.route ?? '';
    return screens.map((screen, index) => {
      const verdict = this.navigation.screenVerdict(screen.route);
      const isCurrent = areaKey === active && (screen.route === this.currentRoute() || (groupRoute !== '' && screen.route === groupRoute));
      const reasonId = `ocu-side-bar-reason-${screen.route.replace(/\//g, '-')}`;
      return {
        route: screen.route,
        label: stringFor(screen.labelKey),
        reason: formatRequires(STRINGS.privilegeRequiresResource, verdict.failedPair),
        reasonId,
        describedBy: verdict.allowed ? null : reasonId,
        gated: !verdict.allowed,
        ariaDisabled: verdict.allowed ? null : 'true',
        ariaCurrent: isCurrent ? 'page' : null,
        tabIndex: index === focused ? 0 : -1,
      };
    });
  });

  /** Absent on Home, absent while collapsed, and absent while the width yields it (DESIGN.md Yield order). */
  private readonly showing = computed(() => {
    this.generation();
    const areaKey = this.area();
    if (areaKey === '') return false;
    const area = areaByKey(areaKey);
    if (area !== null && area.navigates) return false;
    return this.shell.open() && this.panel.layout().sideBarShown;
  });

  constructor() {
    const stopNavigation = this.navigation.subscribe(() => this.bump());
    const stopShell = this.shell.subscribe(() => this.bump());
    // A width that yields the bar removes it at the next render; focus inside leaves first.
    const stopPanel = this.panel.subscribe(() => {
      if (!this.panel.layout().sideBarShown) this.yieldFocusToRail();
      this.bump();
    });
    const stopRouter = this.router.events.subscribe(() => this.bump());
    inject(DestroyRef).onDestroy(() => {
      stopNavigation();
      stopShell();
      stopPanel();
      stopRouter.unsubscribe();
      this.overlays.remove(SIDE_BAR_OVERLAY_ID);
    });

    // Registered exactly while it is on screen, at the bottom of the stack: a bar that opened
    // while the command box was already up still sits under it, so Escape's order does not
    // depend on which surface appeared first.
    effect(() => {
      if (this.showing()) {
        this.overlays.push(SIDE_BAR_OVERLAY_ID, () => this.closeFromKeyboard(), 'bottom');
        return;
      }
      this.overlays.remove(SIDE_BAR_OVERLAY_ID);
    });
  }

  protected get visible(): boolean {
    return this.showing();
  }

  protected get areaLabel(): string {
    const area = areaByKey(this.area());
    return area === null ? '' : stringFor(area.labelKey);
  }

  protected get landmark(): string {
    return formatArea(STRINGS.navSideBarLandmark, this.areaLabel);
  }

  protected get entries(): readonly SideBarEntry[] {
    return this.resolved();
  }

  /** Open a screen. A gated entry does nothing; it is refused here, not by the DOM. */
  protected open(entry: SideBarEntry): void {
    if (entry.gated) return;
    const index = this.resolved().findIndex((candidate) => candidate.route === entry.route);
    if (index >= 0) this.focusedIndex.set(index);
    // The current query travels with the entry: `?ns=` is data scope, and opening a screen
    // from the side bar must not move the user's work to another namespace (AD-44, DW-134).
    void this.router.navigateByUrl(withQuery(entry.route, this.router.url));
  }

  protected onKeydown(event: KeyboardEvent): void {
    const count = this.resolved().length;
    if (count === 0) return;
    const current = this.focusedIndex();
    let next = current;
    if (event.key === 'ArrowDown') next = (current + 1) % count;
    else if (event.key === 'ArrowUp') next = (current - 1 + count) % count;
    else if (event.key === 'Home') next = 0;
    else if (event.key === 'End') next = count - 1;
    else return;
    event.preventDefault();
    this.focusedIndex.set(next);
    const buttons = this.host.nativeElement.querySelectorAll<HTMLButtonElement>('.ocu-side-bar-item');
    buttons.item(next)?.focus();
  }

  /**
   * Ctrl/Cmd+B. With focus already inside the side bar the toggle also hands focus to the
   * area's rail item, so nothing is collapsed out from under the keyboard.
   */
  protected onGlobalKeydown(event: KeyboardEvent): void {
    if (!isSideBarChord(event)) return;
    if (document.querySelector('[role="dialog"]') !== null) return;
    // Full screen covers the bar; the chord would toggle, and persist, a bar nobody can see.
    if (this.panel.fullScreen()) return;
    // Inert while anything is stacked over the bar -- the command box overlay and, later, the
    // panel (EXPERIENCE.md "anywhere (inert while a dialog or the command-box overlay is open)"). The bar's own registration is the one entry that does not
    // count, because it is the thing the chord acts on.
    const top = this.overlays.top();
    if (top !== '' && top !== SIDE_BAR_OVERLAY_ID) return;
    event.preventDefault();
    this.toggleFromKeyboard();
  }

  /**
   * Escape, through the overlay stack. It only ever collapses -- never re-opens -- and the
   * collapse is **not** written to the stored preference (**DW-144**): a dismissal says "not
   * this, now", where Ctrl/Cmd+B says "keep it closed". Routing both through `toggleOpen()`
   * made one Escape start every later area, and every later tab, collapsed.
   */
  private closeFromKeyboard(): void {
    if (!this.showing()) return;
    this.yieldFocusToRail();
    this.shell.collapse();
  }

  /**
   * Ctrl/Cmd+B. With focus already inside the bar it hands focus to the area's rail item
   * first, so nothing is collapsed out from under the keyboard, then toggles -- which
   * persists, because this is the user asking (DW-134).
   */
  private toggleFromKeyboard(): void {
    this.yieldFocusToRail();
    // While the width yields the bar, the chord reopens it over the yield, and closing a reopened
    // bar returns it to the yield; neither is an answer about the stored preference.
    if (this.panel.sideBarYielded()) {
      this.panel.reopenSideBar();
      return;
    }
    if (this.panel.sideBarReopened()) {
      this.panel.releaseSideBar();
      return;
    }
    this.shell.toggleOpen();
    if (this.shell.open() && this.panel.sideBarYielded()) this.panel.reopenSideBar();
  }

  /** Nothing may be removed while it holds focus (EXPERIENCE.md "**Focus destinations.** No control"). */
  private yieldFocusToRail(): void {
    const inside = this.host.nativeElement.contains(document.activeElement);
    if (inside) document.getElementById(railItemDomId(this.area()))?.focus();
  }

  private currentRoute(): string {
    return this.router.url.split('?')[0].split('#')[0].replace(/^\/+/, '');
  }

  private bump(): void {
    this.generation.set(this.generation() + 1);
  }
}
