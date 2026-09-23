import { Injectable, Injector, inject } from '@angular/core';
import { Router } from '@angular/router';

import { editorScreenFor, screenForRoute, withQuery } from '../../core/navigation';
import { ScreenActions } from '../../core/screen-actions';

/** The descriptor whose command bar this action appears on. */
export const WEB_APP_LIST_DESCRIPTOR = 'OcuPilot.Screen.Descriptor.WebAppList';

/** That descriptor's own route, which resolves its paired form through `editorScreenFor`. */
export const WEB_APP_LIST_ROUTE = 'web-applications/list';

/** The declared primary action id: the command bar's Create, which opens the form. */
export const CREATE_ACTION = 'create';

/**
 * The handler behind the Web applications list's declared Create (AD-5, AD-19).
 *
 * **Why a service rather than a page.** The Web applications list is served by the generic
 * `ListPage`, which renders any `list` archetype from its descriptor and knows nothing about any
 * area. Its actions therefore cannot be registered from it. They are registered here, once,
 * against the descriptor's own class name, which is the key `ScreenActions` is indexed by -- and
 * the command bar, the command box and the row menu all offer an action only for the descriptor of
 * the screen on display, so a registration that outlives the screen is offered on no other one.
 *
 * **Why the registration is tab-scoped rather than page-scoped** (DW-246). `ScreenActions.register`
 * notifies its subscribers synchronously; `CommandBar` subscribes and writes its own `generation`
 * signal, and its template reads that signal through `hasPrimaryAction`. A handler registered from
 * a routed page's constructor would therefore write a signal an already-checked `OnPush` sibling
 * depends on, in the same change-detection pass -- which is `ExpressionChangedAfterItHasBeenChecked`
 * exactly. Registering before the first pass, from the application root, removes the shape rather
 * than working around it. Nothing principal-specific is held here: what is registered is
 * behaviour, so the next principal's list needs the same handler and there is nothing to tear
 * down.
 *
 * **The route is resolved, never written.** `editorScreenFor` is the one reader of the convention
 * that says where a list's editor lives (`<list route>/edit`), and `withQuery` carries the
 * namespace, as every other navigation in this client does.
 */
@Injectable({ providedIn: 'root' })
export class WebAppActions {
  private readonly injector = inject(Injector);

  private readonly actions = inject(ScreenActions);

  constructor() {
    this.actions.register(WEB_APP_LIST_DESCRIPTOR, CREATE_ACTION, () => this.openCreate());
  }

  private openCreate(): void {
    const list = screenForRoute(WEB_APP_LIST_ROUTE);
    const editor = list === null ? null : editorScreenFor(list);
    if (editor === null) return;
    const router = this.injector.get(Router);
    void router.navigateByUrl(withQuery(editor.route, router.url));
  }
}
