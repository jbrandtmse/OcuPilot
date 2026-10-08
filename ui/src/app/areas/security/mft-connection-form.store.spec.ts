import { TestBed } from '@angular/core/testing';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type ApiRequestInit, type JsonResult } from '../../core/api';
import { ChangeBus, type ChangeEvent } from '../../core/change-bus';
import { encodeEntityId } from '../../core/entity-id';
import { FormDirty } from '../../core/form-dirty';
import { MFT_CONNECTION_FORM_PATH, MFT_CONNECTION_PATH, MftConnectionForm } from './mft-connection-form.store';

/**
 * The managed file transfer connection editor's store (Story 18.26, AD-4, AD-14, AD-39, AD-55): the form read
 * beside the SSL/TLS list's declared read, a create sending the six fields, an edit sending the changed fields
 * alone and never the name or the service, and violations on their fields. The bus is real and only the
 * server's answers are stubbed.
 */

const PROBE = 'OcuMftProbeA';

function row(overrides: Record<string, unknown> = {}): Record<string, unknown> {
  return {
    Name: PROBE,
    Service: 'Dropbox',
    URL: 'files.ocumftprobe.invalid/',
    SSLConfiguration: 'ClientTLS',
    Username: 'probe@ocumftprobe.invalid',
    ApplicationName: 'OcuMftProbeClient',
    ...overrides,
  };
}

const EMPTY_ROW = { Name: '', Service: '', URL: '', SSLConfiguration: '', Username: '', ApplicationName: '' };

const SSL_ROWS = [
  { Name: 'ClientTLS', Description: '', Enabled: true, Type: 'Client' },
  { Name: 'ServerTLS', Description: '', Enabled: true, Type: 'Server' },
];

const ACCEPTED: JsonResult<unknown> = { kind: 'ok', status: 200, body: { id: PROBE, readBack: { verdict: 'matches', fields: [], written: [] } } };

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
      if (path.startsWith(MFT_CONNECTION_FORM_PATH)) return (options.formResult ?? { kind: 'ok', status: 200, body: { row: options.form ?? row() } }) as JsonResult<T>;
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
  return { store: TestBed.inject(MftConnectionForm), calls, events, formDirty };
}

function writes(calls: readonly Call[]): Call[] {
  return calls.filter((call) => call.method !== 'GET');
}

afterEach(() => {
  TestBed.resetTestingModule();
});

