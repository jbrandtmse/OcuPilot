import { NgComponentOutlet } from '@angular/common';
import {
  ChangeDetectionStrategy,
  Component,
  DestroyRef,
  type Type,
  computed,
  inject,
  signal,
} from '@angular/core';
import { toSignal } from '@angular/core/rxjs-interop';
import { ActivatedRoute } from '@angular/router';

import { HomePage } from '../areas/home/home.page';
import { decodeEntityId } from '../core/entity-id';
import { NavigationService, screenForUrl } from '../core/navigation';
import type { ArchetypeKey, BuiltArchetypeKey } from '../core/screens.generated';
import { ShellState } from '../core/shell-state';
import { STRINGS, stringFor } from '../core/strings';
import { ListPage } from './list-page';
import { ScreenDenied } from './screen-denied';

/**
 * Archetype to page component (AD-5).
 *
 * **This is what keeps "adding a screen" from meaning "editing a router".** A descriptor
 * declares an archetype; the route table is generated from the mirror and points every route at
 * this one component; and the page that renders is looked up here by that declared archetype --
 * never by a route-table entry naming a component, and never by a per-screen `@if`. A slice
 * adding the first screen of a new archetype registers it in this map and nothing else changes;
 * a slice adding a screen of an archetype already here changes nothing at all.
 *
 * **A built archetype must have a page.** Every `BuiltArchetypeKey` -- the archetype of a
 * `built: true` descriptor, emitted by the mirror -- is a required key here, so a descriptor
 * that sets `built: true` before its page is registered fails `ng build` naming the missing
 * archetype. Any other archetype is optional, and one with no entry renders nothing. Exported so
 * `screen-outlet.spec.ts` can assert that refusal against this map's own type.
 */
type ArchetypePages = { readonly [K in BuiltArchetypeKey]: Type<unknown> } & {
  readonly [K in Exclude<ArchetypeKey, BuiltArchetypeKey>]?: Type<unknown>;
};

export const ARCHETYPE_PAGES: ArchetypePages = {
  home: HomePage,
  list: ListPage,
};

/**
 * The guard `page` applies before indexing `ARCHETYPE_PAGES` -- exported as a pure function so
 * it can be pinned directly against a fixture map, without routing a corrupted archetype through
 * the generated screen mirror (`screens.generated.ts`), which the test suite must not edit.
 *
 * Story 1.15 closed the archetype vocabulary (`OcuPilot.Screen.Archetype`, mirrored as
 * `ArchetypeKey`), so a declared archetype is now one of a known set. That does not make a bare
 * index (`pages[archetype] ?? null`) safe: `ARCHETYPE_PAGES` is a partial map over that set, and
 * a bare index resolves `constructor`, `toString`, or any other inherited `Object.prototype`
 * member to that member's function -- which is not `null` or `undefined`, so it survives the
 * `??` fallback and reaches `ngComponentOutlet` as a non-component. The parameter stays `string`
 * for the same reason the function is exported: it is pinned against a fixture map, with values
 * the closed vocabulary does not contain. `Object.hasOwn` accepts only a key the map declares.
 */
export function resolveArchetypePage(
  pages: Readonly<Record<string, Type<unknown>>>,
  archetype: string
): Type<unknown> | null {
  return Object.hasOwn(pages, archetype) ? pages[archetype] : null;
}

/**
 * The routed target for every route in the table, and Story 1.5's `app-deep-link` grown up.
 *
 * It does three things and no more, because the screens themselves are their slices':
 *
 * 1. **Resolves the route to a descriptor** through the mirror, and tells `ShellState` which
 *    area is active, which is what puts `aria-current="page"` on a rail item and fills the side
 *    bar on a cold deep link.
 * 2. **Renders the screen the descriptor's archetype names** when the navigation map allows it,
 *    the refusal when it denies it (EXPERIENCE.md `:220`), and the not-found screen when the URL
 *    names no declared screen at all. A built screen's archetype always has a page, because
 *    `ARCHETYPE_PAGES` requires one.
 * 3. **Decodes the entity id exactly once.** The id arrives from the router already decoded
 *    once -- Angular's `DefaultUrlSerializer` percent-decodes each segment as it parses the URL
 *    -- so one `decodeEntityId` here completes AD-13's encode-twice, decode-once contract.
 *    Story 1.10's locator bar decodes the same route parameter for its own entity segment;
 *    "decode once" is per value, and neither call is ever chained onto the other's result.
 *
 * The resolved selection is exposed as data attributes, as the placeholder it replaces did, so
 * a browser check can read what the client resolved from a pasted or reloaded URL without
 * reaching into component internals.
 *
 * **The not-found sentence is the command box's own**, "No screen or action matches." -- the
 * Fixed strings table has no not-found row, and this is the table's own sentence for "what you
 * named is not a screen or an action", resolved to a URL rather than to a query. A not-found
 * sentence of its own would be new product copy, which is the owner's call.
 *
 * Every control-flow condition is a paren-free member reference, for the reason `sign-in.ts`
 * records: `ui/tools/client-lint.mjs`'s blanker matches `@if` plus one parenthesised group.
 */
