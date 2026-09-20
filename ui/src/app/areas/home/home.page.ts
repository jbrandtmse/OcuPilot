import {
  ChangeDetectionStrategy,
  Component,
  DestroyRef,
  computed,
  inject,
  signal,
} from '@angular/core';
import { Router } from '@angular/router';

import {
  AccountPreferences,
  FAVORITE_KIND,
  RECENT_KIND,
  formatNamed,
  type PreferenceKind,
} from '../../core/account-preferences';
import { About } from '../../core/about';
import { InstanceService, serverFlagKind } from '../../core/instance';
import {
  NavigationService,
  areaByKey,
  firstAllowedScreen,
  formatRequires,
  isListedScreen,
  screenForRoute,
  withQuery,
} from '../../core/navigation';
import { ScopeService } from '../../core/scope';
import { shortcutScreens } from '../../core/shortcuts';
import { Session } from '../../core/session';
import { ShellState } from '../../core/shell-state';
import { STRINGS, stringFor } from '../../core/strings';
import { ServerFlag } from '../../shell/server-flag';

/** One screen name inside a tile's caption; every part but the first carries a separator. */
interface CaptionPart {
  readonly key: string;
  readonly label: string;
  readonly separated: boolean;
}

/** One area tile, resolved for rendering. */
interface AreaTile {
  readonly key: string;
  readonly label: string;
  readonly caption: readonly CaptionPart[];
  readonly gated: boolean;
  readonly ariaDisabled: string | null;
  readonly reason: string;
  readonly reasonId: string;
  /** The reason element's id, but only when one is rendered -- a gated tile alone has one. */
  readonly describedBy: string | null;
  /** The area's first built screen, or `''` when it has none yet. */
  readonly route: string;
  readonly hasScreen: boolean;
}

/** One remembered screen, resolved for rendering in the Favorites or Recent items block. */
interface RememberedRow {
  readonly route: string;
  readonly label: string;
  readonly gated: boolean;
  readonly ariaDisabled: string | null;
  /** The failed `(resource, permission)` pair, rendered inside the row's own accessible name. */
  readonly reason: string;
  /** The remove control's accessible name, with `<name>` resolved to this screen. */
  readonly removeLabel: string;
  /** The area whose side bar opening the row shows, as a tile activation does. */
  readonly area: string;
}

/** One of the two remembered-screen blocks above the tile grid, resolved for rendering. */
interface RememberedBlock {
  readonly key: string;
  readonly kind: PreferenceKind;
  readonly heading: string;
  readonly emptyLabel: string;
  readonly clearLabel: string;
  /** The polite sentence removing one row announces. */
  readonly removedLabel: string;
  /** The polite sentence clearing the block announces. */
  readonly clearedLabel: string;
  readonly rows: readonly RememberedRow[];
}

/** One shortcut, resolved for rendering in the fixed Shortcuts block. */
interface ShortcutRow {
  readonly route: string;
  readonly label: string;
  readonly gated: boolean;
  readonly ariaDisabled: string | null;
  /** The failed `(resource, permission)` pair, rendered inside the row's own accessible name. */
  readonly reason: string;
  /** The area whose side bar opening the row shows, as a tile activation does. */
  readonly area: string;
}

/** One destination of the links panel, resolved for rendering. */
interface LinkRow {
  readonly key: string;
  readonly label: string;
  readonly href: string;
}

/** One value on the instance line. The flag segment is a badge rather than text. */
interface LineSegment {
  readonly key: string;
  readonly text: string;
  readonly flag: boolean;
  readonly version: boolean;
  readonly separated: boolean;
}

