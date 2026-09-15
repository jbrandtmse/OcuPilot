import {
  ChangeDetectionStrategy,
  Component,
  DestroyRef,
  ElementRef,
  computed,
  effect,
  inject,
  signal,
  viewChild,
} from '@angular/core';
import { Router } from '@angular/router';

import { NavigationService } from '../core/navigation';
import { OverlayStack } from '../core/overlay-stack';
import { RefreshService } from '../core/refresh';
import { REFRESH_ACTION_ID, ScreenActions, actionLabel } from '../core/screen-actions';
import { applyView } from '../core/screen-read';
import { ScreenStores, type SortDirection } from '../core/screen-store';
import { STRINGS, stringFor } from '../core/strings';
import { formatRowCount } from '../core/table-model';

/**
 * The count region's id, bound rather than typed twice: renaming it on the region alone would
 * compile, build, and leave the filter described by an element that does not exist.
 */
const FILTER_COUNT_ID = 'ocu-command-bar-count';

/** The filter field's id, which a list page hands focus to when its focused table empties. */
export const COMMAND_BAR_FILTER_ID = 'ocu-command-bar-filter';

/** The sort menu's trigger id, which the menu names as its own label (`aria-labelledby`). */
export const SORT_TRIGGER_ID = 'ocu-command-bar-sort-trigger';

/** The sort menu's id, which the trigger's `aria-controls` names while it is open. */
export const SORT_MENU_ID = 'ocu-command-bar-sort-menu';

/** The sort menu's name on the overlay stack, so the shell's one Escape handler closes it. */
export const SORT_MENU_OVERLAY_ID = 'command-bar-sort';

/** One command-bar action, resolved for rendering. */
interface CommandAction {
  readonly id: string;
  readonly label: string;
  readonly reasonId: string;
  readonly ariaDisabled: string | null;
  readonly describedBy: string | null;
}

/** One entry of the sort menu: a declared sort field, or one of the two directions. */
interface SortOption {
  /** The declared `read.sort.fields` member, or `''` on a direction entry. */
  readonly field: string;
  /** The direction this entry sets, or `''` on a field entry. */
  readonly direction: SortDirection;
  /** The column's own label, or the direction's word. Never copy typed into this component. */
  readonly label: string;
  /** `'true'` when this entry is the sort or direction in force. */
  readonly checked: string;
}

/**
 * The command bar: the screen's own actions, its filter and its live-data readouts
 * (EXPERIENCE.md "below the locator-bar", DESIGN.md `:1039`).
 *
 * **Every slot resolves through the screen descriptor** (AD-5). The primary action, the row
 * actions and (from Story 1.14) the refresh declaration are the descriptor's; this component
 * decides only how they are drawn. Nothing here is a per-screen wiring point.
 *
 * **The primary action renders only while a handler is registered for it** (`ScreenActions`).
 * A declared primary action nothing can run is a slot nothing can fill, so it is not drawn, for
 * the reason the three slots below are not; `aria-disabled` would need a published reason and
 * there is none. A click runs the registered handler, and the button follows the registry as
 * handlers come and go.
 *
 * **The auto-refresh chip is this row's control** (AD-43, EXPERIENCE.md "`{spacing.status-bar-height}` band": "a readout, not a
 * control -- the command-bar chip is the control"). It renders only for a screen the framework
 * has bound and whose descriptor declares `refreshes`, and it **advances** through off and the
 * descriptor's permitted rates rather than opening a menu: a menu needs an accessible name and a
 * label per option, and EXPERIENCE.md publishes neither (DW-126). A chip whose visible literal is
 * its accessible name invents nothing, and with one permitted rate it reads as a toggle. Its literals are `RefreshService`'s, resolved from the string table.
 *
 * **A tick never announces.** Neither the chip nor any ancestor of it carries `aria-live`,
 * `role="status"` or `role="alert"` (EXPERIENCE.md "**Status messages (WCAG 4.1.3).**" puts the stamp and the ticks outside
 * the polite set). The filter's count region next to it is a `role="status"`, and the chip is
 * deliberately its sibling rather than its child.
 *
 * **The sort control is this row's too, and it is a command-bar control rather than a clickable
 * header** (Story 2.9). EXPERIENCE.md "below the locator-bar" places sort here by name; `:388` and `:606` give the
 * data table `role="grid"` with **one Tab stop**, which a focusable header cell would break and an
 * unfocusable clickable one would make mouse-only. So the header keeps `aria-sort` and its arrow as
 * the read-out (`data-table.ts`) and this menu is the control. It renders only for a screen whose
 * declared read carries `read.sort.fields`, offers each of them under its own **column's** label key
 * -- no per-field copy is invented -- plus the two directions, and writes `ScreenStore.setSort` /
 * `setDirection`, which persist per screen through `rememberView()` (AD-19). Its shape is
 * `DESIGN.md:1039`'s: a `button-secondary` with a down triangle, as the View menu is.
 *
 * **Two slots are declared and deliberately unrendered**, because nothing can fill them yet and
 * drawing an empty control would be a lie about what the screen can do:
 *
 * - **view options** -- EXPERIENCE.md "below the locator-bar" names it and `DESIGN.md:1039` specifies a View menu,
 *   but neither document publishes a label for it or for its options. Filed rather than invented.
 * - **the last-update stamp** -- `DESIGN.md:1039` puts one here and `:890`/`:1021` and
 *   EXPERIENCE.md "`{spacing.status-bar-height}` band" put it in the status bar, with no precedence rule (**DW-139**). The
 *   status bar carries it, because `:338` states the division of labour outright and the band
 *   already holds the slot; this row carries the control.
 *
 * **Row actions are `aria-disabled`, never `disabled`, with "Select a row first" as their
 * reason on hover and focus** (EXPERIENCE.md "**Mechanism** (the accessibility contract; component rows point here).", "below the locator-bar"). There is no row selection
 * anywhere in Epic 1, so that is every row action's state here -- which is the state this
 * story can pin, not a placeholder.
 *
 * **The filter is the current screen's store's** (AD-19): the field is named "Filter rows"
 * (`commandBarFilterLabel`), reads and writes the filter of the store the screen's table renders,
 * and its polite count is that table's view length once the screen's read has landed (DW-141,
 * DW-162). The field is described by the count region only once that region has words, because a
 * description that announces nothing is worse than none. While a proposal pauses the chip, the chip
 * carries `data-paused` and takes the warning colour; its words are the framework's.
 *
 * Every control-flow condition is a paren-free member reference, for the reason `sign-in.ts`
 * records: `ui/tools/client-lint.mjs`'s blanker matches `@if` plus one parenthesised group.
 */
