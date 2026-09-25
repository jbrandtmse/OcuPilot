import { Injectable, Injector, inject } from '@angular/core';
import { Router } from '@angular/router';

import { createFormFor, screenForRoute, withQuery } from '../../core/navigation';
import { ScreenActions } from '../../core/screen-actions';

/** The tab whose command bar this action appears on. */
export const OAUTH_SERVER_TAB_DESCRIPTOR = 'OcuPilot.Screen.Descriptor.OAuthServerDescriptionTab';

/** That tab's own route, which resolves its paired form through `createFormFor`. */
export const OAUTH_SERVER_TAB_ROUTE = 'security/oauth';

/** The declared primary action id: the command bar's Create, which opens the server description editor. */
export const CREATE_ACTION = 'create';

/**
 * The handler behind the OAuth 2.0 screen's Server descriptions tab's declared Create (AD-5, AD-19).
 *
 * The tab is served by the generic detail page, so its action is registered here, once, against the
 * descriptor's class name, and tab-scoped from the application root for the reason
 * `web-app-actions.ts` gives (DW-246). The route is resolved through `createFormFor`, never written,
 * and `withQuery` carries the namespace.
 */
@Injectable({ providedIn: 'root' })
export class OAuthActions {
  private readonly injector = inject(Injector);

  private readonly actions = inject(ScreenActions);

  constructor() {
    this.actions.register(OAUTH_SERVER_TAB_DESCRIPTOR, CREATE_ACTION, () => this.openCreate());
  }

  private openCreate(): void {
    const tab = screenForRoute(OAUTH_SERVER_TAB_ROUTE);
    const editor = tab === null ? null : createFormFor(tab);
    if (editor === null) return;
    const router = this.injector.get(Router);
    void router.navigateByUrl(withQuery(editor.route, router.url));
  }
}
