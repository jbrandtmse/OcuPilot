import { Injectable, Injector, inject } from '@angular/core';
import { Router } from '@angular/router';

import { ApiService, type JsonResult } from '../../core/api';
import { ChangeBus } from '../../core/change-bus';
import { editorScreenFor, screenForRoute, withQuery } from '../../core/navigation';
import { ScreenActions } from '../../core/screen-actions';
import { ScreenStores } from '../../core/screen-store';
import { violationsOf } from '../../core/violations';
import {
  AGENT_DEFINITIONS_PATH,
  AGENT_DEFINITION_ENTITY,
  AGENT_DEFINITION_SCOPE,
} from './definition-form.store';

/** The descriptor whose rows these actions act on. */
export const DEFINITION_LIST_DESCRIPTOR = 'OcuPilot.Screen.Descriptor.AgentDefinitionList';

/** That descriptor's own route, which resolves its paired editor through `editorScreenFor`. */
export const DEFINITION_LIST_ROUTE = 'agent/definitions';

/** The three declared row action ids, spelled as the descriptor declares them. */
export const ENABLE_ACTION = 'enable';
export const DISABLE_ACTION = 'disable';
export const SET_DEFAULT_ACTION = 'set-default';

/** The declared primary action id: the command bar's Create, which opens the form. */
export const CREATE_ACTION = 'create';

/**
 * The handlers behind the Definitions list's declared actions: its three row actions (AC4) and
 * its Create, which opens the paired form.
 *
 * **Why a service rather than a page.** The Definitions list is served by the generic `ListPage`,
 * which renders any `list` archetype from its descriptor and knows nothing about any area (AD-5).
 * Its actions therefore cannot be registered from it. They are registered here, once, against the
 * descriptor's own class name, which is the key `ScreenActions` is indexed by -- and the command
 * bar, the command box and the row menu all offer an action only for the descriptor of the screen
 * on display, so a registration that outlives the screen is offered on no other one.
 *
 * **Each action reads the selected row's key, which is the definition's id.** The descriptor
 * declares a composite id over `id` alone, so `rowKey` is the identifier the routes take and the
 * identifier AD-14's change event names -- not the name, which an operator can change and which
 * would key a change event on a value the list is about to rewrite.
 *
 * **A write publishes `(agent-definition, instance, id)` and nothing else** (AD-14). The refresh
 * framework marks the row changed and re-fetches the screen in place; the row is never patched
 * from the write's own answer.
 *
 * **A refusal is said out loud, in the server's own words** (AD-39). Both of these writes have a
 * refusal the server declares for them -- `AGENT.ENABLE.UNVERIFIED` on enabling a definition no
 * test has passed for, `AGENT.DEFAULT.DISABLED` on defaulting to a disabled one -- and a refused
 * write leaves the row exactly as it was, which on its own is indistinguishable from the action
 * never having run. The sentence goes into the screen's own store and `ListPage` renders it.
 */
@Injectable({ providedIn: 'root' })
export class DefinitionActions {
  private readonly injector = inject(Injector);

  private readonly actions = inject(ScreenActions);

  private readonly stores = inject(ScreenStores);

  constructor() {
    // Registered for the life of the tab rather than for the life of a page, and not torn down on
    // sign-out: what is registered is behaviour, not data, and the next principal's Definitions
    // list needs exactly the same handlers. Nothing principal-specific is held here.
    this.actions.register(DEFINITION_LIST_DESCRIPTOR, ENABLE_ACTION, () => void this.setEnabled(true));
    this.actions.register(DEFINITION_LIST_DESCRIPTOR, DISABLE_ACTION, () => void this.setEnabled(false));
    this.actions.register(DEFINITION_LIST_DESCRIPTOR, SET_DEFAULT_ACTION, () => void this.setDefault());
    this.actions.register(DEFINITION_LIST_DESCRIPTOR, CREATE_ACTION, () => this.openCreate());
  }

  /** The id of the row the list has selected, or `''`. */
  private selectedId(): string {
    return this.store().selection()[0] ?? '';
  }

  /**
   * Open the create form. EXPERIENCE.md's Definition form row reaches it from the "Definitions
   * name cell" and from that list's Create; this is the Create half.
   *
   * The route is the paired editor's own, resolved through `editorScreenFor` rather than written
   * here, so the one convention that says where a list's editor lives (`<list route>/edit`) has one
   * reader. `withQuery` carries the namespace, as every other navigation in this client does.
   */
  private openCreate(): void {
    const list = screenForRoute(DEFINITION_LIST_ROUTE);
    const editor = list === null ? null : editorScreenFor(list);
    if (editor === null) return;
    const router = this.injector.get(Router);
    void router.navigateByUrl(withQuery(editor.route, router.url));
  }

  /**
   * Enable or disable the selected definition.
   *
   * The body is one key, which is what `HandleUpdate`'s merge is for: every field the body omits
   * keeps its stored value, so a row action cannot wipe the rest of the definition (AD-4's merge
   * is computed on the instance here, because the instance already holds the whole object).
   */
  private async setEnabled(enabled: boolean): Promise<void> {
    const id = this.selectedId();
    if (id === '') return;
    this.store().setRefusal('');
    const result = await this.injector.get(ApiService).requestJson<unknown>(
      `${AGENT_DEFINITIONS_PATH}/${encodeURIComponent(id)}`,
      {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ enabled }),
      }
    );
    if (!this.accepted(result)) return;
    this.publish(id);
  }

  /** Move the default marker to the selected definition. */
  private async setDefault(): Promise<void> {
    const id = this.selectedId();
    if (id === '') return;
    this.store().setRefusal('');
    const result = await this.injector.get(ApiService).requestJson<unknown>(
      `${AGENT_DEFINITIONS_PATH}/${encodeURIComponent(id)}/default`,
      { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: '{}' }
    );
    if (!this.accepted(result)) return;
    this.publish(id);
  }

  /** The Definitions list's own store, which holds the selection and carries the refusal. */
  private store(): ReturnType<ScreenStores['for']> {
    return this.stores.for(DEFINITION_LIST_DESCRIPTOR, []);
  }

  /**
   * Whether the write was accepted; a refusal is put on the screen before this answers `false`.
   *
   * The sentence is the violation's own where the refusal named a field -- which is how both of
   * these routes refuse, under the one `AGENT.VALIDATION` envelope code (AD-39) -- and the
   * envelope's `reason` otherwise, so a 403 or a 404 says something too. Nothing is published and
   * no row is marked changed when a write was refused: the instance did not change.
   */
  private accepted(result: JsonResult<unknown>): boolean {
    if (result.kind === 'ok') return true;
    const first = violationsOf(result)[0];
    const sentence = first?.reason !== undefined && first.reason !== ''
      ? first.reason
      : (result.kind === 'error' ? (result.reason ?? '') : '');
    this.store().setRefusal(sentence);
    return false;
  }

  private publish(id: string): void {
    this.injector.get(ChangeBus).publish({
      kind: 'changed',
      type: AGENT_DEFINITION_ENTITY,
      scope: AGENT_DEFINITION_SCOPE,
      id,
    });
  }
}
