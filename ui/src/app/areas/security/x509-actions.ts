import { Injectable, Injector, inject } from '@angular/core';
import { Router } from '@angular/router';

import { createFormFor, screenForRoute, withQuery } from '../../core/navigation';
import { ScreenActions } from '../../core/screen-actions';

/** The descriptor whose command bar this action appears on. */
export const X509_LIST_DESCRIPTOR = 'OcuPilot.Screen.Descriptor.X509CredentialList';

/** That descriptor's own route, which resolves its paired form through `createFormFor`. */
export const X509_LIST_ROUTE = 'security/x509';

/** The declared primary action id: the command bar's Create, labelled Import, which opens the form. */
export const CREATE_ACTION = 'create';

/**
 * The handler behind the X.509 list's declared Create (AD-5, AD-19).
 *
 * The X.509 list is served by the generic `ListPage`, so its action is registered here, once,
 * against the descriptor's class name, and tab-scoped from the application root for the reason
 * `web-app-actions.ts` gives (DW-246). The route is resolved through `createFormFor`, never written,
 * and `withQuery` carries the namespace.
 */
@Injectable({ providedIn: 'root' })
export class X509Actions {
  private readonly injector = inject(Injector);

  private readonly actions = inject(ScreenActions);

  constructor() {
    this.actions.register(X509_LIST_DESCRIPTOR, CREATE_ACTION, () => this.openImport());
  }

  private openImport(): void {
    const list = screenForRoute(X509_LIST_ROUTE);
    const editor = list === null ? null : createFormFor(list);
    if (editor === null) return;
    const router = this.injector.get(Router);
    void router.navigateByUrl(withQuery(editor.route, router.url));
  }
}
