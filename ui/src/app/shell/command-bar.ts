import {
  ChangeDetectionStrategy,
  Component,
  DestroyRef,
  computed,
  inject,
  signal,
} from '@angular/core';
import { Router } from '@angular/router';

import { NavigationService } from '../core/navigation';
import { RefreshService } from '../core/refresh';
import { STRINGS } from '../core/strings';

/**
 * The count region's id, bound rather than typed twice: renaming it on the region alone would
 * compile, build, and leave the filter described by an element that does not exist.
 */
const FILTER_COUNT_ID = 'ocu-command-bar-count';

/** One command-bar action, resolved for rendering. */
interface CommandAction {
  readonly id: string;
  readonly label: string;
  readonly reasonId: string;
  readonly ariaDisabled: string | null;
  readonly describedBy: string | null;
}

/**
 * The command bar: the screen's own actions, its filter and its live-data readouts
 * (EXPERIENCE.md `:321`, DESIGN.md `:1037`).
 *
 * **Every slot resolves through the screen descriptor** (AD-5). The primary action, the row
 * actions and (from Story 1.14) the refresh declaration are the descriptor's; this component
 * decides only how they are drawn. Nothing here is a per-screen wiring point.
 *
 * **The auto-refresh chip is this row's control** (AD-43, EXPERIENCE.md `:318`: "a readout, not a
 * control -- the command-bar chip is the control"). It renders only for a screen the framework
 * has bound and whose descriptor declares `refreshes`, and it **advances** through off and the
 * descriptor's permitted rates rather than opening a menu: a menu needs an accessible name and a
 * label per option, and EXPERIENCE.md publishes neither (DW-126). A chip whose visible literal is
 * its accessible name invents nothing, and with one permitted rate it reads as a toggle. Its literals are `RefreshService`'s, resolved from the string table.
 *
 * **A tick never announces.** Neither the chip nor any ancestor of it carries `aria-live`,
 * `role="status"` or `role="alert"` (EXPERIENCE.md `:583` puts the stamp and the ticks outside
 * the polite set). The filter's count region next to it is a `role="status"`, and the chip is
 * deliberately its sibling rather than its child.
 *
 * **Three slots are declared and deliberately unrendered in this story**, because nothing can
 * fill them yet and drawing an empty control would be a lie about what the screen can do:
 *
 * - **view options** and **sort** -- `EXPERIENCE.md:321` names both; `DESIGN.md:1037`
 *   specifies a View menu and no sort control, and neither document publishes a label for
 *   either. Filed rather than invented.
 * - **the last-update stamp** -- `DESIGN.md:1037` puts one here and `:890`/`:1021` and
 *   EXPERIENCE.md `:318` put it in the status bar, with no precedence rule (**DW-139**). The
 *   status bar carries it, because `:318` states the division of labour outright and the band
 *   already holds the slot; this row carries the control.
 *
 * **Row actions are `aria-disabled`, never `disabled`, with "Select a row first" as their
 * reason on hover and focus** (EXPERIENCE.md `:214`, `:321`). There is no row selection
 * anywhere in Epic 1, so that is every row action's state here -- which is the state this
 * story can pin, not a placeholder.
 *
 * **The filter field carries no label of its own, and no description while there is no count.**
 * EXPERIENCE.md's Fixed strings table publishes no filter label and it is the sole authority
 * for user-facing words, so the missing name is filed for the lead -- the call `sign-in.ts`
 * made for the reveal toggle's show/hide wording. What Story 1.12 did close is the description
 * half (**DW-141**): the field is described by the count region only once that region has
 * words, because a description that announces nothing is worse than none.
 *
 * Every control-flow condition is a paren-free member reference, for the reason `sign-in.ts`
 * records: `ui/tools/client-lint.mjs`'s blanker matches `@if` plus one parenthesised group.
 */