/**
 * Home: the six area tiles and the instance line beneath them (DESIGN.md `:896`, `:1102`;
 * EXPERIENCE.md "Six tiles in daily-use order").
 *
 * **The tile roster is the area vocabulary, not a list typed here** (AD-5). Every area in the
 * rail gets a tile except the two that are not destinations of their own: Home is the surface
 * the tiles sit on, and Agent co-pilot is reached from the rail. Both are read off the
 * declaration rather than named -- Home is the one area whose rail item `navigates`, Agent the
 * one pinned to the bottom -- so a ninth area would take a tile without this file changing.
 *
 * **A tile's caption is its area's built screen names** (EXPERIENCE.md "Six tiles in daily-use order", "Entries in daily-use order."): the
 * side-bar entries that area lists today, joined by a separator that is `aria-hidden` so a
 * screen reader reads names rather than punctuation. Only Home carries a descriptor at the end
 * of Epic 1, so every caption is empty here; that is the published contract rendering
 * correctly, not a missing empty state. Spelling the ~30 screen names in this component would
 * create a second source for every screen name beside its descriptor's `labelKey`, which is
 * the drift AD-5 exists to prevent.
 *
 * **The icon is a 24px `aria-hidden` slot.** DESIGN.md `:1102` publishes the size and the
 * colour; the glyphs themselves are the owner's and unpublished, and nothing here may reach a
 * CDN for one (NFR-10, AD-47). The slot reserves the published geometry, as the rail's glyph
 * does, and contributes nothing to the tile's accessible name. That name is the button's own
 * text: the area name today, and the area name followed by its caption once an area has built
 * screens to caption with.
 *
 * **A gated tile stays listed, focusable and `aria-disabled="true"`** -- never the `disabled`
 * attribute, never hidden -- with the failed `(resource, permission)` pair as its reason on
 * hover **and** on focus through `aria-describedby` (AD-8; EXPERIENCE.md Privilege Gating).
 * Activating one is refused here, because `aria-disabled` carries no behaviour of its own.
 *
 * **The grid is a list.** `display: grid` strips the implied semantics off a `<ul>`, so the
 * roles are explicit: without them a screen-reader user meets six unrelated buttons with no
 * sense of the set or its size. Roles carry no words, so this needs no published string.
 *
 * **Activation opens the area's side bar and its first screen** (EXPERIENCE.md "Six tiles in daily-use order", as
 * amended for **DW-161**: the first built screen *whose own screen verdict allows*). An area
 * whose screens are not built yet still opens its list -- there is nowhere to navigate to, and
 * the bar names the area and lists nothing. An area whose screens are all refused is a
 * different case and is gated in place. The side bar is left open either way: a tile is not
 * the rail item, so a second activation must not toggle it shut.
 *
 * **The instance line carries no per-field labels.** DESIGN.md `:896`'s parenthesised list --
 * server, version, namespace, flag, user -- is the whole published contract and EXPERIENCE.md
 * publishes no Fixed-strings row for it (DW-126), so the five render in that order with `aria-hidden`
 * separators -- the call Story 1.10 made for the status bar's own segments. A field the
 * instance could not report drops, taking its separator with it. It is also where the **full**
 * instance version is readable (**DW-146**): the 24px status bar has to truncate it to a
 * `title`, and this is page content that wraps instead.
 *
 * **Favorites and Recent items sit above the grid** (DESIGN.md `:898`; EXPERIENCE.md
 * "Home — System Information panel · favorites · recents", whose Where column reads "fit
 * above/beside the tile row"; Story 15.2, AD-50). Each is a `role="list"` of `role="listitem"` rows wrapping real buttons --
 * the page's own keyboard model, the same one the tile grid uses, so no roving-tabindex model is
 * invented here. A row whose route no longer resolves to a built screen is **dropped** rather than
 * rendered as a button that opens nothing (AD-37 degrade); the row stays stored, because what the
 * user saved is not this client's to delete. A row the user may no longer open stays listed,
 * focusable and `aria-disabled="true"` with its reason inside the button's own content, which is
 * the shape the command box uses for the same verdict.
 *
 * **Shortcuts and Links sit beside them** (Story 15.3, FR-73; DESIGN.md `:898`). Shortcuts is the
 * classic portal's own fixed roster named as OcuPilot routes (`core/shortcuts.ts`) -- a roster, not
 * a second finder, because the command box is the one finder -- and a row naming no built screen is
 * dropped. Links is the three destinations the classic links panel names, as anchors carrying the
 * house outbound pattern; nothing on either block fetches from another host, so the only off-origin
 * traffic either can cause is a navigation the user clicks (AD-11 rule 4, AD-47). Neither block
 * offers a remove or a Clear: they are fixed rosters, not stored lists, so there is nothing to
 * announce and neither uses the polite region below.
 *
 * **The two remembered blocks are announced from one polite region on this page**, not from the row that
 * disappears: a removed row cannot announce its own removal. The region is visually hidden
 * (`account-menu.ts`'s idiom) rather than a caption, so one removal does not leave a sentence
 * standing under the blocks for the component's life. It is written **after** the write settles
 * and only when the block's stored list actually moved, so a refusal or an unreachable instance
 * announces nothing rather than a removal that did not happen; clearing it first is what gives a
 * second removal a change to announce at all.
 *
 * Every control-flow condition is a paren-free member reference, for the reason `sign-in.ts`
 * records: `ui/tools/client-lint.mjs`'s blanker matches `@if` plus one parenthesised group.
 */
