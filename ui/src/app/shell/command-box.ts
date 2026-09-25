import {
  ChangeDetectionStrategy,
  Component,
  DestroyRef,
  ElementRef,
  computed,
  inject,
  signal,
  viewChild,
} from '@angular/core';
import { Router } from '@angular/router';

import { AccountPreferences } from '../core/account-preferences';
import {
  NavigationService,
  areaByKey,
  formatRequires,
  isListedScreen,
  withQuery,
} from '../core/navigation';
import { OverlayStack } from '../core/overlay-stack';
import { REFRESH_ACTION_ID, ScreenActions, actionLabel } from '../core/screen-actions';
import { ScreenStores } from '../core/screen-store';
import type { ScreenDeclaration } from '../core/screens.generated';
import { selfProtectionReason } from '../core/self-protection';
import { Session } from '../core/session';
import { ShellState } from '../core/shell-state';
import { STRINGS, stringFor } from '../core/strings';
import { rowFor } from '../core/table-model';

/** The command box's name on the overlay stack (DW-137). */
export const COMMAND_BOX_OVERLAY_ID = 'command-box';

/** The chord that opens the command box, on both platforms (EXPERIENCE.md "Opens on click or Ctrl/Cmd+K; typing filters every screen the user may open"). */
export function isCommandBoxChord(event: KeyboardEvent): boolean {
  return (
    (event.ctrlKey || event.metaKey) &&
    !event.altKey &&
    !event.shiftKey &&
    event.key.toLowerCase() === 'k'
  );
}

/** The placeholders the Fixed strings table leaves for the two result counts. */
export const SCREEN_COUNT_PLACEHOLDER = '<n>';
export const ACTION_COUNT_PLACEHOLDER = '<m>';

/**
 * `<n> screens, <m> actions` with both counts resolved. A function rather than a `replace`
 * inside the template, for the reason `formatRequires` is one: renaming a placeholder on one
 * side only would ship the placeholder to the user, and a source-text pin cannot see that.
 */
export function formatResultCount(template: string, screens: number, actions: number): string {
  return template
    .split(SCREEN_COUNT_PLACEHOLDER)
    .join(String(screens))
    .split(ACTION_COUNT_PLACEHOLDER)
    .join(String(actions));
}

/** One result row, resolved for rendering. */
interface CommandRow {
  readonly id: string;
  readonly kind: string;
  readonly label: string;
  /** A screen's area name, which is what tells two same-named screens apart. */
  readonly detail: string;
  readonly reason: string;
  readonly gated: boolean;
  readonly route: string;
  /** A screen row's area key, whose side bar choosing the row opens. `''` for an action row. */
  readonly area: string;
  /** The descriptor and declared id an action row runs. Both `''` for a screen row. */
  readonly descriptor: string;
  readonly actionId: string;
  readonly ariaDisabled: string | null;
}

/**
 * The command box: the header's 360px field and the result sheet it opens
 * (EXPERIENCE.md "Opens on click or Ctrl/Cmd+K; typing", "*Header, center.* Opens on click"; DESIGN.md `:1017`).
 *
 * **It resolves through the descriptor mirror and the navigation map** (AD-5, AD-8), never a
 * hand-kept list: every built screen is a candidate, matched against the aliases its own
 * descriptor declares, and the current screen's declared actions are the second group. The two
 * `role="group"` elements are named Screens and Actions (EXPERIENCE.md "command-box result-group labels").
 *
 * **A gated screen stays listed and non-selectable**, with the failed `(resource, permission)`
 * pair inside the row's own content and therefore inside its accessible name. No tooltip: the
 * input keeps DOM focus while the list is open, so a tooltip on a row could never show
 * (DESIGN.md `:1017`).
 *
 * **Escape belongs to the overlay stack, not to this component.** The box registers while it
 * is open and the shell's one Escape handler closes the topmost member, which is what lets a
 * single Escape close the box over an open side bar without also collapsing the bar
 * (DW-137). Focus returns to wherever it was when the box opened.
 *
 * **It also closes on a pointer or focus gesture outside it**, the same dismissal DW-109
 * gave the account menu, and for the same reason: the field is a Tab stop while the sheet is
 * shut, so a box left open covered the screen with `aria-expanded="true"` while the user
 * worked elsewhere. Like the menu's, that dismissal does not move focus.
 *
 * **Favorited screens are listed first within Screens** (Story 15.2): "menu search" is this box
 * and nothing else -- EXPERIENCE.md's Rejected list already records "menu-only search with a
 * 220 ms typeahead" as rejected in favour of the command box -- so this story adds no input, no
 * group and no change to the count sentence. Only the order inside the Screens group moves, and it is a stable partition: among
 * favorites, and among the rest, the declaration order the mirror already fixes is unchanged.
 *
 * **It is not a channel to the agent** (EXPERIENCE.md "Gated entries stay listed and arrow-reachable"): typed text never becomes a
 * turn and the avatar never appears here.
 *
 * **The chord is shown once, as the kbd chip at the field's right edge** -- never in the
 * placeholder, which is the Fixed strings table's own sentence and says nothing about keys.
 * The chip's text is computed in TypeScript because it is platform-dependent, the same reason
 * `account-menu.ts`'s glyph is (Rule 14: the command glyph is an escape, never a literal
 * byte).
 *
 * **The placeholder is drawn at 100%** (`epics.md:1351`, `DESIGN.md:1007`: no text in the
 * header is drawn below 100%). `DESIGN.md:1017` draws it at 80%; the divergence is filed for
 * the lead rather than argued around here.
 *
 * Every control-flow condition is a paren-free member reference, for the reason `sign-in.ts`
 * records: `ui/tools/client-lint.mjs`'s blanker matches `@if` plus one parenthesised group.
 */
