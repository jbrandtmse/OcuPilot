import { TestBed } from '@angular/core/testing';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type ApiRequestInit, type JsonResult } from '../core/api';
import { ChangeBus, type ChangeEvent } from '../core/change-bus';
import { ScreenActions } from '../core/screen-actions';
import { ScreenStores } from '../core/screen-store';
import { ENTITY_SINGLETON_ID, SCREENS } from '../core/screens.generated';
import { STRINGS } from '../core/strings';
import { rowKey } from '../core/table-model';
import { stubAccountPreferences } from '../testing/account-preferences';
import { Session } from '../core/session';
import {
  ADD_ROLE,
  REMOVE_ROLE,
  REQUIRE_PASSWORD_CHANGE,
  SCREEN_ACTION_DESCRIPTORS,
  SET_PASSWORD,
  ScreenActionHandler,
} from './screen-action-handler';

/** The screen this handler serves first, read from the mirror rather than restated here. */
const WEB_APPS = SCREENS.find((screen) => screen.descriptor === SCREEN_ACTION_DESCRIPTORS[0])!;

/** A row the instance would not protect, and one it would. */
const ORDINARY_ROW = '/csp/myapp';

const OWN_ROW = '/api/ocupilot';

async function settle(): Promise<void> {
  for (let pass = 0; pass < 4; pass += 1) await new Promise((resolve) => setTimeout(resolve, 2));
}

function mount(answer: JsonResult<unknown> = { kind: 'ok', status: 200, body: {} }, descriptor = WEB_APPS.descriptor) {
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
  const screen = SCREENS.find((entry) => entry.descriptor === descriptor)!;
  const store = stores.for(screen.descriptor, screen.refreshRates);
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

/** Story 7.3's two OAuth 2.0 tabs, read from the mirror rather than restated here. */
const OAUTH_CLIENTS = SCREENS.find((screen) => screen.descriptor === 'OcuPilot.Screen.Descriptor.OAuthClientTab')!;

const OAUTH_SERVER_CLIENTS = SCREENS.find(
  (screen) => screen.descriptor === 'OcuPilot.Screen.Descriptor.OAuthServerClientTab'
)!;

/**
 * AD-53, Story 7.3: the OAuth 2.0 tabs' delete runs through the same handler, with each tab's own
 * published consequence, and a server client is targeted by its `ClientId` -- the vendor's IdKey --
 * never by its `Name`, which two clients may share.
 */
describe('the OAuth 2.0 tabs\u2019 delete', () => {
  it('registers delete on both tabs and opens each tab\u2019s own consequence', async () => {
    // Mutation (Rule 19): drop either descriptor from `SCREEN_ACTION_DESCRIPTORS` -> its `has`
    // assertion goes red, and no surface draws its delete (DW-389).
    for (const [screen, consequence, row, type] of [
      [OAUTH_CLIENTS, STRINGS.oauthClientDeleteConsequence, 'OcuPilotTestDelete', 'oauth2-client-configuration'],
      [OAUTH_SERVER_CLIENTS, STRINGS.oauthServerClientDeleteConsequence, 'probe-client-id', 'oauth2-server-client'],
    ] as const) {
      const answer: JsonResult<unknown> = {
        kind: 'ok',
        status: 200,
        body: { action: 'deleted', target: { type, scope: 'instance', id: row } },
      };
      const { actions, handler, store, calls, events } = mount(answer, screen.descriptor);
      expect(screen.rowActions.map((action) => action.id)).toEqual(['delete']);
      expect(actions.has(screen.descriptor, 'delete')).toBe(true);
      store.setSelection([row]);
      actions.run(screen.descriptor, 'delete');
      await settle();
      expect(calls).toHaveLength(0);
      expect(handler.pending()?.consequence).toBe(consequence);
      expect(handler.pending()?.verb).toBe(STRINGS.actionDelete);
      handler.confirmPending();
      await settle();
      expect(calls).toHaveLength(1);
      expect(calls[0].path).toBe(`/api/ocupilot/screens/${screen.toolIdentifier}/action`);
      expect(JSON.parse(calls[0].body)).toEqual({ action: 'delete', id: row });
      expect(events).toHaveLength(1);
      expect(events[0].action).toBe('deleted');
      expect(events[0].type).toBe(type);
      expect(events[0].id).toBe(row);
    }
  });

  it('targets a server client by its ClientId, not by the Name it may share', async () => {
    // Mutation (Rule 19): declare the tab's id `single` -> the row key is the Name cell's, and the
    // pending target and the sent id go red.
    const row = { Name: 'Shared name', ClientId: 'abc-123', ClientType: 'resource', RedirectURL: [], Description: '' };
    const key = rowKey(row, OAUTH_SERVER_CLIENTS);
    expect(key).toBe('abc-123');
    const { actions, handler, store, calls } = mount(undefined, OAUTH_SERVER_CLIENTS.descriptor);
    store.setSelection([key]);
    actions.run(OAUTH_SERVER_CLIENTS.descriptor, 'delete');
    await settle();
    expect(handler.pending()?.target).toBe('abc-123');
    handler.confirmPending();
    await settle();
    expect(JSON.parse(calls[0].body)).toEqual({ action: 'delete', id: 'abc-123' });
  });
});

/** The Users list, read from the mirror (Story 7.2). */
const USERS = SCREENS.find((screen) => screen.descriptor === 'OcuPilot.Screen.Descriptor.UserList')!;

/** Mount with one answer per request, in order, and a session signed in as `Dana`. */
function mountUsers(answers: readonly JsonResult<unknown>[]) {
  TestBed.resetTestingModule();
  const calls: { path: string; method: string; body: string }[] = [];
  const queue = [...answers];
  const api = {
    requestJson: async <T,>(path: string, init: ApiRequestInit = {}): Promise<JsonResult<T>> => {
      calls.push({ path, method: init.method ?? 'GET', body: init.body ?? '' });
      return (queue.shift() ?? { kind: 'ok', status: 200, body: {} }) as JsonResult<T>;
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
      { provide: Session, useValue: { userName: () => 'Dana' } as unknown as Session },
    ],
  });
  const actions = TestBed.inject(ScreenActions);
  const handler = TestBed.inject(ScreenActionHandler);
  const store = stores.for(USERS.descriptor, USERS.refreshRates);
  store.applyTick([{ Name: 'probe', Roles: ['%SQL', '%Developer'] }], false, '', new Date());
  store.setSelection(['probe']);
  return { actions, handler, store, calls, events };
}

