import { Injectable, Injector, inject } from '@angular/core';
import { Router } from '@angular/router';

import { createFormFor, screenForRoute, withQuery } from '../../core/navigation';
import { ScreenActions } from '../../core/screen-actions';

/** The descriptor whose command bar this action appears on. */
export const USER_LIST_DESCRIPTOR = 'OcuPilot.Screen.Descriptor.UserList';

/** That descriptor's own route, which resolves its paired form through `createFormFor`. */
export const USER_LIST_ROUTE = 'permissions/users';

/** The declared primary action id: the command bar's Create, which opens the form. */
export const CREATE_ACTION = 'create';

/**
 * The handler behind the Users list's declared Create (AD-5, AD-19).
 *
 * The Users list is served by the generic `ListPage`, so its action is registered here, once,
 * against the descriptor's class name -- the key `ScreenActions` is indexed by. It is tab-scoped
 * and constructed from the application root before the first change-detection pass, for the
 * reason `web-app-actions.ts` gives (DW-246): a registration from a routed page's constructor
 * would write `CommandBar`'s signal inside a pass that has already checked it.
 *
 * The route is resolved through `createFormFor`, never written, and `withQuery` carries the
 * namespace.
 */
@Injectable({ providedIn: 'root' })
export class UserActions {
  private readonly injector = inject(Injector);

  private readonly actions = inject(ScreenActions);

  constructor() {
    this.actions.register(USER_LIST_DESCRIPTOR, CREATE_ACTION, () => this.openCreate());
  }

  private openCreate(): void {
    const list = screenForRoute(USER_LIST_ROUTE);
    const editor = list === null ? null : createFormFor(list);
    if (editor === null) return;
    const router = this.injector.get(Router);
    void router.navigateByUrl(withQuery(editor.route, router.url));
  }
}
