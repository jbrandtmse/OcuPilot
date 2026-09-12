import {
  ChangeDetectionStrategy,
  Component,
  DestroyRef,
  computed,
  inject,
  signal,
} from '@angular/core';
import { Router } from '@angular/router';

import { InstanceService, serverFlagKind } from '../../core/instance';
import {
  NavigationService,
  firstAllowedScreen,
  formatRequires,
  withQuery,
} from '../../core/navigation';
import { ScopeService } from '../../core/scope';
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
 * EXPERIENCE.md `:352`).
 *
 * **The tile roster is the area vocabulary, not a list typed here** (AD-5). Every area in the
 * rail gets a tile except the two that are not destinations of their own: Home is the surface
 * the tiles sit on, and Agent co-pilot is reached from the rail. Both are read off the
 * declaration rather than named -- Home is the one area whose rail item `navigates`, Agent the
 * one pinned to the bottom -- so a ninth area would take a tile without this file changing.
 *
 * **A tile's caption is its area's built screen names** (EXPERIENCE.md `:352`, `:157`): the
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
 * **Activation opens the area's side bar and its first screen** (EXPERIENCE.md `:352`, as
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
 * Every control-flow condition is a paren-free member reference, for the reason `sign-in.ts`
 * records: `ui/tools/client-lint.mjs`'s blanker matches `@if` plus one parenthesised group.
 */
@Component({
  selector: 'app-home-page',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [ServerFlag],
  template: `<section class="ocu-home">
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
          <app-server-flag [value]="segment.text" />
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

  /**
   * The middle dot DESIGN.md `:896` and EXPERIENCE.md `:352` join with, produced in TypeScript
   * so no non-ASCII byte enters a template (Rule 14). Its surrounding spaces are the flex row's
   * gap rather than characters, so the separator carries no text of its own to be announced --
   * and it is `aria-hidden` wherever it is rendered, which is EXPERIENCE.md `:588`'s own rule
   * for this glyph in particular.
   */
  protected readonly separatorGlyph = '\u00b7';

  /** Bumped whenever the navigation map changes, so the tiles' verdicts follow it. */
  private readonly mapGeneration = signal(0);

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
    inject(DestroyRef).onDestroy(() => {
      stopNavigation();
      stopInstance();
      stopScope();
      stopSession();
    });
  }

  protected get tiles(): readonly AreaTile[] {
    return this.resolvedTiles();
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
}