const UPDATED: JsonResult<unknown> = {
  kind: 'ok',
  status: 200,
  body: { action: 'updated', target: { type: 'user', scope: 'instance', id: 'probe' } },
};

describe('the Users list row actions (Story 7.2)', () => {
  it('registers every declared action but the undrawn change-on-login flag', () => {
    // Mutation (Rule 19): drop the Users list from `SCREEN_ACTION_DESCRIPTORS` -> nothing registers
    // and this goes red on every id, so no surface draws a Users row action (AC1).
    const { actions } = mountUsers([]);
    const drawn = USERS.rowActions.map((action) => action.id).filter((id) => id !== REQUIRE_PASSWORD_CHANGE);
    expect(drawn).toEqual(['enable', 'disable', SET_PASSWORD, ADD_ROLE, REMOVE_ROLE, 'delete']);
    for (const id of drawn) expect(actions.has(USERS.descriptor, id)).toBe(true);
    expect(actions.has(USERS.descriptor, REQUIRE_PASSWORD_CHANGE)).toBe(false);
  });

  it('opens delete with its own consequence and a protected account with its published refusal', async () => {
    const { actions, handler, store, calls } = mountUsers([]);
    actions.run(USERS.descriptor, 'delete');
    expect(handler.pending()?.kind).toBe('typed-name');
    expect(handler.pending()?.consequence).toBe(STRINGS.userDeleteConsequence);
    handler.cancelPending();

    store.setSelection(['dana']);
    actions.run(USERS.descriptor, 'disable');
    await settle();
    expect(calls).toHaveLength(0);
    expect(store.refusal()).toBe(STRINGS.userRefusalCurrentUser);
  });

  it('sends the flag first, then the password exactly as pasted, then the flag again, and nothing after a refused flag', async () => {
    // Mutation (Rule 19): trim the value, or drop `values` from `send` -> the body assertion goes red.
    const pasted = 'pw1 ';
    const first = mountUsers([UPDATED, UPDATED, UPDATED]);
    first.actions.run(USERS.descriptor, SET_PASSWORD);
    expect(first.handler.pending()?.kind).toBe('set-password');
    await first.handler.submitPassword(pasted, true);
    // The flag is re-asserted after the password, because the vendor's password change clears it.
    expect(first.calls.map((call) => JSON.parse(call.body))).toEqual([
      { action: REQUIRE_PASSWORD_CHANGE, id: 'probe' },
      { action: SET_PASSWORD, id: 'probe', values: { Password: pasted } },
      { action: REQUIRE_PASSWORD_CHANGE, id: 'probe' },
    ]);
    expect(first.events).toHaveLength(3);

    const refused = mountUsers([{ kind: 'error', status: 403, code: 'PROHIBITED.UNCOVEREDFIELD', reason: 'no', detail: null }]);
    refused.actions.run(USERS.descriptor, SET_PASSWORD);
    await refused.handler.submitPassword(pasted, true);
    expect(refused.calls).toHaveLength(1);
    expect(refused.store.refusal()).toBe('no');

    // A password the instance refuses (its policy): its sentence on the refusal line, the flag
    // written first left set, and no second flag write.
    const policy = mountUsers([UPDATED, { kind: 'error', status: 400, code: 'PORT.VALIDATION', reason: 'too short', detail: null }]);
    policy.actions.run(USERS.descriptor, SET_PASSWORD);
    await policy.handler.submitPassword(pasted, true);
    expect(policy.calls.map((call) => JSON.parse(call.body).action)).toEqual([REQUIRE_PASSWORD_CHANGE, SET_PASSWORD]);
    expect(policy.store.refusal()).toBe('too short');
    expect(policy.events).toHaveLength(1);

    const unflagged = mountUsers([UPDATED]);
    unflagged.actions.run(USERS.descriptor, SET_PASSWORD);
    await unflagged.handler.submitPassword(pasted, false);
    expect(unflagged.calls.map((call) => JSON.parse(call.body))).toEqual([
      { action: SET_PASSWORD, id: 'probe', values: { Password: pasted } },
    ]);
  });

  it('offers a remove of the row\u2019s own roles and an add of the Roles list\u2019s others, sending one role', async () => {
    const { actions, handler, calls } = mountUsers([
      { kind: 'ok', status: 200, body: { rows: [{ Name: '%SQL' }, { Name: '%Operator' }, { Name: '%developer' }, { Name: 'Probe' }] } },
      UPDATED,
    ]);
    actions.run(USERS.descriptor, REMOVE_ROLE);
    await settle();
    expect(handler.pending()?.kind).toBe('role');
    expect(handler.pending()?.options).toEqual(['%SQL', '%Developer']);
    handler.cancelPending();

    actions.run(USERS.descriptor, ADD_ROLE);
    await settle();
    expect(calls[0].path).toBe('/api/ocupilot/screens/permissions.roles/read?maxRows=1000');
    // Held roles are left out, case-insensitively; a privileged role is offered and the instance decides.
    expect(handler.pending()?.options).toEqual(['%Operator', 'Probe']);
    handler.submitRole('Probe');
    await settle();
    expect(JSON.parse(calls[1].body)).toEqual({ action: ADD_ROLE, id: 'probe', values: { Role: 'Probe' } });
  });
});