@Component({
  selector: 'app-command-box',
  changeDetection: ChangeDetectionStrategy.OnPush,
  host: {
    '(document:keydown)': 'onGlobalKeydown($event)',
    '(document:pointerdown)': 'onOutside($event)',
    '(document:focusin)': 'onOutside($event)',
  },
  template: `<div class="ocu-command-box">
    <input
      #field
      id="ocu-command-box-field"
      class="ocu-command-box-field"
      type="text"
      role="combobox"
      autocomplete="off"
      aria-autocomplete="list"
      aria-controls="ocu-command-box-list"
      placeholder="{{ STRINGS.commandBoxPlaceholder }}"
      [attr.aria-expanded]="expanded"
      [attr.aria-activedescendant]="activeDescendant"
      [value]="query()"
      (click)="openFromPointer()"
      (input)="onQuery($event)"
      (keydown)="onKeydown($event)"
    />
    <span class="ocu-command-box-kbd" aria-hidden="true">{{ chordChip }}</span>
    @if (expanded) {
      <div class="ocu-command-box-sheet">
        <div id="ocu-command-box-list" class="ocu-command-box-list" role="listbox">
          <div
            class="ocu-command-box-group ocu-command-box-group-screens"
            role="group"
            aria-label="{{ STRINGS.commandBoxGroupScreens }}"
          >
            @for (row of screenRows; track row.id) {
              <div
                class="ocu-command-box-option"
                role="option"
                [id]="row.id"
                [class.ocu-command-box-option-active]="row.id === activeDescendant"
                [class.ocu-command-box-option-gated]="row.gated"
                [attr.aria-selected]="row.id === activeDescendant"
                [attr.aria-disabled]="row.ariaDisabled"
                (click)="choose(row)"
              >
                <span class="ocu-command-box-option-label">{{ row.label }}</span>
                @if (row.detail) {
                  <span class="ocu-command-box-option-detail">{{ row.detail }}</span>
                }
                @if (row.gated) {
                  <span class="ocu-command-box-option-reason">{{ row.reason }}</span>
                }
              </div>
            }
          </div>
          <div
            class="ocu-command-box-group ocu-command-box-group-actions"
            role="group"
            aria-label="{{ STRINGS.commandBoxGroupActions }}"
          >
            @for (row of actionRows; track row.id) {
              <div
                class="ocu-command-box-option"
                role="option"
                [id]="row.id"
                [class.ocu-command-box-option-active]="row.id === activeDescendant"
                [class.ocu-command-box-option-gated]="row.gated"
                [attr.aria-selected]="row.id === activeDescendant"
                [attr.aria-disabled]="row.ariaDisabled"
                (click)="choose(row)"
              >
                <span class="ocu-command-box-option-label">{{ row.label }}</span>
                @if (row.gated) {
                  <span class="ocu-command-box-option-reason">{{ row.reason }}</span>
                }
              </div>
            }
          </div>
        </div>
        <p class="ocu-command-box-count" role="status">{{ countMessage }}</p>
      </div>
    }
  </div>`,
})
export class CommandBox {
  private readonly navigation = inject(NavigationService);
  private readonly overlays = inject(OverlayStack);
  private readonly actions = inject(ScreenActions);
  /**
   * Read for one thing only: which row the current screen has selected, which is what a
   * self-protection rule is judged against (AD-53). The box writes to no store.
   */
  private readonly stores = inject(ScreenStores);
  private readonly router = inject(Router);
  private readonly session = inject(Session, { optional: true });
  private readonly shell = inject(ShellState);
  private readonly preferences = inject(AccountPreferences);
  private readonly host: ElementRef<HTMLElement> = inject(ElementRef);

