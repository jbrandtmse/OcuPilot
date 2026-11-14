import { TestBed } from '@angular/core/testing';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type ApiRequestInit, type JsonResult } from '../core/api';
import { ChangeBus, type ChangeEvent } from '../core/change-bus';
import { ScopeService } from '../core/scope';
import { ScreenActions, actionLabel } from '../core/screen-actions';
import { ScreenStores } from '../core/screen-store';
import { SCREENS } from '../core/screens.generated';
import { STRINGS } from '../core/strings';
import { stubAccountPreferences } from '../testing/account-preferences';
import { SCREEN_ACTION_DESCRIPTORS, ScreenActionHandler } from './screen-action-handler';

const CUBE_MANAGER = 'OcuPilot.Screen.Descriptor.AnalyticsCubeManager';

const ACTION_PATH = '/api/ocupilot/screens/analytics.cubemanager/action';

const BUILD_LINES = ['Facts in Sales: 5', 'Facts in Visits: 1000'];

interface Call {
  readonly path: string;
  readonly method: string;
  readonly body: Record<string, unknown>;
}

/** A handler over a stubbed instance that answers every call with `answer`, and the calls it saw. */
function mount(answer: (call: Call) => JsonResult<unknown>) {
  TestBed.resetTestingModule();
  const calls: Call[] = [];
  const api = {
    requestJson: async <T,>(path: string, init: ApiRequestInit = {}): Promise<JsonResult<T>> => {
      const call: Call = { path, method: init.method ?? 'GET', body: init.body ? (JSON.parse(init.body) as Record<string, unknown>) : {} };
      calls.push(call);
      return answer(call) as JsonResult<T>;
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
      { provide: ScopeService, useValue: { namespace: () => 'USER' } as unknown as ScopeService },
    ],
  });
  const actions = TestBed.inject(ScreenActions);
  const handler = TestBed.inject(ScreenActionHandler);
  const screen = SCREENS.find((entry) => entry.descriptor === CUBE_MANAGER)!;
  const store = stores.for(screen.descriptor, screen.refreshRates);
  store.setSelection(['Sales']);
  return { actions, handler, store, calls, events };
}

function done(lines: readonly string[]): JsonResult<unknown> {
  return {
    kind: 'ok',
    status: 200,
    body: { action: 'updated', target: { type: 'cube', scope: 'namespace:USER', id: 'Sales' }, output: { lines, errors: false } },
  };
}

async function settle(): Promise<void> {
  for (let pass = 0; pass < 6; pass += 1) await new Promise((resolve) => setTimeout(resolve, 2));
}

afterEach(() => {
  TestBed.resetTestingModule();
});

/**
 * Story 20.34, AD-53: the Cube manager's two row actions. Build is destructive, so it opens the typed-name dialog over the cube's name
 * with the build's consequence; Synchronize is sent at once. Each ends in the outcome dialog that lists the lines the instance
 * answered, and a refused action shows its sentence on the list and opens nothing.
 */
describe('the Cube manager\u2019s Build and Synchronize through the generic handler (Story 20.34)', () => {
  it('registers Build and Synchronize on the Cube manager, each with its label', () => {
    // Mutation (Rule 19): drop the descriptor from `SCREEN_ACTION_DESCRIPTORS` -> the roster assertion goes red.
    const { actions } = mount(() => done([]));
    expect(SCREEN_ACTION_DESCRIPTORS).toContain(CUBE_MANAGER);
    expect(actions.has(CUBE_MANAGER, 'build')).toBe(true);
    expect(actions.has(CUBE_MANAGER, 'synchronize')).toBe(true);
    expect(actionLabel(CUBE_MANAGER, 'build')).toBe(STRINGS.aboutBuild);
    expect(actionLabel(CUBE_MANAGER, 'synchronize')).toBe(STRINGS.actionSynchronize);
  });

  it('opens Build\u2019s typed-name dialog over the cube\u2019s name and sends nothing before the name is typed', async () => {
    // Mutation (Rule 19): send at once in place of the dialog -> the calls assertion goes red.
    const { actions, handler, calls } = mount(() => done(BUILD_LINES));
    actions.run(CUBE_MANAGER, 'build');
    await settle();
    expect(calls).toHaveLength(0);
    const pending = handler.pending();
    expect(pending?.kind).toBe('typed-name');
    expect(pending?.name).toBe('Sales');
    expect(pending?.verb).toBe(STRINGS.aboutBuild);
    expect(pending?.consequence).toBe(STRINGS.analyticsCubeBuildConsequence);
  });

  it('sends the confirmed Build, publishes the update of the cube, and reports the answered lines in the outcome dialog', async () => {
    // Mutation (Rule 19): drop `OUTCOME_ACTIONS` -> no outcome opens and the kind assertion goes red; publish no change -> the event
    // assertion goes red.
    const { actions, handler, calls, events } = mount(() => done(BUILD_LINES));
    actions.run(CUBE_MANAGER, 'build');
    await settle();
    handler.confirmPending();
    await settle();
    expect(calls).toEqual([{ path: ACTION_PATH, method: 'POST', body: { action: 'build', id: 'Sales' } }]);
    expect(events.map((event) => `${event.kind}|${'action' in event ? event.action : ''}|${'type' in event ? event.type : ''}`)).toEqual(['changed|updated|cube']);
    const outcome = handler.pending();
    expect(outcome?.kind).toBe('outcome');
    expect(outcome?.outcome).toEqual(BUILD_LINES);
    expect(outcome?.verb).toBe(STRINGS.aboutBuild);
    expect(outcome?.name).toBe('Sales');
    handler.cancelPending();
    expect(handler.pending()).toBeNull();
  });

  it('sends Synchronize at once and reports its lines', async () => {
    // Mutation (Rule 19): add `synchronize` to `DESTRUCTIVE_ACTIONS` -> the dialog opens first and the calls assertion goes red.
    const lines = ['Facts updated in Sales: 10'];
    const { actions, handler, calls } = mount(() => done(lines));
    actions.run(CUBE_MANAGER, 'synchronize');
    await settle();
    expect(calls).toEqual([{ path: ACTION_PATH, method: 'POST', body: { action: 'synchronize', id: 'Sales' } }]);
    expect(handler.pending()?.kind).toBe('outcome');
    expect(handler.pending()?.outcome).toEqual(lines);
  });

  it('opens no outcome where the instance answered no line, and shows a refusal\u2019s sentence on the list with no event', async () => {
    // Mutation (Rule 19): open the outcome on a refusal -> the pending assertion goes red.
    const { actions, handler, store, events } = mount(() => ({ kind: 'error', status: 409, code: 'ANALYTICS.CUBE.BUSY', reason: STRINGS.analyticsRefusalCubeBusy, detail: null }));
    actions.run(CUBE_MANAGER, 'synchronize');
    await settle();
    expect(handler.pending()).toBeNull();
    expect(store.refusal()).toBe(STRINGS.analyticsRefusalCubeBusy);
    expect(events).toHaveLength(0);
    const quiet = mount(() => done([]));
    quiet.actions.run(CUBE_MANAGER, 'synchronize');
    await settle();
    expect(quiet.handler.pending()).toBeNull();
  });
});
