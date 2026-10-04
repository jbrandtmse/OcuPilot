import { Injectable, Injector, inject } from '@angular/core';
import { Router } from '@angular/router';

import { createFormFor, screenForRoute, withQuery } from '../../core/navigation';
import { ScreenActions } from '../../core/screen-actions';

/** The descriptor whose command bar this action appears on. */
export const ECP_DATA_SERVER_LIST_DESCRIPTOR = 'OcuPilot.Screen.Descriptor.EcpDataServerList';

/** That descriptor's own route, which resolves its paired form through `createFormFor`. */
export const ECP_DATA_SERVER_LIST_ROUTE = 'os-management/ecp-data-servers';

/** The declared primary action id: the command bar's Create, which opens the ECP data server form. */
export const CREATE_ACTION = 'create';

/**
 * The handler behind the ECP data servers list's declared Create (Story 18.20, AD-5, AD-19), on the
 * `license-server-actions.ts` model: registered once against the descriptor's class name and
 * tab-scoped from the application root. The route is resolved through `createFormFor`, never
 * written. The list's Delete is the shell's generic row action, and its Change status is registered
 * by the list's own page.
 */
@Injectable({ providedIn: 'root' })
export class EcpDataServerActions {
  private readonly injector = inject(Injector);

  private readonly actions = inject(ScreenActions);

  constructor() {
    this.actions.register(ECP_DATA_SERVER_LIST_DESCRIPTOR, CREATE_ACTION, () => this.openCreate());
  }

  private openCreate(): void {
    const list = screenForRoute(ECP_DATA_SERVER_LIST_ROUTE);
    const form = list === null ? null : createFormFor(list);
    if (form === null) return;
    const router = this.injector.get(Router);
    void router.navigateByUrl(withQuery(form.route, router.url));
  }
}
