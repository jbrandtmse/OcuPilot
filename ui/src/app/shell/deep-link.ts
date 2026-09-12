import { ChangeDetectionStrategy, Component, computed, inject } from '@angular/core';
import { toSignal } from '@angular/core/rxjs-interop';
import { ActivatedRoute } from '@angular/router';

import { decodeEntityId } from '../core/entity-id';

/**
 * Placeholder target for every route in `app.routes.ts`, and the whole of the
 * client half of the deep-link criterion: it exposes the selection the router
 * resolved -- area, screen, decoded id and namespace -- as data attributes, so a
 * browser check can read what the client actually resolved from a pasted or
 * reloaded URL without reaching into component internals.
 *
 * It renders no copy, which is why it needs no `STRINGS` key. Story 1.9 replaces
 * both this component and the route table with the screen descriptor registry.
 *
 * The id arrives from the router already decoded once -- Angular's
 * `DefaultUrlSerializer` percent-decodes each path segment as it parses the URL, not
 * the browser -- so `decodeEntityId` is called exactly once here, which is the single
 * decode point AD-13 allows.
 */
@Component({
  selector: 'app-deep-link',
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `<div
    class="ocu-deep-link"
    [attr.data-area]="area()"
    [attr.data-screen]="screen()"
    [attr.data-id]="id()"
    [attr.data-ns]="ns()"
  ></div>`,
})
export class DeepLink {
  private readonly route = inject(ActivatedRoute);

  private readonly params = toSignal(this.route.paramMap, {
    initialValue: this.route.snapshot.paramMap,
  });

  private readonly query = toSignal(this.route.queryParamMap, {
    initialValue: this.route.snapshot.queryParamMap,
  });

  protected readonly area = computed(() => this.params().get('area') ?? '');

  protected readonly screen = computed(() => this.params().get('screen') ?? '');

  protected readonly id = computed(() => {
    const raw = this.params().get('id');
    return raw === null ? '' : decodeEntityId(raw);
  });

  protected readonly ns = computed(() => this.query().get('ns') ?? '');
}
