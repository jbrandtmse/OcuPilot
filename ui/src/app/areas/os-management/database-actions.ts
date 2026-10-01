import { Injectable, Injector, inject } from '@angular/core';
import { Router } from '@angular/router';

import { createFormFor, screenForRoute, withQuery } from '../../core/navigation';
import { ScreenActions } from '../../core/screen-actions';

/** The descriptor whose command bar this action appears on. */
export const LOCAL_DATABASE_LIST_DESCRIPTOR = 'OcuPilot.Screen.Descriptor.LocalDatabaseList';

/** That descriptor's own route, which resolves its paired form through `createFormFor`. */
export const LOCAL_DATABASE_LIST_ROUTE = 'os-management/local-databases';

/** The declared primary action id: the command bar's Create, which opens the database wizard. */
export const CREATE_ACTION = 'create';

/** The Databases list's descriptor, whose Check integrity opens its flow (Story 18.4). */
export const DATABASE_LIST_DESCRIPTOR = 'OcuPilot.Screen.Descriptor.DatabaseList';

/** The Databases list's declared primary and row action: Check integrity. */
export const INTEGRITY_ACTION = 'integrity';

/** The Check integrity flow's route. */
export const DATABASE_INTEGRITY_ROUTE = 'os-management/databases/integrity';

/** The query parameter New Namespace opens the database wizard with, naming where it returns (AD-47). */
export const RETURN_PARAM = 'returnTo';

/** The one `returnTo` value the wizard honors: back to New Namespace. A closed marker, never a URL. */
export const RETURN_TO_NAMESPACE = 'namespace';

/** The query parameter the wizard returns to New Namespace with, asking it to restore what was typed. */
export const KEPT_PARAM = 'kept';

/** The query parameter carrying the database the wizard created, which New Namespace chooses as Globals. */
export const CREATED_DATABASE_PARAM = 'database';

/** The value `url`'s query carries under `name`, or `null` (the `routeNamespace` model). */
export function queryValue(url: string, name: string): string | null {
  const cut = url.indexOf('?');
  return cut < 0 ? null : new URLSearchParams(url.slice(cut + 1).split('#')[0]).get(name);
}

/** `url` with `query` appended to its query string. */
export function withParams(url: string, query: string): string {
  return url + (url.includes('?') ? '&' : '?') + query;
}

/**
 * The handler behind the Local databases list's declared Create (AD-5, AD-19), on the
 * `namespace-actions.ts` model: registered once against the descriptor's class name and tab-scoped
 * from the application root. The route is resolved through `createFormFor`, never written, and
 * `withQuery` carries the namespace. The list's Delete is the shell's generic row action.
 *
 * **The Databases list's Check integrity opens its flow** (Story 18.4), from the command bar and the
 * command box; the flow checks the row the list has selected, if any, when it opens. The flow sends
 * the check itself, through the shell's handler, with the checked directories as its target.
 */
@Injectable({ providedIn: 'root' })
export class DatabaseActions {
  private readonly injector = inject(Injector);

  private readonly actions = inject(ScreenActions);

  constructor() {
    this.actions.register(LOCAL_DATABASE_LIST_DESCRIPTOR, CREATE_ACTION, () => this.openCreate());
    this.actions.register(DATABASE_LIST_DESCRIPTOR, INTEGRITY_ACTION, () => this.openIntegrity());
  }

  private openIntegrity(): void {
    const router = this.injector.get(Router);
    void router.navigateByUrl(withQuery(DATABASE_INTEGRITY_ROUTE, router.url));
  }

  private openCreate(): void {
    const list = screenForRoute(LOCAL_DATABASE_LIST_ROUTE);
    const wizard = list === null ? null : createFormFor(list);
    if (wizard === null) return;
    const router = this.injector.get(Router);
    void router.navigateByUrl(withQuery(wizard.route, router.url));
  }
}