  protected readonly STRINGS = STRINGS;

  /**
   * The chord, spelled the way the platform spells it. The command glyph is an escape, never
   * a literal byte (Rule 14).
   */
  protected readonly chordChip = isApplePlatform() ? '\u2318K' : 'Ctrl+K';

  private readonly fieldEl = viewChild.required<ElementRef<HTMLInputElement>>('field');

  private readonly openFlag = signal(false);

  private readonly activeIndex = signal(0);

  protected readonly query = signal('');

  /** Bumped whenever the map, the route or the action registry changes, so the list recomputes. */
  private readonly generation = signal(0);

  /** Where focus was when the box opened, so Escape can put it back (EXPERIENCE.md "**Focus order.** skip link"). */
  private returnFocus: HTMLElement | null = null;

  private readonly rows = computed<readonly CommandRow[]>(() => {
    this.generation();
    const needle = this.query().trim().toLowerCase();
    return [...this.screenCandidates(needle), ...this.actionCandidates(needle)];
  });

  constructor() {
    const stopNavigation = this.navigation.subscribe(() => this.bump());
    const stopRouter = this.router.events.subscribe(() => this.bump());
    const stopActions = this.actions.subscribe(() => this.bump());
    // Which screens are favorited decides the Screens group's order, so a change to the lists
    // re-ranks an open box rather than waiting for the next router event.
    const stopPreferences = this.preferences.subscribe(() => this.bump());
    inject(DestroyRef).onDestroy(() => {
      stopNavigation();
      stopRouter.unsubscribe();
      stopActions();
      stopPreferences();
      this.overlays.remove(COMMAND_BOX_OVERLAY_ID);
    });
  }

  protected get expanded(): boolean {
    return this.openFlag();
  }

  protected get screenRows(): readonly CommandRow[] {
    return this.rows().filter((row) => row.kind === 'screen');
  }

  protected get actionRows(): readonly CommandRow[] {
    return this.rows().filter((row) => row.kind === 'action');
  }

  /** The active row's id while the list is open, else `null` -- never a dangling reference. */
  protected get activeDescendant(): string | null {
    if (!this.openFlag()) return null;
    const rows = this.rows();
    if (rows.length === 0) return null;
    return rows[Math.min(this.activeIndex(), rows.length - 1)].id;
  }

  /** The polite count, or the no-match sentence when the filter matched nothing. */
  protected get countMessage(): string {
    const screens = this.screenRows.length;
    const actions = this.actionRows.length;
    if (screens + actions === 0) return STRINGS.commandBoxNoMatch;
    return formatResultCount(STRINGS.commandBoxResultCount, screens, actions);
  }

  /** Ctrl/Cmd+K from anywhere. Inert while a dialog is open (EXPERIENCE.md "anywhere (inert while a dialog or the command-box overlay is open)"). */
  protected onGlobalKeydown(event: KeyboardEvent): void {
    if (!isCommandBoxChord(event)) return;
    if (document.querySelector('[role="dialog"]') !== null) return;
    event.preventDefault();
    this.open(document.activeElement);
  }

  protected openFromPointer(): void {
    this.open(this.fieldEl().nativeElement);
  }

  protected onQuery(event: Event): void {
    this.query.set((event.target as HTMLInputElement).value);
    this.activeIndex.set(0);
    this.open(this.fieldEl().nativeElement);
  }

  /**
   * A pointer or focus gesture outside the box closes it, the way it closes the account menu
   * (DW-109). The field is reachable by Tab while the sheet is shut, so without this a box
   * opened by the chord stayed open over the screen -- `aria-expanded="true"` and a result
   * sheet covering the content -- for as long as the user worked anywhere else.
   *
   * Dismissal deliberately does not move focus: the user has already chosen where it goes.
   * `close()` only restores focus to the element the box was opened from, and that element is
   * no longer where the user is, so the return target is dropped first.
   */
  protected onOutside(event: Event): void {
    if (!this.openFlag()) return;
    const target = event.target;
    if (target instanceof Node && this.host.nativeElement.contains(target)) return;
    this.returnFocus = null;
    this.close();
  }

