import {
  ChangeDetectionStrategy,
  Component,
  DestroyRef,
  ElementRef,
  computed,
  inject,
  signal,
} from '@angular/core';
import { Router } from '@angular/router';

import { AgentStatus, DEFINITIONS_ROUTE } from '../core/agent-status';
import { NavigationService, formatArea, formatRequires, withQuery } from '../core/navigation';
import { ShellState } from '../core/shell-state';
import { STRINGS, stringFor } from '../core/strings';

/** One rail item, resolved for rendering. */
interface RailItem {
  readonly key: string;
  readonly label: string;
  readonly initial: string;
  readonly tooltip: string;
  readonly domId: string;
  readonly tipId: string;
  readonly pinBottom: boolean;
  readonly navigates: boolean;
  readonly gated: boolean;
  readonly ariaDisabled: string | null;
  readonly ariaCurrent: string | null;
  readonly tabIndex: number;
  /**
   * The attention dot's accessible name, or `''` for an item that carries no dot. The name IS
   * the reason (EXPERIENCE.md's `attention-dot`: "Tooltip and accessible name state the reason"),
   * so an empty string is the whole of "no dot".
   */
  readonly attention: string;
}

/** The area the attention dot belongs to. The only badge on the rail, ever. */
export const AGENT_AREA_KEY = 'agent';

/** The id a side bar uses to return focus to an area's rail item (EXPERIENCE.md "**Focus destinations.** No control"). */
export function railItemDomId(areaKey: string): string {
  return `ocu-rail-item-${areaKey}`;
}

/**
 * The activity rail: the eight areas in daily-use order, Agent co-pilot pinned to the bottom
 * (EXPERIENCE.md "**The rail, top to bottom (daily-use order):**", "`{spacing.rail-width}` icon"; DESIGN.md `:972-1003`).
 *
 * **One Tab stop, arrows within it.** Exactly one item is in the tab order at a time -- the
 * first until an arrow key or an activation moves it -- and Up/Down move between items, Home and
 * End jump to the ends.
 * Enter and Space activate, which a real `<button>` does natively. That is a roving tabindex,
 * not eight tab stops.
 *
 * **A click opens an area's side bar without navigating.** Clicking the item whose list is
 * already showing collapses it. Home is the exception: it has no screen list, so its item
 * navigates and collapses (EXPERIENCE.md "rail-items in daily-use order: Home"). The decision itself lives in `ShellState`, so
 * this component owns only the routing half.
 *
 * **Gated items stay reachable.** `aria-disabled="true"`, never the `disabled` attribute, never
 * hidden, keeping their place in the Tab and arrow order, with the failed
 * `(resource, permission)` pair as a tooltip on hover **and** on focus through
 * `aria-describedby`. The tooltip element is always in the DOM so assistive technology reads it
 * whether or not it is visible; CSS decides when it is shown. The Agent co-pilot item never
 * gates (EXPERIENCE.md "Agent co-pilot › Definitions and Switches") -- its area declares no privilege pair, which an empty set
 * expresses without a second flag.
 *
 * **No count badge, ever** (EXPERIENCE.md "`{spacing.rail-width}` icon"). The one rail badge in the design is the
 * attention dot on Agent co-pilot, and this is the story that lights it. It is a **sibling of the
 * button, not a child**: inside the button it would be inside that button's own `aria-label` and
 * silenced, and the button's name has to stay the area's. Outside it, the dot carries its own
 * name -- the published sentence for this caller's audience -- and is announced as itself.
 *
 * The glyph is the area name's first letter, produced in TypeScript and `aria-hidden`, standing
 * in for the owner's icon set: DESIGN.md's interim set is one Material Symbols glyph per area,
 * and nothing here may reach an external host for one (NFR-10, AD-47). The accessible name is
 * the area name, so nothing about the placeholder is announced.
 *
 * Every control-flow condition and every `@for` header is paren-free, for the reason
 * `sign-in.ts` records: `ui/tools/client-lint.mjs`'s blanker matches one parenthesised group,
 * so a call expression inside one leaves a stray bracket the literal-text-node rule reports.
 */
@Component({
  selector: 'app-rail',
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `<nav class="ocu-rail" [attr.aria-label]="railLandmark">
    @for (item of items; track item.key) {
      <span class="ocu-rail-slot" [class.ocu-rail-slot-bottom]="item.pinBottom">
        <button
          type="button"
          class="ocu-rail-item"
          [id]="item.domId"
          [attr.aria-label]="item.label"
          [attr.aria-current]="item.ariaCurrent"
          [attr.aria-disabled]="item.ariaDisabled"
          [attr.aria-describedby]="item.tipId"
          [attr.tabindex]="item.tabIndex"
          [class.ocu-rail-item-active]="item.ariaCurrent"
          [class.ocu-rail-item-gated]="item.gated"
          (click)="activate(item)"
          (keydown)="onKeydown($event)"
        >
          <span class="ocu-rail-glyph" aria-hidden="true">{{ item.initial }}</span>
        </button>
        @if (item.attention) {
          <span class="ocu-rail-dot" role="img" [attr.aria-label]="item.attention"></span>
        }
        <span class="ocu-rail-tooltip" role="tooltip" [id]="item.tipId">{{ item.tooltip }}</span>
      </span>
    }
  </nav>`,
})
export class Rail {
  private readonly navigation = inject(NavigationService);
  private readonly agentStatus = inject(AgentStatus);
  private readonly shell = inject(ShellState);
  private readonly router = inject(Router);
  private readonly host: ElementRef<HTMLElement> = inject(ElementRef);