@Component({
  selector: 'app-home-page',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [ServerFlag],
  template: `<section class="ocu-home">
    <div class="ocu-home-remembered">
      @for (block of blocks; track block.key) {
        <section class="ocu-home-block">
          <h2 class="ocu-home-block-heading">{{ block.heading }}</h2>
          @if (block.rows.length) {
            <div class="ocu-home-block-list" role="list">
              @for (row of block.rows; track row.route) {
                <span class="ocu-home-block-row" role="listitem">
                  <button
                    type="button"
                    class="ocu-home-block-open"
                    [attr.aria-disabled]="row.ariaDisabled"
                    (click)="openRemembered(row)"
                  >
                    <span class="ocu-home-block-label" [title]="row.label">{{ row.label }}</span>
                    @if (row.gated) {
                      <span class="ocu-home-block-reason">{{ row.reason }}</span>
                    }
                  </button>
                  <button
                    type="button"
                    class="ocu-home-block-remove"
                    [attr.aria-label]="row.removeLabel"
                    (click)="removeRemembered(block, row)"
                  >
                    <span class="ocu-home-block-glyph" aria-hidden="true">{{ removeGlyph }}</span>
                  </button>
                </span>
              }
            </div>
            <button type="button" class="ocu-home-block-clear" (click)="clearRemembered(block)">
              {{ block.clearLabel }}
            </button>
          } @else {
            <p class="ocu-home-block-empty">{{ block.emptyLabel }}</p>
          }
        </section>
      }
      <section class="ocu-home-block ocu-home-block-fixed">
        <h2 class="ocu-home-block-heading">{{ STRINGS.shortcutsHeading }}</h2>
        @if (shortcuts.length) {
          <div class="ocu-home-block-list" role="list">
            @for (row of shortcuts; track row.route) {
              <span class="ocu-home-block-row" role="listitem">
                <button
                  type="button"
                  class="ocu-home-block-open"
                  [attr.aria-disabled]="row.ariaDisabled"
                  (click)="openShortcut(row)"
                >
                  <span class="ocu-home-block-label" [title]="row.label">{{ row.label }}</span>
                  @if (row.gated) {
                    <span class="ocu-home-block-reason">{{ row.reason }}</span>
                  }
                </button>
              </span>
            }
          </div>
        } @else {
          <p class="ocu-home-block-empty">{{ STRINGS.shortcutsEmpty }}</p>
        }
      </section>
      @if (links.length) {
        <section class="ocu-home-block ocu-home-block-fixed">
          <h2 class="ocu-home-block-heading">{{ STRINGS.linksHeading }}</h2>
          <div class="ocu-home-block-list" role="list">
            @for (row of links; track row.key) {
              <span class="ocu-home-block-row" role="listitem">
                <a class="ocu-home-block-link" [href]="row.href" target="_blank" rel="noreferrer">
                  <span class="ocu-home-block-label" [title]="row.label">{{ row.label }}</span>
                  <span class="ocu-external-glyph" aria-hidden="true">{{ externalGlyph }}</span>
                </a>
              </span>
            }
          </div>
        </section>
      }
    </div>
    <span class="ocu-home-status ocu-visually-hidden" role="status">{{ announcement }}</span>
    <div class="ocu-area-tile-grid" role="list">
      @for (tile of tiles; track tile.key) {
        <span class="ocu-area-tile-slot" role="listitem">
          <button
            type="button"
            class="ocu-area-tile"
            [attr.aria-disabled]="tile.ariaDisabled"
            [attr.aria-describedby]="tile.describedBy"
            (click)="activate(tile)"
          >
            <span class="ocu-area-tile-icon" aria-hidden="true"></span>
            <span class="ocu-area-tile-name">{{ tile.label }}</span>
            <span class="ocu-area-tile-caption">
              @for (part of tile.caption; track part.key) {
                @if (part.separated) {
                  <span class="ocu-area-tile-separator" aria-hidden="true">{{
                    separatorGlyph
                  }}</span>
                }
                <span class="ocu-area-tile-screen">{{ part.label }}</span>
              }
            </span>
          </button>
          @if (tile.gated) {
            <span class="ocu-area-tile-reason" role="tooltip" [id]="tile.reasonId">{{
              tile.reason
            }}</span>
          }
        </span>
      }
    </div>
    <p class="ocu-instance-line">
      @for (segment of instanceLine; track segment.key) {
        @if (segment.separated) {
          <span class="ocu-instance-separator" aria-hidden="true">{{ separatorGlyph }}</span>
        }
        @if (segment.flag) {
          <app-server-flag [value]="segment.text" [unbounded]="true" />
        } @else {
          <span
            class="ocu-instance-segment"
            [class.ocu-instance-version]="segment.version"
            >{{ segment.text }}</span
          >
        }
      }
    </p>
  </section>`,
})
export class HomePage {
  private readonly navigation = inject(NavigationService);
  private readonly instance = inject(InstanceService);
  private readonly scope = inject(ScopeService);
  private readonly session = inject(Session);
  private readonly shell = inject(ShellState);
  private readonly router = inject(Router);
  private readonly preferences = inject(AccountPreferences);
  private readonly about = inject(About);

