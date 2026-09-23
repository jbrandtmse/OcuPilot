import { TestBed } from '@angular/core/testing';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type ApiRequestInit, type JsonResult } from '../core/api';
import { ChangeBus, type ChangeEvent } from '../core/change-bus';
import { ScreenActions } from '../core/screen-actions';
import { ScreenStores } from '../core/screen-store';
import { SCREENS } from '../core/screens.generated';
import { STRINGS } from '../core/strings';
import { stubAccountPreferences } from '../testing/account-preferences';
import { SCREEN_ACTION_DESCRIPTORS, ScreenActionHandler } from './screen-action-handler';

/** The screen this handler serves first, read from the mirror rather than restated here. */
const WEB_APPS = SCREENS.find((screen) => screen.descriptor === SCREEN_ACTION_DESCRIPTORS[0])!;

/** A row the instance would not protect, and one it would. */
const ORDINARY_ROW = '/csp/myapp';

const OWN_ROW = '/api/ocupilot';

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
  const handler = TestBed.inject(ScreenActionHandler);
  const store = stores.for(WEB_APPS.descriptor, WEB_APPS.refreshRates);
  return { actions, handler, store, calls, events };
}

afterEach(() => {
  TestBed.resetTestingModule();
});

/**
 * AD-53: the screen's own caller of the write operation -- one generic handler over the
 * descriptor's declared row actions, one route, and the change event the instance answered.
 */
describe('the generic screen-action handler', () => {
  it('registers every row action the descriptor declares, against that descriptor', () => {
    // Mutation (Rule 19): empty `SCREEN_ACTION_DESCRIPTORS` -> nothing registers, and this goes
    // red on every id; with it, no surface would draw a row action at all (DW-389).
    const { actions } = mount();
    expect(WEB_APPS.rowActions.length).toBeGreaterThan(0);
    for (const action of WEB_APPS.rowActions) {
      expect(actions.has(WEB_APPS.descriptor, action.id)).toBe(true);
    }
    expect(actions.has(WEB_APPS.descriptor, 'terminate')).toBe(false);
  });

  it('sends the selected row through the screen-action route and publishes what the instance answered', async () => {
    // Mutation (Rule 19): publish `'updated'` here rather than the answer's own action -> the
    // action assertion goes red. The verb is the instance's (AD-14).
    const { actions, store, calls, events } = mount({
      kind: 'ok',
      status: 200,
      body: { action: 'deleted', target: { type: 'web-application', scope: 'instance', id: ORDINARY_ROW } },
    });
    store.setSelection([ORDINARY_ROW]);

    actions.run(WEB_APPS.descriptor, 'enable');
    await settle();

    expect(calls).toHaveLength(1);
    expect(calls[0].path).toBe(`/api/ocupilot/screens/${WEB_APPS.toolIdentifier}/action`);
    expect(calls[0].method).toBe('POST');
    expect(JSON.parse(calls[0].body)).toEqual({ action: 'enable', id: ORDINARY_ROW });

    expect(events).toHaveLength(1);
    expect(events[0].kind).toBe('changed');
    expect(events[0].action).toBe('deleted');
    expect(events[0].type).toBe('web-application');
    expect(events[0].id).toBe(ORDINARY_ROW);
  });

  it('sends nothing with no row selected', async () => {
    const { actions, calls, events } = mount();
    actions.run(WEB_APPS.descriptor, 'enable');
    await settle();
    expect(calls).toHaveLength(0);
    expect(events).toHaveLength(0);
  });

  it('opens the typed-name dialog for a destructive action and sends only once it is confirmed', async () => {
    // Mutation (Rule 19): drop the `isDestructive` branch from `start` -> the delete is sent
    // before anything is confirmed, and the first `calls` assertion goes red.
    const { actions, handler, store, calls } = mount({
      kind: 'ok',
      status: 200,
      body: { action: 'deleted', target: { type: 'web-application', scope: 'instance', id: ORDINARY_ROW } },
    });
    store.setSelection([ORDINARY_ROW]);

    actions.run(WEB_APPS.descriptor, 'delete');
    await settle();
    expect(calls).toHaveLength(0);
    const pending = handler.pending();
    expect(pending?.actionId).toBe('delete');
    expect(pending?.target).toBe(ORDINARY_ROW);
    expect(pending?.verb).toBe(STRINGS.actionDelete);
    expect(pending?.consequence).toBe(STRINGS.webAppDeleteConsequence);

    handler.cancelPending();
    await settle();
    expect(handler.pending()).toBeNull();
    expect(calls).toHaveLength(0);

    actions.run(WEB_APPS.descriptor, 'delete');
    handler.confirmPending();
    await settle();
    expect(calls).toHaveLength(1);
    expect(JSON.parse(calls[0].body)).toEqual({ action: 'delete', id: ORDINARY_ROW });
  });

  it('explains a self-protected row rather than sending, in the instance\u2019s own published words', async () => {
    // AD-10, AD-53: this is an explanation, not a gate -- the route refuses the same write with
    // the same sentence. Disable is the leg that can go red on `calls`: it sends at once where it
    // is not refused, while a delete sends nothing before its dialog is confirmed either way.
    // Mutation (Rule 19): make `selfProtectionReason` answer `''` -> the disable is sent and the
    // `calls` assertion goes red, and the delete opens its dialog and `pending()` goes red.
    const { actions, handler, store, calls, events } = mount();
    store.setSelection([OWN_ROW]);

    actions.run(WEB_APPS.descriptor, 'disable');
    await settle();
    expect(calls).toHaveLength(0);
    expect(events).toHaveLength(0);
    expect(store.refusal()).toBe(STRINGS.webAppServesOcuPilotRefusal);

    store.setRefusal('');
    actions.run(WEB_APPS.descriptor, 'delete');
    await settle();
    expect(handler.pending()).toBeNull();
    expect(calls).toHaveLength(0);
    expect(store.refusal()).toBe(STRINGS.webAppServesOcuPilotRefusal);
  });

  it('puts a refused write\u2019s own sentence on the screen and publishes nothing', async () => {
    // AD-39: the envelope's `reason`, never a sentence this client wrote.
    const { actions, store, events } = mount({
      kind: 'error',
      status: 403,
      code: 'PROHIBITED.SERVINGPATH',
      reason: STRINGS.webAppServesOcuPilotRefusal,
      detail: null,
    });
    store.setSelection([ORDINARY_ROW]);

    actions.run(WEB_APPS.descriptor, 'disable');
    await settle();
    expect(events).toHaveLength(0);
    expect(store.refusal()).toBe(STRINGS.webAppServesOcuPilotRefusal);
  });
});