@Component({
  selector: 'app-command-bar',
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `<div class="ocu-command-bar">
    @if (hasPrimaryAction) {
      <button type="button" class="ocu-button-primary ocu-command-bar-primary">
        {{ primaryActionLabel }}
      </button>
    }
    <input
      id="ocu-command-bar-filter"
      class="ocu-command-bar-filter"
      type="search"
      autocomplete="off"
      [attr.aria-describedby]="filterDescribedBy"
      [value]="filter()"
      (input)="onFilter($event)"
    />
    <p [id]="countId" class="ocu-command-bar-count" role="status">{{ matchCount }}</p>
    @for (action of rowActions; track action.id) {
      <span class="ocu-command-bar-action-slot">
        <button
          type="button"
          class="ocu-button-text ocu-command-bar-action"
          [attr.aria-disabled]="action.ariaDisabled"
          [attr.aria-describedby]="action.describedBy"
        >
          {{ action.label }}
        </button>
        <span class="ocu-command-bar-reason" role="tooltip" [id]="action.reasonId">{{
          STRINGS.privilegeSelectRowFirst
        }}</span>
      </span>
    }
    <span class="ocu-command-bar-spacer"></span>
    @if (hasRefreshChip) {
      <button
        type="button"
        class="ocu-button-text ocu-command-bar-refresh"
        (click)="onAdvanceRate()"
      >
        {{ refreshChipLabel }}
      </button>
    }
  </div>`,
})
export class CommandBar {
  private readonly navigation = inject(NavigationService);
  private readonly refresh = inject(RefreshService);
  private readonly router = inject(Router);

  protected readonly STRINGS = STRINGS;

  protected readonly countId = FILTER_COUNT_ID;

  protected readonly filter = signal('');

  /** Bumped on every router event, so the bar follows the screen. */
  private readonly generation = signal(0);

  private readonly screen = computed(() => {
    this.generation();
    return this.navigation.screenForUrl(this.router.url);
  });

  private readonly resolved = computed<readonly CommandAction[]>(() => {
    const screen = this.screen();
    if (screen === null) return [];
    return screen.rowActions
      .filter((action) => action.id !== '')
      .map((action) => ({
        id: action.id,
        label: action.id,
        reasonId: `ocu-command-bar-reason-${action.id}`,
        // Never the `disabled` attribute: a gated or unavailable control keeps its place in
        // the Tab order and keeps announcing why (EXPERIENCE.md, Privilege Gating).
        ariaDisabled: 'true',
        describedBy: `ocu-command-bar-reason-${action.id}`,
      }));
  });

  constructor() {
    const stopRouter = this.router.events.subscribe(() => this.bump());
    const stopNavigation = this.navigation.subscribe(() => this.bump());
    // The chip follows the framework, not the route: a rate change, a proposal opening and a
    // proposal expiring all move what it reads without the URL changing.
    const stopRefresh = this.refresh.subscribe(() => this.bump());
    inject(DestroyRef).onDestroy(() => {
      stopRouter.unsubscribe();
      stopNavigation();
      stopRefresh();
    });
  }

  protected get hasPrimaryAction(): boolean {
    return this.primaryActionLabel !== '';
  }

  /**
   * The primary action's label is its declared identifier until a screen carries a label key
   * for it (Epic 2). It is descriptor data, not copy typed into this component.
   */
  protected get primaryActionLabel(): string {
    return this.screen()?.primaryAction.id ?? '';
  }

  protected get rowActions(): readonly CommandAction[] {
    return this.resolved();
  }

  /**
   * The polite match count. Empty until a screen has rows to count: the region exists so the
   * count has somewhere to land, and `role="status"` announces it when it changes rather than
   * when it appears.
   */
  protected get matchCount(): string {
    return '';
  }

  /**
   * The filter's description, **or nothing at all while there is no count** (**DW-141**).
   *
   * An `aria-describedby` pointing at an empty region is worse than none: a screen reader
   * announces a described control and then reads nothing, which reads as a description that
   * failed rather than as a control with none. The region itself stays in the DOM, because
   * `role="status"` announces a change to a region that was already there.
   *
   * The other half of DW-141 -- the field has no accessible **name** -- is not closed here.
   * Naming it needs a Fixed-strings row EXPERIENCE.md does not publish (DW-126), and this
   * story may not invent one; `command-bar.spec.ts` pins the gap rather than papering it over.
   */
  protected get filterDescribedBy(): string | null {
    return this.matchCount === '' ? null : FILTER_COUNT_ID;
  }

  /**
   * The chip's literal, from the framework. `''` for every screen the framework has not bound or
   * whose descriptor does not declare `refreshes`, which is every screen in Epic 1.
   */
  protected get refreshChipLabel(): string {
    this.generation();
    return this.refresh.chipLabel();
  }

  protected get hasRefreshChip(): boolean {
    return this.refreshChipLabel !== '';
  }

  /** Off, then each permitted rate ascending, then off again. The chip is the cycle's control. */
  protected onAdvanceRate(): void {
    this.refresh.advanceRate();
  }

  protected onFilter(event: Event): void {
    this.filter.set((event.target as HTMLInputElement).value);
  }

  private bump(): void {
    this.generation.set(this.generation() + 1);
  }
}