  protected readonly STRINGS = STRINGS;

  /**
   * The middle dot DESIGN.md `:896` and EXPERIENCE.md "Six tiles in daily-use order" join with, produced in TypeScript
   * so no non-ASCII byte enters a template (Rule 14). Its surrounding spaces are the flex row's
   * gap rather than characters, so the separator carries no text of its own to be announced --
   * and it is `aria-hidden` wherever it is rendered, which is EXPERIENCE.md "**Names, roles, glyphs.** Rail-items"'s own rule
   * for this glyph in particular.
   */
  protected readonly separatorGlyph = '\u00b7';

  /** Bumped whenever the navigation map changes, so the tiles' verdicts follow it. */
  private readonly mapGeneration = signal(0);

  /** Bumped whenever the remembered lists change, so the two blocks follow them. */
  private readonly preferenceGeneration = signal(0);

  /** Bumped whenever the About read settles, so the links panel follows it. */
  private readonly aboutGeneration = signal(0);

  /** The polite region's text: empty until a removal or a clear has changed the store. */
  private readonly announcementValue = signal('');

  /**
   * The remove control's glyph, produced in TypeScript so no non-ASCII byte enters a template
   * (Rule 14). It is `aria-hidden`, so the control's accessible name is its `aria-label` alone --
   * which names the screen it removes.
   */
  protected readonly removeGlyph = '\u00d7';

  /**
   * The north-east arrow every outbound link in the shell carries (`instance-notice.ts`,
   * `classic-link-card.ts`), written as its escape so no non-ASCII byte enters a template
   * (Rule 14). `aria-hidden`, so each link's accessible name is its own word.
   */
  protected readonly externalGlyph = '\u2197';

  /** Mirrors the framework-free services into the reactive graph, as the status bar does. */
  private readonly serverName = signal(this.instance.serverName());

  private readonly instanceVersion = signal(this.instance.instanceVersion());

  private readonly serverFlag = signal(this.instance.serverFlag());

  private readonly namespace = signal(this.scope.namespace());

  private readonly userName = signal(this.session.userName());

