import { ChangeDetectionStrategy, Component, computed, input } from '@angular/core';

import { formatRequires } from '../core/navigation';
import { STRINGS } from '../core/strings';

/**
 * What a deep link to a route the user's privileges do not allow renders: the screen's title,
 * and a permission-denied message naming the `(resource, permission)` pair that failed
 * (EXPERIENCE.md `:220`). The rail, the side bar and the rest of the shell keep working around
 * it -- this occupies the content area and nothing else.
 *
 * **Not an `empty-state` and not a banner** (EXPERIENCE.md `:348`: "A refused document or a
 * permission-denied screen is not an empty-state -- it shows the refusal"). It is
 * `role="alert"`, so a user who deep-linked into a refusal hears it rather than finding a blank
 * content area.
 *
 * **The message is the Fixed strings table's own gated-control sentence**, `Requires
 * <resource>`, resolved to the failed pair. The table carries no permission-denied row of its
 * own, and the sentences EXPERIENCE.md spells at `:234` and `:437` are illustrations its own
 * rule (`:248`) forbids transcribing; the pair spelling is also what "names the pair that
 * failed" asks for.
 *
 * Presentational: it takes what it renders as inputs, so the routed component decides *when* a
 * refusal is shown and this decides only what one looks like.
 */
@Component({
  selector: 'app-screen-denied',
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `<section class="ocu-screen-denied" role="alert">
    <h1 class="ocu-screen-denied-title">{{ title() }}</h1>
    <p class="ocu-screen-denied-reason">{{ message() }}</p>
  </section>`,
})
export class ScreenDenied {
  /** The screen's own title, already resolved from its descriptor's string key. */
  readonly title = input.required<string>();

  /** The pair that failed, spelled `resource:permission`. */
  readonly failedPair = input.required<string>();

  protected readonly message = computed(() =>
    formatRequires(STRINGS.privilegeRequiresResource, this.failedPair())
  );
}
