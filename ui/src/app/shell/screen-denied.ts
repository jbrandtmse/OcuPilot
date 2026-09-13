import { ChangeDetectionStrategy, Component, computed, input } from '@angular/core';

import { formatDeniedScreen } from '../core/navigation';
import { STRINGS } from '../core/strings';

/**
 * What a deep link to a route the user's privileges do not allow renders: the screen's title,
 * and a permission-denied message naming the `(resource, permission)` pair that failed
 * (EXPERIENCE.md `:222`). The rail, the side bar and the rest of the shell keep working around
 * it -- this occupies the content area and nothing else.
 *
 * **Not an `empty-state` and not a banner** (EXPERIENCE.md `:361`: "A refused document or a
 * permission-denied screen is not an empty-state -- it shows the refusal"). It is
 * `role="alert"`, so a user who deep-linked into a refusal hears it rather than finding a blank
 * content area.
 *
 * **The message is the Fixed strings table's permission-denied sentence**, `You need <resource>
 * to open <screen>.` (EXPERIENCE.md `:294`), with `<resource>` resolved to the failed pair,
 * spelled `resource:permission`, and `<screen>` to the screen's title.
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
    formatDeniedScreen(STRINGS.privilegeDeniedScreen, this.failedPair(), this.title())
  );
}