  private readonly resolvedTiles = computed<readonly AreaTile[]>(() => {
    this.mapGeneration();
    return this.navigation
      .areas()
      .filter((area) => !area.navigates && !area.pinBottom)
      .map((area) => {
        const verdict = this.navigation.areaVerdict(area.key);
        const screens = this.navigation.screensForArea(area.key);
        // **DW-161: the target is the first screen the user may actually open**, not the first
        // one declared. An area whose verdict allows entry but whose first built screen this
        // user's own `screenVerdict` refuses used to be a tile that navigated straight into a
        // refusal; it now opens the next screen that is allowed instead.
        const openable = firstAllowedScreen(screens, (route) =>
          this.navigation.screenVerdict(route)
        );
        // ...and when none of them is, the tile is gated in place -- listed, focusable,
        // `aria-disabled` -- exactly as the side bar refuses one of its own entries. An area
        // with NO built screens is a different thing and stays open: it has nowhere to go, not
        // somewhere it may not go, and its tile still opens the (empty) side bar.
        const blocked = screens.length > 0 && openable === null;
        const gated = !verdict.allowed || blocked;
        // The pair that is actually missing. For a refused area that is the area's own; for an
        // area whose screens are all refused it is the first screen's, because "Requires " with
        // nothing after it names no privilege at all.
        const failedPair = verdict.allowed
          ? this.navigation.screenVerdict(screens[0]?.route ?? '').failedPair
          : verdict.failedPair;
        const reasonId = `ocu-area-tile-reason-${area.key}`;
        return {
          key: area.key,
          label: stringFor(area.labelKey),
          caption: screens.map((screen, index) => ({
            key: screen.route,
            label: stringFor(screen.labelKey),
            separated: index > 0,
          })),
          gated,
          ariaDisabled: gated ? 'true' : null,
          reason: formatRequires(STRINGS.privilegeRequiresResource, failedPair),
          reasonId,
          describedBy: gated ? reasonId : null,
          route: openable === null ? '' : openable.route,
          hasScreen: openable !== null,
        };
      });
  });

  private readonly resolvedBlocks = computed<readonly RememberedBlock[]>(() => {
    this.preferenceGeneration();
    this.mapGeneration();
    return [
      {
        key: 'favorites',
        kind: FAVORITE_KIND,
        heading: STRINGS.favoritesHeading,
        emptyLabel: STRINGS.favoritesEmpty,
        clearLabel: STRINGS.favoritesClear,
        removedLabel: STRINGS.favoritesRemoved,
        clearedLabel: STRINGS.favoritesCleared,
        rows: this.rowsFor(this.preferences.favorites(), STRINGS.favoritesRemoveNamed),
      },
      {
        key: 'recents',
        kind: RECENT_KIND,
        heading: STRINGS.recentsHeading,
        emptyLabel: STRINGS.recentsEmpty,
        clearLabel: STRINGS.recentsClear,
        removedLabel: STRINGS.recentsRemoved,
        clearedLabel: STRINGS.recentsCleared,
        rows: this.rowsFor(this.preferences.recents(), STRINGS.recentsRemoveNamed),
      },
    ];
  });

  /**
   * The fixed shortcuts roster, less the rows naming no built screen (AD-37 degrade), each
   * carrying this user's own verdict for it.
   */
  private readonly resolvedShortcuts = computed<readonly ShortcutRow[]>(() => {
    this.mapGeneration();
    return shortcutScreens().map((screen) => {
      const verdict = this.navigation.screenVerdict(screen.route);
      return {
        route: screen.route,
        label: stringFor(screen.labelKey),
        gated: !verdict.allowed,
        ariaDisabled: verdict.allowed ? null : 'true',
        reason: formatRequires(STRINGS.privilegeRequiresResource, verdict.failedPair),
        area: screen.area,
      };
    });
  });

  /**
   * The three links-panel destinations, in the classic portal's own order, less any the instance
   * did not answer an address for -- an anchor with no `href` is not a link.
   *
   * When that leaves none -- a read that has not answered yet, or one that failed with nothing
   * held -- the block does not render at all. A heading standing over an empty list says there are
   * no links when the truth is that the instance has not said; and unlike the remembered blocks
   * beside it, there is nothing here a person did that an empty state could report back to them.
   */
  private readonly resolvedLinks = computed<readonly LinkRow[]>(() => {
    this.aboutGeneration();
    const links = this.about.links();
    return [
      { key: 'documentation', label: STRINGS.linksDocumentation, href: links.documentation },
      { key: 'support', label: STRINGS.linksSupport, href: links.support },
      { key: 'intersystems', label: STRINGS.linksInterSystems, href: links.intersystems },
    ].filter((row) => row.href !== '');
  });

