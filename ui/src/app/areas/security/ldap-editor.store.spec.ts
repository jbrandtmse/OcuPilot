import { TestBed } from '@angular/core/testing';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type ApiRequestInit, type JsonResult } from '../../core/api';
import { ChangeBus, type ChangeEvent } from '../../core/change-bus';
import { FormDirty } from '../../core/form-dirty';
import { STRINGS } from '../../core/strings';
import {
  FLAG_ACTIVE_DIRECTORY,
  FLAG_ENABLED,
  FLAG_GROUPS,
  FLAG_KERBEROS_ONLY,
  FLAG_NESTED,
  FLAG_UNIVERSAL,
  LdapEditor,
} from './ldap-editor.store';

/**
 * The LDAP editor's store over scripted routes (Story 16.14): the form read for a create and an edit,
 * the flag couplings over `LDAPFlags`, the search password's three options, the name check, Copy
 * settings from, the examples, the Save's body and change event, a refused password write, a Save
 * of an absent configuration, and Test authentication.
 */

const PROBE = 'ocup99store.invalid';

/** A configuration as the form read answers it. */
function config(overrides: Record<string, unknown> = {}) {
  return {
    Name: PROBE,
    Description: 'probe',
    LDAPFlags: 1 + 8 + 16 + 32 + 64,
    LDAPHostNames: ['h1.invalid'],
    LDAPSearchUsername: 'CN=u,DC=ocup99store,DC=invalid',
    LDAPBaseDN: 'DC=ocup99store,DC=invalid',
    LDAPBaseDNForGroups: 'DC=ocup99store,DC=invalid',
    LDAPUniqueDNIdentifier: 'sAMAccountName',
    LDAPServerTimeout: 60,
    LDAPClientTimeout: 180,
    LDAPCACertFile: '/certs/ca.pem',
    OrganizationId: 'intersystems',
    GroupId: 'Group',
    InstanceId: 'Instance',
    RoleId: 'Role',
    EscalationRoleId: 'EscalationRole',
    NamespaceId: 'Namespace',
    RoutineId: 'Routine',
    DelimiterId: '-',
    LDAPGroupId: '',
    LDAPInstanceId: 'node_IRIS',
    LDAPAttributeNameSpace: 'intersystems-Namespace',
    LDAPAttributeComment: 'description',
    LDAPAttributes: ['cn', 'mail'],
    ...overrides,
  };
}

interface Call {
  readonly path: string;
  readonly method: string;
  readonly body: string;
}

type Route = (call: Call) => JsonResult<unknown> | undefined;

function ok(body: unknown, status = 200): JsonResult<unknown> {
  return { kind: 'ok', status, body };
}

/** The default answers: the form read, the list read, the name check, the examples, and a Save. */
function defaults(read: Record<string, unknown> | null, kerberos = true): Route {
  return (call) => {
    if (call.path.startsWith('/api/ocupilot/ldap/form?new=1')) return ok({ ldap: { ...config(), Name: '', LDAPHostNames: [], Description: '' }, kerberos });
    if (call.path.startsWith('/api/ocupilot/ldap/form?name=')) {
      return read === null ? { kind: 'error', status: 404, code: 'LDAP.ABSENT', reason: STRINGS.ldapGone, detail: null } : ok({ ldap: read, kerberos });
    }
    if (call.path.startsWith('/api/ocupilot/screens/security.ldap/read')) return ok({ rows: [{ Name: 'corp.example.com' }, { Name: PROBE }] });
    if (call.path.startsWith('/api/ocupilot/ldap/name?')) return ok({ name: 'OcuP99New', canonical: 'ocup99new.com', baseDN: 'DC=ocup99new,DC=com', taken: false });
    if (call.path.startsWith('/api/ocupilot/ldap/examples?')) return ok({ universal: 'U', group: 'G', instance: 'I' });
    if (call.method === 'POST' && call.path === '/api/ocupilot/ldap') return ok({ name: 'ocup99new.com', readBack: { verdict: 'matches', fields: [], written: [] } }, 201);
    if (call.method === 'PUT') return ok({ name: PROBE, readBack: { verdict: 'matches', fields: [], written: [] } });
    return undefined;
  };
}

