import { TestBed } from '@angular/core/testing';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type ApiRequestInit, type JsonResult } from '../../core/api';
import { ChangeBus, type ChangeEvent } from '../../core/change-bus';
import { encodeEntityId, joinCompositeId } from '../../core/entity-id';
import { FormDirty } from '../../core/form-dirty';
import { STRINGS } from '../../core/strings';
import { SUPERSERVER_FORM_PATH, SUPERSERVER_PATH, SuperserverForm } from './superserver-form.store';

/**
 * The superserver editor's store (Story 18.25, AD-4, AD-14, AD-39, AD-55): the form read beside the SSL/TLS
 * list's declared read, a create sending the id parts and the fifteen settings, an edit sending the changed
 * settings alone, the fields the server locks and the ones what the superserver is leaves unavailable, the
 * SSL/TLS consequence of a serving superserver, and violations on their fields. The bus is real and only the
 * server's answers are stubbed.
 */

const PROBE_ID = joinCompositeId(['21825', '0.0.0.0']);

const SYSTEM_ID = joinCompositeId(['1972', '0.0.0.0']);

const SERVING_SENTENCE = 'The server\u2019s own serving sentence.';

function row(overrides: Record<string, unknown> = {}): Record<string, unknown> {
  return {
    Port: 21825,
    BindAddress: '0.0.0.0',
    Description: 'a probe',
    Enabled: true,
    EnableCacheDirect: false,
    EnableClients: true,
    EnableCSP: true,
    EnableDataCheck: false,
    EnableECP: false,
    EnableMirror: false,
    EnableNodeJS: false,
    EnableShadows: false,
    EnableSharding: false,
    EnableSNMP: false,
    EnableWebLink: false,
    SSLConfig: '',
    SSLSupportLevel: 0,
    SystemDefault: false,
    ...overrides,
  };
}

function form(overrides: Record<string, unknown> = {}, locked: unknown[] = [], serving = false, windows = false): Record<string, unknown> {
  return { row: row(overrides), serving, locked, windows };
}

const SSL_ROWS = [
  { Name: 'ClientTLS', Description: '', Enabled: true, Type: 'Client' },
  { Name: 'ServerTLS', Description: '', Enabled: true, Type: 'Server' },
];

const ACCEPTED: JsonResult<unknown> = { kind: 'ok', status: 200, body: { id: PROBE_ID, readBack: { verdict: 'matches', fields: [], written: [] } } };

interface Call {
  readonly path: string;
  readonly method: string;
  readonly body: string;
}

function mount(options: { form?: Record<string, unknown>; formResult?: JsonResult<unknown>; save?: JsonResult<unknown> } = {}) {
  TestBed.resetTestingModule();
  const calls: Call[] = [];
  const api = {
    requestJson: async <T,>(path: string, init: ApiRequestInit = {}): Promise<JsonResult<T>> => {
      const method = init.method ?? 'GET';
      calls.push({ path, method, body: init.body ?? '' });
      if (path.includes('/read?')) return { kind: 'ok', status: 200, body: { rows: SSL_ROWS, truncated: false, banner: '' } } as unknown as JsonResult<T>;
      if (path.startsWith(SUPERSERVER_FORM_PATH)) return (options.formResult ?? { kind: 'ok', status: 200, body: options.form ?? form() }) as JsonResult<T>;
      return (options.save ?? ACCEPTED) as JsonResult<T>;
    },
  };
  const bus = new ChangeBus();
  const events: ChangeEvent[] = [];
  bus.subscribe((event) => events.push(event));
  const formDirty = new FormDirty();
  TestBed.configureTestingModule({
    providers: [
      { provide: ApiService, useValue: api as unknown as ApiService },
      { provide: ChangeBus, useValue: bus },
      { provide: FormDirty, useValue: formDirty },
    ],
  });
  return { store: TestBed.inject(SuperserverForm), calls, events, formDirty };
}

function writes(calls: readonly Call[]): Call[] {
  return calls.filter((call) => call.method !== 'GET');
}

afterEach(() => {
  TestBed.resetTestingModule();
});