  /**
   * The five values in DESIGN.md `:896`'s order, with the ones the instance could not report
   * dropped. The flag is a segment like any other so the separators fall where the rendered
   * values are, and its own "nothing is set" state (`serverFlagKind` `none`, the ordinary case
   * -- DW-10) drops it here rather than leaving a separator pointing at an empty badge.
   */
  private readonly resolvedLine = computed<readonly LineSegment[]>(() => {
    const declared = [
      { key: 'server', text: this.serverName(), flag: false, version: false },
      { key: 'version', text: this.instanceVersion(), flag: false, version: true },
      { key: 'namespace', text: this.namespace(), flag: false, version: false },
      { key: 'flag', text: this.serverFlag(), flag: true, version: false },
      { key: 'user', text: this.userName(), flag: false, version: false },
    ];
    return declared
      .filter((part) => (part.flag ? serverFlagKind(part.text) !== 'none' : part.text !== ''))
      .map((part, index) => ({ ...part, separated: index > 0 }));
  });

  constructor() {
    const stopNavigation = this.navigation.subscribe(() =>
      this.mapGeneration.set(this.mapGeneration() + 1)
    );
    const stopInstance = this.instance.subscribe(() => {
      this.serverName.set(this.instance.serverName());
      this.instanceVersion.set(this.instance.instanceVersion());
      this.serverFlag.set(this.instance.serverFlag());
    });
    const stopScope = this.scope.subscribe(() => this.namespace.set(this.scope.namespace()));
    const stopSession = this.session.subscribe(() => this.userName.set(this.session.userName()));
    const stopPreferences = this.preferences.subscribe(() =>
      this.preferenceGeneration.set(this.preferenceGeneration() + 1)
    );
    // Read the remembered lists on arrival, not only once at sign-in. `App.verifyWhenSignedIn`
    // issues the tab's first read, but it fires on a session *state change*, so a tab that stays
    // signed in never reads again -- and this is the only surface that renders both lists. Without
    // this, a write whose answer the store parked (a newer request settled first, or the instance
    // did not reply) leaves Home showing the wrong lists for the life of the tab, and arriving at
    // Home is exactly the gesture that cannot repair it. A failed read still parks rather than
    // clearing, so the matrix's unreachable-instance row is unchanged.
    void this.preferences.load();
    // The links panel's three destinations come from the same caller-own read About uses: the
    // documentation one follows whether this instance serves its own copy, so a second source for
    // it could disagree with the Help control about where the documentation is. Read here because
    // Home is where the panel is; a tab that never opens Home never spends the request.
    const stopAbout = this.about.subscribe(() =>
      this.aboutGeneration.set(this.aboutGeneration() + 1)
    );
    void this.about.load();
    inject(DestroyRef).onDestroy(() => {
      stopNavigation();
      stopInstance();
      stopScope();
      stopSession();
      stopPreferences();
      stopAbout();
    });
  }

  protected get tiles(): readonly AreaTile[] {
    return this.resolvedTiles();
  }

  protected get blocks(): readonly RememberedBlock[] {
    return this.resolvedBlocks();
  }

  protected get shortcuts(): readonly ShortcutRow[] {
    return this.resolvedShortcuts();
  }

  protected get links(): readonly LinkRow[] {
    return this.resolvedLinks();
  }

  protected get announcement(): string {
    return this.announcementValue();
  }

  protected get instanceLine(): readonly LineSegment[] {
    return this.resolvedLine();
  }

  /**
   * Open the area: show its screen list, and go to its first built screen when it has one.
   *
   * Enter and Space reach this through the tile's own `<button>`, which is why there is no
   * keydown handler -- a native button's activation behaviour already makes the keyboard path
   * identical to the click, refusal included.
   *
   * The current query travels: `?ns=` is data scope, and a tile click that dropped it would
   * silently move the user's work to another namespace (AD-44).
   */
  protected activate(tile: AreaTile): void {
    if (tile.gated) return;
    this.shell.showArea(tile.key);
    if (!tile.hasScreen) return;
    void this.router.navigateByUrl(withQuery(tile.route, this.router.url));
  }

