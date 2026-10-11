import { Injectable, Injector, inject } from '@angular/core';
import { Router } from '@angular/router';

import { createFormFor, screenForRoute, withQuery } from '../../core/navigation';
import { ScreenActions } from '../../core/screen-actions';

/** The descriptor whose command bar this action appears on. */
export const ROUTINE_APP_LIST_DESCRIPTOR = 'OcuPilot.Screen.Descriptor.RoutineAppList';

/** That descriptor's own route, which resolves its paired form through `createFormFor`. */
export const ROUTINE_APP_LIST_ROUTE = 'web-applications/routine-applications';

/** The declared primary action id: the command bar's Create, which opens the application form. */
export const CREATE_ACTION = 'create';

/**
 * The handler behind the privileged routine applications list's declared Create (Story 18.31, AD-5, AD-19), on the
 * `docdb-app-actions.ts` model: registered once against the descriptor's class name and tab-scoped from the
 * application root. The route is resolved through `createFormFor`, never written. The list's Delete is the shell's
 * generic row action. No form base exists to share (DW-2278).
 */
@Injectable({ providedIn: 'root' })
export class RoutineAppActions {
  private readonly injector = inject(Injector);

  private readonly actions = inject(ScreenActions);

  constructor() {
    this.actions.register(ROUTINE_APP_LIST_DESCRIPTOR, CREATE_ACTION, () => this.openCreate());
  }

  private openCreate(): void {
    const list = screenForRoute(ROUTINE_APP_LIST_ROUTE);
    const form = list === null ? null : createFormFor(list);
    if (form === null) return;
    const router = this.injector.get(Router);
    void router.navigateByUrl(withQuery(form.route, router.url));
  }
}
