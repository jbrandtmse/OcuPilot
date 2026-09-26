import { Injectable, Injector, inject } from '@angular/core';
import { Router } from '@angular/router';

import { createFormFor, parentCriteria, screenForRoute, withQuery } from '../../core/navigation';
import { ScreenActions } from '../../core/screen-actions';

/** The descriptor whose command bar this action appears on. */
export const WALLET_SECRET_LIST_DESCRIPTOR = 'OcuPilot.Screen.Descriptor.WalletSecretList';

/** That descriptor's own route, which resolves its paired form through `createFormFor`. */
export const WALLET_SECRET_LIST_ROUTE = 'security/wallet/secrets';

/** The declared primary action id: the command bar's Create, which opens the form. */
export const CREATE_ACTION = 'create';

/** The Secrets list's one criterion, which the form's create takes as its query parameter. */
export const COLLECTION_CRITERION = 'collection';

/**
 * The handler behind the Secrets list's declared Create (AD-5, AD-19).
 *
 * The Secrets list is served by the generic `ListPage`, so its action is registered here, once,
 * against the descriptor's class name, and tab-scoped from the application root for the reason
 * `web-app-actions.ts` gives (DW-246). The route is resolved through `createFormFor`, never written;
 * `withQuery` carries the namespace, and the collection on screen -- the list's own criterion, read
 * through `parentCriteria` -- travels as the form's `collection` query parameter.
 */
@Injectable({ providedIn: 'root' })
export class WalletActions {
  private readonly injector = inject(Injector);

  private readonly actions = inject(ScreenActions);

  constructor() {
    this.actions.register(WALLET_SECRET_LIST_DESCRIPTOR, CREATE_ACTION, () => this.openCreate());
  }

  private openCreate(): void {
    const list = screenForRoute(WALLET_SECRET_LIST_ROUTE);
    const editor = list === null ? null : createFormFor(list);
    if (list === null || editor === null) return;
    const router = this.injector.get(Router);
    const collection = parentCriteria(list, router.url)[COLLECTION_CRITERION] ?? '';
    const target = withQuery(editor.route, router.url);
    const joined = collection === '' ? target : `${target}${target.includes('?') ? '&' : '?'}${COLLECTION_CRITERION}=${encodeURIComponent(collection)}`;
    void router.navigateByUrl(joined);
  }
}
