import { TestBed } from '@angular/core/testing';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type JsonResult } from '../../core/api';
import { ChangeBus } from '../../core/change-bus';
import { FormDirty } from '../../core/form-dirty';
import {
  ECP_DATA_SERVER_FORM_PATH,
  ECP_DATA_SERVER_NAME_PATH,
  ECP_DATA_SERVER_PATH,
  EcpDataServerForm,
  NAME_TAKEN_CODE,
  wireValue,
} from './ecp-data-server-form.store';

/**
 * The ECP data server form's store (Story 18.20) over a stub of the HTTP answers: a new server's
 * defaults, the blur look-up, the required-field rule, an absent edit, a stored mirror connection
 * kept, the server limit as the form's error and the wire shape of each field.
 */

const RULES = {
  requiredFields: ['Name', 'Address', 'Port'],
  maxLengths: { Name: 64, Address: 255 },
  rules: [{ field: 'Address', code: 'ECP.DATASERVER.ADDRESS', reason: "Enter the data server's host name or IP address." }],
  licensed: false,
};

const NEW_SERVER = { Name: '', Address: '', Port: 1972, MirrorConnection: 0, SSLConfig: false, BatchMode: false, Status: '' };

interface Sent {
  readonly path: string;
  readonly method: string;
  readonly body: unknown;
}

function mount(answer: (path: string, method: string) => JsonResult<unknown>) {
  TestBed.resetTestingModule();
  const sent: Sent[] = [];
  const api = {
    requestJson: async <T,>(path: string, init: { method?: string; body?: string } = {}): Promise<JsonResult<T>> => {
      const method = init.method ?? 'GET';
      sent.push({ path, method, body: init.body === undefined ? null : JSON.parse(init.body) });
      return answer(path, method) as JsonResult<T>;
    },
  };
  TestBed.configureTestingModule({
    providers: [
      { provide: ApiService, useValue: api as unknown as ApiService },
      { provide: FormDirty, useValue: new FormDirty() },
      { provide: ChangeBus, useValue: new ChangeBus() },
    ],
  });
  return { store: TestBed.inject(EcpDataServerForm), sent };
}

/** The form read for an edit of `name` holding `server`. */
function editRead(server: Record<string, unknown>): JsonResult<unknown> {
  return { kind: 'ok', status: 200, body: { ...RULES, server } };
}

afterEach(() => {
  TestBed.resetTestingModule();
});

