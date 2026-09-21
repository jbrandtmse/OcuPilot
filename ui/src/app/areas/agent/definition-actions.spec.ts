import { TestBed } from '@angular/core/testing';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type ApiRequestInit, type JsonResult } from '../../core/api';
import { ChangeBus, type ChangeEvent } from '../../core/change-bus';
import { entityRefKey } from '../../core/entity-ref';
import { ScreenActions } from '../../core/screen-actions';
import { ScreenStores } from '../../core/screen-store';
import { screenForRoute } from '../../core/navigation';
import { stubAccountPreferences } from '../../testing/account-preferences';
import {
  CREATE_ACTION,
  DEFINITION_LIST_DESCRIPTOR,
  DEFINITION_LIST_ROUTE,
  DISABLE_ACTION,
  DefinitionActions,
  ENABLE_ACTION,
  SET_DEFAULT_ACTION,
} from './definition-actions';

/** The list's own generated declaration, read from the mirror rather than restated here. */
const DEFINITION_LIST_SCREEN = screenForRoute(DEFINITION_LIST_ROUTE);

/**
 * AC4: the Definitions list's three row actions act on the selected row in place and publish the
 * `(agent-definition, instance, id)` change event that re-fetches it.
 *
 * The real `ScreenActions`, `ScreenStores` and `ChangeBus` run: what is stubbed is the one thing an
 * instance supplies, the HTTP answer.
 */

function memoryStorage() {
  const map = new Map<string, string>();
  return {
    getItem: (key: string) => map.get(key) ?? null,
    setItem: (key: string, value: string) => {
      map.set(key, value);
    },
    removeItem: (key: string) => {
      map.delete(key);
    },
  };
}

async function settle(): Promise<void> {
  for (let pass = 0; pass < 4; pass += 1) await new Promise((resolve) => setTimeout(resolve, 2));
}

function mount(answer: JsonResult<unknown> = { kind: 'ok', status: 200, body: {} }) {
  TestBed.resetTestingModule();
  const calls: { path: string; method: string; body: string }[] = [];
  const api = {
    requestJson: async <T,>(path: string, init: ApiRequestInit = {}): Promise<JsonResult<T>> => {
      calls.push({ path, method: init.method ?? 'GET', body: init.body ?? '' });
      return answer as JsonResult<T>;
    },
  };
  const bus = new ChangeBus();
  const events: ChangeEvent[] = [];
  bus.subscribe((event) => events.push(event));
  const stores = new ScreenStores({ account: stubAccountPreferences() });
  TestBed.configureTestingModule({
    providers: [
      { provide: ApiService, useValue: api as unknown as ApiService },
      { provide: ChangeBus, useValue: bus },
      { provide: ScreenStores, useValue: stores },
      { provide: ScreenActions, useValue: new ScreenActions() },
    ],
  });
  const actions = TestBed.inject(ScreenActions);
  TestBed.inject(DefinitionActions);
  return { actions, stores, calls, events };
}

afterEach(() => {
  TestBed.resetTestingModule();
});