describe('the superserver store', () => {
  it('B1, AD-5: a create opens over the form read and the SSL/TLS list\u2019s declared read, offering the server configurations only', async () => {
    const { store, calls } = mount({ form: form({ Port: '', BindAddress: '', Description: '', EnableCSP: false, SSLSupportLevel: 0, SystemDefault: false }) });
    await store.open('');
    expect(calls.map((call) => call.path).sort()).toEqual(['/api/ocupilot/screens/security.ssl/read?maxRows=500', SUPERSERVER_FORM_PATH]);
    expect([store.mode(), store.editable(), store.configs()]).toEqual(['create', true, ['ServerTLS']]);
    expect([store.checked('Enabled'), store.checked('EnableClients'), store.checked('EnableCSP'), store.value('SSLSupportLevel'), store.value('Port')]).toEqual([true, true, false, '0', '']);
  });

  it('B1: an edit holds the row, the lock, the serving mark and the platform, and the id parts take no input', async () => {
    const locked = [{ field: 'Enabled', code: 'PROHIBITED.SERVINGSUPERSERVER', reason: SERVING_SENTENCE }, { field: 'EnableCSP', code: 'PROHIBITED.SERVINGSUPERSERVER', reason: SERVING_SENTENCE }];
    const { store, calls } = mount({ form: form({ Port: 1972, SystemDefault: true, EnableECP: true }, locked, true, false) });
    await store.open(SYSTEM_ID);
    expect(calls.some((call) => call.path === `${SUPERSERVER_FORM_PATH}?id=${encodeURIComponent(SYSTEM_ID)}`)).toBe(true);
    expect([store.mode(), store.serving(), store.systemDefault(), store.windows(), store.id()]).toEqual(['edit', true, true, false, SYSTEM_ID]);
    expect([store.lockReason('Enabled'), store.lockReason('EnableCSP'), store.lockReason('EnableClients')]).toEqual([SERVING_SENTENCE, SERVING_SENTENCE, '']);
    store.setValue('Port', '99');
    store.setValue('BindAddress', 'x');
    expect([store.value('Port'), store.value('BindAddress')]).toEqual(['1972', '0.0.0.0']);
  });

  it('B2, AD-4: an edit sends the changed settings alone, the level as a number, and publishes the update naming its tool', async () => {
    const { store, calls, events, formDirty } = mount();
    await store.open(PROBE_ID);
    store.setValue('Description', 'changed');
    store.setFlag('EnableDataCheck', true);
    store.setValue('SSLConfig', 'ServerTLS');
    store.setValue('SSLSupportLevel', '1');
    expect(formDirty.dirty()).toBe(true);
    expect(await store.save()).toBe(true);
    const write = writes(calls)[0];
    expect([write.method, write.path]).toEqual(['PUT', `${SUPERSERVER_PATH}/${encodeEntityId(PROBE_ID)}`]);
    expect(JSON.parse(write.body)).toEqual({ Description: 'changed', EnableDataCheck: true, SSLConfig: 'ServerTLS', SSLSupportLevel: 1 });
    expect(events.map((event) => `${event.type}|${event.scope}|${event.id}|${event.action}|${event.tool}`)).toEqual([`superserver|instance|${PROBE_ID}|updated|security.superservers.update`]);
    expect([store.saved(), formDirty.dirty()]).toEqual([true, false]);
  });

  it('B4: the consequence a Save answers is held for the form, and the next edit drops it', async () => {
    const accepted: JsonResult<unknown> = { kind: 'ok', status: 200, body: { id: PROBE_ID, consequence: 'SUPERSERVER.SERVESOCUPILOT', readBack: { verdict: 'matches', fields: [], written: [] } } };
    const { store } = mount({ save: accepted });
    await store.open(PROBE_ID);
    store.setValue('SSLSupportLevel', '1');
    expect(await store.save()).toBe(true);
    expect(store.consequence()).toBe('SUPERSERVER.SERVESOCUPILOT');
    store.setValue('Description', 'again');
    expect(store.consequence()).toBe('');
  });

  it('B2: a create posts the port, the bind address and the fifteen settings, typed, and publishes the creation', async () => {
    const { store, calls, events } = mount({ form: form({ Port: '', BindAddress: '', Description: '', EnableCSP: false }) });
    await store.open('');
    store.setValue('Port', ' 21825 ');
    store.setFlag('EnableCSP', true);
    expect(await store.save()).toBe(true);
    const write = writes(calls)[0];
    expect([write.method, write.path]).toEqual(['POST', SUPERSERVER_PATH]);
    const body = JSON.parse(write.body) as Record<string, unknown>;
    expect(Object.keys(body).sort()).toEqual(['BindAddress', 'Description', 'EnableCSP', 'EnableCacheDirect', 'EnableClients', 'EnableDataCheck', 'EnableECP', 'EnableMirror', 'EnableNodeJS', 'EnableSNMP', 'EnableShadows', 'EnableSharding', 'EnableWebLink', 'Enabled', 'Port', 'SSLConfig', 'SSLSupportLevel']);
    expect([body['Port'], body['BindAddress'], body['EnableCSP'], body['Enabled'], body['SSLSupportLevel']]).toEqual(['21825', '', true, true, 0]);
    expect(Object.keys(body)).not.toContain('SystemDefault');
    expect(events.map((event) => `${event.id}|${event.action}|${event.tool}`)).toEqual([`${PROBE_ID}|created|security.superservers.create`]);
    expect(store.createdId()).toBe(PROBE_ID);
  });

  it('B4: a locked flag and a flag the superserver cannot take take no input, and ECP, mirroring, sharding and SNMP are unavailable off the system default and off Windows', async () => {
    const locked = [{ field: 'Enabled', code: 'PROHIBITED.SERVINGSUPERSERVER', reason: SERVING_SENTENCE }];
    const { store } = mount({ form: form({}, locked, true, false) });
    await store.open(PROBE_ID);
    store.setFlag('Enabled', false);
    store.setFlag('EnableECP', true);
    store.setFlag('EnableMirror', true);
    store.setFlag('EnableSharding', true);
    store.setFlag('EnableSNMP', true);
    expect([store.checked('Enabled'), store.checked('EnableECP'), store.checked('EnableMirror'), store.checked('EnableSharding'), store.checked('EnableSNMP')]).toEqual([true, false, false, false, false]);
    expect(['EnableECP', 'EnableMirror', 'EnableSharding', 'EnableSNMP', 'EnableCSP'].map((field) => store.unavailable(field))).toEqual([true, true, true, true, false]);
    store.setFlag('EnableCSP', false);
    expect(store.checked('EnableCSP')).toBe(false);
  });

  it('B4: the system default takes ECP, mirroring and sharding, and Windows takes SNMP', async () => {
    const { store } = mount({ form: form({ SystemDefault: true }, [], false, true) });
    await store.open(SYSTEM_ID);
    store.setFlag('EnableECP', false);
    store.setFlag('EnableSNMP', true);
    expect([store.unavailable('EnableECP'), store.unavailable('EnableSNMP'), store.checked('EnableECP'), store.checked('EnableSNMP')]).toEqual([false, false, false, true]);
  });

  it('B4: a changed SSL/TLS field of a serving superserver states its consequence before Save, and an unchanged one does not', async () => {
    const { store } = mount({ form: form({}, [], true, false) });
    await store.open(PROBE_ID);
    expect(store.sslCaption()).toBe('');
    store.setValue('SSLSupportLevel', '1');
    expect(store.sslCaption()).toBe(STRINGS.superserverServesConsequence);
    store.setValue('SSLSupportLevel', '0');
    expect(store.sslCaption()).toBe('');
    const { store: other } = mount({ form: form({}, [], false, false) });
    await other.open(PROBE_ID);
    other.setValue('SSLConfig', 'ServerTLS');
    expect(other.sslCaption()).toBe('');
  });

  it('AD-39: a refused Save puts the server\u2019s violations on their fields and keeps what was entered; editing the field drops its violation', async () => {
    const refused: JsonResult<unknown> = {
      kind: 'error',
      status: 422,
      code: 'SUPERSERVER.VALIDATION',
      reason: 'The superserver was refused.',
      detail: { violations: [{ field: 'Port', code: 'SUPERSERVER.PORT', reason: 'The port is a whole number from 100 to 65535.' }] },
    };
    const { store, events } = mount({ form: form({ Port: '', BindAddress: '' }), save: refused });
    await store.open('');
    store.setValue('Port', '99');
    expect(await store.save()).toBe(false);
    expect([store.violationFor('Port'), store.value('Port'), events.length, store.saved()]).toEqual(['The port is a whole number from 100 to 65535.', '99', 0, false]);
    store.setValue('Port', '100');
    expect(store.violationFor('Port')).toBe('');
  });

  it('AD-4: an edit that changed nothing writes nothing, and a superserver the instance does not hold blocks Save', async () => {
    const { store, calls } = mount();
    await store.open(PROBE_ID);
    expect(await store.save()).toBe(true);
    expect(writes(calls)).toEqual([]);
    const absent = mount({ formResult: { kind: 'error', status: 404, code: 'PORT.NOTFOUND', reason: 'That item is no longer present on this instance', detail: null } });
    await absent.store.open(PROBE_ID);
    expect([absent.store.absent(), absent.store.canSave()]).toEqual([true, false]);
  });

  it('B2: a privilege denial keeps its code and the pair it names, and a fault the instance gives is the form\u2019s reason', async () => {
    const denied: JsonResult<unknown> = { kind: 'error', status: 403, code: 'AUTH.NOPRIVILEGE', reason: 'denied', detail: { failedPair: '%Admin_Secure:USE' } };
    const { store } = mount({ save: denied });
    await store.open(PROBE_ID);
    store.setValue('Description', 'x');
    expect(await store.save()).toBe(false);
    expect([store.refusalCode(), store.refusalPair()]).toEqual(['AUTH.NOPRIVILEGE', '%Admin_Secure:USE']);
  });
});
