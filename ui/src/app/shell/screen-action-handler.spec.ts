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
  ADD_APPLICATION_ROLE,
  ADD_GRANTED_ROLE,
  ADD_MATCHING_ROLE,
  ADD_ROLE,
  COPY_MAPPINGS,
  DATABASE_DETAILS,
  EXPAND_VOLUME,
  LOCAL_DATABASE_LIST,
  NAMESPACE_LIST,
  REMOVE_APPLICATION_ROLE,
  REMOVE_GRANTED_ROLE,
  REMOVE_MATCHING_ROLE,
  REMOVE_RESOURCE_GRANT,
  REMOVE_ROLE,
  REQUIRE_PASSWORD_CHANGE,
  RESOURCE_LIST,
  ROLE_LIST,
  SCREEN_ACTION_DESCRIPTORS,
  SET_PASSWORD,
  SET_RESOURCE_GRANT,
  ScreenActionHandler,
  TASK_EXPORT,
  TASK_IMPORT,
  TASK_IMPORT_TARGET,
  TASK_MANAGER_RESUME,
  TASK_MANAGER_START,
  TASK_MANAGER_SUSPEND,
  TASK_MANAGER_TARGET,
  TASK_SCHEDULE,
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
    // The four role actions are the web application editor's, whose pickers supply their values,
    // so no list surface draws them (DW-389).
    const undrawn = [ADD_APPLICATION_ROLE, REMOVE_APPLICATION_ROLE, ADD_MATCHING_ROLE, REMOVE_MATCHING_ROLE];
    for (const action of WEB_APPS.rowActions) {
      expect(actions.has(WEB_APPS.descriptor, action.id)).toBe(!undrawn.includes(action.id));
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

  it('carries the instance\u2019s read-back onto the change event, and none it did not answer', async () => {
    // Mutation (Rule 19): drop `readBack` from `send()`'s publish -> the first assertion goes red,
    // and the marked row would say "Changed" and nothing about what the instance now holds (AD-58).
    const answered = mount({
      kind: 'ok',
      status: 200,
      body: {
        action: 'updated',
        target: { type: 'web-application', scope: 'instance', id: ORDINARY_ROW },
        readBack: { verdict: 'matches', fields: [], written: [] },
      },
    });
    answered.store.setSelection([ORDINARY_ROW]);
    answered.actions.run(WEB_APPS.descriptor, 'enable');
    await settle();
    expect(answered.events[0].readBack).toEqual({ verdict: 'matches', fields: [], written: [], reason: '' });

    const outside = mount({
      kind: 'ok',
      status: 200,
      body: {
        action: 'updated',
        target: { type: 'web-application', scope: 'instance', id: ORDINARY_ROW },
        readBack: { verdict: 'probably', fields: [], written: [] },
      },
    });
    outside.store.setSelection([ORDINARY_ROW]);
    outside.actions.run(WEB_APPS.descriptor, 'enable');
    await settle();
    expect(outside.events).toHaveLength(1);
    expect('readBack' in outside.events[0]).toBe(false);
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

const OAUTH_RESOURCE_SERVERS = SCREENS.find(
  (screen) => screen.descriptor === 'OcuPilot.Screen.Descriptor.OAuthResourceServerTab'
)!;

const OAUTH_AUTH_SERVER = SCREENS.find((screen) => screen.descriptor === 'OcuPilot.Screen.Descriptor.OAuthServerTab')!;

/**
 * AD-53, Story 7.3: the OAuth 2.0 tabs' delete runs through the same handler, with each tab's own
 * published consequence, and a server client is targeted by its `ClientId` -- the vendor's IdKey --
 * never by its `Name`, which two clients may share.
 */
describe('the OAuth 2.0 tabs\u2019 delete', () => {
  it('registers delete on the four tabs and opens each tab\u2019s own consequence', async () => {
    // Mutation (Rule 19): drop any of the descriptors from `SCREEN_ACTION_DESCRIPTORS` -> its `has`
    // assertion goes red, and no surface draws its delete (DW-389).
    for (const [screen, consequence, row, type, rowActions] of [
      [OAUTH_CLIENTS, STRINGS.oauthClientDeleteConsequence, 'OcuPilotTestDelete', 'oauth2-client-configuration', ['delete', 'rotatekeys', 'register']],
      [OAUTH_SERVER_CLIENTS, STRINGS.oauthServerClientDeleteConsequence, 'probe-client-id', 'oauth2-server-client', ['delete', 'updatejwks']],
      [OAUTH_RESOURCE_SERVERS, STRINGS.oauthResourceServerDeleteConsequence, 'OcuPilotProbeResource', 'oauth2-resource-server', ['delete']],
      [OAUTH_AUTH_SERVER, STRINGS.oauthAuthServerDeleteConsequence, 'probe-issuer', 'oauth2-server', ['delete', 'rotatekeys']],
    ] as const) {
      const answer: JsonResult<unknown> = {
        kind: 'ok',
        status: 200,
        body: { action: 'deleted', target: { type, scope: 'instance', id: row } },
      };
      const { actions, handler, store, calls, events } = mount(answer, screen.descriptor);
      expect(screen.rowActions.map((action) => action.id)).toEqual(rowActions);
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
    expect(drawn).toEqual(['enable', 'disable', SET_PASSWORD, ADD_ROLE, REMOVE_ROLE, 'delete', 'revoke-tokens']);
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

  it('offers a remove of the row\u2019s own roles and an add of the form read\u2019s others, sending one role', async () => {
    // Story 9.1 (DW-1523): the add's choices come from `GET /users/form`, each with the server's own
    // privilege mark, which the dialog states the grant's consequence from.
    // Mutation (Rule 19): drop the privileged marks from `openRole` -> the privileged assertion goes red.
    const { actions, handler, calls } = mountUsers([
      {
        kind: 'ok',
        status: 200,
        body: {
          roles: [
            { name: '%SQL', privileged: false },
            { name: '%Operator', privileged: true },
            { name: '%developer', privileged: false },
            { name: 'Probe', privileged: false },
          ],
        },
      },
      UPDATED,
    ]);
    actions.run(USERS.descriptor, REMOVE_ROLE);
    await settle();
    expect(handler.pending()?.kind).toBe('role');
    expect(handler.pending()?.options).toEqual(['%SQL', '%Developer']);
    handler.cancelPending();

    actions.run(USERS.descriptor, ADD_ROLE);
    await settle();
    expect(calls[0].path).toBe('/api/ocupilot/users/form');
    // Held roles are left out, case-insensitively; a privileged role is offered and the instance decides.
    expect(handler.pending()?.options).toEqual(['%Operator', 'Probe']);
    expect(handler.pending()?.privileged).toEqual(['%Operator']);
    handler.submitRole('Probe');
    await settle();
    expect(JSON.parse(calls[1].body)).toEqual({ action: ADD_ROLE, id: 'probe', values: { Role: 'Probe' } });
  });

  it('reads a Remove role\u2019s impact for the chosen role, and drops an answer for a choice that moved on', async () => {
    // Story 16.19 (AD-8): the line is read each time the choice changes, and a late answer for an
    // earlier choice never lands. Mutation (Rule 19): drop the `ask` check in `chooseRole` -> the
    // stale leg goes red.
    let release: (value: JsonResult<unknown>) => void = () => undefined;
    const slow = new Promise<JsonResult<unknown>>((resolve) => (release = resolve));
    const losesSql = { kind: 'role-removal', refused: null, parts: [{ part: 'loses', count: 1, names: ['%DB_USER:RW'], unchecked: '' }] };
    const losesNothing = { kind: 'role-removal', refused: null, parts: [{ part: 'loses', count: 0, names: [], unchecked: '' }] };
    const { actions, handler, calls } = mountUsers([]);
    const api = TestBed.inject(ApiService) as unknown as { requestJson: (path: string, init?: ApiRequestInit) => Promise<JsonResult<unknown>> };
    const answers: Promise<JsonResult<unknown>>[] = [slow, Promise.resolve({ kind: 'ok', status: 200, body: { impact: losesNothing } })];
    api.requestJson = async (path: string, init: ApiRequestInit = {}) => {
      calls.push({ path, method: init.method ?? 'GET', body: init.body ?? '' });
      return answers.shift() ?? { kind: 'ok', status: 200, body: {} };
    };
    actions.run(USERS.descriptor, REMOVE_ROLE);
    await settle();
    expect(handler.pending()?.impact).toBe('');

    const first = handler.chooseRole('%SQL');
    const second = handler.chooseRole('%Developer');
    await second;
    expect(calls[0].path).toBe(`/api/ocupilot/screens/${USERS.toolIdentifier}/impact?action=remove-role&id=probe&value=%25SQL`);
    expect(handler.pending()?.impact).toBe('Impact: probe loses nothing their other roles do not still grant.');
    release({ kind: 'ok', status: 200, body: { impact: losesSql } });
    await first;
    expect(handler.pending()?.impact).toBe('Impact: probe loses nothing their other roles do not still grant.');

    void handler.chooseRole('');
    expect(handler.pending()?.impact).toBe('');
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
    expect(mount({ kind: 'ok', status: 200, body: {} }, SCHEDULE).actions.has(SCHEDULE, 'delete')).toBe(true);
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

describe('Processes and Process details: Suspend, Resume and Terminate (Story 7.8)', () => {
  const LIST = 'OcuPilot.Screen.Descriptor.ProcessList';
  const DETAILS = 'OcuPilot.Screen.Descriptor.ProcessDetails';
  const target = { type: 'process', scope: 'instance', id: '4711' };

  it('sends Suspend and Resume at once, from either screen, and never draws the flagged action', async () => {
    // Mutation (Rule 19): drop Processes from `SCREEN_ACTION_DESCRIPTORS` -> nothing registers.
    for (const descriptor of [LIST, DETAILS]) {
      for (const actionId of ['suspend', 'resume']) {
        const { actions, handler, store, calls, events } = mount({ kind: 'ok', status: 200, body: { action: 'updated', target } }, descriptor);
        expect(actions.has(descriptor, actionId)).toBe(true);
        expect(actions.has(descriptor, 'terminate')).toBe(true);
        expect(actions.has(descriptor, 'terminate-with-error')).toBe(false);
        store.setSelection(['4711']);

        actions.run(descriptor, actionId);
        await settle();
        expect(handler.pending()).toBeNull();
        expect(calls).toHaveLength(1);
        expect(calls[0].path).toBe('/api/ocupilot/screens/osmgmt.processes/action');
        expect(JSON.parse(calls[0].body)).toEqual({ action: actionId, id: '4711' });
        expect(events.map((event) => `${event.type}:${event.action}:${event.id}`)).toEqual(['process:updated:4711']);
      }
    }
  });

  it('opens Terminate\u2019s dialog titled with the pid, and sends terminate unchecked, terminate-with-error checked', async () => {
    // Mutation (Rule 19): drop the flag's entry from `FLAGGED_ACTIONS` -> the flag label and the
    // checked request go red.
    for (const flag of [false, true]) {
      const { actions, handler, store, calls, events } = mount({ kind: 'ok', status: 200, body: { action: 'deleted', target } }, LIST);
      store.setSelection(['4711']);

      actions.run(LIST, 'terminate');
      await settle();
      expect(calls).toHaveLength(0);
      const pending = handler.pending();
      expect(pending?.kind).toBe('typed-name');
      expect(pending?.verb).toBe(STRINGS.actionTerminate);
      expect(pending?.name).toBe('4711');
      expect(pending?.target).toBe('4711');
      expect(pending?.consequence).toBe(STRINGS.processTerminateConsequence);
      expect(pending?.flagLabel).toBe(STRINGS.processTerminateErrorFlag);

      handler.confirmPending(flag);
      await settle();
      expect(calls).toHaveLength(1);
      const sent = JSON.parse(calls[0].body);
      expect(sent).toEqual({ action: flag ? 'terminate-with-error' : 'terminate', id: '4711' });
      expect(Object.hasOwn(sent, 'values')).toBe(false);
      expect(events.map((event) => `${event.type}:${event.action}:${event.id}`)).toEqual(['process:deleted:4711']);
    }
  });

  it('sends Process details\u2019 Terminate to the processes list\u2019s route, and puts a refusal on the details page', async () => {
    // Mutation (Rule 19): drop Process details from `ACTION_ADDRESS` -> the path reads
    // osmgmt.processdetails and goes red.
    const refused = { kind: 'error', status: 403, reason: STRINGS.processRefusalOcuPilot, code: 'PROHIBITED.OCUPILOTPROCESS' } as unknown as JsonResult<unknown>;
    const { actions, handler, store, calls, events } = mount(refused, DETAILS);
    store.setSelection(['4711']);
    actions.run(DETAILS, 'terminate');
    await settle();
    expect(handler.pending()?.flagLabel).toBe(STRINGS.processTerminateErrorFlag);
    handler.confirmPending(true);
    await settle();
    expect(calls).toHaveLength(1);
    expect(calls[0].path).toBe('/api/ocupilot/screens/osmgmt.processes/action');
    expect(JSON.parse(calls[0].body)).toEqual({ action: 'terminate-with-error', id: '4711' });
    expect(store.refusal()).toBe(STRINGS.processRefusalOcuPilot);
    expect(events).toEqual([]);
  });

  it('offers no flag on another screen\u2019s typed-name dialog', async () => {
    const { actions, handler, store } = mount({ kind: 'ok', status: 200, body: {} }, 'OcuPilot.Screen.Descriptor.TaskScheduleList');
    store.setSelection(['42']);
    actions.run('OcuPilot.Screen.Descriptor.TaskScheduleList', 'delete');
    await settle();
    expect(handler.pending()?.flagLabel).toBe('');
    handler.cancelPending();
  });
});

describe('Processes\u2019 Broadcast over the checked rows (Story 16.6)', () => {
  const LIST = 'OcuPilot.Screen.Descriptor.ProcessList';
  const target = { type: 'process', scope: 'instance', id: '812,907' };

  it('opens the broadcast dialog over the checked set, never the selection, and sends one request with the trimmed message', async () => {
    const { actions, handler, store, calls, events } = mount({ kind: 'ok', status: 200, body: { action: 'updated', target } }, LIST);
    expect(actions.has(LIST, 'broadcast')).toBe(true);
    store.setSelection(['4711']);
    actions.run(LIST, 'broadcast');
    await settle();
    expect(handler.pending()).toBeNull();

    store.setChecked(['907', '812']);
    actions.run(LIST, 'broadcast');
    await settle();
    const pending = handler.pending();
    expect(pending?.kind).toBe('broadcast');
    expect(pending?.count).toBe(2);
    expect(pending?.target).toBe('812,907');
    expect(calls).toHaveLength(0);

    await handler.submitBroadcast('  Down at 18:00  ');
    await settle();
    expect(calls).toHaveLength(1);
    expect(calls[0].path).toBe('/api/ocupilot/screens/osmgmt.processes/action');
    expect(JSON.parse(calls[0].body)).toEqual({ action: 'broadcast', id: '812,907', values: { Message: 'Down at 18:00' } });
    expect(handler.pending()?.sent).toBe(true);
    expect(store.checked().size).toBe(0);
    expect(store.selection()).toEqual(['4711']);
    expect(events.map((event) => `${event.type}:${event.action}:${event.id}`)).toEqual(['process:updated:812,907']);

    await handler.submitBroadcast('again');
    await settle();
    expect(calls).toHaveLength(1);
    handler.cancelPending();
    expect(handler.pending()).toBeNull();
  });

  // Mutation (Rule 19): put the refusal on the list's store rather than the dialog -> red.
  it('keeps the dialog open on a refusal with the envelope\u2019s own reason, and keeps the checks', async () => {
    const refused = { kind: 'error', status: 409, reason: STRINGS.processBroadcastRefusalRecipient, code: 'PROCESS.BROADCAST.RECIPIENT' } as unknown as JsonResult<unknown>;
    const { actions, handler, store, calls, events } = mount(refused, LIST);
    store.setChecked(['812', '907']);
    actions.run(LIST, 'broadcast');
    await settle();
    await handler.submitBroadcast('Down at 18:00');
    await settle();
    expect(calls).toHaveLength(1);
    expect(handler.pending()?.kind).toBe('broadcast');
    expect(handler.pending()?.refusal).toBe(STRINGS.processBroadcastRefusalRecipient);
    expect(handler.pending()?.sent).toBe(false);
    expect(store.refusal()).toBe('');
    expect(store.checked().size).toBe(2);
    expect(events).toEqual([]);
  });

  // Mutation (Rule 19): drop `pending.sending === true ||` from `submitBroadcast` -> the second
  // Send posts too and this goes red.
  it('a second Send while the first is in flight sends nothing', async () => {
    const { actions, handler, store, calls } = mount({ kind: 'ok', status: 200, body: { action: 'updated', target } }, LIST);
    store.setChecked(['812', '907']);
    actions.run(LIST, 'broadcast');
    await settle();
    const first = handler.submitBroadcast('Down at 18:00');
    const second = handler.submitBroadcast('Down at 18:00');
    await Promise.all([first, second]);
    await settle();
    expect(calls).toHaveLength(1);
    expect(handler.pending()?.sent).toBe(true);
  });

  // Mutation (Rule 19): compare the answered dialog by kind and target instead of identity -> the
  // reopened dialog reads sent before anything was typed in it, and this goes red.
  it('a Send answered after its dialog was closed and reopened leaves the reopened one unsent', async () => {
    const { actions, handler, store, calls } = mount({ kind: 'ok', status: 200, body: { action: 'updated', target } }, LIST);
    store.setChecked(['812', '907']);
    actions.run(LIST, 'broadcast');
    await settle();
    const inFlight = handler.submitBroadcast('Down at 18:00');
    handler.cancelPending();
    actions.run(LIST, 'broadcast');
    await inFlight;
    await settle();
    expect(calls).toHaveLength(1);
    expect(handler.pending()?.kind).toBe('broadcast');
    expect(handler.pending()?.sent).toBe(false);
    expect(handler.pending()?.sending).toBe(false);
  });

  it('Cancel sends nothing, and a set over the declared max opens nothing', async () => {
    const { actions, handler, store, calls } = mount({ kind: 'ok', status: 200, body: {} }, LIST);
    store.setChecked(['812']);
    actions.run(LIST, 'broadcast');
    await settle();
    expect(handler.pending()?.count).toBe(1);
    handler.cancelPending();
    await settle();
    expect(calls).toHaveLength(0);
    expect(store.checked().size).toBe(1);

    store.setChecked(Array.from({ length: 21 }, (_, index) => String(100 + index)));
    actions.run(LIST, 'broadcast');
    await settle();
    expect(handler.pending()).toBeNull();
    expect(calls).toHaveLength(0);
  });
});

describe('the application error log: one Delete whose target names its scope (Story 7.10)', () => {
  const LOG = 'OcuPilot.Screen.Descriptor.LogErrorList';
  const SEP = '\u0001';

  it('titles, types and explains each scope by the target\u2019s own part count, and sends the whole id', async () => {
    // Mutation (Rule 19): drop the log's entry from `SCOPED_TARGETS` -> every scope opens as
    // "Delete <the joined id>" with the namespace sentence, and the verb, name and consequence go
    // red for the date and error legs.
    const scopes = [
      { id: 'USER', verb: STRINGS.errorDeleteEveryVerb, name: 'USER', consequence: STRINGS.errorDeleteEveryConsequence },
      { id: `USER${SEP}09/23/2026`, verb: STRINGS.errorDeleteDateVerb, name: '09/23/2026', consequence: STRINGS.errorDeleteDateConsequence },
      { id: `USER${SEP}09/23/2026${SEP}4`, verb: STRINGS.errorDeleteOneVerb, name: '4', consequence: STRINGS.errorDeleteOneConsequence },
    ];
    for (const scope of scopes) {
      const target = { type: 'application-error', scope: 'instance', id: scope.id.toLowerCase() };
      const { actions, handler, store, calls, events } = mount({ kind: 'ok', status: 200, body: { action: 'deleted', target } }, LOG);
      expect(actions.has(LOG, 'delete')).toBe(true);
      store.setSelection([scope.id]);

      actions.run(LOG, 'delete');
      await settle();
      expect(calls).toHaveLength(0);
      const pending = handler.pending();
      expect(pending?.kind).toBe('typed-name');
      expect(pending?.verb).toBe(scope.verb);
      expect(pending?.name).toBe(scope.name);
      expect(pending?.target).toBe(scope.id);
      expect(pending?.consequence).toBe(scope.consequence);
      expect(pending?.flagLabel).toBe('');

      handler.confirmPending();
      await settle();
      expect(calls).toHaveLength(1);
      expect(calls[0].path).toBe('/api/ocupilot/screens/logs.applicationerrors/action');
      expect(JSON.parse(calls[0].body)).toEqual({ action: 'delete', id: scope.id });
      expect(events.map((event) => `${event.type}:${event.action}:${event.id}`)).toEqual([
        `application-error:deleted:${scope.id.toLowerCase()}`,
      ]);
    }
  });

  it('keeps another screen\u2019s delete on its own label and consequence', async () => {
    const { actions, handler, store } = mount({ kind: 'ok', status: 200, body: {} }, 'OcuPilot.Screen.Descriptor.TaskScheduleList');
    store.setSelection(['42']);
    actions.run('OcuPilot.Screen.Descriptor.TaskScheduleList', 'delete');
    await settle();
    expect(handler.pending()?.verb).toBe(STRINGS.actionDelete);
    expect(handler.pending()?.consequence).toBe(STRINGS.taskDeleteConsequence);
    handler.cancelPending();
  });
});

describe('the System events and User events lists (Story 7.11)', () => {
  const SYSTEM = 'OcuPilot.Screen.Descriptor.AuditSystemEventList';
  const USER = 'OcuPilot.Screen.Descriptor.AuditUserEventList';
  const MARKER = 'OcuPilot/Security/AgentWrite';
  const OTHER = 'OcuPilot/Security/ConfigChange';
  const SQL = '%System/%SQL/XDBCStatementUtility';

  function rows(store: ReturnType<typeof mount>['store']): void {
    store.applyTick(
      [
        { EventName: MARKER, Enabled: true, Total: 3, Written: 3, Lost: 0 },
        { EventName: OTHER, Enabled: true, Total: 1, Written: 1, Lost: 0 },
      ],
      false,
      '',
      new Date()
    );
  }

  it('sends reset and enable at once, with no dialog', async () => {
    // Mutation (Rule 19): drop the lists from `SCREEN_ACTION_DESCRIPTORS` -> no handler registers
    // and nothing is sent.
    const { actions, handler, store, calls } = mount({ kind: 'ok', status: 200, body: {} }, SYSTEM);
    store.setSelection([SQL]);
    for (const action of ['reset', 'enable']) {
      expect(actions.run(SYSTEM, action)).toBe(true);
      await settle();
      expect(handler.pending()).toBeNull();
    }
    expect(calls.map((call) => JSON.parse(call.body))).toEqual([
      { action: 'reset', id: SQL },
      { action: 'enable', id: SQL },
    ]);
    expect(calls[0].path).toBe('/api/ocupilot/screens/security.auditsystemevents/action');
    expect(actions.has(SYSTEM, 'delete')).toBe(false);
  });

  it('warns before disabling the marker event, and disables any other row at once', async () => {
    // Mutation (Rule 19): drop `WARNING_ROWS` -> the marker disable is sent at once and the
    // pending assertions go red.
    const { actions, handler, store, calls } = mount({ kind: 'ok', status: 200, body: {} }, USER);
    rows(store);
    store.setSelection([MARKER]);
    actions.run(USER, 'disable');
    await settle();
    expect(calls).toHaveLength(0);
    const pending = handler.pending();
    expect(pending?.kind).toBe('warning');
    expect(pending?.verb).toBe(STRINGS.agentDefinitionDisable);
    expect(pending?.consequence).toBe(STRINGS.proposalAuditWarning);
    handler.confirmPending();
    await settle();
    expect(calls.map((call) => JSON.parse(call.body))).toEqual([{ action: 'disable', id: MARKER }]);

    store.setSelection([OTHER]);
    actions.run(USER, 'disable');
    await settle();
    expect(handler.pending()).toBeNull();
    expect(calls.map((call) => JSON.parse(call.body))).toEqual([
      { action: 'disable', id: MARKER },
      { action: 'disable', id: OTHER },
    ]);
  });

  it('types the event name before a delete, with the advisory on the marker row only', async () => {
    // Mutation (Rule 19): drop the User events list's `DESTRUCTIVE_CONSEQUENCES` entry -> no delete
    // registers and the first assertion goes red.
    const { actions, handler, store, calls } = mount({ kind: 'ok', status: 200, body: {} }, USER);
    rows(store);
    expect(actions.has(USER, 'delete')).toBe(true);
    for (const [row, advisory] of [
      [MARKER, STRINGS.proposalAuditWarning],
      [OTHER, ''],
    ]) {
      store.setSelection([row]);
      actions.run(USER, 'delete');
      await settle();
      const pending = handler.pending();
      expect(pending?.kind).toBe('typed-name');
      expect(pending?.name).toBe(row);
      expect(pending?.consequence).toBe(STRINGS.auditUserEventDeleteConsequence);
      expect(pending?.advisory).toBe(advisory);
      handler.cancelPending();
    }
    expect(calls).toHaveLength(0);
  });

  it('sends one action through sendFor as a row action would, and answers whether it applied', async () => {
    const target = { type: 'audit-event', scope: 'instance', id: SQL.toLowerCase() };
    const { handler, calls, events } = mount({ kind: 'ok', status: 200, body: { action: 'updated', target } }, SYSTEM);
    expect(await handler.sendFor(SYSTEM, 'enable', SQL)).toBe(true);
    expect(JSON.parse(calls[0].body)).toEqual({ action: 'enable', id: SQL });
    expect(events.map((event) => `${event.type}:${event.action}`)).toEqual(['audit-event:updated']);
  });
});

/**
 * Story 9.1 (DW-1501): an editor starts the Users list's own actions on the account it shows,
 * through the one handler and the one route, with a sink of its own for the refusal and the applied
 * write -- the list's store is not touched.
 */
describe('startFor, the editor half of the Users list actions', () => {
  function sink() {
    const seen = { refusals: [] as string[], applied: [] as string[] };
    return {
      seen,
      sink: { setRefusal: (reason: string) => seen.refusals.push(reason), applied: (actionId: string) => seen.applied.push(actionId) },
    };
  }

  it('sends a role an editor has already chosen at once, reporting to the editor rather than the list', async () => {
    const { handler, calls, store } = mountUsers([UPDATED]);
    const { seen, sink: editorSink } = sink();
    handler.startFor(USERS.descriptor, REMOVE_ROLE, 'probe', { Roles: ['%SQL'] }, editorSink, '%SQL');
    await settle();
    expect(handler.pending()).toBeNull();
    expect(JSON.parse(calls[0].body)).toEqual({ action: REMOVE_ROLE, id: 'probe', values: { Role: '%SQL' } });
    expect(seen.applied).toEqual([REMOVE_ROLE]);
    expect(store.refusal()).toBe('');
  });

  it('opens the list\u2019s own dialogs for the editor, and a refusal reaches the editor\u2019s sink', async () => {
    // Mutation (Rule 19): report to the list store in `send` whatever the sink -> the sink's
    // refusal assertion goes red.
    const refused = { kind: 'error', status: 403, code: 'PROHIBITED.SERVICEACCOUNTSIGNIN', reason: 'no sign-in change', detail: null } as JsonResult<unknown>;
    const { handler } = mountUsers([refused]);
    const { seen, sink: editorSink } = sink();
    handler.startFor(USERS.descriptor, SET_PASSWORD, 'probe', { Roles: [] }, editorSink);
    expect(handler.pending()?.kind).toBe('set-password');
    expect(handler.pending()?.descriptor).toBe(USERS.descriptor);
    await handler.submitPassword('Probe-password-1', false);
    expect(seen.refusals).toEqual(['', 'no sign-in change']);
    expect(seen.applied).toEqual([]);
  });

  it('draws a service account\u2019s Set password refused with the sign-in sentence before anything is sent', async () => {
    // Mutation (Rule 19): drop the rule from UserList's set-password declaration -> the dialog opens.
    const { handler, calls } = mountUsers([UPDATED]);
    const { seen, sink: editorSink } = sink();
    handler.startFor(USERS.descriptor, SET_PASSWORD, 'CSPSystem', null, editorSink);
    expect(handler.pending()).toBeNull();
    expect(seen.refusals).toEqual([STRINGS.userRefusalServiceAccountSignIn]);
    expect(calls).toHaveLength(0);
  });
});

/**
 * Story 9.2: the web application editor starts the Web applications list's role actions with the
 * values its pickers chose, sent at once through the one route; on OcuPilot's own applications the
 * privilege-grant sentence is drawn and nothing is sent (AD-53, AD-56 (ii)).
 */
describe('startFor with values, the web application editor half of the role actions', () => {
  it('sends the chosen values at once, reporting to the editor', async () => {
    // Mutation (Rule 19): drop the `values` short-circuit from `startFor` -> nothing is sent.
    const { handler, calls } = mount({ kind: 'ok', status: 200, body: { action: 'updated', target: { type: 'web-application', scope: 'instance', id: ORDINARY_ROW } } });
    const seen = { refusals: [] as string[], applied: [] as string[] };
    const editorSink = { setRefusal: (reason: string) => seen.refusals.push(reason), applied: (actionId: string) => seen.applied.push(actionId) };
    handler.startFor(WEB_APPS.descriptor, ADD_MATCHING_ROLE, ORDINARY_ROW, null, editorSink, '', { MatchRole: '%Operator', Role: '%SQL' });
    await settle();
    expect(handler.pending()).toBeNull();
    expect(JSON.parse(calls[0].body)).toEqual({ action: ADD_MATCHING_ROLE, id: ORDINARY_ROW, values: { MatchRole: '%Operator', Role: '%SQL' } });
    expect(seen.applied).toEqual([ADD_MATCHING_ROLE]);
  });

  it('draws OcuPilot\u2019s own application refused with the privilege-grant sentence and sends nothing', async () => {
    const { handler, calls } = mount();
    const seen = { refusals: [] as string[] };
    handler.startFor(WEB_APPS.descriptor, ADD_APPLICATION_ROLE, OWN_ROW, null, { setRefusal: (reason: string) => seen.refusals.push(reason) }, '', { Role: '%All' });
    await settle();
    expect(seen.refusals).toEqual([STRINGS.webAppPrivilegeGrantRefusal]);
    expect(calls).toHaveLength(0);
  });
});

/**
 * Story 9.3: the Roles and Resources lists' Delete (DW-1513, DW-1528) and the role editor's value
 * actions, through the one route.
 */
describe('the Roles and Resources lists\u2019 Delete (Story 9.3)', () => {
  const ROLES_LIST = SCREENS.find((screen) => screen.descriptor === ROLE_LIST)!;
  const RESOURCES_LIST = SCREENS.find((screen) => screen.descriptor === RESOURCE_LIST)!;

  function mountWith(answers: readonly JsonResult<unknown>[], descriptor: string) {
    const mounted = mount(undefined, descriptor);
    const queue = [...answers];
    const api = TestBed.inject(ApiService) as unknown as { requestJson: (path: string, init?: ApiRequestInit) => Promise<JsonResult<unknown>> };
    api.requestJson = async (path: string, init: ApiRequestInit = {}) => {
      mounted.calls.push({ path, method: init.method ?? 'GET', body: init.body ?? '' });
      return (queue.shift() ?? { kind: 'ok', status: 200, body: {} }) as JsonResult<unknown>;
    };
    return mounted;
  }

  it('registers Delete on both lists and none of the role editor\u2019s value actions', () => {
    // Mutation (Rule 19): drop the Roles list from `SCREEN_ACTION_DESCRIPTORS` -> the delete leg goes red.
    const { actions } = mount(undefined, ROLE_LIST);
    expect(actions.has(ROLE_LIST, 'delete')).toBe(true);
    expect(actions.has(RESOURCE_LIST, 'delete')).toBe(true);
    for (const id of [ADD_GRANTED_ROLE, REMOVE_GRANTED_ROLE, SET_RESOURCE_GRANT, REMOVE_RESOURCE_GRANT]) {
      expect(actions.has(ROLE_LIST, id)).toBe(false);
    }
  });

  it('states the removal\u2019s impact as its advisory, read as the dialog opens, and opens without it when the read fails', async () => {
    // Story 16.19 (AD-8), replacing the holders line (DW-1513).
    // Mutation (Rule 19): open the role delete without its impact read -> the advisory assertion goes red.
    const impact = {
      kind: 'role-delete',
      refused: null,
      parts: [
        { part: 'holders', count: 2, names: ['Ann', 'Bo'], unchecked: '' },
        { part: 'grantingApplications', count: 1, names: ['/csp/p'], unchecked: '' },
      ],
    };
    const { handler, calls, store } = mountWith([{ kind: 'ok', status: 200, body: { impact } }], ROLE_LIST);
    handler.startFor(ROLE_LIST, 'delete', 'Probe', { Name: 'Probe' }, store);
    await settle();
    expect(calls).toHaveLength(1);
    expect(calls[0].path).toBe(`/api/ocupilot/screens/${ROLES_LIST.toolIdentifier}/impact?action=delete&id=Probe`);
    expect(calls[0].method).toBe('GET');
    expect(handler.pending()?.consequence).toBe(STRINGS.roleDeleteConsequence);
    expect(handler.pending()?.advisory).toBe('Impact: 2 users hold it: Ann, Bo; 1 web application grants it: /csp/p.');
    handler.cancelPending();

    const failed = mountWith([{ kind: 'error', status: 403, code: 'AUTH.NOPRIVILEGE', reason: 'no', detail: null } as JsonResult<unknown>], ROLE_LIST);
    failed.handler.startFor(ROLE_LIST, 'delete', 'Probe', { Name: 'Probe' }, failed.store);
    await settle();
    expect(failed.handler.pending()?.kind).toBe('typed-name');
    expect(failed.handler.pending()?.advisory).toBe('');
    expect(ROLES_LIST.rowActions.find((action) => action.id === 'delete')?.selfProtection).toBe('system-role');
  });

  it('states a resource delete\u2019s refusal as its advisory, in the prohibited set\u2019s own sentence', async () => {
    // Story 16.19 (AD-10): a refused removal's line is the refusal's reason, never an impact.
    const reason = 'This resource guards OcuPilot\u2019s own data.';
    const { handler, store } = mountWith(
      [{ kind: 'ok', status: 200, body: { impact: { kind: 'resource-delete', refused: { code: 'PROHIBITED.OCUPILOTRESOURCE', reason }, parts: [] } } }],
      RESOURCE_LIST
    );
    handler.startFor(RESOURCE_LIST, 'delete', 'Probe', { Name: 'Probe', AllowDelete: true }, store);
    await settle();
    expect(handler.pending()?.advisory).toBe(reason);
  });

  // AC4: a caller short the databases pair reads that part as unchecked, naming the pair, and
  // the other two parts still counted -- never "it guards no database".
  // Mutation (Rule 19): disable phraseOf's unchecked branch in core/impact.ts -> this goes red.
  it('states a resource delete\u2019s unchecked part as its advisory, naming the missing pair, never as none', async () => {
    const impact = {
      kind: 'resource-delete',
      refused: null,
      parts: [
        { part: 'grantingRoles', count: 2, names: ['A', 'B'], unchecked: '' },
        { part: 'guardedApplications', count: 1, names: ['/csp/q'], unchecked: '' },
        { part: 'guardedDatabases', count: 0, names: [], unchecked: '%Admin_Manage:USE' },
      ],
    };
    const { handler, store } = mountWith([{ kind: 'ok', status: 200, body: { impact } }], RESOURCE_LIST);
    handler.startFor(RESOURCE_LIST, 'delete', 'Probe', { Name: 'Probe', AllowDelete: true }, store);
    await settle();
    expect(handler.pending()?.advisory).toBe(
      'Impact: 2 roles grant it: A, B; it guards 1 web application: /csp/q; which databases it guards was not checked (requires %Admin_Manage:USE).'
    );
    expect(handler.pending()?.advisory).not.toContain(STRINGS.impactGuardedDatabasesNone);
  });

  it('opens the dialog of the Delete started last when an earlier impact read answers after it', async () => {
    // Story 16.19: an impact read that lands after another Delete started never opens its dialog.
    // Mutation (Rule 19): drop the `ask` check in `openWithImpact` -> this goes red.
    const impact = (name: string) => ({
      kind: 'resource-delete',
      refused: null,
      parts: [
        { part: 'grantingRoles', count: 1, names: [name], unchecked: '' },
        { part: 'guardedApplications', count: 0, names: [], unchecked: '' },
        { part: 'guardedDatabases', count: 0, names: [], unchecked: '' },
      ],
    });
    let release: (value: JsonResult<unknown>) => void = () => undefined;
    const slow = new Promise<JsonResult<unknown>>((resolve) => (release = resolve));
    const { handler, store } = mountWith([], RESOURCE_LIST);
    const api = TestBed.inject(ApiService) as unknown as { requestJson: (path: string, init?: ApiRequestInit) => Promise<JsonResult<unknown>> };
    const answers: Promise<JsonResult<unknown>>[] = [slow, Promise.resolve({ kind: 'ok', status: 200, body: { impact: impact('RoleB') } })];
    api.requestJson = async () => answers.shift() ?? { kind: 'ok', status: 200, body: {} };
    handler.startFor(RESOURCE_LIST, 'delete', 'ResA', { Name: 'ResA', AllowDelete: true }, store);
    handler.startFor(RESOURCE_LIST, 'delete', 'ResB', { Name: 'ResB', AllowDelete: true }, store);
    await settle();
    expect(handler.pending()?.target).toBe('ResB');
    release({ kind: 'ok', status: 200, body: { impact: impact('RoleA') } });
    await settle();
    expect(handler.pending()?.target).toBe('ResB');
    expect(handler.pending()?.advisory).toContain('RoleB');
  });

  it('draws a predefined role and a system resource refused before anything is sent', async () => {
    // Mutation (Rule 19): pass no row to `selfProtectionReason` in `startFor` -> the resource leg goes red.
    const roles = mount(undefined, ROLE_LIST);
    roles.handler.startFor(ROLE_LIST, 'delete', '%Developer', { Name: '%Developer' }, roles.store);
    expect(roles.store.refusal()).toBe(STRINGS.roleRefusalSystem);
    expect(roles.handler.pending()).toBeNull();
    const resources = mount(undefined, RESOURCE_LIST);
    resources.handler.startFor(RESOURCE_LIST, 'delete', '%DB_IRISSYS', { Name: '%DB_IRISSYS', AllowDelete: false }, resources.store);
    expect(resources.store.refusal()).toBe(STRINGS.resourceRefusalSystem);
    expect(resources.calls).toHaveLength(0);
    resources.handler.startFor(RESOURCE_LIST, 'delete', 'Probe', { Name: 'Probe', AllowDelete: true }, resources.store);
    await settle();
    expect(resources.handler.pending()?.consequence).toBe(STRINGS.resourceDeleteConsequence);
    // The one request is the impact read the dialog opens with; nothing is sent to the action route.
    expect(resources.calls.map((call) => call.method)).toEqual(['GET']);
    expect(resources.calls[0].path).toBe(`/api/ocupilot/screens/${RESOURCES_LIST.toolIdentifier}/impact?action=delete&id=Probe`);
    expect(RESOURCES_LIST.rowActions.find((action) => action.id === 'delete')?.selfProtection).toBe('system-resource');
  });
});

/**
 * Story 9.5 (DW-1541, DW-1556, FR-42): the X.509 credentials, Secrets and SSL/TLS configurations
 * lists' Delete, each typed by its name, each with its own consequence, and OcuPilot's own provider
 * configuration drawn refused before anything is sent.
 */
describe('the X.509, Secrets and SSL/TLS lists\u2019 Delete (Story 9.5)', () => {
  const X509_LIST = 'OcuPilot.Screen.Descriptor.X509CredentialList';
  const WALLET_LIST = 'OcuPilot.Screen.Descriptor.WalletSecretList';
  const SSL_LIST = 'OcuPilot.Screen.Descriptor.SslConfigList';

  it('registers Delete on the three lists, each opening the typed-name dialog with its own consequence', () => {
    // Mutation (Rule 19): drop a list's entry from `DESTRUCTIVE_CONSEQUENCES` -> its consequence assertion goes red.
    for (const [descriptor, target, consequence] of [
      [X509_LIST, 'ProbeCredential', STRINGS.x509DeleteConsequence],
      [WALLET_LIST, 'Probe.Secret', STRINGS.walletSecretDeleteConsequence],
      [SSL_LIST, 'ProbeSsl', STRINGS.sslDeleteConsequence],
    ] as const) {
      const { actions, handler, store, calls } = mount(undefined, descriptor);
      expect(actions.has(descriptor, 'delete')).toBe(true);
      handler.startFor(descriptor, 'delete', target, descriptor === X509_LIST ? { Alias: target } : { Name: target }, store);
      expect(handler.pending()?.kind).toBe('typed-name');
      expect(handler.pending()?.name).toBe(target);
      expect(handler.pending()?.consequence).toBe(consequence);
      expect(calls).toHaveLength(0);
    }
  });

  it('sends a confirmed Delete through the screen-action route, keyed by the name', async () => {
    const { handler, store, calls } = mount({ kind: 'ok', status: 200, body: { action: 'deleted', target: { type: 'ssl-configuration', scope: 'instance', id: 'ProbeSsl' } } }, SSL_LIST);
    handler.startFor(SSL_LIST, 'delete', 'ProbeSsl', { Name: 'ProbeSsl' }, store);
    handler.confirmPending();
    await settle();
    expect(calls).toHaveLength(1);
    expect(calls[0].path).toBe('/api/ocupilot/screens/security.ssl/action');
    expect(JSON.parse(calls[0].body)).toMatchObject({ action: 'delete', id: 'ProbeSsl' });
  });

  it("draws OcuPilot's own provider configuration refused before anything is sent", () => {
    // Mutation (Rule 19): declare no rule on the SSL list's delete -> the refusal assertion goes red.
    const { handler, store, calls } = mount(undefined, SSL_LIST);
    handler.startFor(SSL_LIST, 'delete', 'OcuPilotProvider', { Name: 'OcuPilotProvider' }, store);
    expect(store.refusal()).toBe(STRINGS.sslRefusalOcuPilot);
    expect(handler.pending()).toBeNull();
    expect(calls).toHaveLength(0);
  });
});

/**
 * Story 18.2 (AD-8, AD-10): the Namespaces list's Delete types the name, states the consequence and
 * the removal's impact as the dialog opens, or the kernel's refusal of OcuPilot's own namespace, and
 * publishes the deleted namespace the instance answered.
 */
describe('the Namespaces list\u2019s Delete (Story 18.2)', () => {
  const NAMESPACES = SCREENS.find((screen) => screen.descriptor === NAMESPACE_LIST)!;

  function mountWith(answers: readonly JsonResult<unknown>[]) {
    const mounted = mount(undefined, NAMESPACE_LIST);
    const queue = [...answers];
    const api = TestBed.inject(ApiService) as unknown as { requestJson: (path: string, init?: ApiRequestInit) => Promise<JsonResult<unknown>> };
    api.requestJson = async (path: string, init: ApiRequestInit = {}) => {
      mounted.calls.push({ path, method: init.method ?? 'GET', body: init.body ?? '' });
      return (queue.shift() ?? { kind: 'ok', status: 200, body: {} }) as JsonResult<unknown>;
    };
    return mounted;
  }

  it('opens the typed-name dialog with the consequence and the impact read as it opens, and sends the delete once confirmed', async () => {
    // Mutation (Rule 19): drop the Namespaces list from `IMPACT_ACTIONS` -> the impact read and the
    // advisory assertions go red; drop it from `SCREEN_ACTION_DESCRIPTORS` -> the registration does.
    const impact = {
      kind: 'namespace-delete',
      refused: null,
      parts: [
        { part: 'boundApplications', count: 2, names: ['/csp/ocuprobe182bd1', '/csp/ocuprobe182bd2'], unchecked: '' },
        { part: 'databases', count: 2, names: ['IRISTEMP', 'USER'], unchecked: '' },
      ],
    };
    const deleted = { action: 'deleted', target: { type: 'namespace', scope: 'instance', id: 'OCUPROBE182BD' } };
    const { actions, handler, calls, events, store } = mountWith([
      { kind: 'ok', status: 200, body: { impact } },
      { kind: 'ok', status: 200, body: deleted },
    ]);
    expect(actions.has(NAMESPACE_LIST, 'delete')).toBe(true);
    handler.startFor(NAMESPACE_LIST, 'delete', 'OCUPROBE182BD', { Name: 'OCUPROBE182BD' }, store);
    await settle();
    expect(calls).toHaveLength(1);
    expect(calls[0].path).toBe(`/api/ocupilot/screens/${NAMESPACES.toolIdentifier}/impact?action=delete&id=OCUPROBE182BD`);
    expect(handler.pending()?.kind).toBe('typed-name');
    expect(handler.pending()?.name).toBe('OCUPROBE182BD');
    expect(handler.pending()?.consequence).toBe(STRINGS.namespaceDeleteConsequence);
    expect(handler.pending()?.advisory).toBe(
      'Impact: 2 web applications run in it and are deleted with it: /csp/ocuprobe182bd1, /csp/ocuprobe182bd2; it uses 2 databases, which stay: IRISTEMP, USER.'
    );

    handler.confirmPending();
    await settle();
    expect(calls).toHaveLength(2);
    expect(calls[1].path).toBe(`/api/ocupilot/screens/${NAMESPACES.toolIdentifier}/action`);
    expect(calls[1].method).toBe('POST');
    expect(JSON.parse(calls[1].body)).toEqual({ action: 'delete', id: 'OCUPROBE182BD' });
    expect(events.map(({ kind, type, scope, id, action }) => ({ kind, type, scope, id, action }))).toEqual([
      { kind: 'changed', type: 'namespace', scope: 'instance', id: 'OCUPROBE182BD', action: 'deleted' },
    ]);
  });

  it('states the kernel\u2019s refusal of OcuPilot\u2019s own namespace as the advisory, and sends nothing until confirmed', async () => {
    const reason = STRINGS.namespaceRefusalOcuPilot;
    const { handler, calls, store } = mountWith([
      { kind: 'ok', status: 200, body: { impact: { kind: 'namespace-delete', refused: { code: 'PROHIBITED.OCUPILOTNAMESPACE', reason }, parts: [] } } },
    ]);
    handler.startFor(NAMESPACE_LIST, 'delete', 'HSCUSTOM', { Name: 'HSCUSTOM' }, store);
    await settle();
    expect(handler.pending()?.consequence).toBe(STRINGS.namespaceDeleteConsequence);
    expect(handler.pending()?.advisory).toBe(reason);
    handler.cancelPending();
    expect(calls.map((call) => call.method)).toEqual(['GET']);
    expect(NAMESPACES.rowActions.find((action) => action.id === 'delete')?.selfProtection).toBe('');
  });
});

/**
 * Story 16.2: the Web sessions list's End session, typed by the session id with its own consequence,
 * and a session under one of OcuPilot's own applications drawn refused before anything is sent.
 */
describe('the Web sessions list\u2019s End session (Story 16.2)', () => {
  const SESSIONS = 'OcuPilot.Screen.Descriptor.WebSessionList';
  const ID = 'wSeS5iOnId';

  it('registers End session, opening the typed-name dialog titled by the verb and the session id', () => {
    // Mutation (Rule 19): remove 'end' from `DESTRUCTIVE_ACTIONS` -> the action is sent at once
    // and the dialog assertions go red.
    const { actions, handler, store, calls } = mount(undefined, SESSIONS);
    expect(actions.has(SESSIONS, 'end')).toBe(true);
    handler.startFor(SESSIONS, 'end', ID, { ID, Application: '/api/atelier/' }, store);
    const pending = handler.pending();
    expect(pending?.kind).toBe('typed-name');
    expect(`${pending?.verb} ${pending?.name}`).toBe(`End session ${ID}`);
    expect(pending?.consequence).toBe(STRINGS.webSessionEndConsequence);
    expect(calls).toHaveLength(0);
  });

  it('sends a confirmed End session once, keyed by the session id, and publishes the deleted event', async () => {
    const { handler, store, calls, events } = mount(
      { kind: 'ok', status: 200, body: { action: 'deleted', target: { type: 'web-session', scope: 'instance', id: ID } } },
      SESSIONS
    );
    handler.startFor(SESSIONS, 'end', ID, { ID, Application: '/api/atelier/' }, store);
    handler.confirmPending();
    await settle();
    expect(calls).toHaveLength(1);
    expect(calls[0].path).toBe('/api/ocupilot/screens/webapp.sessions/action');
    expect(JSON.parse(calls[0].body)).toEqual({ action: 'end', id: ID });
    expect(events.map((event) => `${event.action} ${event.type} ${event.id}`)).toEqual([`deleted web-session ${ID}`]);
  });

  it("draws a session under OcuPilot's own application refused before anything is sent", () => {
    // Mutation (Rule 19): drop the `ocupilot-session` branch from `selfProtectionReason` -> the
    // dialog opens and the refusal assertion goes red.
    const { handler, store, calls } = mount(undefined, SESSIONS);
    handler.startFor(SESSIONS, 'end', ID, { ID, Application: '/api/ocupilot/' }, store);
    expect(store.refusal()).toBe(STRINGS.webSessionRefusalOcuPilot);
    expect(handler.pending()).toBeNull();
    expect(calls).toHaveLength(0);
  });

  it("offers End session on a preserve-mode session and shows the instance's refusal, pointing to its process, after the click", async () => {
    // Mutation (Rule 19): answer the preserve-mode sentence for a `Preserve` 1 row in
    // `selfProtectionReason` -> no dialog opens and the typed-name assertion goes red.
    const refused = { kind: 'error', status: 403, code: 'PROHIBITED.PRESERVEDSESSION', reason: STRINGS.webSessionRefusalPreserved, detail: null } as JsonResult<unknown>;
    const { handler, store, calls, events } = mount(refused, SESSIONS);
    handler.startFor(SESSIONS, 'end', ID, { ID, Application: '/csp/hscustom/', Preserve: 1, SesProcessId: '4242' }, store);
    expect(handler.pending()?.kind).toBe('typed-name');
    expect(store.refusal()).toBe('');
    handler.confirmPending();
    await settle();
    expect(calls).toHaveLength(1);
    expect(JSON.parse(calls[0].body)).toEqual({ action: 'end', id: ID });
    expect(store.refusal()).toBe(STRINGS.webSessionRefusalPreserved);
    expect(events).toEqual([]);
  });
});

/**
 * Story 16.5: the Background tasks list's Cancel task, which warns first with its own consequence,
 * and its Pause and Resume, each sent at once. A row's id is its source and id joined.
 */
describe('the Background tasks list\u2019s Cancel task, Pause and Resume (Story 16.5)', () => {
  const BACKGROUND = 'OcuPilot.Screen.Descriptor.BackgroundTaskList';
  const ID = 'Management Portal\u00014242';
  const ROW = { Source: 'Management Portal', Id: '4242', Status: 'Paused' };
  const TARGET = { type: 'background-task', scope: 'instance', id: ID };

  it('opens the warning before Cancel task, titled by the verb with the consequence, and the dialog\u2019s Cancel sends nothing', async () => {
    // Mutation (Rule 19): remove `cancel` from WARNING_CONSEQUENCES' BackgroundTaskList entry -> the
    // cancel is sent at once and the warning assertions go red.
    const { actions, handler, store, calls } = mount({ kind: 'ok', status: 200, body: { action: 'updated', target: TARGET } }, BACKGROUND);
    expect(actions.has(BACKGROUND, 'cancel')).toBe(true);
    handler.startFor(BACKGROUND, 'cancel', ID, ROW, store);
    const pending = handler.pending();
    expect(pending?.kind).toBe('warning');
    expect(pending?.verb).toBe(STRINGS.backgroundTaskCancelAction);
    expect(pending?.consequence).toBe(STRINGS.backgroundTaskCancelConsequence);
    handler.cancelPending();
    await settle();
    expect(calls).toHaveLength(0);
  });

  it('sends Cancel task once past the warning\u2019s Proceed, keyed by the composite id, and publishes the updated event', async () => {
    const { handler, store, calls, events } = mount({ kind: 'ok', status: 200, body: { action: 'updated', target: TARGET } }, BACKGROUND);
    handler.startFor(BACKGROUND, 'cancel', ID, ROW, store);
    handler.confirmPending();
    await settle();
    expect(calls).toHaveLength(1);
    expect(calls[0].path).toBe('/api/ocupilot/screens/tasks.background/action');
    expect(JSON.parse(calls[0].body)).toEqual({ action: 'cancel', id: ID });
    expect(events.map((event) => `${event.action} ${event.type} ${event.id}`)).toEqual([`updated background-task ${ID}`]);
  });

  it('sends Pause and Resume at once, with no dialog', async () => {
    // Mutation (Rule 19): add `pause` to WARNING_CONSEQUENCES' BackgroundTaskList entry -> Pause opens
    // the warning and nothing is sent, red.
    const { handler, store, calls } = mount({ kind: 'ok', status: 200, body: { action: 'updated', target: TARGET } }, BACKGROUND);
    for (const action of ['pause', 'resume']) {
      handler.startFor(BACKGROUND, action, ID, ROW, store);
      expect(handler.pending()).toBeNull();
    }
    await settle();
    expect(calls.map((call) => JSON.parse(call.body).action)).toEqual(['pause', 'resume']);
  });
});

/**
 * Story 16.10: External language servers' Start, sent at once, and its Stop, which warns first with
 * its own consequence; the wrong verb for a server's state is refused with its published sentence.
 */
describe('External language servers\u2019 Start and Stop (Story 16.10)', () => {
  const SERVERS = 'OcuPilot.Screen.Descriptor.LanguageServerList';
  const NAME = '%Java Server';
  const ROW = { Name: NAME, Type: 'Java', Port: 53272, CurrentlyRunning: false };
  const TARGET = { type: 'language-server', scope: 'instance', id: NAME };

  it('sends Start at once, with no dialog, keyed by the server\u2019s name, and publishes the updated event', async () => {
    const { actions, handler, store, calls, events } = mount({ kind: 'ok', status: 200, body: { action: 'updated', target: TARGET } }, SERVERS);
    expect(actions.has(SERVERS, 'start')).toBe(true);
    handler.startFor(SERVERS, 'start', NAME, ROW, store);
    expect(handler.pending()).toBeNull();
    await settle();
    expect(calls).toHaveLength(1);
    expect(calls[0].path).toBe('/api/ocupilot/screens/osmgmt.languageservers/action');
    expect(JSON.parse(calls[0].body)).toEqual({ action: 'start', id: NAME });
    expect(events.map((event) => `${event.action} ${event.type} ${event.id}`)).toEqual([`updated language-server ${NAME}`]);
  });

  it('opens the warning before Stop with its consequence, sends nothing on Cancel, and sends once past Proceed', async () => {
    // Mutation (Rule 19): remove the LanguageServerList entry from WARNING_CONSEQUENCES -> Stop is
    // sent at once and the warning assertions go red.
    const { handler, store, calls } = mount({ kind: 'ok', status: 200, body: { action: 'updated', target: TARGET } }, SERVERS);
    handler.startFor(SERVERS, 'stop', NAME, { ...ROW, CurrentlyRunning: true }, store);
    const pending = handler.pending();
    expect(pending?.kind).toBe('warning');
    expect(pending?.verb).toBe(STRINGS.actionStop);
    expect(pending?.consequence).toBe(STRINGS.languageServerStopConsequence);
    handler.cancelPending();
    await settle();
    expect(calls).toHaveLength(0);
    handler.startFor(SERVERS, 'stop', NAME, { ...ROW, CurrentlyRunning: true }, store);
    handler.confirmPending();
    await settle();
    expect(calls.map((call) => JSON.parse(call.body))).toEqual([{ action: 'stop', id: NAME }]);
  });

  it('shows a state refusal\u2019s published sentence rather than the envelope\u2019s generic reason', async () => {
    // Mutation (Rule 19): drop the published problems from `refusalReason` -> the store shows the
    // generic reason and this goes red.
    for (const problem of [STRINGS.languageServerRefusalRunning, STRINGS.languageServerRefusalStopped]) {
      const refused = { kind: 'error', status: 400, code: 'TOOL.ARGUMENTS', reason: 'The tool call\'s arguments do not match what the tool accepts.', detail: { problem } } as unknown as JsonResult<unknown>;
      const { handler, store, events } = mount(refused, SERVERS);
      handler.startFor(SERVERS, 'start', NAME, ROW, store);
      await settle();
      expect(store.refusal()).toBe(problem);
      expect(events).toEqual([]);
      TestBed.resetTestingModule();
    }
    const unpublished = { kind: 'error', status: 400, code: 'TOOL.ARGUMENTS', reason: 'The generic reason.', detail: { problem: 'this instance did not report whether that server is running' } } as unknown as JsonResult<unknown>;
    const { handler, store } = mount(unpublished, SERVERS);
    handler.startFor(SERVERS, 'start', NAME, ROW, store);
    await settle();
    expect(store.refusal()).toBe('The generic reason.');
  });

  it('a start the instance refused shows the envelope\u2019s own sentence', async () => {
    const refused = { kind: 'error', status: 500, code: 'LANGUAGESERVER.START', reason: STRINGS.languageServerStartFailed, detail: null } as unknown as JsonResult<unknown>;
    const { handler, store, events } = mount(refused, SERVERS);
    handler.startFor(SERVERS, 'start', NAME, ROW, store);
    await settle();
    expect(store.refusal()).toBe(STRINGS.languageServerStartFailed);
    expect(events).toEqual([]);
  });

  // Story 16.25: Delete types the server's name under its consequence, and a running server's
  // refusal is the published sentence, not the envelope's generic reason.
  it('opens Delete\u2019s typed-name dialog with its consequence, sends nothing on Cancel, and sends the name once confirmed', async () => {
    // Mutation (Rule 19): drop the LanguageServerList entry from DESTRUCTIVE_CONSEQUENCES -> no dialog
    // opens and the typed-name assertions go red.
    const deleted = { action: 'deleted', target: TARGET };
    const { actions, handler, store, calls, events } = mount({ kind: 'ok', status: 200, body: deleted }, SERVERS);
    expect(actions.has(SERVERS, 'delete')).toBe(true);
    handler.startFor(SERVERS, 'delete', NAME, ROW, store);
    const pending = handler.pending();
    expect(pending?.kind).toBe('typed-name');
    expect(pending?.name).toBe(NAME);
    expect(pending?.consequence).toBe(STRINGS.languageServerDeleteConsequence);
    handler.cancelPending();
    await settle();
    expect(calls).toHaveLength(0);
    handler.startFor(SERVERS, 'delete', NAME, ROW, store);
    handler.confirmPending();
    await settle();
    expect(calls.map((call) => JSON.parse(call.body))).toEqual([{ action: 'delete', id: NAME }]);
    expect(events.map((event) => `${event.action} ${event.type} ${event.id}`)).toEqual([`deleted language-server ${NAME}`]);
  });

  it('shows a running server\u2019s delete refusal in its published sentence', async () => {
    // Mutation (Rule 19): drop languageServerRefusalRunningEdit from PUBLISHED_PROBLEMS -> the store
    // shows the generic reason and this goes red.
    const refused = { kind: 'error', status: 400, code: 'TOOL.ARGUMENTS', reason: 'The generic reason.', detail: { problem: STRINGS.languageServerRefusalRunningEdit } } as unknown as JsonResult<unknown>;
    const { handler, store, events } = mount(refused, SERVERS);
    handler.startFor(SERVERS, 'delete', NAME, { ...ROW, CurrentlyRunning: true }, store);
    handler.confirmPending();
    await settle();
    expect(store.refusal()).toBe(STRINGS.languageServerRefusalRunningEdit);
    expect(events).toEqual([]);
  });
});

/**
 * Story 18.14: the three mapping lists' Delete types the mapping's name -- the row key is
 * `[namespace, Name]`, whose separator no one can type -- states its kind's consequence, and sends
 * the whole row key; the Namespaces list's Copy mappings is left to that list's own page.
 */
describe('the mapping lists\u2019 Delete and the Namespaces list\u2019s Copy mappings (Story 18.14)', () => {
  const MAPPING_LISTS = [
    ['OcuPilot.Screen.Descriptor.GlobalMappingList', STRINGS.globalMappingDeleteConsequence],
    ['OcuPilot.Screen.Descriptor.RoutineMappingList', STRINGS.routineMappingDeleteConsequence],
    ['OcuPilot.Screen.Descriptor.PackageMappingList', STRINGS.packageMappingDeleteConsequence],
  ] as const;

  it('registers Delete on each list, typing the mapping\u2019s name under its kind\u2019s consequence', () => {
    // Mutation (Rule 19): drop a list's entry from `TYPED_NAME_ROWS` -> its name assertion goes red,
    // the dialog asking for the joined row key; drop its `DESTRUCTIVE_CONSEQUENCES` entry -> its
    // registration and consequence assertions go red.
    for (const [descriptor, consequence] of MAPPING_LISTS) {
      const { actions, handler, store, calls } = mount(undefined, descriptor);
      const target = 'OCUPROBE1814BA\u0001OcuProbe1814G';
      expect(actions.has(descriptor, 'delete')).toBe(true);
      handler.startFor(descriptor, 'delete', target, { namespace: 'OCUPROBE1814BA', Name: 'OcuProbe1814G' }, store);
      expect(handler.pending()?.kind).toBe('typed-name');
      expect(handler.pending()?.name).toBe('OcuProbe1814G');
      expect(handler.pending()?.target).toBe(target);
      expect(handler.pending()?.consequence).toBe(consequence);
      expect(handler.pending()?.advisory).toBe('');
      expect(calls).toHaveLength(0);
    }
  });

  it('sends a confirmed Delete with the whole row key, and publishes what the instance answered', async () => {
    const descriptor = 'OcuPilot.Screen.Descriptor.GlobalMappingList';
    const screen = SCREENS.find((entry) => entry.descriptor === descriptor)!;
    const target = 'OCUPROBE1814BA\u0001OcuProbe1814G';
    const { handler, store, calls, events } = mount(
      { kind: 'ok', status: 200, body: { action: 'deleted', target: { type: 'global-mapping', scope: 'instance', id: target } } },
      descriptor
    );
    handler.startFor(descriptor, 'delete', target, { namespace: 'OCUPROBE1814BA', Name: 'OcuProbe1814G' }, store);
    handler.confirmPending();
    await settle();
    expect(calls).toHaveLength(1);
    expect(calls[0].path).toBe(`/api/ocupilot/screens/${screen.toolIdentifier}/action`);
    expect(JSON.parse(calls[0].body)).toEqual({ action: 'delete', id: target });
    expect(events.map(({ type, id, action }) => ({ type, id, action }))).toEqual([{ type: 'global-mapping', id: target, action: 'deleted' }]);
  });

  it('leaves Copy mappings undrawn, for the Namespaces list\u2019s own page to register', () => {
    // Mutation (Rule 19): drop the Namespaces list's entry from `UNDRAWN_ACTIONS` -> this goes red,
    // and a later construction of the handler would replace the page's registration with a send
    // that carries no source.
    const { actions } = mount(undefined, NAMESPACE_LIST);
    expect(actions.has(NAMESPACE_LIST, 'delete')).toBe(true);
    expect(actions.has(NAMESPACE_LIST, COPY_MAPPINGS)).toBe(false);
  });

  it('leaves the Task schedule\u2019s Export and Import undrawn, for its own page to register', () => {
    // Mutation (Rule 19): drop the Task schedule's entry from `UNDRAWN_ACTIONS` -> this goes red, and
    // Export would be sent at once with no file.
    const { actions } = mount(undefined, TASK_SCHEDULE);
    expect(actions.has(TASK_SCHEDULE, 'delete')).toBe(true);
    expect(actions.has(TASK_SCHEDULE, TASK_EXPORT)).toBe(false);
    expect(actions.has(TASK_SCHEDULE, TASK_IMPORT)).toBe(false);
  });
});

/**
 * Story 16.4: `sendFor` with a sink of its own keeps a refusal off the list's banner, and
 * `lastRefusal` answers what the instance refused with -- its sentence, its field-level violations and
 * its detail -- until the next send, which clears it.
 */
describe('lastRefusal, the refusal a dialog draws on its own fields', () => {
  it('answers the envelope\u2019s sentence, violations and detail, and null once an action is applied', async () => {
    // Mutation (Rule 19): stop `send` setting `lastRefused` from the envelope -> the violations
    // assertion goes red.
    const refused: JsonResult<unknown> = {
      kind: 'error',
      status: 400,
      code: 'PATH.ROOT',
      reason: 'Choose an allowed directory.',
      detail: { violations: [{ field: 'root', code: 'PATH.ROOT', reason: 'Choose an allowed directory.' }], task: 'OcuP164A' },
    };
    const { handler, calls, store } = mount(refused, TASK_SCHEDULE);
    const seen: string[] = [];
    const applied = await handler.sendFor(TASK_SCHEDULE, TASK_IMPORT, TASK_IMPORT_TARGET, { root: '/r/', path: 't.xml' }, { setRefusal: (reason) => seen.push(reason) });
    expect(applied).toBe(false);
    expect(JSON.parse(calls[0].body)).toEqual({ action: 'import', id: 'import', values: { root: '/r/', path: 't.xml' } });
    expect(handler.lastRefusal()).toEqual({
      reason: 'Choose an allowed directory.',
      violations: [{ field: 'root', code: 'PATH.ROOT', reason: 'Choose an allowed directory.' }],
      detail: refused.kind === 'error' ? refused.detail : null,
    });
    expect(seen).toEqual(['', 'Choose an allowed directory.']);
    expect(store.refusal()).toBe('');
  });

  it('answers null once a later action on the same handler is applied', async () => {
    // Mutation (Rule 19): keep `lastRefused` through `send` (drop its reset at the top and answer the
    // previous value on an applied action) -> the null assertion goes red.
    const answer: Record<string, unknown> = {
      kind: 'error',
      status: 409,
      code: 'TASK.IMPORT.PRESENT',
      reason: 'Every task in this file is already on this instance.',
      detail: null,
    };
    const { handler } = mount(answer as unknown as JsonResult<unknown>, TASK_SCHEDULE);
    expect(await handler.sendFor(TASK_SCHEDULE, TASK_IMPORT, TASK_IMPORT_TARGET, { root: '/r/', path: 't.xml' })).toBe(false);
    expect(handler.lastRefusal()?.reason).toBe('Every task in this file is already on this instance.');
    for (const key of Object.keys(answer)) delete answer[key];
    Object.assign(answer, { kind: 'ok', status: 200, body: { action: 'created', target: { type: 'task', scope: 'instance', id: 'import' } } });
    expect(await handler.sendFor(TASK_SCHEDULE, TASK_IMPORT, TASK_IMPORT_TARGET, { root: '/r/', path: 't.xml' })).toBe(true);
    expect(handler.lastRefusal()).toBeNull();
  });
});

/**
 * Story 18.3 (AD-8, AD-10, AD-56 (ii)): Local databases' Delete types the name, states the removal's
 * impact read unchecked as the dialog opens, and offers "Also delete the database file" as the
 * action's declared `DeleteFile` value -- sent as a string on the same `delete`, never as a
 * swapped action.
 */
describe('the Local databases list\u2019s Delete (Story 18.3)', () => {
  const DATABASES = SCREENS.find((screen) => screen.descriptor === LOCAL_DATABASE_LIST)!;

  function mountWith(answers: readonly JsonResult<unknown>[]) {
    const mounted = mount(undefined, LOCAL_DATABASE_LIST);
    const queue = [...answers];
    const api = TestBed.inject(ApiService) as unknown as { requestJson: (path: string, init?: ApiRequestInit) => Promise<JsonResult<unknown>> };
    api.requestJson = async (path: string, init: ApiRequestInit = {}) => {
      mounted.calls.push({ path, method: init.method ?? 'GET', body: init.body ?? '' });
      return (queue.shift() ?? { kind: 'ok', status: 200, body: {} }) as JsonResult<unknown>;
    };
    return mounted;
  }

  const IMPACT = {
    kind: 'database-delete',
    refused: null,
    parts: [
      { part: 'namespaces', count: 1, names: ['OCUPROBE183NS'], unchecked: '' },
      { part: 'applications', count: 1, names: ['/csp/ocuprobe183'], unchecked: '' },
      { part: 'sharedFile', count: 0, names: [], unchecked: '' },
    ],
  };

  it('opens the typed-name dialog with the consequence, the file option and the impact read unchecked', async () => {
    // Mutation (Rule 19): drop the list from `IMPACT_ACTIONS` -> the impact read and advisory go red;
    // drop its `VALUE_FLAGS` entry -> the flag label and the `value=false` query go red.
    const { actions, handler, calls, store } = mountWith([{ kind: 'ok', status: 200, body: { impact: IMPACT } }]);
    expect(actions.has(LOCAL_DATABASE_LIST, 'delete')).toBe(true);
    handler.startFor(LOCAL_DATABASE_LIST, 'delete', 'OCUPROBE183A', { Name: 'OCUPROBE183A' }, store);
    await settle();
    expect(calls).toHaveLength(1);
    expect(calls[0].path).toBe(`/api/ocupilot/screens/${DATABASES.toolIdentifier}/impact?action=delete&id=OCUPROBE183A&value=false`);
    const pending = handler.pending();
    expect(pending?.kind).toBe('typed-name');
    expect(pending?.name).toBe('OCUPROBE183A');
    expect(pending?.consequence).toBe(STRINGS.localDatabaseDeleteConsequence);
    expect(pending?.flagLabel).toBe(STRINGS.localDatabaseDeleteFileOption);
    expect(pending?.advisory).toBe(
      'Impact: 1 namespace uses it and must stop using it first: OCUPROBE183NS; 1 web application runs in those namespaces: /csp/ocuprobe183.'
    );
  });

  it('sends DeleteFile as a string value on the same delete, checked or not, and publishes what the instance answered', async () => {
    // Mutation (Rule 19): make `confirmPending` swap the action for a checked box instead of sending
    // `DeleteFile` -> the body assertions go red.
    for (const checked of [true, false]) {
      const deleted = { action: 'deleted', target: { type: 'database-configuration', scope: 'instance', id: 'OCUPROBE183A' } };
      const { handler, calls, events, store } = mountWith([
        { kind: 'ok', status: 200, body: { impact: { ...IMPACT, parts: [] } } },
        { kind: 'ok', status: 200, body: deleted },
      ]);
      handler.startFor(LOCAL_DATABASE_LIST, 'delete', 'OCUPROBE183A', { Name: 'OCUPROBE183A' }, store);
      await settle();
      handler.confirmPending(checked);
      await settle();
      expect(calls).toHaveLength(2);
      expect(calls[1].path).toBe(`/api/ocupilot/screens/${DATABASES.toolIdentifier}/action`);
      expect(calls[1].method).toBe('POST');
      expect(JSON.parse(calls[1].body)).toEqual({ action: 'delete', id: 'OCUPROBE183A', values: { DeleteFile: checked ? 'true' : 'false' } });
      expect(events.map(({ type, id, action }) => ({ type, id, action }))).toEqual([
        { type: 'database-configuration', id: 'OCUPROBE183A', action: 'deleted' },
      ]);
    }
  });

  it('states the kernel\u2019s refusal of a protected database as the advisory, and sends nothing until confirmed', async () => {
    const reason = STRINGS.databaseRefusalOcuPilot;
    const { handler, calls, store } = mountWith([
      { kind: 'ok', status: 200, body: { impact: { kind: 'database-delete', refused: { code: 'PROHIBITED.OCUPILOTDATABASE', reason }, parts: [] } } },
    ]);
    handler.startFor(LOCAL_DATABASE_LIST, 'delete', 'IRISSYS', { Name: 'IRISSYS' }, store);
    await settle();
    expect(handler.pending()?.advisory).toBe(reason);
    handler.cancelPending();
    expect(calls.map((call) => call.method)).toEqual(['GET']);
  });

  it('keeps the Terminate flag an action swap: a declared value is the database delete\u2019s alone', async () => {
    const { handler, calls, store } = mount(undefined, 'OcuPilot.Screen.Descriptor.ProcessList');
    handler.startFor('OcuPilot.Screen.Descriptor.ProcessList', 'terminate', '4711', null, store);
    handler.confirmPending(true);
    await settle();
    expect(JSON.parse(calls[0].body)).toEqual({ action: 'terminate-with-error', id: '4711' });
  });
});

/**
 * Story 18.4 (AD-53, AD-56 (ii), AD-10): Database details' five disk operations each warn before they
 * are sent; the mount's warning carries its read-only flag and the truncate's and compact's a size,
 * each sent as the tool's one declared value; the Dismount reads the prohibited set's refusal as its
 * advisory when it opens; and every send leaves its progress for the page's status line. The Local
 * databases list's Add a volume is undrawn, and warns with its initial size when the editor starts it.
 */
describe('the disk operations (Story 18.4)', () => {
  const DETAILS = SCREENS.find((screen) => screen.descriptor === DATABASE_DETAILS)!;
  const LOCAL = SCREENS.find((screen) => screen.descriptor === LOCAL_DATABASE_LIST)!;
  const DIRECTORY = '/durable/iris/mgr/ocuprobe184a/';

  function mountWith(answers: readonly JsonResult<unknown>[], descriptor = DATABASE_DETAILS) {
    const mounted = mount(undefined, descriptor);
    const queue = [...answers];
    const api = TestBed.inject(ApiService) as unknown as { requestJson: (path: string, init?: ApiRequestInit) => Promise<JsonResult<unknown>> };
    api.requestJson = async (path: string, init: ApiRequestInit = {}) => {
      mounted.calls.push({ path, method: init.method ?? 'GET', body: init.body ?? '' });
      return (queue.shift() ?? { kind: 'ok', status: 200, body: {} }) as JsonResult<unknown>;
    };
    return mounted;
  }

  it('registers the five operations on Database details and leaves Add a volume undrawn', () => {
    // Mutation (Rule 19): drop Database details from `SCREEN_ACTION_DESCRIPTORS` -> the five go red.
    const { actions } = mount(undefined, DATABASE_DETAILS);
    for (const id of ['mount', 'dismount', 'truncate', 'compact', 'defragment']) {
      expect(DETAILS.rowActions.some((action) => action.id === id)).toBe(true);
      expect(actions.has(DATABASE_DETAILS, id)).toBe(true);
    }
    expect(LOCAL.rowActions.some((action) => action.id === EXPAND_VOLUME)).toBe(true);
    expect(actions.has(LOCAL_DATABASE_LIST, EXPAND_VOLUME)).toBe(false);
  });

  it('warns before the mount with its read-only flag, and sends ReadOnly as a string value either way', async () => {
    // Mutation (Rule 19): drop the mount's `WARNING_VALUES` entry -> the flag label and the value go red.
    for (const checked of [true, false]) {
      const { handler, calls, store } = mountWith([]);
      handler.startFor(DATABASE_DETAILS, 'mount', DIRECTORY, null, store);
      const pending = handler.pending();
      expect(pending?.kind).toBe('warning');
      expect(pending?.verb).toBe(STRINGS.databaseActionMount);
      expect(pending?.consequence).toBe(STRINGS.databaseMountConsequence);
      expect(pending?.flagLabel).toBe(STRINGS.databaseMountReadOnly);
      expect(pending?.fieldLabel).toBe('');
      expect(calls).toHaveLength(0);
      handler.confirmPending(checked);
      await settle();
      expect(calls[0].path).toBe(`/api/ocupilot/screens/${DETAILS.toolIdentifier}/action`);
      expect(JSON.parse(calls[0].body)).toEqual({ action: 'mount', id: DIRECTORY, values: { ReadOnly: checked ? 'true' : 'false' } });
    }
  });

  it('warns before the truncate and the compact with a size field, and sends the size under its declared name', async () => {
    for (const [action, value, label, hint, consequence] of [
      ['truncate', 'TargetSize', STRINGS.databaseTargetSizeLabel, STRINGS.databaseTargetSizeHint, STRINGS.databaseTruncateConsequence],
      ['compact', 'TargetFreeSpace', STRINGS.databaseTargetFreeLabel, STRINGS.databaseTargetFreeHint, STRINGS.databaseCompactConsequence],
    ] as const) {
      const { handler, calls, store } = mountWith([]);
      handler.startFor(DATABASE_DETAILS, action, DIRECTORY, null, store);
      const pending = handler.pending();
      expect(pending?.consequence).toBe(consequence);
      expect(pending?.fieldLabel).toBe(label);
      expect(pending?.fieldHint).toBe(hint);
      expect(pending?.flagLabel).toBe('');
      handler.confirmPending(false, '30');
      await settle();
      expect(JSON.parse(calls[0].body)).toEqual({ action, id: DIRECTORY, values: { [value]: '30' } });
    }
  });

  it('warns before the defragment and sends no value', async () => {
    const { handler, calls, store } = mountWith([]);
    handler.startFor(DATABASE_DETAILS, 'defragment', DIRECTORY, null, store);
    expect(handler.pending()?.consequence).toBe(STRINGS.databaseDefragmentConsequence);
    handler.confirmPending();
    await settle();
    expect(JSON.parse(calls[0].body)).toEqual({ action: 'defragment', id: DIRECTORY });
  });

  it('reads the dismount\u2019s impact as its dialog opens, and states a protected database\u2019s refusal as the advisory', async () => {
    // Mutation (Rule 19): drop Database details from `IMPACT_ACTIONS` -> the read and the advisory go red.
    const reason = STRINGS.databaseRefusalOcuPilot;
    const { handler, calls, store } = mountWith([
      { kind: 'ok', status: 200, body: { impact: { kind: 'database-dismount', refused: { code: 'PROHIBITED.OCUPILOTDATABASE', reason }, parts: [] } } },
    ]);
    handler.startFor(DATABASE_DETAILS, 'dismount', DIRECTORY, null, store);
    await settle();
    expect(calls[0].path).toBe(`/api/ocupilot/screens/${DETAILS.toolIdentifier}/impact?action=dismount&id=${encodeURIComponent(DIRECTORY)}`);
    const pending = handler.pending();
    expect(pending?.kind).toBe('warning');
    expect(pending?.consequence).toBe(STRINGS.databaseDismountConsequence);
    expect(pending?.advisory).toBe(reason);
    handler.cancelPending();
    expect(calls.map((call) => call.method)).toEqual(['GET']);

    const permitted = mountWith([{ kind: 'ok', status: 200, body: { impact: null } }]);
    permitted.handler.startFor(DATABASE_DETAILS, 'dismount', DIRECTORY, null, permitted.store);
    await settle();
    expect(permitted.handler.pending()?.advisory).toBe('');
  });

  it('leaves each send\u2019s progress: running while in flight, then finished, still running or refused', async () => {
    // Mutation (Rule 19): never set `continues` in `send()` -> the still-running leg reads finished.
    for (const [answer, state] of [
      [{ kind: 'ok', status: 200, body: {} }, 'finished'],
      [{ kind: 'ok', status: 200, body: { continues: true } }, 'continues'],
      [{ kind: 'error', status: 409, code: 'DATABASE.DISMOUNTED', reason: STRINGS.databaseGlobalsHint, detail: null }, 'refused'],
    ] as const) {
      const { handler, store } = mountWith([answer as JsonResult<unknown>]);
      expect(handler.progress()).toBeNull();
      const sent = handler.sendFor(DATABASE_DETAILS, 'defragment', DIRECTORY);
      expect(handler.progress()?.state).toBe('running');
      expect(handler.progress()?.target).toBe(DIRECTORY);
      await sent;
      expect(handler.progress()?.state).toBe(state);
      expect(handler.progress()?.actionId).toBe('defragment');
      if (state === 'refused') expect(store.refusal()).toBe(STRINGS.databaseGlobalsHint);
    }
  });

  it('warns before Add a volume with its initial size, and reports to the editor\u2019s own sink', async () => {
    const { handler, calls } = mountWith([{ kind: 'ok', status: 200, body: {} }], LOCAL_DATABASE_LIST);
    const refusals: string[] = [];
    const applied: string[] = [];
    handler.startFor(LOCAL_DATABASE_LIST, EXPAND_VOLUME, 'OCUPROBE184A', null, {
      setRefusal: (reason) => refusals.push(reason),
      applied: (action) => applied.push(action),
    });
    const pending = handler.pending();
    expect(pending?.verb).toBe(STRINGS.databaseExpandAction);
    expect(pending?.consequence).toBe(STRINGS.databaseExpandConsequence);
    expect(pending?.fieldLabel).toBe(STRINGS.databaseInitialSize);
    handler.confirmPending(false, '5');
    await settle();
    expect(JSON.parse(calls[0].body)).toEqual({ action: EXPAND_VOLUME, id: 'OCUPROBE184A', values: { InitialSize: '5' } });
    expect(applied).toEqual([EXPAND_VOLUME]);
  });
});

/**
 * Story 16.11: the Task schedule's three Task Manager actions. The handler registers none of them --
 * the page does -- and each is sent on the literal target: Suspend behind its warning dialog, whose
 * body is the published consequence, and Resume and Start at once. A refusal in the wrong state, or
 * of a task type's privilege, shows its published sentence.
 */
describe('the Task Manager\u2019s Suspend, Resume and Start (Story 16.11)', () => {
  const TARGET = { type: 'task', scope: 'instance', id: TASK_MANAGER_TARGET };

  it('leaves all three undrawn for the page to register', () => {
    // Mutation (Rule 19): drop the three from the Task schedule's `UNDRAWN_ACTIONS` entry -> the
    // handler registers them as row actions and this goes red.
    const { actions } = mount(undefined, TASK_SCHEDULE);
    for (const actionId of [TASK_MANAGER_SUSPEND, TASK_MANAGER_RESUME, TASK_MANAGER_START]) {
      expect(actions.has(TASK_SCHEDULE, actionId)).toBe(false);
    }
  });

  it('opens the warning before Suspend, titled with its label and stating its consequence; Cancel sends nothing and Proceed sends once', async () => {
    // Mutation (Rule 19): drop the Task schedule's entry from WARNING_CONSEQUENCES -> Suspend is sent
    // at once and the warning assertions go red.
    const { handler, store, calls, events } = mount({ kind: 'ok', status: 200, body: { action: 'updated', target: TARGET } }, TASK_SCHEDULE);
    handler.startFor(TASK_SCHEDULE, TASK_MANAGER_SUSPEND, TASK_MANAGER_TARGET, {}, store);
    const pending = handler.pending();
    expect(pending?.kind).toBe('warning');
    expect(pending?.verb).toBe(STRINGS.taskManagerSuspendAction);
    expect(pending?.consequence).toBe(STRINGS.taskManagerSuspendConsequence);
    handler.cancelPending();
    await settle();
    expect(calls).toHaveLength(0);

    handler.startFor(TASK_SCHEDULE, TASK_MANAGER_SUSPEND, TASK_MANAGER_TARGET, {}, store);
    handler.confirmPending();
    await settle();
    expect(calls).toHaveLength(1);
    expect(calls[0].path).toBe('/api/ocupilot/screens/tasks.schedule/action');
    expect(JSON.parse(calls[0].body)).toEqual({ action: TASK_MANAGER_SUSPEND, id: TASK_MANAGER_TARGET });
    expect(events.map((event) => `${event.type}:${event.action}:${event.id}`)).toEqual([`task:updated:${TASK_MANAGER_TARGET}`]);
  });

  it('sends Resume and Start at once, with no dialog', async () => {
    for (const actionId of [TASK_MANAGER_RESUME, TASK_MANAGER_START]) {
      const { handler, store, calls } = mount({ kind: 'ok', status: 200, body: { action: 'updated', target: TARGET } }, TASK_SCHEDULE);
      handler.startFor(TASK_SCHEDULE, actionId, TASK_MANAGER_TARGET, {}, store);
      expect(handler.pending()).toBeNull();
      await settle();
      expect(calls.map((call) => JSON.parse(call.body))).toEqual([{ action: actionId, id: TASK_MANAGER_TARGET }]);
      TestBed.resetTestingModule();
    }
  });

  it('shows each published refusal rather than the envelope\u2019s generic reason', async () => {
    // Mutation (Rule 19): drop the Task Manager sentences from `PUBLISHED_PROBLEMS` -> the store shows
    // the generic reason and this goes red.
    const published = [
      STRINGS.taskManagerRefusalRunning,
      STRINGS.taskManagerRefusalSuspended,
      STRINGS.taskManagerRefusalSuspendedStart,
      STRINGS.taskManagerRefusalStopped,
      STRINGS.taskTypePrivilegeRefusal,
    ];
    for (const problem of published) {
      const refused = { kind: 'error', status: 400, code: 'TOOL.ARGUMENTS', reason: 'The generic reason.', detail: { problem } } as unknown as JsonResult<unknown>;
      const { handler, store, events } = mount(refused, TASK_SCHEDULE);
      handler.startFor(TASK_SCHEDULE, TASK_MANAGER_RESUME, TASK_MANAGER_TARGET, {}, store);
      await settle();
      expect(store.refusal()).toBe(problem);
      expect(events).toEqual([]);
      TestBed.resetTestingModule();
    }
  });
});