function mount(route: Route) {
  TestBed.resetTestingModule();
  const calls: Call[] = [];
  const api = {
    requestJson: async <T,>(path: string, init: ApiRequestInit = {}): Promise<JsonResult<T>> => {
      const call = { path, method: init.method ?? 'GET', body: init.body ?? '' };
      calls.push(call);
      return (route(call) ?? { kind: 'error', status: 500, code: 'X', reason: 'unrouted', detail: null }) as JsonResult<T>;
    },
  };
  const formDirty = new FormDirty();
  const bus = new ChangeBus();
  const events: ChangeEvent[] = [];
  bus.subscribe((event) => events.push(event));
  TestBed.configureTestingModule({
    providers: [
      { provide: ApiService, useValue: api as unknown as ApiService },
      { provide: FormDirty, useValue: formDirty },
      { provide: ChangeBus, useValue: bus },
    ],
  });
  return { store: TestBed.inject(LdapEditor), calls, events, formDirty };
}

/** The last call's parsed body. */
function lastBody(calls: readonly Call[]): Record<string, unknown> {
  return JSON.parse(calls[calls.length - 1].body) as Record<string, unknown>;
}

afterEach(() => TestBed.resetTestingModule());

describe('the LDAP editor store (Story 16.14)', () => {
  it('AC1: an edit reads the configuration its route names, with the Kerberos answer and the CA file shown', async () => {
    const { store, calls } = mount(defaults(config()));
    await store.open(PROBE);
    expect(calls[0].path).toBe(`/api/ocupilot/ldap/form?name=${encodeURIComponent(PROBE)}`);
    expect(store.mode()).toBe('edit');
    expect(store.held()).toBe(true);
    expect(store.kerberos()).toBe(true);
    expect(store.caFile()).toBe('/certs/ca.pem');
    expect(store.hosts()).toEqual(['h1.invalid']);
    expect(store.attributes()).toEqual(['cn', 'mail']);
    expect(store.text('LDAPServerTimeout')).toBe('60');
    expect(store.changedFields()).toEqual({});
  });

  it('AC1: a create reads a new configuration\u2019s values and the list\u2019s names for Copy settings from', async () => {
    const { store, calls } = mount(defaults(config()));
    await store.open('');
    await Promise.resolve();
    await Promise.resolve();
    expect(calls[0].path).toBe('/api/ocupilot/ldap/form?new=1');
    expect(store.mode()).toBe('create');
    expect(store.name()).toBe('');
    expect(calls.some((call) => call.path.startsWith('/api/ocupilot/screens/security.ldap/read'))).toBe(true);
    expect(store.copyOptions()).toEqual(['corp.example.com', PROBE]);
  });

  it('AC1: unticking Use LDAP groups clears nested and universal groups, and the four groupless attributes take input', async () => {
    // Mutation (Rule 19): drop the 16/32 clear from `setFlag` -> the flags keep 48 and this goes red.
    const { store } = mount(defaults(config()));
    await store.open(PROBE);
    expect(store.groupsEnabled()).toBe(true);
    expect(store.attributeEnabled('LDAPAttributeRoles')).toBe(false);
    store.setFlag(FLAG_GROUPS, false);
    expect(store.flags()).toBe(FLAG_ACTIVE_DIRECTORY + FLAG_ENABLED);
    expect(store.groupsEnabled()).toBe(false);
    expect(store.attributeEnabled('LDAPAttributeRoles')).toBe(true);
    expect(store.attributeEnabled('LDAPAttributeMail')).toBe(true);
    store.setFlag(FLAG_UNIVERSAL, true);
    expect(store.flag(FLAG_UNIVERSAL)).toBe(false);
    expect(store.changedFields()).toEqual({ LDAPFlags: FLAG_ACTIVE_DIRECTORY + FLAG_ENABLED });
  });

  it('AC1: nested groups takes input only while Active Directory and groups are both ticked; unticking either clears it', async () => {
    const { store } = mount(defaults(config()));
    await store.open(PROBE);
    expect(store.nestedEnabled()).toBe(true);
    store.setFlag(FLAG_ACTIVE_DIRECTORY, false);
    expect(store.flag(FLAG_NESTED)).toBe(false);
    expect(store.flag(FLAG_UNIVERSAL)).toBe(true);
    expect(store.nestedEnabled()).toBe(false);
    store.setFlag(FLAG_NESTED, true);
    expect(store.flag(FLAG_NESTED)).toBe(false);
  });

  it('AC1: unticking LDAP configuration makes it Kerberos-only and clears LDAP enabled; ticking it clears Kerberos-only', async () => {
    const { store } = mount(defaults(config()));
    await store.open(PROBE);
    store.setLdapConfiguration(false);
    expect(store.kerberosOnly()).toBe(true);
    expect(store.flag(FLAG_ENABLED)).toBe(false);
    expect(store.changedFields()).toEqual({ LDAPFlags: 1 + 8 + 16 + 32 + FLAG_KERBEROS_ONLY });
    store.setLdapConfiguration(true);
    expect(store.kerberosOnly()).toBe(false);
    expect(store.flags()).toBe(1 + 8 + 16 + 32);
  });

  it('AC5: Leave as is sends no password, Enter sends the value, Clear sends an empty one', async () => {
    const { store } = mount(defaults(config()));
    await store.open(PROBE);
    expect(store.passwordMode()).toBe('leave');
    store.setPasswordMode('enter');
    store.setPassword('fake-probe-value');
    store.setConfirm('fake-probe-value');
    expect(store.changedFields()).toEqual({ LDAPSearchPassword: 'fake-probe-value' });
    store.setPasswordMode('clear');
    expect(store.password()).toBe('');
    expect(store.changedFields()).toEqual({ LDAPSearchPassword: '' });
    store.setPasswordMode('leave');
    expect(store.changedFields()).toEqual({});
  });

  it('AC5: two passwords that differ are refused here and nothing is sent; an accepted Save clears both', async () => {
    const { store, calls } = mount(defaults(config()));
    await store.open(PROBE);
    store.setPasswordMode('enter');
    store.setPassword('fake-probe-value');
    store.setConfirm('fake-probe-other');
    const before = calls.length;
    expect(await store.save()).toBe(false);
    expect(calls.length).toBe(before);
    expect(store.violationFor('LDAPSearchPassword')).toBe(STRINGS.ldapPasswordMismatch);
    store.setConfirm('fake-probe-value');
    expect(await store.save()).toBe(true);
    expect(lastBody(calls)).toEqual({ LDAPSearchPassword: 'fake-probe-value' });
    expect(store.password()).toBe('');
    expect(store.confirm()).toBe('');
    expect(store.passwordMode()).toBe('leave');
  });

  it('Integration: an edit puts the changed fields, the flags and a list whole, shows Saved and publishes updated with its read-back', async () => {
    // Mutation (Rule 19): skip `publish` in `save` -> no event and this goes red.
    const { store, calls, events, formDirty } = mount(defaults(config()));
    await store.open(PROBE);
    store.setText('Description', 'changed');
    store.setFlag(2, true);
    expect(store.addEntry('LDAPHostNames', ' h2.invalid ')).toBe(true);
    expect(store.addEntry('LDAPHostNames', 'h2.invalid')).toBe(false);
    store.setText('LDAPClientTimeout', '200');
    expect(formDirty.dirty()).toBe(true);
    expect(store.canTest()).toBe(false);
    expect(await store.save()).toBe(true);
    const put = calls[calls.length - 1];
    expect(put.method).toBe('PUT');
    expect(put.path).toBe('/api/ocupilot/ldap/ocup99store%252Einvalid');
    expect(JSON.parse(put.body)).toEqual({ Description: 'changed', LDAPClientTimeout: 200, LDAPFlags: 1 + 2 + 8 + 16 + 32 + 64, LDAPHostNames: ['h1.invalid', 'h2.invalid'] });
    expect(store.saved()).toBe(true);
    expect(formDirty.dirty()).toBe(false);
    expect(events).toHaveLength(1);
    expect(events[0]).toMatchObject({
      kind: 'changed',
      type: 'ldap-configuration',
      scope: 'instance',
      id: PROBE,
      action: 'updated',
      readBack: { verdict: 'matches', fields: [], written: [], reason: '' },
    });
  });

  it('Save step 4: a Save whose password write was refused lands, publishes updated, and holds the instance\u2019s sentence', async () => {
    const reason = 'The instance refused the search password.';
    const base = defaults(config());
    const { store, events } = mount((call) =>
      call.method === 'PUT' ? ok({ name: PROBE, secretsRefused: reason, readBack: { verdict: 'matches', fields: [], written: [] } }) : base(call)
    );
    await store.open(PROBE);
    store.setText('Description', 'changed');
    store.setPasswordMode('enter');
    store.setPassword('fake-probe-value');
    store.setConfirm('fake-probe-value');
    expect(await store.save()).toBe(true);
    expect(store.secretsRefused()).toBe(reason);
    expect(store.saved()).toBe(true);
    expect(store.password()).toBe('');
    expect(events.map((event) => (event.kind === 'changed' ? event.action : ''))).toEqual(['updated']);
  });

  it('Matrix "Absent": a Save answered 404 turns the editor absent and publishes nothing', async () => {
    const base = defaults(config());
    const gone: JsonResult<unknown> = { kind: 'error', status: 404, code: 'LDAP.ABSENT', reason: STRINGS.ldapGone, detail: null };
    const { store, events } = mount((call) => (call.method === 'PUT' ? gone : base(call)));
    await store.open(PROBE);
    store.setText('Description', 'changed');
    expect(await store.save()).toBe(false);
    expect(store.absent()).toBe(true);
    expect(store.canSave()).toBe(false);
    expect(events).toEqual([]);
  });

  it('AC6: a create posts the name and every setting, and publishes created under the name the instance stores', async () => {
    const { store, calls, events } = mount(defaults(config()));
    await store.open('');
    store.setName('ocup99new.com');
    store.addEntry('LDAPHostNames', 'h1.invalid');
    store.setPasswordMode('enter');
    store.setPassword('fake-probe-value');
    store.setConfirm('fake-probe-value');
    expect(await store.save()).toBe(true);
    const post = calls[calls.length - 1];
    expect(post.method).toBe('POST');
    expect(post.path).toBe('/api/ocupilot/ldap');
    const body = JSON.parse(post.body) as Record<string, unknown>;
    expect(body['Name']).toBe('ocup99new.com');
    expect(body['LDAPHostNames']).toEqual(['h1.invalid']);
    expect(body['LDAPFlags']).toBe(1 + 8 + 16 + 32 + 64);
    expect(body['LDAPServerTimeout']).toBe(60);
    expect(body['LDAPSearchPassword']).toBe('fake-probe-value');
    expect(body['LDAPCACertFile']).toBeUndefined();
    expect(store.createdId()).toBe('ocup99new.com');
    expect(events.map((event) => (event.kind === 'changed' ? [event.id, event.action] : []))).toEqual([['ocup99new.com', 'created']]);
    expect(store.password()).toBe('');
  });

  it('AC6: on blur the name takes the form the instance stores, and only the empty base DNs fill', async () => {
    const { store, calls } = mount(defaults(config()));
    await store.open('');
    store.setText('LDAPBaseDNForGroups', 'DC=kept');
    store.setText('LDAPBaseDN', '');
    store.setName('OcuP99New');
    await store.checkName();
    expect(calls[calls.length - 1].path).toBe('/api/ocupilot/ldap/name?name=OcuP99New');
    expect(store.name()).toBe('ocup99new.com');
    expect(store.text('LDAPBaseDN')).toBe('DC=ocup99new,DC=com');
    expect(store.text('LDAPBaseDNForGroups')).toBe('DC=kept');
  });

  it('AC6: a name the instance refuses is marked on the field with its sentence', async () => {
    const refusal: JsonResult<unknown> = {
      kind: 'error',
      status: 422,
      code: 'LDAP.VALIDATION',
      reason: 'x',
      detail: { violations: [{ field: 'Name', code: 'LDAP.NAME.FORM', reason: 'Use the full name the instance stores, such as example.com.' }] },
    };
    const base = defaults(config());
    const { store } = mount((call) => (call.path.startsWith('/api/ocupilot/ldap/name?') ? refusal : base(call)));
    await store.open('');
    store.setName('.com');
    await store.checkName();
    expect(store.violationFor('Name')).toBe('Use the full name the instance stores, such as example.com.');
  });

  it('Copy settings from copies every setting but the name, the description and the base DNs, and asks for a new password', async () => {
    const { store } = mount(defaults(config({ Description: 'source', LDAPFlags: 2 + 64, LDAPBaseDN: 'DC=source', LDAPBaseDNForGroups: 'DC=sourcegroups' })));
    await store.open('');
    store.setName('ocup99new.com');
    store.setText('Description', 'mine');
    store.setText('LDAPBaseDN', 'DC=mine');
    await store.copyFrom(PROBE);
    expect(store.copiedFrom()).toBe(PROBE);
    expect(store.name()).toBe('ocup99new.com');
    expect(store.text('Description')).toBe('mine');
    expect(store.text('LDAPBaseDN')).toBe('DC=mine');
    expect(store.text('LDAPBaseDNForGroups')).toBe('DC=ocup99store,DC=invalid');
    expect(store.flags()).toBe(2 + 64);
    expect(store.hosts()).toEqual(['h1.invalid']);
    expect(store.text('LDAPSearchUsername')).toBe('CN=u,DC=ocup99store,DC=invalid');
    expect(store.passwordMode()).toBe('enter');
  });

  it('the examples are read again from the instance with the group inputs the form holds', async () => {
    const { store, calls } = mount(defaults(config()));
    await store.open(PROBE);
    store.setText('GroupId', 'Grp');
    await store.readExamples();
    const read = calls.filter((call) => call.path.startsWith('/api/ocupilot/ldap/examples?')).at(-1);
    const query = new URLSearchParams(read?.path.split('?')[1] ?? '');
    expect(query.get('GroupId')).toBe('Grp');
    expect(query.get('OrganizationId')).toBe('intersystems');
    expect(query.get('UniversalGroup')).toBe('1');
    expect(query.get('LDAPInstanceId')).toBe('node_IRIS');
    expect(store.examples()).toEqual({ universal: 'U', group: 'G', instance: 'I' });
  });

  it('AC3: Test authentication posts the user and password to the saved configuration and shows the instance\u2019s lines', async () => {
    const base = defaults(config());
    const { store, calls } = mount((call) => (call.path.endsWith('/test') ? ok({ lines: ['Can\u2019t contact LDAP server', 'Test completed'] }) : base(call)));
    await store.open(PROBE);
    expect(store.canTest()).toBe(true);
    await store.test('u', 'fake-probe-value');
    const posted = calls[calls.length - 1];
    expect(posted.path).toBe('/api/ocupilot/ldap/ocup99store%252Einvalid/test');
    expect(JSON.parse(posted.body)).toEqual({ Username: 'u', Password: 'fake-probe-value' });
    expect(store.testLines()).toEqual(['Can\u2019t contact LDAP server', 'Test completed']);
    store.clearTest();
    expect(store.testLines()).toBeNull();
  });

  it('a test the gateway ended reads as no answer, and a refused field lands on it', async () => {
    const base = defaults(config());
    let answer: JsonResult<unknown> = { kind: 'error', status: 504, code: null, reason: null, detail: null };
    const { store } = mount((call) => (call.path.endsWith('/test') ? answer : base(call)));
    await store.open(PROBE);
    await store.test('u', 'x');
    expect(store.testNoAnswer()).toBe(true);
    expect(store.testLines()).toBeNull();
    answer = {
      kind: 'error',
      status: 422,
      code: 'LDAP.VALIDATION',
      reason: 'x',
      detail: { violations: [{ field: 'Username', code: 'LDAP.TEST.USERNAME', reason: 'Enter the user name without a domain; the test uses this configuration.' }] },
    };
    await store.test('u@x.com', 'x');
    expect(store.testNoAnswer()).toBe(false);
    expect(store.testViolationFor('Username')).toBe('Enter the user name without a domain; the test uses this configuration.');
  });

  it('AC6: a Save made while the name check is in flight waits for it and sends the stored form', async () => {
    const base = defaults(config());
    let release: () => void = () => undefined;
    const held = (call: Call) =>
      new Promise<JsonResult<unknown>>((resolve) => {
        release = () => resolve(base(call) as JsonResult<unknown>);
      }) as unknown as JsonResult<unknown>;
    const { store, calls } = mount((call) => (call.path.startsWith('/api/ocupilot/ldap/name?') ? held(call) : base(call)));
    await store.open('');
    store.setText('LDAPBaseDN', '');
    store.setText('LDAPBaseDNForGroups', '');
    store.addEntry('LDAPHostNames', 'h1.invalid');
    store.setName('OcuP99New');
    void store.checkName();
    const saving = store.save();
    release();
    expect(await saving).toBe(true);
    const body = JSON.parse(calls.filter((call) => call.method === 'POST').at(-1)?.body ?? '{}') as Record<string, unknown>;
    expect(body['Name']).toBe('ocup99new.com');
    expect(body['LDAPBaseDN']).toBe('DC=ocup99new,DC=com');
    expect(body['LDAPBaseDNForGroups']).toBe('DC=ocup99new,DC=com');
  });

  it('AC3: a test answered after its dialog closed is dropped, and the next test may run', async () => {
    const base = defaults(config());
    let release: (result: JsonResult<unknown>) => void = () => undefined;
    const held = () =>
      new Promise<JsonResult<unknown>>((resolve) => {
        release = resolve;
      }) as unknown as JsonResult<unknown>;
    const { store } = mount((call) => (call.path.endsWith('/test') ? held() : base(call)));
    await store.open(PROBE);
    const running = store.test('u', 'fake-probe-value');
    expect(store.testing()).toBe(true);
    store.clearTest();
    expect(store.testing()).toBe(false);
    release(ok({ lines: ['Test completed'] }));
    await running;
    expect(store.testLines()).toBeNull();
  });

  it('AD-14: an outside change re-read by a clean editor reads the examples again', async () => {
    const { store, calls } = mount(defaults(config()));
    await store.open(PROBE);
    const before = calls.filter((call) => call.path.startsWith('/api/ocupilot/ldap/examples?')).length;
    await store.refresh();
    expect(calls.filter((call) => call.path.startsWith('/api/ocupilot/ldap/examples?'))).toHaveLength(before + 1);
  });

  it('an absent configuration blocks Save and Test; reset forgets everything, the passwords first', async () => {
    const { store } = mount(defaults(null));
    await store.open('nope.com');
    expect(store.absent()).toBe(true);
    expect(store.canSave()).toBe(false);
    expect(store.canTest()).toBe(false);
    const held = mount(defaults(config()));
    await held.store.open(PROBE);
    held.store.setPasswordMode('enter');
    held.store.setPassword('fake-probe-value');
    held.store.retainAcrossRouteReplacement();
    expect(held.store.password()).toBe('');
    held.store.setPasswordMode('enter');
    held.store.setPassword('fake-probe-value');
    held.store.reset();
    expect(held.store.password()).toBe('');
    expect(held.store.held()).toBe(false);
  });
});
