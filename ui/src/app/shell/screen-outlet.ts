import { ChangeDetectionStrategy, Component, DestroyRef, computed, inject, signal } from '@angular/core';
import { toSignal } from '@angular/core/rxjs-interop';
import { ActivatedRoute } from '@angular/router';

import { decodeEntityId } from '../core/entity-id';
import { NavigationService, screenForUrl } from '../core/navigation';
import { ShellState } from '../core/shell-state';
import { STRINGS, stringFor } from '../core/strings';
import { ScreenDenied } from './screen-denied';

/**
 * The routed target for every route in the table, and Story 1.5's `app-deep-link` grown up.
 *
 * It does three things and no more, because the screens themselves are Epic 2's:
 *
 * 1. **Resolves the route to a descriptor** through the mirror, and tells `ShellState` which
 *    area is active, which is what puts `aria-current="page"` on a rail item and fills the side
 *    bar on a cold deep link.
 * 2. **Renders the refusal when the navigation map denies this screen** (EXPERIENCE.md `:220`),
 *    and the not-found screen when the URL names no declared screen at all. An allowed screen
 *    renders nothing yet -- the shell, the rail and the side bar are around it, and Story 1.12
 *    and Epic 2 fill the content area in.
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
  imports: [ScreenDenied],
  template: `<div
    class="ocu-screen-outlet"
    [attr.data-area]="area()"
    [attr.data-screen]="screenRoute()"
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
}