describe('EcpDataServerForm', () => {
  it('a create offers the port the form read names, 1972, and every checkbox unchecked', async () => {
    const { store } = mount(() => ({ kind: 'ok', status: 200, body: { ...RULES, server: NEW_SERVER } }));
    await store.open('');
    expect(store.value('Port')).toBe('1972');
    expect(store.checked('MirrorConnection')).toBe(false);
    expect(store.checked('SSLConfig')).toBe(false);
    expect(store.checked('BatchMode')).toBe(false);
    expect(store.mirrorLocked()).toBe(false);
  });

  // Mutation (Rule 19): send `SSLConfig` as a boolean in `wireValue` -> the create body assertion goes red.
  it('a create posts the name and the five fields, the port a number, the mirror connection and SSL/TLS 0 or 1, batch mode a boolean', async () => {
    const { store, sent } = mount((path, method) =>
      method === 'POST' ? { kind: 'ok', status: 201, body: { name: 'OCUPROBEECPC' } } : { kind: 'ok', status: 200, body: { ...RULES, server: NEW_SERVER } }
    );
    await store.open('');
    store.setValue('Name', 'ocuprobeecpc');
    store.setValue('Address', '192.0.2.10');
    store.setFlag('SSLConfig', true);
    store.setFlag('BatchMode', true);
    expect(await store.save()).toBe(true);
    expect(sent.filter((entry) => entry.method === 'POST')).toEqual([
      {
        path: ECP_DATA_SERVER_PATH,
        method: 'POST',
        body: { Name: 'ocuprobeecpc', Address: '192.0.2.10', Port: 1972, MirrorConnection: 0, SSLConfig: 1, BatchMode: true },
      },
    ]);
    expect(store.createdId()).toBe('OCUPROBEECPC');
  });

  it('an edit reads the stored flags, puts only the changed fields, and writes nothing when nothing changed', async () => {
    const { store, sent } = mount((path, method) =>
      method === 'PUT'
        ? { kind: 'ok', status: 200, body: { name: 'OCUPROBEECPA' } }
        : editRead({ Name: 'OCUPROBEECPA', Address: '192.0.2.10', Port: 1972, MirrorConnection: 0, SSLConfig: false, BatchMode: true, Status: 'Not Connected' })
    );
    await store.open('OCUPROBEECPA');
    expect(store.checked('BatchMode')).toBe(true);
    expect(await store.save()).toBe(true);
    expect(sent.filter((entry) => entry.method === 'PUT')).toEqual([]);
    store.setValue('Port', '1973');
    store.setFlag('BatchMode', false);
    await store.save();
    expect(sent.filter((entry) => entry.method === 'PUT')).toEqual([
      { path: `${ECP_DATA_SERVER_PATH}/OCUPROBEECPA`, method: 'PUT', body: { Port: 1973, BatchMode: false } },
    ]);
  });

  // Mutation (Rule 19): drop the `mirrorLockedValue` guard from `setFlag` -> the mirror connection
  // changes and is sent, and this goes red.
  it('a stored mirror connection other than 0 is kept: its checkbox takes no input and is never sent', async () => {
    for (const stored of [1, -1]) {
      const { store, sent } = mount((path, method) =>
        method === 'PUT'
          ? { kind: 'ok', status: 200, body: { name: 'OCUPROBEECPM' } }
          : editRead({ Name: 'OCUPROBEECPM', Address: '192.0.2.10', Port: 1972, MirrorConnection: stored, SSLConfig: false, BatchMode: false, Status: 'Not Connected' })
      );
      await store.open('OCUPROBEECPM');
      expect(store.mirrorLocked(), String(stored)).toBe(true);
      expect(store.checked('MirrorConnection'), String(stored)).toBe(true);
      store.setFlag('MirrorConnection', false);
      expect(store.checked('MirrorConnection'), String(stored)).toBe(true);
      store.setFlag('SSLConfig', true);
      await store.save();
      expect(sent.filter((entry) => entry.method === 'PUT').map((entry) => entry.body), String(stored)).toEqual([{ SSLConfig: 1 }]);
    }
  });

  it('a stored mirror connection of 0 is offered, and sent as 1 when checked', async () => {
    const { store, sent } = mount((path, method) =>
      method === 'PUT'
        ? { kind: 'ok', status: 200, body: { name: 'OCUPROBEECPA' } }
        : editRead({ Name: 'OCUPROBEECPA', Address: '192.0.2.10', Port: 1972, MirrorConnection: 0, SSLConfig: false, BatchMode: false, Status: '' })
    );
    await store.open('OCUPROBEECPA');
    expect(store.mirrorLocked()).toBe(false);
    store.setFlag('MirrorConnection', true);
    await store.save();
    expect(sent.filter((entry) => entry.method === 'PUT').map((entry) => entry.body)).toEqual([{ MirrorConnection: 1 }]);
    // Mutation (Rule 19): drop the lock in `save`'s accepted branch -> these go red, and the box the
    // instance now refuses to turn off takes input again.
    expect(store.mirrorLocked()).toBe(true);
    store.setFlag('MirrorConnection', false);
    expect(store.checked('MirrorConnection')).toBe(true);
  });

  it('a name the instance already holds is marked taken on blur, with its own sentence', async () => {
    const { store, sent } = mount((path) =>
      path.startsWith(ECP_DATA_SERVER_NAME_PATH)
        ? { kind: 'ok', status: 200, body: { name: 'OCUPROBEECPA', taken: true, reason: 'An ECP data server of that name already exists.' } }
        : { kind: 'ok', status: 200, body: { ...RULES, server: NEW_SERVER } }
    );
    await store.open('');
    store.setValue('Name', 'ocuprobeecpa');
    await store.onBlur('Name');
    expect(sent.map((entry) => entry.path)).toContain(`${ECP_DATA_SERVER_NAME_PATH}?name=ocuprobeecpa`);
    expect(store.violations()).toEqual([{ field: 'Name', code: NAME_TAKEN_CODE, reason: 'An ECP data server of that name already exists.' }]);
  });

  it("an empty required address takes the form read's own sentence on blur", async () => {
    const { store } = mount(() => ({ kind: 'ok', status: 200, body: { ...RULES, server: NEW_SERVER } }));
    await store.open('');
    await store.onBlur('Address');
    expect(store.violationFor('Address')).toBe("Enter the data server's host name or IP address.");
  });

  it('an edit of a server the instance does not hold is absent and cannot save', async () => {
    const { store, sent } = mount(() => ({ kind: 'error', status: 404, code: 'PORT.NOTFOUND', reason: 'Not found.', detail: null }));
    await store.open('OCUPROBEECPGONE');
    expect(sent.map((entry) => entry.path)).toEqual([`${ECP_DATA_SERVER_FORM_PATH}?name=OCUPROBEECPGONE`]);
    expect(store.absent()).toBe(true);
    expect(store.canSave()).toBe(false);
  });

  it("a refusal on SSL/TLS is the field's, and the server limit, which names no field, is the form's error", async () => {
    const answers: JsonResult<unknown>[] = [
      {
        kind: 'error',
        status: 422,
        code: 'ECP.DATASERVER.SSLCLIENT',
        reason: 'Create and enable the %ECPClient SSL/TLS configuration before using SSL/TLS.',
        detail: { violations: [{ field: 'SSLConfig', code: 'ECP.DATASERVER.SSLCLIENT', reason: 'Create and enable the %ECPClient SSL/TLS configuration before using SSL/TLS.' }] },
      },
      {
        kind: 'error',
        status: 409,
        code: 'ECP.SERVER.LIMIT',
        reason: 'This instance allows at most 2 ECP data servers. Delete one, or raise the limit in ECP settings, first.',
        detail: null,
      },
    ];
    const { store } = mount((path, method) => (method === 'POST' ? answers.shift()! : { kind: 'ok', status: 200, body: { ...RULES, server: NEW_SERVER } }));
    await store.open('');
    store.setValue('Name', 'ocuprobeecpc');
    store.setValue('Address', '192.0.2.10');
    store.setFlag('SSLConfig', true);
    expect(await store.save()).toBe(false);
    expect(store.violationFor('SSLConfig')).toBe('Create and enable the %ECPClient SSL/TLS configuration before using SSL/TLS.');
    expect(store.reason()).toBe('');
    store.setFlag('SSLConfig', false);
    expect(store.violationFor('SSLConfig')).toBe('');
    expect(await store.save()).toBe(false);
    expect(store.violations()).toEqual([]);
    expect(store.reason()).toBe('This instance allows at most 2 ECP data servers. Delete one, or raise the limit in ECP settings, first.');
  });

  it('each field travels as the wire expects', () => {
    expect(wireValue('Port', ' 1972 ')).toBe(1972);
    expect(wireValue('Port', 'x')).toBe('x');
    expect(wireValue('MirrorConnection', 'true')).toBe(1);
    expect(wireValue('MirrorConnection', 'false')).toBe(0);
    expect(wireValue('SSLConfig', 'true')).toBe(1);
    expect(wireValue('BatchMode', 'true')).toBe(true);
    expect(wireValue('BatchMode', 'false')).toBe(false);
    expect(wireValue('Address', '192.0.2.10')).toBe('192.0.2.10');
  });
});
