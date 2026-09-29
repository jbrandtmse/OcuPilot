import { Injectable, Injector, inject } from '@angular/core';
import { Router } from '@angular/router';

import { createFormFor, parentCriteria, screenForDescriptor, withQuery } from '../../core/navigation';
import { ScreenActions } from '../../core/screen-actions';
import { MAPPING_KINDS, type MappingKindDeclaration } from './mapping-form.store';

/** The declared primary action id: the command bar's Create, which opens the kind's mapping form. */
export const CREATE_ACTION = 'create';

/**
 * The mapping lists' one criterion, which the form's create takes as its query parameter. Never
 * `ns`, which is the data-scope parameter `withQuery` carries (AD-44).
 */
export const NAMESPACE_CRITERION = 'namespace';

/** The create URL of `kind`'s form for `namespace`, carrying the data scope `currentUrl` carries. */
export function mappingCreateUrl(formRoute: string, namespace: string, currentUrl: string): string {
  const target = withQuery(formRoute, currentUrl);
  if (namespace === '') return target;
  return `${target}${target.includes('?') ? '&' : '?'}${NAMESPACE_CRITERION}=${encodeURIComponent(namespace)}`;
}

/**
 * The handler behind the three mapping lists' declared Create (AD-5, AD-19, Story 18.14).
 *
 * Each list is served by the generic `ListPage`, so its action is registered here, once per
 * descriptor, and tab-scoped from the application root for the reason `web-app-actions.ts` gives
 * (DW-246). The route is resolved through `createFormFor`, never written; `withQuery` carries the
 * data scope, and the namespace on screen -- the list's own criterion, read through
 * `parentCriteria` -- travels as the form's `namespace` query parameter, as the Secrets list's
 * collection does. Each list's Delete is the shell's generic row action.
 */
@Injectable({ providedIn: 'root' })
export class MappingActions {
  private readonly injector = inject(Injector);

  private readonly actions = inject(ScreenActions);

  constructor() {
    for (const kind of MAPPING_KINDS) {
      this.actions.register(kind.listDescriptor, CREATE_ACTION, () => this.openCreate(kind));
    }
  }

  private openCreate(kind: MappingKindDeclaration): void {
    const list = screenForDescriptor(kind.listDescriptor);
    const editor = list === null ? null : createFormFor(list);
    if (list === null || editor === null) return;
    const router = this.injector.get(Router);
    const namespace = parentCriteria(list, router.url)[NAMESPACE_CRITERION] ?? '';
    void router.navigateByUrl(mappingCreateUrl(editor.route, namespace, router.url));
  }
}