/** Story 7.4: the Auditing configuration form's two actions over the singleton. */
describe('the screen-action handler on the Auditing configuration form', () => {
  const AUDITING = 'OcuPilot.Screen.Descriptor.AuditingConfig';
  const TARGET = { type: 'auditing-configuration', scope: 'instance', id: ENTITY_SINGLETON_ID };

  it('opens the warning before turning auditing off, and sends nothing until it is proceeded past', async () => {
    // Mutation (Rule 19): drop the `warning` branch from `start` -> the disable is sent at once and
    // the first `calls` assertion goes red.
    const { actions, handler, store, calls, events } = mount({ kind: 'ok', status: 200, body: { action: 'updated', target: TARGET } }, AUDITING);
    store.setSelection([ENTITY_SINGLETON_ID]);

    actions.run(AUDITING, 'disable');
    await settle();
    expect(calls).toHaveLength(0);
    const pending = handler.pending();
    expect(pending?.kind).toBe('warning');
    expect(pending?.verb).toBe(STRINGS.auditingTurnOffAction);
    expect(pending?.consequence).toBe(STRINGS.proposalAuditWarning);

    handler.cancelPending();
    await settle();
    expect(calls).toHaveLength(0);

    actions.run(AUDITING, 'disable');
    handler.confirmPending();
    await settle();
    expect(calls).toHaveLength(1);
    expect(calls[0].path).toBe('/api/ocupilot/screens/security.auditing/action');
    expect(JSON.parse(calls[0].body)).toEqual({ action: 'disable', id: ENTITY_SINGLETON_ID });
    expect(events.map((event) => event.type)).toEqual(['auditing-configuration']);
  });

  it('turns auditing on at once, against the singleton', async () => {
    const { actions, handler, store, calls } = mount({ kind: 'ok', status: 200, body: { action: 'updated', target: TARGET } }, AUDITING);
    store.setSelection([ENTITY_SINGLETON_ID]);

    actions.run(AUDITING, 'enable');
    await settle();
    expect(handler.pending()).toBeNull();
    expect(calls).toHaveLength(1);
    expect(JSON.parse(calls[0].body)).toEqual({ action: 'enable', id: 'SYSTEM' });
  });
});

