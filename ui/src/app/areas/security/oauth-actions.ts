import { Injectable, Injector, inject } from '@angular/core';
import { Router } from '@angular/router';

import { createFormFor, screenForRoute, withQuery } from '../../core/navigation';
import { ScreenActions } from '../../core/screen-actions';

/** The tab whose command bar this action appears on. */
export const OAUTH_SERVER_TAB_DESCRIPTOR = 'OcuPilot.Screen.Descriptor.OAuthServerDescriptionTab';

/** That tab's own route, which resolves its paired form through `createFormFor`. */
export const OAUTH_SERVER_TAB_ROUTE = 'security/oauth';

/** The Client configurations tab, whose Create opens the client configuration editor (Story 12.5). */
export const OAUTH_CLIENT_TAB_DESCRIPTOR = 'OcuPilot.Screen.Descriptor.OAuthClientTab';

export const OAUTH_CLIENT_TAB_ROUTE = 'security/oauth/clients';

/** The Resource servers tab, whose Create opens the resource server editor (Story 12.6). */
export const OAUTH_RESOURCE_SERVER_TAB_DESCRIPTOR = 'OcuPilot.Screen.Descriptor.OAuthResourceServerTab';

export const OAUTH_RESOURCE_SERVER_TAB_ROUTE = 'security/oauth/resource-servers';

/** The Authorization server tab, whose Create opens the authorization server editor (Story 12.7). */
export const OAUTH_AUTH_SERVER_TAB_DESCRIPTOR = 'OcuPilot.Screen.Descriptor.OAuthServerTab';

export const OAUTH_AUTH_SERVER_TAB_ROUTE = 'security/oauth/server';

/** The Server client descriptions tab, whose Create opens the server client description editor (Story 12.8). */
export const OAUTH_SERVER_CLIENT_TAB_DESCRIPTOR = 'OcuPilot.Screen.Descriptor.OAuthServerClientTab';

export const OAUTH_SERVER_CLIENT_TAB_ROUTE = 'security/oauth/server-clients';

/** The declared primary action id: the command bar's Create, which opens the tab's editor. */
export const CREATE_ACTION = 'create';

/**
 * The handlers behind the OAuth 2.0 screen's Server descriptions, Client configurations, Resource
 * servers, Authorization server and Server client descriptions tabs' declared Create (AD-5, AD-19).
 *
 * Each tab is served by the generic detail page, so its action is registered here, once, against the
 * descriptor's class name, and tab-scoped from the application root for the reason
 * `web-app-actions.ts` gives (DW-246). The route is resolved through `createFormFor`, never written,
 * and `withQuery` carries the namespace.
 */
@Injectable({ providedIn: 'root' })
export class OAuthActions {
  private readonly injector = inject(Injector);

  private readonly actions = inject(ScreenActions);

  constructor() {
    this.actions.register(OAUTH_SERVER_TAB_DESCRIPTOR, CREATE_ACTION, () => this.openCreate(OAUTH_SERVER_TAB_ROUTE));
    this.actions.register(OAUTH_CLIENT_TAB_DESCRIPTOR, CREATE_ACTION, () => this.openCreate(OAUTH_CLIENT_TAB_ROUTE));
    this.actions.register(OAUTH_RESOURCE_SERVER_TAB_DESCRIPTOR, CREATE_ACTION, () => this.openCreate(OAUTH_RESOURCE_SERVER_TAB_ROUTE));
    this.actions.register(OAUTH_AUTH_SERVER_TAB_DESCRIPTOR, CREATE_ACTION, () => this.openCreate(OAUTH_AUTH_SERVER_TAB_ROUTE));
    this.actions.register(OAUTH_SERVER_CLIENT_TAB_DESCRIPTOR, CREATE_ACTION, () => this.openCreate(OAUTH_SERVER_CLIENT_TAB_ROUTE));
  }

  private openCreate(tabRoute: string): void {
    const tab = screenForRoute(tabRoute);
    const editor = tab === null ? null : createFormFor(tab);
    if (editor === null) return;
    const router = this.injector.get(Router);
    void router.navigateByUrl(withQuery(editor.route, router.url));
  }
}
