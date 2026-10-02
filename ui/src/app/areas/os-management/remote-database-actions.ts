import { Injectable, Injector, inject } from '@angular/core';
import { Router } from '@angular/router';

import { createFormFor, screenForRoute, withQuery } from '../../core/navigation';
import { ScreenActions } from '../../core/screen-actions';

/** The descriptor whose command bar this action appears on. */
export const REMOTE_DATABASE_LIST_DESCRIPTOR = 'OcuPilot.Screen.Descriptor.RemoteDatabaseList';

/** That descriptor's own route, which resolves its paired form through `createFormFor`. */
export const REMOTE_DATABASE_LIST_ROUTE = 'os-management/remote-databases';

/** The declared primary action id: the command bar's Create, which opens the remote database form. */
export const CREATE_ACTION = 'create';

/**
 * The handler behind the Remote databases list's declared Create (Story 18.16, AD-5, AD-19), on the
 * `device-actions.ts` model: registered once against the descriptor's class name and tab-scoped from
 * the application root. The route is resolved through `createFormFor`, never written, and `withQuery`
 * carries the namespace. The list's Delete is the shell's generic row action.
 */
@Injectable({ providedIn: 'root' })
export class RemoteDatabaseActions {
  private readonly injector = inject(Injector);

  private readonly actions = inject(ScreenActions);

  constructor() {
    this.actions.register(REMOTE_DATABASE_LIST_DESCRIPTOR, CREATE_ACTION, () => this.openCreate());
  }

  private openCreate(): void {
    const list = screenForRoute(REMOTE_DATABASE_LIST_ROUTE);
    const form = list === null ? null : createFormFor(list);
    if (form === null) return;
    const router = this.injector.get(Router);
    void router.navigateByUrl(withQuery(form.route, router.url));
  }
}