describe('the On-demand tasks list\u2019s Run (Story 7.5)', () => {
  const ON_DEMAND = 'OcuPilot.Screen.Descriptor.TaskOnDemandList';

  it('sends Run at once with no dialog, keyed by the task\u2019s Id, and publishes the answered task change', async () => {
    // Mutation (Rule 19): drop the list from `SCREEN_ACTION_DESCRIPTORS` -> nothing registers and
    // nothing is sent.
    const target = { type: 'task', scope: 'instance', id: '42' };
    const { actions, handler, store, calls, events } = mount({ kind: 'ok', status: 200, body: { action: 'updated', target } }, ON_DEMAND);
    expect(actions.has(ON_DEMAND, 'run')).toBe(true);
    store.setSelection(['42']);

    actions.run(ON_DEMAND, 'run');
    await settle();
    expect(handler.pending()).toBeNull();
    expect(calls).toHaveLength(1);
    expect(calls[0].path).toBe('/api/ocupilot/screens/tasks.ondemand/action');
    expect(JSON.parse(calls[0].body)).toEqual({ action: 'run', id: '42' });
    expect(events).toHaveLength(1);
    expect(events[0].kind).toBe('changed');
    expect(events[0].type).toBe('task');
    expect(events[0].action).toBe('updated');
    expect(events[0].id).toBe('42');
  });
});

describe('the Task schedule\u2019s Run, Suspend, Resume and Delete (Story 7.6)', () => {
  const SCHEDULE = 'OcuPilot.Screen.Descriptor.TaskScheduleList';
  const target = { type: 'task', scope: 'instance', id: '42' };

  it('registers all four actions and sends Run, Suspend and Resume at once, keyed by the Id', async () => {
    // Mutation (Rule 19): drop the schedule from `SCREEN_ACTION_DESCRIPTORS` -> nothing registers and
    // nothing is sent.
    for (const actionId of ['run', 'suspend', 'resume']) {
      const { actions, handler, store, calls, events } = mount({ kind: 'ok', status: 200, body: { action: 'updated', target } }, SCHEDULE);
      expect(actions.has(SCHEDULE, actionId)).toBe(true);
      store.setSelection(['42']);

      actions.run(SCHEDULE, actionId);
      await settle();
      expect(handler.pending()).toBeNull();
      expect(calls).toHaveLength(1);
      expect(calls[0].path).toBe('/api/ocupilot/screens/tasks.schedule/action');
      expect(JSON.parse(calls[0].body)).toEqual({ action: actionId, id: '42' });
      expect(events.map((event) => `${event.type}:${event.action}:${event.id}`)).toEqual(['task:updated:42']);
    }
  });

  it('opens Delete\u2019s dialog titled with the row\u2019s Name, and sends its Id once confirmed', async () => {
    // Mutation (Rule 19): drop the schedule's entry from `TYPED_NAME_ROWS` -> the dialog names the Id
    // and the `name` assertion goes red.
    const { actions, handler, store, calls, events } = mount({ kind: 'ok', status: 200, body: { action: 'deleted', target } }, SCHEDULE);
    store.applyTick([{ Id: '42', Name: 'Nightly purge', Type: 'User' }], false, '', new Date());
    store.setSelection(['42']);

    actions.run(SCHEDULE, 'delete');
    await settle();
    expect(calls).toHaveLength(0);
    const pending = handler.pending();
    expect(pending?.kind).toBe('typed-name');
    expect(pending?.name).toBe('Nightly purge');
    expect(pending?.target).toBe('42');
    expect(pending?.verb).toBe(STRINGS.actionDelete);
    expect(pending?.consequence).toBe(STRINGS.taskDeleteConsequence);
    expect(pending?.advisory).toBe('');

    handler.confirmPending();
    await settle();
    expect(calls).toHaveLength(1);
    expect(JSON.parse(calls[0].body)).toEqual({ action: 'delete', id: '42' });
    expect(events.map((event) => `${event.type}:${event.action}:${event.id}`)).toEqual(['task:deleted:42']);
  });

  it('adds the system-task advisory to a System row\u2019s delete, and none to a User row\u2019s', async () => {
    // Mutation (Rule 19): drop the advisory from `TYPED_NAME_ROWS` -> the System assertion goes red.
    const { actions, handler, store } = mount({ kind: 'ok', status: 200, body: {} }, SCHEDULE);
    store.applyTick(
      [
        { Id: '1', Name: 'Switch Journal', Type: 'System' },
        { Id: '42', Name: 'Nightly purge', Type: 'User' },
      ],
      false,
      '',
      new Date()
    );
    store.setSelection(['1']);
    actions.run(SCHEDULE, 'delete');
    await settle();
    expect(handler.pending()?.name).toBe('Switch Journal');
    expect(handler.pending()?.advisory).toBe(STRINGS.taskSystemDeleteConsequence);
    handler.cancelPending();

    store.setSelection(['42']);
    actions.run(SCHEDULE, 'delete');
    await settle();
    expect(handler.pending()?.advisory).toBe('');
    handler.cancelPending();
  });
});
