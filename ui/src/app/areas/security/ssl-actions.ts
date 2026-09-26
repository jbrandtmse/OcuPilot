import { Injectable, Injector, inject } from '@angular/core';
import { Router } from '@angular/router';

import { createFormFor, screenForRoute, withQuery } from '../../core/navigation';
import { ScreenActions } from '../../core/screen-actions';

/** The descriptor whose command bar this action appears on. */
export const SSL_LIST_DESCRIPTOR = 'OcuPilot.Screen.Descriptor.SslConfigList';

/** That descriptor's own route, which resolves its paired form through `createFormFor`. */
export const SSL_LIST_ROUTE = 'security/ssl';

/** The declared primary action id: the command bar's Create, which opens the form. */
export const CREATE_ACTION = 'create';

/**
 * The handler behind the SSL/TLS configurations list's declared Create (AD-5, AD-19).
 *
 * The list is served by the generic `ListPage`, so its action is registered here, once, against the
 * descriptor's class name, and tab-scoped from the application root for the reason
 * `web-app-actions.ts` gives (DW-246). The route is resolved through `createFormFor`, never written,
 * and `withQuery` carries the namespace.
 */
@Injectable({ providedIn: 'root' })
export class SslActions {
  private readonly injector = inject(Injector);

  private readonly actions = inject(ScreenActions);

  constructor() {
    this.actions.register(SSL_LIST_DESCRIPTOR, CREATE_ACTION, () => this.openCreate());
  }

  private openCreate(): void {
    const list = screenForRoute(SSL_LIST_ROUTE);
    const editor = list === null ? null : createFormFor(list);
    if (editor === null) return;
    const router = this.injector.get(Router);
    void router.navigateByUrl(withQuery(editor.route, router.url));
  }
}
