import { TestBed } from '@angular/core/testing';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type ApiRequestInit, type JsonResult } from '../../core/api';
import { ChangeBus, type ChangeEvent } from '../../core/change-bus';
import { PreferenceStore } from '../../core/preferences';
import { ScreenActions } from '../../core/screen-actions';
import { ScreenStores } from '../../core/screen-store';
import {
  DEFINITION_LIST_DESCRIPTOR,
  DISABLE_ACTION,
  DefinitionActions,
  ENABLE_ACTION,
  SET_DEFAULT_ACTION,
} from './definition-actions';

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
  const stores = new ScreenStores({ preferences: new PreferenceStore({ storage: memoryStorage() }) });
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
        key: events[0]?.key,
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
});
