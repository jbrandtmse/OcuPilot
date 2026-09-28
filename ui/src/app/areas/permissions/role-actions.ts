import { Injectable, Injector, inject } from '@angular/core';
import { Router } from '@angular/router';

import { createFormFor, screenForDescriptor, screenForRoute, withQuery } from '../../core/navigation';
import { PERMISSION_CHECK_ACTION_ID, ScreenActions } from '../../core/screen-actions';
import { ScreenStores } from '../../core/screen-store';
import { PermissionCheck } from '../../shell/permission-check';

/** The descriptor whose command bar this action appears on. */
export const ROLE_LIST_DESCRIPTOR = 'OcuPilot.Screen.Descriptor.RoleList';

/** That descriptor's own route, which resolves its paired form through `createFormFor`. */
export const ROLE_LIST_ROUTE = 'permissions/roles';

/** The declared primary action id: the command bar's Create, which opens the form. */
export const CREATE_ACTION = 'create';

/**
 * The handlers behind the Roles list's declared Create (AD-5, AD-19) and its Check permission (Story
 * 16.3), which opens the dialog prefilled with the selected row.
 *
 * The Roles list is served by the generic `ListPage`, so its action is registered here, once,
 * against the descriptor's class name -- the key `ScreenActions` is indexed by. It is tab-scoped
 * and constructed from the application root before the first change-detection pass, for the
 * reason `web-app-actions.ts` gives (DW-246): a registration from a routed page's constructor
 * would write `CommandBar`'s signal inside a pass that has already checked it.
 *
 * The route is resolved through `createFormFor`, never written, and `withQuery` carries the
 * namespace.
 */
@Injectable({ providedIn: 'root' })
export class RoleActions {
  private readonly injector = inject(Injector);

  private readonly actions = inject(ScreenActions);

  private readonly check = inject(PermissionCheck);

  constructor() {
    this.actions.register(ROLE_LIST_DESCRIPTOR, CREATE_ACTION, () => this.openCreate());
    // Story 16.3: screen-level, so it runs with or without a selection; a selected row prefills it.
    this.actions.register(ROLE_LIST_DESCRIPTOR, PERMISSION_CHECK_ACTION_ID, () => this.check.open(ROLE_LIST_DESCRIPTOR, 'role', this.selected()));
  }

  /** The Roles list's selected row, or `''`. */
  private selected(): string {
    const screen = screenForDescriptor(ROLE_LIST_DESCRIPTOR);
    if (screen === null) return '';
    return this.injector.get(ScreenStores).for(screen.descriptor, screen.refreshRates).selection()[0] ?? '';
  }

  private openCreate(): void {
    const list = screenForRoute(ROLE_LIST_ROUTE);
    const editor = list === null ? null : createFormFor(list);
    if (editor === null) return;
    const router = this.injector.get(Router);
    void router.navigateByUrl(withQuery(editor.route, router.url));
  }
}
