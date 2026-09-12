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
import { STRINGS } from '../core/strings';

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
 * **Four slots are declared and deliberately unrendered in this story**, because nothing can
 * fill them yet and drawing an empty control would be a lie about what the screen can do:
 *
 * - **view options** and **sort** -- `EXPERIENCE.md:321` names both; `DESIGN.md:1037`
 *   specifies a View menu and no sort control, and neither document publishes a label for
 *   either. Filed rather than invented.
 * - **the auto-refresh chip** -- no descriptor declares refresh yet; Story 1.14 owns the
 *   framework, this bar owns the chip's place in the row (AD-43).
 * - **the last-update stamp** -- Story 1.14 supplies the value; `statusLastUpdate` is the
 *   string it will carry.
 *
 * **Row actions are `aria-disabled`, never `disabled`, with "Select a row first" as their
 * reason on hover and focus** (EXPERIENCE.md `:214`, `:321`). There is no row selection
 * anywhere in Epic 1, so that is every row action's state here -- which is the state this
 * story can pin, not a placeholder.
 *
 * **The filter field carries no label of its own.** EXPERIENCE.md's Fixed strings table
 * publishes no filter label and it is the sole authority for user-facing words, so the field
 * ships as a `type="search"` input described by its own count region, and the missing row is
 * filed for the lead -- the call `sign-in.ts` made for the reveal toggle's show/hide wording.
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
      aria-describedby="ocu-command-bar-count"
      [value]="filter()"
      (input)="onFilter($event)"
    />
    <p id="ocu-command-bar-count" class="ocu-command-bar-count" role="status">{{ matchCount }}</p>
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
  </div>`,
})
export class CommandBar {
  private readonly navigation = inject(NavigationService);
  private readonly router = inject(Router);

  protected readonly STRINGS = STRINGS;

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
    inject(DestroyRef).onDestroy(() => {
      stopRouter.unsubscribe();
      stopNavigation();
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
   * count has somewhere to land and so the filter has something to be described by, and
   * `role="status"` announces it when it changes rather than when it appears.
   */
  protected get matchCount(): string {
    return '';
  }

  protected onFilter(event: Event): void {
    this.filter.set((event.target as HTMLInputElement).value);
  }

  private bump(): void {
    this.generation.set(this.generation() + 1);
  }
}
