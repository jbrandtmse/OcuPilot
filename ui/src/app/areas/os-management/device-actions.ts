import { Injectable, Injector, inject } from '@angular/core';
import { Router } from '@angular/router';

import { createFormFor, screenForRoute, withQuery } from '../../core/navigation';
import { ScreenActions } from '../../core/screen-actions';

/** The descriptor whose command bar this action appears on. */
export const DEVICE_LIST_DESCRIPTOR = 'OcuPilot.Screen.Descriptor.DeviceList';

/** That descriptor's own route, which resolves its paired form through `createFormFor`. */
export const DEVICE_LIST_ROUTE = 'os-management/devices';

/** The declared primary action id: the command bar's Create, which opens the device editor. */
export const CREATE_ACTION = 'create';

/**
 * The handler behind the Devices list's declared Create (AD-5, AD-19).
 *
 * The Devices list is served by the generic `ListPage`, so its action is registered here, once,
 * against the descriptor's class name, and tab-scoped from the application root for the reason
 * `web-app-actions.ts` gives (DW-246). The route is resolved through `createFormFor`, never written,
 * and `withQuery` carries the namespace.
 */
@Injectable({ providedIn: 'root' })
export class DeviceActions {
  private readonly injector = inject(Injector);

  private readonly actions = inject(ScreenActions);

  constructor() {
    this.actions.register(DEVICE_LIST_DESCRIPTOR, CREATE_ACTION, () => this.openCreate());
  }

  private openCreate(): void {
    const list = screenForRoute(DEVICE_LIST_ROUTE);
    const editor = list === null ? null : createFormFor(list);
    if (editor === null) return;
    const router = this.injector.get(Router);
    void router.navigateByUrl(withQuery(editor.route, router.url));
  }
}