describe('the Definitions list row actions', () => {
  it('registers the three the descriptor declares, against that descriptor', () => {
    const { actions } = mount();
    for (const id of [ENABLE_ACTION, DISABLE_ACTION, SET_DEFAULT_ACTION]) {
      expect(actions.has(DEFINITION_LIST_DESCRIPTOR, id)).toBe(true);
    }
    expect(actions.has('OcuPilot.Screen.Descriptor.WebAppList', ENABLE_ACTION)).toBe(false);
  });

  it('AC4: enable and disable send one key to the selected row, and publish the scoped triple', async () => {
    const { actions, stores, calls, events } = mount();
    stores.for(DEFINITION_LIST_DESCRIPTOR, []).setSelection(['7']);

    actions.run(DEFINITION_LIST_DESCRIPTOR, ENABLE_ACTION);
    await settle();
    expect(calls).toEqual([
      { path: '/api/ocupilot/agent/definitions/7', method: 'PUT', body: JSON.stringify({ enabled: true }) },
    ]);
    // Mutation (Rule 19): drop the publish from the row action -> this goes red, and the list
    // then never re-fetches the row it just changed (AD-14).
    expect(events).toEqual([
      {
        kind: 'changed',
        type: 'agent-definition',
        scope: 'instance',
        id: '7',
        // Composed from the triple, not read back out of the event under test: reading the actual
        // into the expected made this one field assert nothing.
        key: entityRefKey('agent-definition', 'instance', '7'),
        action: 'updated',
        proposalId: '',
        expiresAt: 0,
      },
    ]);

    actions.run(DEFINITION_LIST_DESCRIPTOR, DISABLE_ACTION);
    await settle();
    expect(calls[1]).toEqual({
      path: '/api/ocupilot/agent/definitions/7',
      method: 'PUT',
      body: JSON.stringify({ enabled: false }),
    });
  });

  it('AC4: set-default posts to the marker route', async () => {
    const { actions, stores, calls } = mount();
    stores.for(DEFINITION_LIST_DESCRIPTOR, []).setSelection(['12']);
    actions.run(DEFINITION_LIST_DESCRIPTOR, SET_DEFAULT_ACTION);
    await settle();
    expect(calls).toEqual([
      { path: '/api/ocupilot/agent/definitions/12/default', method: 'POST', body: '{}' },
    ]);
  });

  it('with nothing selected, an action reaches no route at all', async () => {
    const { actions, calls } = mount();
    actions.run(DEFINITION_LIST_DESCRIPTOR, ENABLE_ACTION);
    await settle();
    expect(calls).toEqual([]);
  });

  it('a refused write publishes nothing, so the list is never told a change that did not happen', async () => {
    const { actions, stores, events } = mount({
      kind: 'error',
      status: 422,
      code: 'AGENT.VALIDATION',
      reason: 'The agent definition was refused',
      detail: { violations: [{ field: 'default', code: 'AGENT.DEFAULT.DISABLED', reason: 'Enable this definition before making it the default.' }] },
    });
    stores.for(DEFINITION_LIST_DESCRIPTOR, []).setSelection(['3']);
    actions.run(DEFINITION_LIST_DESCRIPTOR, SET_DEFAULT_ACTION);
    await settle();
    expect(events).toEqual([]);
  });

  it("DW-366: a refused write puts the violation's own sentence on the screen", async () => {
    const { actions, stores } = mount({
      kind: 'error',
      status: 422,
      code: 'AGENT.VALIDATION',
      reason: 'The agent definition was refused',
      detail: {
        violations: [
          {
            field: 'default',
            code: 'AGENT.DEFAULT.DISABLED',
            reason: 'Enable this definition before making it the default.',
          },
        ],
      },
    });
    const store = stores.for(DEFINITION_LIST_DESCRIPTOR, []);
    store.setSelection(['3']);
    actions.run(DEFINITION_LIST_DESCRIPTOR, SET_DEFAULT_ACTION);
    await settle();
    // Mutation (Rule 19): put back `if (result.kind !== 'ok') return;` in `setDefault` -> this
    // goes red, and the refusal reaches no surface at all: the row is unchanged, which is what
    // the screen looks like when nothing happened.
    expect(store.refusal()).toBe('Enable this definition before making it the default.');
  });

  it('a refusal with no violations falls back to the envelope reason, and the next run clears it', async () => {
    const { actions, stores, calls } = mount({
      kind: 'error',
      status: 403,
      code: 'AUTH.NOPRIVILEGE',
      reason: 'This account does not hold OcuPilot administrative privilege',
      detail: null,
    });
    const store = stores.for(DEFINITION_LIST_DESCRIPTOR, []);
    store.setSelection(['3']);
    actions.run(DEFINITION_LIST_DESCRIPTOR, ENABLE_ACTION);
    await settle();
    expect(store.refusal()).toBe('This account does not hold OcuPilot administrative privilege');
    expect(calls).toHaveLength(1);

    store.setSelection([]);
    actions.run(DEFINITION_LIST_DESCRIPTOR, ENABLE_ACTION);
    await settle();
    // Nothing was selected, so nothing was issued and the standing sentence is still the one the
    // instance last said -- it is cleared where a write is actually attempted, not on every click.
    expect(calls).toHaveLength(1);
    expect(store.refusal()).toBe('This account does not hold OcuPilot administrative privilege');
  });

  it("EXPERIENCE.md's Definition form row: Create is registered as the list's primary action", () => {
    const { actions } = mount();
    // Mutation (Rule 19): set the descriptor's `primaryAction.id` back to `""` -> the command bar
    // draws no Create, and on an instance with no definition the form is reachable only by typing
    // its URL, because its `sideBarPosition` 0 keeps it out of every navigation surface.
    expect(actions.has(DEFINITION_LIST_DESCRIPTOR, CREATE_ACTION)).toBe(true);
    expect(DEFINITION_LIST_SCREEN?.primaryAction.id).toBe(CREATE_ACTION);
  });
});