describe('the managed file transfer connection store', () => {
  it('B1, AD-5: a create opens over the form read and the SSL/TLS list\u2019s declared read, offering the client configurations only', async () => {
    const { store, calls } = mount({ form: EMPTY_ROW });
    await store.open('');
    expect(calls.map((call) => call.path).sort()).toEqual([MFT_CONNECTION_FORM_PATH, '/api/ocupilot/screens/security.ssl/read?maxRows=500']);
    expect([store.mode(), store.editable(), store.configs()]).toEqual(['create', true, ['ClientTLS']]);
    expect([store.value('Name'), store.value('Service')]).toEqual(['', 'Box']);
  });

  it('B1: an edit holds the row, and the name and service take no input', async () => {
    const { store, calls } = mount();
    await store.open(PROBE);
    expect(calls.some((call) => call.path === `${MFT_CONNECTION_FORM_PATH}?id=${encodeURIComponent(PROBE)}`)).toBe(true);
    expect([store.mode(), store.id(), store.value('Service'), store.value('Username')]).toEqual(['edit', PROBE, 'Dropbox', 'probe@ocumftprobe.invalid']);
    store.setValue('Name', 'Other');
    store.setValue('Service', 'Box');
    expect([store.value('Name'), store.value('Service')]).toEqual([PROBE, 'Dropbox']);
  });

  it('B2, AD-4: an edit sends the changed fields alone and publishes the update naming its tool', async () => {
    const { store, calls, events, formDirty } = mount();
    await store.open(PROBE);
    store.setValue('Username', 'changed@ocumftprobe.invalid');
    expect(formDirty.dirty()).toBe(true);
    expect(await store.save()).toBe(true);
    const write = writes(calls)[0];
    expect([write.method, write.path]).toEqual(['PUT', `${MFT_CONNECTION_PATH}/${encodeEntityId(PROBE)}`]);
    expect(JSON.parse(write.body)).toEqual({ Username: 'changed@ocumftprobe.invalid' });
    expect(events.map((event) => `${event.type}|${event.scope}|${event.id}|${event.action}|${event.tool}`)).toEqual([`mft-connection|instance|${PROBE}|updated|security.mftconnections.update`]);
    expect([store.saved(), formDirty.dirty()]).toEqual([true, false]);
  });

  it('B2: a create posts the six fields exactly as typed and publishes the creation', async () => {
    const { store, calls, events } = mount({ form: EMPTY_ROW });
    await store.open('');
    store.setValue('Name', PROBE);
    store.setValue('Service', 'Kiteworks');
    store.setValue('URL', 'files.ocumftprobe.invalid/');
    store.setValue('SSLConfiguration', 'ClientTLS');
    store.setValue('Username', 'probe@ocumftprobe.invalid');
    store.setValue('ApplicationName', 'OcuMftProbeClient');
    expect(await store.save()).toBe(true);
    const write = writes(calls)[0];
    expect([write.method, write.path]).toEqual(['POST', MFT_CONNECTION_PATH]);
    expect(JSON.parse(write.body)).toEqual({
      Name: PROBE,
      Service: 'Kiteworks',
      URL: 'files.ocumftprobe.invalid/',
      SSLConfiguration: 'ClientTLS',
      Username: 'probe@ocumftprobe.invalid',
      ApplicationName: 'OcuMftProbeClient',
    });
    expect(events.map((event) => `${event.id}|${event.action}|${event.tool}`)).toEqual([`${PROBE}|created|security.mftconnections.create`]);
    expect(store.createdId()).toBe(PROBE);
  });

  it('AD-39: a refused Save puts the server\u2019s violations on their fields and keeps what was entered; editing the field drops its violation', async () => {
    const refused: JsonResult<unknown> = {
      kind: 'error',
      status: 422,
      code: 'MFT.VALIDATION',
      reason: 'The connection was refused.',
      detail: { violations: [{ field: 'Name', code: 'MFT.TAKEN', reason: 'A connection with that name already exists.' }] },
    };
    const { store, events } = mount({ form: EMPTY_ROW, save: refused });
    await store.open('');
    store.setValue('Name', PROBE);
    expect(await store.save()).toBe(false);
    expect([store.violationFor('Name'), store.value('Name'), events.length, store.saved()]).toEqual(['A connection with that name already exists.', PROBE, 0, false]);
    store.setValue('Name', 'OcuMftProbeB');
    expect(store.violationFor('Name')).toBe('');
  });

  it('AD-4: an edit that changed nothing writes nothing, and a connection the instance does not hold blocks Save', async () => {
    const { store, calls } = mount();
    await store.open(PROBE);
    expect(await store.save()).toBe(true);
    expect(writes(calls)).toEqual([]);
    const absent = mount({ formResult: { kind: 'error', status: 404, code: 'PORT.NOTFOUND', reason: 'That item is no longer present on this instance', detail: null } });
    await absent.store.open(PROBE);
    expect([absent.store.absent(), absent.store.canSave()]).toEqual([true, false]);
  });

  it('B2: a privilege denial keeps its code and the pair it names', async () => {
    const denied: JsonResult<unknown> = { kind: 'error', status: 403, code: 'AUTH.NOPRIVILEGE', reason: 'denied', detail: { failedPair: '%Admin_Secure:USE' } };
    const { store } = mount({ save: denied });
    await store.open(PROBE);
    store.setValue('URL', 'other.ocumftprobe.invalid/');
    expect(await store.save()).toBe(false);
    expect([store.refusalCode(), store.refusalPair()]).toEqual(['AUTH.NOPRIVILEGE', '%Admin_Secure:USE']);
  });
});