  protected readonly railLandmark = STRINGS.navRailLandmark;

  /** Bumped whenever the map or the shell state changes, so the item list recomputes. */
  private readonly generation = signal(0);

  /** Which item currently owns the rail's single tab stop. */
  private readonly focusedIndex = signal(0);

  private readonly resolved = computed<readonly RailItem[]>(() => {
    this.generation();
    const focused = this.focusedIndex();
    const active = this.shell.activeArea();
    const attention = this.attentionReason();
    return this.navigation.areas().map((area, index) => {
      const label = stringFor(area.labelKey);
      const verdict = this.navigation.areaVerdict(area.key);
      const isActive = area.key === active;
      return {
        key: area.key,
        label,
        initial: label.slice(0, 1).toUpperCase(),
        tooltip: verdict.allowed
          ? formatArea(STRINGS.navRailItemTooltip, label)
          : formatRequires(STRINGS.privilegeRequiresResource, verdict.failedPair),
        domId: railItemDomId(area.key),
        tipId: `ocu-rail-tip-${area.key}`,
        pinBottom: area.pinBottom,
        navigates: area.navigates,
        gated: !verdict.allowed,
        ariaDisabled: verdict.allowed ? null : 'true',
        ariaCurrent: isActive ? 'page' : null,
        tabIndex: index === focused ? 0 : -1,
        attention: area.key === AGENT_AREA_KEY ? attention : '',
      };
    });
  });

  constructor() {
    const stopNavigation = this.navigation.subscribe(() => this.bump());
    const stopShell = this.shell.subscribe(() => this.bump());
    const stopStatus = this.agentStatus.subscribe(() => this.bump());
    inject(DestroyRef).onDestroy(() => {
      stopNavigation();
      stopShell();
      stopStatus();
    });
  }

  /**
   * Why the Agent co-pilot item is showing a dot, or `''` when it is not (FR-28, DW-356).
   *
   * The dot is lit while the agent is unconfigured; Story 3.7 adds the kill switch as its second
   * condition. A failed Test connection is deliberately not a third: nothing on the instance
   * records one, so nothing could ever clear it.
   *
   * The reason is the same published sentence the panel shows that audience, chosen by the same
   * verdict, so the dot and the panel can never say two different things about one state. Neither
   * names an audience until the map has actually arrived -- `loaded()`, not `answered()`, for the
   * reason the panel records: a read that completed with a failure leaves every verdict *allowed*,
   * which is the right default for gating and the wrong one for deciding whose job this is.
   */
  private attentionReason(): string {
    if (!this.navigation.loaded() || !this.agentStatus.answered()) return '';
    if (this.agentStatus.configured()) return '';
    return this.navigation.screenVerdict(DEFINITIONS_ROUTE).allowed
      ? STRINGS.agentGateReminderBanner
      : STRINGS.agentGateEmptyState;
  }

  protected get items(): readonly RailItem[] {
    return this.resolved();
  }

  /**
   * Open the area's side bar, or -- for Home alone -- navigate to it and collapse. A gated item
   * does nothing: it is `aria-disabled`, which carries no behaviour of its own, so the refusal
   * has to be here.
   */
  protected activate(item: RailItem): void {
    if (item.gated) return;
    const index = this.resolved().findIndex((candidate) => candidate.key === item.key);
    if (index >= 0) this.focusedIndex.set(index);
    if (!this.shell.activateArea(item.key, item.navigates)) return;
    // A navigating area opens its first built screen; Home's is the application root, whose
    // declared route is the empty string. The current query travels with it: `?ns=` is data
    // scope, and a rail click that dropped it would silently move the user's work to another
    // namespace (AD-44, DW-134).
    const first = this.navigation.screensForArea(item.key)[0];
    void this.router.navigateByUrl(
      withQuery(first === undefined ? '' : first.route, this.router.url)
    );
  }

  /**
   * Up and Down move within the rail; Home and End jump to its ends. Gated items keep their
   * place in the order -- skipping them is exactly what `aria-disabled` exists to avoid.
   */
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
    this.focusItem(next);
  }

  private focusItem(index: number): void {
    const buttons = this.host.nativeElement.querySelectorAll<HTMLButtonElement>('.ocu-rail-item');
    buttons.item(index)?.focus();
  }

  private bump(): void {
    this.generation.set(this.generation() + 1);
  }
}