  /**
   * Down and Up move the active row; Enter opens it. Escape is deliberately absent: the
   * shell's one handler asks the overlay stack, so a key press here cannot close two things.
   *
   * **Nothing is bound while the sheet is shut.** The candidate list is the whole roster at
   * an empty query, so an Enter pressed in the collapsed field -- which Tab reaches, since
   * the box opens on click and chord, not on focus -- would have navigated to whichever
   * screen happens to be first, with no list on screen to say so.
   */
  protected onKeydown(event: KeyboardEvent): void {
    if (!this.openFlag()) return;
    const count = this.rows().length;
    if (event.key === 'Enter') {
      event.preventDefault();
      if (count > 0) this.choose(this.rows()[Math.min(this.activeIndex(), count - 1)]);
      return;
    }
    if (count === 0) return;
    const current = Math.min(this.activeIndex(), count - 1);
    let next = current;
    if (event.key === 'ArrowDown') next = (current + 1) % count;
    else if (event.key === 'ArrowUp') next = (current - 1 + count) % count;
    else if (event.key === 'Home') next = 0;
    else if (event.key === 'End') next = count - 1;
    else return;
    event.preventDefault();
    this.activeIndex.set(next);
  }

  /**
   * Open a row. A gated or unavailable row does nothing: `aria-disabled` carries no behaviour
   * of its own, so the refusal has to be here. An available action row closes the box and runs
   * the action's registered handler once, the same `ScreenActions.run` the command bar's button
   * calls.
   *
   * A screen navigation carries the current query, because `?ns=` is data scope and the box
   * reaches every screen in the product (AD-44, DW-134). Before it navigates, an open side bar is
   * moved to the screen's area, so the list beside the screen is that screen's own; an area whose
   * rail item navigates (Home) has no screen list and is left alone. A collapsed bar stays
   * collapsed, because Ctrl/Cmd+B's choice is remembered (EXPERIENCE.md's side-bar row) and
   * `setActiveArea` already moves a collapsed bar with the route. Focus is **not** handed
   * back on the way out: the element it was taken from belongs to the screen being left, and
   * returning to it is right for Escape and wrong for a choice the user made.
   */
  protected choose(row: CommandRow): void {
    if (row.gated) return;
    if (row.kind === 'screen') {
      this.returnFocus = null;
      this.close();
      const area = areaByKey(row.area);
      if (area !== null && !area.navigates && this.shell.open()) this.shell.showArea(area.key);
      void this.router.navigateByUrl(withQuery(row.route, this.router.url));
      return;
    }
    this.close();
    this.actions.run(row.descriptor, row.actionId);
  }

  private open(returnTo: Element | null): void {
    if (!this.openFlag()) {
      this.returnFocus = returnTo instanceof HTMLElement ? returnTo : null;
      this.overlays.push(COMMAND_BOX_OVERLAY_ID, () => this.close());
      this.openFlag.set(true);
    }
    this.fieldEl().nativeElement.focus();
  }

  /**
   * Close, unregister, give focus back and forget the filter. Safe to call from the overlay
   * stack, which has already removed this entry, and safe to call twice.
   *
   * The query is cleared on the way out rather than on the way in: a box reopened on the last
   * search shows a filtered list the user did not ask for, and an `aria-activedescendant`
   * pointing at a row chosen in a different context.
   */
  private close(): void {
    if (!this.openFlag()) return;
    this.openFlag.set(false);
    this.overlays.remove(COMMAND_BOX_OVERLAY_ID);
    this.query.set('');
    this.activeIndex.set(0);
    const target = this.returnFocus;
    this.returnFocus = null;
    if (target !== null && target.isConnected) target.focus();
  }

  private screenCandidates(needle: string): readonly CommandRow[] {
    const rows: CommandRow[] = [];
    // Listed screens only (Story 3.5). A screen declaring `sideBarPosition` 0 is routable and
    // never advertised: the Definition form takes a `single` id, so a search result landing on it
    // with no id would open a create form the user did not ask for. The seam still answers every
    // built screen, so the route table is unaffected.
    for (const screen of this.navigation.builtScreens().filter(isListedScreen)) {
      const label = stringFor(screen.labelKey);
      if (!matchesScreen(screen, label, needle)) continue;
      const area = areaByKey(screen.area);
      const verdict = this.navigation.screenVerdict(screen.route);
      rows.push({
        id: `ocu-command-box-screen-${screen.route.replace(/\//g, '-') || 'root'}`,
        kind: 'screen',
        label,
        detail: area === null ? '' : stringFor(area.labelKey),
        reason: formatRequires(STRINGS.privilegeRequiresResource, verdict.failedPair),
        gated: !verdict.allowed,
        route: screen.route,
        area: screen.area,
        descriptor: '',
        actionId: '',
        ariaDisabled: verdict.allowed ? null : 'true',
      });
    }
    // Story 15.2: favorited screens first, everything else after, each half in the order it was
    // already in. A stable partition rather than a sort, so the declaration order the mirror
    // fixes is the tie-break -- a comparator returning 0 leaves that to the engine.
    const favorite: CommandRow[] = [];
    const rest: CommandRow[] = [];
    for (const row of rows) {
      if (this.preferences.isFavorite(row.route)) favorite.push(row);
      else rest.push(row);
    }
    return [...favorite, ...rest];
  }