  /**
   * Open a remembered screen. A gated row does nothing: `aria-disabled` carries no behaviour of
   * its own, so the refusal has to be here -- the same shape the tiles and the command box use.
   *
   * An open side bar is moved to the screen's area first, so the list beside the screen is that
   * screen's own; a collapsed one stays collapsed, because Ctrl/Cmd+B's choice is remembered. The
   * current query travels, because `?ns=` is data scope (AD-44).
   */
  protected openRemembered(row: RememberedRow): void {
    if (row.gated) return;
    const area = areaByKey(row.area);
    if (area !== null && !area.navigates && this.shell.open()) this.shell.showArea(area.key);
    void this.router.navigateByUrl(withQuery(row.route, this.router.url));
  }

  /**
   * Open a shortcut. A gated row does nothing, the same shape the tiles, the remembered rows and
   * the command box use for the same verdict: `aria-disabled` carries no behaviour of its own.
   *
   * An open side bar is moved to the screen's area first, so the list beside the screen is that
   * screen's own; a collapsed one stays collapsed. The current query travels, because `?ns=` is
   * data scope (AD-44).
   */
  protected openShortcut(row: ShortcutRow): void {
    if (row.gated) return;
    const area = areaByKey(row.area);
    if (area !== null && !area.navigates && this.shell.open()) this.shell.showArea(area.key);
    void this.router.navigateByUrl(withQuery(row.route, this.router.url));
  }

  /**
   * Drop one row, and announce which list it left once the instance's answer says it did. That
   * answer re-renders the block, so a removal the instance refused -- or never heard -- leaves
   * the row where it is and announces nothing.
   */
  protected removeRemembered(block: RememberedBlock, row: RememberedRow): void {
    this.announceOnChange(block.kind, block.removedLabel, () =>
      this.preferences.remove(block.kind, row.route)
    );
  }

  /** Empty one block, and announce it on the same terms. */
  protected clearRemembered(block: RememberedBlock): void {
    this.announceOnChange(block.kind, block.clearedLabel, () => this.preferences.clear(block.kind));
  }

  /**
   * Announce <code>label</code> once <code>write</code> has settled, and only when the stored list
   * for <code>kind</code> no longer holds what it held when the write was issued.
   *
   * <code>write</code> is a function rather than a promise so the list it is compared against is
   * read before the request goes out, whatever the store does synchronously on the way.
   *
   * The comparison is on membership rather than on length, because a concurrent visit can add a
   * row as this one removes one and leave the length where it was -- which would announce nothing
   * although the row the user asked about did go.
   *
   * Cleared before the wait for two reasons: a sentence the region already carries is not read
   * out again when it is re-written, and a refusal must not leave the previous action's
   * confirmation standing as though it were this one's.
   */
  private announceOnChange(kind: PreferenceKind, label: string, write: () => Promise<void>): void {
    const held = [...this.stored(kind)];
    this.announcementValue.set('');
    void write().then(() => {
      const now = this.stored(kind);
      if (held.every((route) => now.includes(route)) && held.length === now.length) return;
      this.announcementValue.set(label);
    });
  }

  /** The routes the store holds for one kind, whatever this page renders of them. */
  private stored(kind: PreferenceKind): readonly string[] {
    return kind === FAVORITE_KIND ? this.preferences.favorites() : this.preferences.recents();
  }

  /**
   * One block's rows: the routes the instance answered, less the ones that no longer name a built
   * screen (AD-37 -- dropped from the rendering, never from the store), each carrying the verdict
   * this user's navigation map holds for it.
   *
   * An **unlisted** screen is dropped on the same terms. `sideBarPosition` 0 marks one reached only
   * from its own list and keyed by an entity id, so the stored route is the id-less parent and a
   * row for it would open the screen with no entity -- a create form the user did not ask for.
   * `recents-recorder.ts` no longer records one; this drops the rows an earlier build stored.
   */
  private rowsFor(routes: readonly string[], removeTemplate: string): readonly RememberedRow[] {
    const rows: RememberedRow[] = [];
    for (const route of routes) {
      const screen = screenForRoute(route);
      if (screen === null || !screen.built || !isListedScreen(screen)) continue;
      const label = stringFor(screen.labelKey);
      const verdict = this.navigation.screenVerdict(route);
      rows.push({
        route,
        label,
        gated: !verdict.allowed,
        ariaDisabled: verdict.allowed ? null : 'true',
        reason: formatRequires(STRINGS.privilegeRequiresResource, verdict.failedPair),
        removeLabel: formatNamed(removeTemplate, label),
        area: screen.area,
      });
    }
    return rows;
  }
}
