import { Injectable, Injector, inject } from '@angular/core';

import { ApiService } from '../../core/api';
import { ChangeBus } from '../../core/change-bus';
import { ScreenActions } from '../../core/screen-actions';
import { ScreenStores } from '../../core/screen-store';
import {
  AGENT_DEFINITIONS_PATH,
  AGENT_DEFINITION_ENTITY,
  AGENT_DEFINITION_SCOPE,
} from './definition-form.store';

/** The descriptor whose rows these actions act on. */
export const DEFINITION_LIST_DESCRIPTOR = 'OcuPilot.Screen.Descriptor.AgentDefinitionList';

/** The three declared row action ids, spelled as the descriptor declares them. */
export const ENABLE_ACTION = 'enable';
export const DISABLE_ACTION = 'disable';
export const SET_DEFAULT_ACTION = 'set-default';

/**
 * The handlers behind the Definitions list's three row actions (AC4).
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
 */
@Injectable({ providedIn: 'root' })
export class DefinitionActions {
  private readonly injector = inject(Injector);

  private readonly actions = inject(ScreenActions);

  private readonly stores = inject(ScreenStores);

  constructor() {
    // Registered for the life of the tab rather than for the life of a page, and not torn down on
    // sign-out: what is registered is behaviour, not data, and the next principal's Definitions
    // list needs exactly the same three handlers. Nothing principal-specific is held here.
    this.actions.register(DEFINITION_LIST_DESCRIPTOR, ENABLE_ACTION, () => void this.setEnabled(true));
    this.actions.register(DEFINITION_LIST_DESCRIPTOR, DISABLE_ACTION, () => void this.setEnabled(false));
    this.actions.register(DEFINITION_LIST_DESCRIPTOR, SET_DEFAULT_ACTION, () => void this.setDefault());
  }

  /** The id of the row the list has selected, or `''`. */
  private selectedId(): string {
    return this.stores.for(DEFINITION_LIST_DESCRIPTOR, []).selection()[0] ?? '';
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
    const result = await this.injector.get(ApiService).requestJson<unknown>(
      `${AGENT_DEFINITIONS_PATH}/${encodeURIComponent(id)}`,
      {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ enabled }),
      }
    );
    if (result.kind !== 'ok') return;
    this.publish(id);
  }

  /** Move the default marker to the selected definition. */
  private async setDefault(): Promise<void> {
    const id = this.selectedId();
    if (id === '') return;
    const result = await this.injector.get(ApiService).requestJson<unknown>(
      `${AGENT_DEFINITIONS_PATH}/${encodeURIComponent(id)}/default`,
      { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: '{}' }
    );
    if (result.kind !== 'ok') return;
    this.publish(id);
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
