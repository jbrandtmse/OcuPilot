import { ChangeDetectionStrategy, Component, DestroyRef, inject, signal } from '@angular/core';

import { isStale } from '../core/build-identity';
import { InstanceService } from '../core/instance';
import { STRINGS } from '../core/strings';

/**
 * The polite prompt a tab holding an older bundle than the instance has installed (Story 15.3,
 * DW-3; EXPERIENCE.md "**Status messages (WCAG 4.1.3).** The transcript").
 *
 * **It never reloads by itself and it never blocks.** A reload discards whatever the user was
 * doing -- an open form, a filtered table, a conversation -- so the decision is theirs and the
 * region is polite rather than an alert. Nothing else on the page is inert while it stands.
 *
 * **Absence is not a mismatch.** `isStale` is false whenever either identity is empty, so a dev
 * serve, a build with hashing off and an instance that cannot say what it installed all render
 * nothing. The comparison runs on every `/instance` settle, which is the read the shell already
 * makes at sign-in and on every connectivity recovery -- so no timer is armed for this.
 *
 * Every control-flow condition is a paren-free member reference, for the reason `sign-in.ts`
 * records: `ui/tools/client-lint.mjs`'s blanker matches `@if` plus one parenthesised group.
 */
@Component({
  selector: 'app-stale-bundle-notice',
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `@if (stale) {
    <div class="ocu-stale-bundle" role="status">
      <span class="ocu-stale-bundle-text">{{ STRINGS.staleBundleNotice }}</span>
      <button type="button" class="ocu-button-secondary" (click)="chooseReload()">
        {{ STRINGS.actionReload }}
      </button>
    </div>
  }`,
})
export class StaleBundleNotice {
  private readonly instance = inject(InstanceService);

  protected readonly STRINGS = STRINGS;

  /** Mirrors the framework-free instance service into the reactive graph. */
  private readonly serverIdentity = signal(this.instance.buildIdentity());

  constructor() {
    const stop = this.instance.subscribe(() =>
      this.serverIdentity.set(this.instance.buildIdentity())
    );
    inject(DestroyRef).onDestroy(stop);
  }

  protected get stale(): boolean {
    return isStale(this.serverIdentity());
  }

  /**
   * Fetch the document again rather than re-running the cached one: `index.html` is served
   * `no-store`, so an ordinary reload already asks the instance for it, and that is what brings
   * the new hashed bundle with it.
   */
  protected chooseReload(): void {
    window.location.reload();
  }
}