  /**
   * The current screen's declared actions, in the command bar's own two classes: the primary
   * action, listed only while a handler is registered for it, and the row actions -- which are
   * unavailable until a row is selected, exactly as the bar draws them. A row the box offered as
   * selectable and then silently ignored would say the opposite of what the bar says about the
   * same action.
   *
   * The two classes carry different id prefixes, so a screen declaring a primary and a row
   * action under one identifier cannot produce two rows sharing a DOM id.
   */
  private actionCandidates(needle: string): readonly CommandRow[] {
    const screen = this.navigation.screenForUrl(this.router.url);
    if (screen === null) return [];
    const declared: { id: string; rowScoped: boolean; reason?: string }[] = [];
    // Refresh first, and only where a handler is registered -- which is the same test the bar
    // applies, so a screen that cannot re-read offers it on neither surface (DW-260).
    if (this.actions.has(screen.descriptor, REFRESH_ACTION_ID)) {
      declared.push({ id: REFRESH_ACTION_ID, rowScoped: false });
    }
    if (this.actions.has(screen.descriptor, screen.primaryAction.id)) {
      declared.push({ id: screen.primaryAction.id, rowScoped: false });
    }
    // The row a self-protection rule is judged against is the one the screen has selected, read
    // from the same store the command bar reads (AD-53). With nothing selected the reason stays
    // "Select a row first", which is what both surfaces already say.
    const selected = screen.rowActions.length === 0
      ? ''
      : this.stores.for(screen.descriptor, screen.refreshRates).selection()[0] ?? '';
    const row = selected === '' ? null : rowFor(this.stores.for(screen.descriptor, screen.refreshRates).data(), screen, selected);
    for (const action of screen.rowActions) {
      // DW-389: the same test the primary action above already applies -- a declared action with
      // no registered handler is a control nothing can act on, so no surface offers it.
      if (action.id !== '' && this.actions.has(screen.descriptor, action.id)) {
        declared.push({
          id: action.id,
          rowScoped: true,
          reason: selected === ''
            ? STRINGS.privilegeSelectRowFirst
            : selfProtectionReason(action.selfProtection, selected, this.signedIn(), row),
        });
      }
    }
    return declared
      .filter(
        (action) =>
          needle === '' ||
          actionLabel(screen.descriptor, action.id).toLowerCase().includes(needle)
      )
      .map((action) => ({
        id: `ocu-command-box-${action.rowScoped ? 'row' : 'action'}-${action.id}`,
        kind: 'action',
        label: actionLabel(screen.descriptor, action.id),
        detail: '',
        // A row action is offered while nothing stands in its way, and listed with the reason
        // inline when something does -- "Select a row first", or the selected row's own
        // self-protection sentence (AD-53). The bar resolves the same two in the same order.
        reason: action.reason ?? '',
        gated: (action.reason ?? '') !== '',
        route: '',
        area: '',
        descriptor: screen.descriptor,
        actionId: action.id,
        ariaDisabled: (action.reason ?? '') !== '' ? 'true' : null,
      }));
  }

  private bump(): void {
    this.generation.set(this.generation() + 1);
  }

  /**
   * The account this tab is signed in as, which the `protected-account` rule compares a row
   * against (AD-53). Optional, so a surface rendered without a session explains nothing by it.
   */
  private signedIn(): string {
    return this.session?.userName() ?? '';
  }
}

/** A screen matches its own name, its declared aliases, or its route -- never an invented list. */
function matchesScreen(screen: ScreenDeclaration, label: string, needle: string): boolean {
  if (needle === '') return true;
  if (label.toLowerCase().includes(needle)) return true;
  if (screen.route.toLowerCase().includes(needle)) return true;
  return screen.commandAliases.some((alias) => alias.toLowerCase().includes(needle));
}

/**
 * Whether to spell the chord the Apple way. `navigator.platform` is deprecated but is still
 * the only synchronous signal every supported browser answers; a miss costs the chip's
 * spelling and nothing else, so there is no fallback worth a round trip.
 */
export function isApplePlatform(): boolean {
  const source = `${navigator.platform ?? ''} ${navigator.userAgent ?? ''}`;
  return /mac|iphone|ipad|ipod/i.test(source);
}