@Component({
  selector: 'app-screen-outlet',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [NgComponentOutlet, ScreenDenied],
  template: `<div
    class="ocu-screen-outlet"
    [attr.data-area]="area()"
    [attr.data-screen]="screenRoute()"
    [attr.data-archetype]="archetype()"
    [attr.data-id]="entityId()"
    [attr.data-ns]="namespace()"
  >
    @if (notFound) {
      <section class="ocu-screen-denied" role="alert">
        <p class="ocu-screen-denied-reason">{{ STRINGS.commandBoxNoMatch }}</p>
      </section>
    }
    @if (denied) {
      <app-screen-denied [title]="title()" [failedPair]="failedPair()" />
    }
    @if (page) {
      <ng-container [ngComponentOutlet]="page" />
    }
  </div>`,
})
export class ScreenOutlet {
  private readonly route = inject(ActivatedRoute);
  private readonly navigation = inject(NavigationService);
  private readonly shell = inject(ShellState);

  protected readonly STRINGS = STRINGS;

  private readonly segments = toSignal(this.route.url, { initialValue: this.route.snapshot.url });

  private readonly params = toSignal(this.route.paramMap, {
    initialValue: this.route.snapshot.paramMap,
  });

  private readonly query = toSignal(this.route.queryParamMap, {
    initialValue: this.route.snapshot.queryParamMap,
  });

  /** Mirrors the framework-free navigation map into the reactive graph. */
  private readonly mapGeneration = signal(0);

  private readonly screen = computed(() =>
    screenForUrl('/' + this.segments().map((segment) => segment.path).join('/'))
  );

  protected readonly area = computed(() => this.screen()?.area ?? '');

  protected readonly screenRoute = computed(() => this.screen()?.route ?? '');

  protected readonly archetype = computed(() => this.screen()?.archetype ?? '');

  protected readonly title = computed(() => stringFor(this.screen()?.labelKey ?? ''));

  protected readonly entityId = computed(() => {
    const raw = this.params().get('id');
    return raw === null ? '' : decodeEntityId(raw);
  });

  protected readonly namespace = computed(() => this.query().get('ns') ?? '');

  protected readonly failedPair = computed(() => {
    this.mapGeneration();
    const screen = this.screen();
    return screen === null ? '' : this.navigation.screenVerdict(screen.route).failedPair;
  });

  private readonly allowed = computed(() => {
    this.mapGeneration();
    const screen = this.screen();
    return screen === null ? true : this.navigation.screenVerdict(screen.route).allowed;
  });

  constructor() {
    const stop = this.navigation.subscribe(() =>
      this.mapGeneration.set(this.mapGeneration() + 1)
    );
    inject(DestroyRef).onDestroy(stop);

    // The area the route belongs to is shell state, not screen state: it drives the rail's
    // `aria-current` and fills the side bar on a cold deep link. Set from an effect-free read
    // of the same computed the template uses, whenever the route changes.
    const stopRoute = this.route.url.subscribe(() => this.shell.setActiveArea(this.area()));
    inject(DestroyRef).onDestroy(() => stopRoute.unsubscribe());
  }

  protected get notFound(): boolean {
    return this.screen() === null;
  }

  protected get denied(): boolean {
    return this.screen() !== null && !this.allowed();
  }

  /**
   * The page for an allowed screen, resolved through the archetype map above -- `null` for a
   * denied screen, an unknown URL, or an archetype no page is registered for.
   */
  protected get page(): Type<unknown> | null {
    const screen = this.screen();
    if (screen === null || !this.allowed()) return null;
    return resolveArchetypePage(ARCHETYPE_PAGES, screen.archetype);
  }
}