@Component({
  selector: 'app-command-bar',
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `<div class="ocu-command-bar">
    @if (hasPrimaryAction) {
      <button
        type="button"
        class="ocu-button-primary ocu-command-bar-primary"
        (click)="onPrimaryAction()"
      >
        {{ primaryActionLabel }}
      </button>
    }
    <input
      [id]="filterId"
      class="ocu-command-bar-filter"
      type="search"
      autocomplete="off"
      [attr.aria-label]="STRINGS.commandBarFilterLabel"
      [attr.aria-describedby]="filterDescribedBy"
      [value]="filterValue"
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
    @if (hasSortControl) {
      <span #sortControl class="ocu-command-bar-sort" (focusout)="onSortFocusOut($event)">
        <button
          #sortTrigger
          type="button"
          [id]="sortTriggerId"
          class="ocu-button-secondary ocu-command-bar-sort-trigger"
          aria-haspopup="menu"
          [attr.aria-expanded]="sortOpen"
          [attr.aria-controls]="sortControls"
          (click)="onToggleSort()"
        >
          <span class="ocu-command-bar-sort-label">{{ STRINGS.sortMenuLabel }}</span>
          <span class="ocu-command-bar-sort-caret" aria-hidden="true">{{ caretGlyph }}</span>
        </button>
        @if (sortOpen) {
          <div
            #sortMenu
            class="ocu-command-bar-sort-menu"
            role="menu"
            [id]="sortMenuId"
            [attr.aria-labelledby]="sortTriggerId"
            (keydown)="onSortKeydown($event)"
            (mousedown)="onSortMouseDown($event)"
          >
            <div role="group">
              @for (option of sortFieldOptions; track option.field) {
                <button
                  type="button"
                  class="ocu-command-bar-sort-item"
                  role="menuitemradio"
                  tabindex="-1"
                  [attr.aria-checked]="option.checked"
                  (click)="onChooseSort(option.field)"
                >
                  {{ option.label }}
                </button>
              }
            </div>
            <div class="ocu-command-bar-sort-separator" role="separator"></div>
            <div role="group">
              @for (option of sortDirectionOptions; track option.direction) {
                <button
                  type="button"
                  class="ocu-command-bar-sort-item"
                  role="menuitemradio"
                  tabindex="-1"
                  [attr.aria-checked]="option.checked"
                  (click)="onChooseDirection(option.direction)"
                >
                  {{ option.label }}
                </button>
              }
            </div>
          </div>
        }
      </span>
    }
    @if (hasRefreshAction) {
      <button
        type="button"
        class="ocu-button-text ocu-command-bar-action ocu-command-bar-refresh-action"
        (click)="onRefreshAction()"
      >
        {{ refreshActionLabel }}
      </button>
    }
    <span class="ocu-command-bar-spacer"></span>
    @if (hasRefreshChip) {
      <button
        type="button"
        class="ocu-button-text ocu-command-bar-refresh"
        [attr.data-paused]="refreshPaused"
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
  private readonly actions = inject(ScreenActions);
  private readonly router = inject(Router);
  private readonly stores = inject(ScreenStores);
  private readonly overlays = inject(OverlayStack);

  protected readonly STRINGS = STRINGS;

  protected readonly countId = FILTER_COUNT_ID;

  protected readonly filterId = COMMAND_BAR_FILTER_ID;

  protected readonly sortTriggerId = SORT_TRIGGER_ID;

  protected readonly sortMenuId = SORT_MENU_ID;

  /**
   * The down triangle DESIGN.md `:1039` gives the View menu, which this control borrows rather
   * than inventing a second menu shape. Written as its escape so no non-ASCII byte enters a
   * source file (Rule 14), and `aria-hidden`, so the trigger reads as "Sort" alone.
   */
  protected readonly caretGlyph = '\u25BE';

  /** Bumped on router, map, refresh and action-registry changes, so the bar follows them. */
  private readonly generation = signal(0);

  private readonly sortMenuOpen = signal(false);

  private readonly sortTriggerEl = viewChild<ElementRef<HTMLButtonElement>>('sortTrigger');

  private readonly sortMenuEl = viewChild<ElementRef<HTMLElement>>('sortMenu');

  /** Trigger and menu together, which is the region focus has to leave for the menu to close. */
  private readonly sortControlEl = viewChild<ElementRef<HTMLElement>>('sortControl');

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
        // Resolved through the one label map, as the command box already does (Story 3.5). A
        // declared action carries no label key, so its id is its name until a screen publishes
        // words for it -- and when one does, the bar and the box have to say the same word, which
        // is what this spec's own reachability assertion compares.
        label: actionLabel(action.id),
        reasonId: `ocu-command-bar-reason-${action.id}`,
        // Never the `disabled` attribute: a gated or unavailable control keeps its place in
        // the Tab order and keeps announcing why (EXPERIENCE.md, Privilege Gating).
        ariaDisabled: 'true',
        describedBy: `ocu-command-bar-reason-${action.id}`,
      }));
  });

  /**
   * The sort menu's entries: the screen's declared sort fields that its table shows a column for,
   * in column order, then the two directions.
   *
   * **A declared sort field with no column is not offered**, because its only available name would
   * be the vendor's own key (`LastFinished`, `NextScheduled`) or an invented word -- the DW-126
   * rule that keeps the chip a chip. Every label here is a column's declared `labelKey` resolved
   * against the one string source, or one of the two direction words the Fixed strings table
   * publishes; nothing is typed into this component.
   */
  private readonly sortOptions = computed<{
    readonly fields: readonly SortOption[];
    readonly directions: readonly SortOption[];
  }>(() => {
    this.generation();
    const screen = this.screen();
    const read = screen?.read ?? null;
    if (screen === null || read === null || screen.table === null) return { fields: [], directions: [] };
    const store = this.stores.for(screen.descriptor, screen.refreshRates);
    // The sort and direction in force, resolved exactly as `data-table.ts`'s headers resolve them,
    // so the menu's checked entry and the header's `aria-sort` cannot disagree.
    const inForce = read.sort.fields.includes(store.sort()) ? store.sort() : read.sort.default;
    const direction = store.direction() === '' ? read.sort.direction : store.direction();
    const fields = screen.table.columns
      .filter((column) => read.sort.fields.includes(column.field))
      .map((column) => ({
        field: column.field,
        direction: '' as SortDirection,
        label: stringFor(column.labelKey),
        checked: column.field === inForce ? 'true' : 'false',
      }));
    const directions: readonly SortOption[] = [
      { field: '', direction: 'asc', label: STRINGS.sortDirectionAscending, checked: direction === 'asc' ? 'true' : 'false' },
      { field: '', direction: 'desc', label: STRINGS.sortDirectionDescending, checked: direction === 'desc' ? 'true' : 'false' },
    ];
    return { fields, directions };
  });

  constructor() {
    // The bar is the shell's, not the route's, so its `DestroyRef` never fires on a navigation.
    // An open sort menu therefore has to be closed here: left open it would either survive onto a
    // screen whose sort fields are not the ones it lists, or -- where the next screen draws no
    // control at all -- be dropped by the `@if` with its overlay entry still registered, which
    // would swallow the next Escape.
    const stopRouter = this.router.events.subscribe(() => {
      this.closeSort(false);
      this.bump();
    });
    const stopNavigation = this.navigation.subscribe(() => this.bump());
    // The chip follows the framework, not the route: a rate change, a proposal opening and a
    // proposal expiring all move what it reads without the URL changing.
    const stopRefresh = this.refresh.subscribe(() => this.bump());
    const stopActions = this.actions.subscribe(() => this.bump());
    inject(DestroyRef).onDestroy(() => {
      stopRouter.unsubscribe();
      stopNavigation();
      stopRefresh();
      stopActions();
      this.overlays.remove(SORT_MENU_OVERLAY_ID);
    });

    // A `role="menu"` that never takes focus is a menu only in name, and the entries do not exist
    // until the `@if` has rendered -- which under zoneless change detection is after the click
    // handler has returned. The move is made from an effect, which runs once the view query has
    // been updated with the rendered menu; `account-menu.ts` does the same for the same reason.
    effect(() => {
      if (!this.sortMenuOpen()) return;
      this.sortMenuEl()?.nativeElement.querySelector<HTMLElement>('[role="menuitemradio"]')?.focus();
    });
  }

  /** A declared primary action with a registered handler. */
  protected get hasPrimaryAction(): boolean {
    this.generation();
    const screen = this.screen();
    if (screen === null || screen.primaryAction.id === '') return false;
    return this.actions.has(screen.descriptor, screen.primaryAction.id);
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
   * The polite match count: `<n> rows` over the current screen's table view once its read has
   * landed, and `''` before then or on a screen with no read. The region exists from the start so
   * the count has somewhere to land, and `role="status"` announces it when it changes rather than
   * when it appears.
   */
  protected get matchCount(): string {
    this.generation();
    const screen = this.screen();
    if (screen === null || screen.read === null) return '';
    if (this.refresh.descriptor() !== screen.descriptor || !this.refresh.hasLoaded()) return '';
    const store = this.stores.for(screen.descriptor, screen.refreshRates);
    const view = applyView(store.data(), screen.read, {
      filter: store.filter(),
      sort: store.sort(),
      direction: store.direction(),
    });
    return formatRowCount(STRINGS.tableRowCount, view.length);
  }

  /** The current screen's filter, or `''` on a screen with no read. */
  protected get filterValue(): string {
    this.generation();
    const screen = this.screen();
    if (screen === null || screen.read === null) return '';
    return this.stores.for(screen.descriptor, screen.refreshRates).filter();
  }

  /**
   * The filter's description, **or nothing at all while there is no count** (**DW-141**).
   *
   * An `aria-describedby` pointing at an empty region is worse than none: a screen reader
   * announces a described control and then reads nothing, which reads as a description that
   * failed rather than as a control with none. The region itself stays in the DOM, because
   * `role="status"` announces a change to a region that was already there.
   */
  protected get filterDescribedBy(): string | null {
    return this.matchCount === '' ? null : FILTER_COUNT_ID;
  }

  /**
   * The manual Refresh control (DW-260), drawn on exactly the screens that registered a handler
   * for it: the five list screens, the audit viewer once it has a search to re-run, and the
   * error-log drill. Home registers none, because it reads nothing.
   *
   * It is separate from the auto-refresh chip beside it and stands whatever the chip says: a
   * screen that does not auto-refresh is the one that most needs a way to re-read, and a paused
   * chip does not make the read unavailable.
   */
  protected get hasRefreshAction(): boolean {
    this.generation();
    const screen = this.screen();
    if (screen === null) return false;
    return this.actions.has(screen.descriptor, REFRESH_ACTION_ID);
  }

  protected readonly refreshActionLabel = actionLabel(REFRESH_ACTION_ID);

  protected onRefreshAction(): void {
    const screen = this.screen();
    if (screen === null) return;
    this.actions.run(screen.descriptor, REFRESH_ACTION_ID);
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

  /** `'true'` while a live proposal pauses the chip, which then takes the warning colour. */
  protected get refreshPaused(): string | null {
    return this.refreshChipLabel === STRINGS.statusAutoRefreshPaused ? 'true' : null;
  }

  // --- The sort control ----------------------------------------------------------------------

  protected get sortFieldOptions(): readonly SortOption[] {
    return this.sortOptions().fields;
  }

  protected get sortDirectionOptions(): readonly SortOption[] {
    return this.sortOptions().directions;
  }

  /**
   * Whether the control is drawn at all: a screen whose declared read offers at least one sort
   * field its table shows a column for. A screen with no read, no table or no offerable field has
   * nothing to sort by, and a menu with only the two directions in it would be a control over a
   * choice the user cannot see.
   */
  protected get hasSortControl(): boolean {
    return this.sortFieldOptions.length > 0;
  }

  protected get sortOpen(): boolean {
    return this.sortMenuOpen();
  }

  /** The menu's id while it is open, so the trigger never names an element that is not there. */
  protected get sortControls(): string | null {
    return this.sortMenuOpen() ? SORT_MENU_ID : null;
  }

  /**
   * Open the menu and move focus to its first entry, or close it and give focus back. Focus is
   * restored before the entries leave the DOM, because removing a control while it holds focus is
   * banned outright (EXPERIENCE.md, Interaction Primitives).
   */
  protected onToggleSort(): void {
    if (this.sortMenuOpen()) {
      this.closeSort(true);
      return;
    }
    this.overlays.push(SORT_MENU_OVERLAY_ID, () => this.closeSort(true));
    this.sortMenuOpen.set(true);
  }

  /** Arrow, Home and End move between entries, the menu pattern the row menu already follows. */
  protected onSortKeydown(event: KeyboardEvent): void {
    const items = this.sortItems();
    if (items.length === 0) return;
    const at = items.indexOf(document.activeElement as HTMLElement);
    let next = -1;
    if (event.key === 'ArrowDown') next = (at + 1) % items.length;
    else if (event.key === 'ArrowUp') next = (at - 1 + items.length) % items.length;
    else if (event.key === 'Home') next = 0;
    else if (event.key === 'End') next = items.length - 1;
    if (next < 0) return;
    event.preventDefault();
    items[next].focus();
  }

  /**
   * Keep focus where it is while an entry is pressed: a browser that does not focus a button on
   * click would otherwise move focus out of the menu, close it, and lose the click.
   */
  protected onSortMouseDown(event: MouseEvent): void {
    event.preventDefault();
  }

  /**
   * Focus leaving the control closes the menu, which is also what a click outside it does. The
   * region watched is the trigger and the menu together, never the menu alone, for two reasons. The
   * trigger is the menu's sibling, so a browser that focuses a button on mousedown would otherwise
   * close the menu and let the click that follows re-open it, leaving the control unable to dismiss
   * itself -- <method>onToggleSort</method> owns that case. And Shift+Tab out of the first entry
   * lands on the trigger, from where the next Tab would otherwise leave the menu open with focus
   * somewhere else entirely.
   */
  protected onSortFocusOut(event: FocusEvent): void {
    const control = this.sortControlEl()?.nativeElement;
    const next = event.relatedTarget;
    if (control === undefined || (next instanceof Node && control.contains(next))) return;
    this.closeSort(false);
  }

  /** Choose the field the table sorts on. The store owns it, and remembers it (AD-19). */
  protected onChooseSort(field: string): void {
    const screen = this.screen();
    if (screen === null || screen.read === null) return;
    this.stores.for(screen.descriptor, screen.refreshRates).setSort(field);
    this.closeSort(true);
    this.bump();
  }

  /** Choose the direction it sorts in. */
  protected onChooseDirection(direction: SortDirection): void {
    const screen = this.screen();
    if (screen === null || screen.read === null) return;
    this.stores.for(screen.descriptor, screen.refreshRates).setDirection(direction);
    this.closeSort(true);
    this.bump();
  }

  private closeSort(returnFocus: boolean): void {
    if (!this.sortMenuOpen()) return;
    if (returnFocus) this.sortTriggerEl()?.nativeElement.focus();
    this.sortMenuOpen.set(false);
    this.overlays.remove(SORT_MENU_OVERLAY_ID);
  }

  private sortItems(): HTMLElement[] {
    const menu = this.sortMenuEl()?.nativeElement;
    return menu === undefined ? [] : Array.from(menu.querySelectorAll<HTMLElement>('[role="menuitemradio"]'));
  }

  protected onPrimaryAction(): void {
    const screen = this.screen();
    if (screen === null) return;
    this.actions.run(screen.descriptor, screen.primaryAction.id);
  }

  /** Off, then each permitted rate ascending, then off again. The chip is the cycle's control. */
  protected onAdvanceRate(): void {
    this.refresh.advanceRate();
  }

  protected onFilter(event: Event): void {
    const screen = this.screen();
    if (screen === null || screen.read === null) return;
    this.stores.for(screen.descriptor, screen.refreshRates).setFilter((event.target as HTMLInputElement).value);
    this.bump();
  }

  private bump(): void {
    this.generation.set(this.generation() + 1);
  }
}
