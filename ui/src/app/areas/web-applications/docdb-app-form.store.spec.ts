import { TestBed } from '@angular/core/testing';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type ApiRequestInit, type JsonResult } from '../../core/api';
import { ChangeBus, type ChangeEvent } from '../../core/change-bus';
import { encodeEntityId, joinCompositeId } from '../../core/entity-id';
import { FormDirty } from '../../core/form-dirty';
import { DOCDB_APP_FORM_PATH, DOCDB_APP_PATH, DocDbAppForm } from './docdb-app-form.store';

/**
 * The Doc DB application editor's store (Story 18.30, AD-4, AD-14, AD-39, AD-55): the form read beside the Resources
 * list's declared read, a create sending the five fields, an edit sending the changed fields alone and never the
 * namespace or the name, and violations on their fields. The bus is real and only the server's answers are stubbed.
 */

const ID = joinCompositeId(['USER', 'OcuProbe1830A']);

function row(overrides: Record<string, unknown> = {}): Record<string, unknown> {
  return { Name: 'OcuProbe1830A', Namespace: 'USER', Description: 'probe', Enabled: true, Resource: 'OcuProbe1830Res', ...overrides };
}

const EMPTY_ROW = { Name: '', Namespace: '', Description: '', Enabled: true, Resource: '' };

const RESOURCE_ROWS = [
  { Name: 'OcuProbe1830Res', Description: '', PublicPermission: '', ResourceType: 'Application', AllowDelete: true },
  { Name: '%Service_DocDB', Description: '', PublicPermission: '', ResourceType: 'Service', AllowDelete: false },
  { Name: '%DocDB_Admin', Description: '', PublicPermission: '', ResourceType: 'System', AllowDelete: false },
  { Name: '%DB_USER', Description: '', PublicPermission: '', ResourceType: 'Database', AllowDelete: false },
];

const ACCEPTED: JsonResult<unknown> = { kind: 'ok', status: 200, body: { id: ID, readBack: { verdict: 'matches', fields: [], written: [] } } };

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
      if (path.includes('/read?')) return { kind: 'ok', status: 200, body: { rows: RESOURCE_ROWS, truncated: false, banner: '' } } as unknown as JsonResult<T>;
      if (path.startsWith(DOCDB_APP_FORM_PATH)) return (options.formResult ?? { kind: 'ok', status: 200, body: { row: options.form ?? row() } }) as JsonResult<T>;
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
  return { store: TestBed.inject(DocDbAppForm), calls, events, formDirty };
}

function writes(calls: readonly Call[]): Call[] {
  return calls.filter((call) => call.method !== 'GET');
}

afterEach(() => {
  TestBed.resetTestingModule();
});

describe('the Doc DB application store', () => {
  it('B1, AD-5: a create opens over the form read and the Resources list\u2019s declared read, offering the service, system and application resources the classic page offers, in the namespace the person works in', async () => {
    const { store, calls } = mount({ form: EMPTY_ROW });
    await store.open('', 'HSCUSTOM');
    expect(calls.map((call) => call.path).sort()).toEqual([DOCDB_APP_FORM_PATH, '/api/ocupilot/screens/permissions.resources/read?maxRows=500']);
    // Mutation (Rule 19): drop 'System' from the store's `RESOURCE_TYPES` -> `%DocDB_Admin` leaves the picker and this
    // goes red.
    expect([store.mode(), store.editable(), store.resources()]).toEqual(['create', true, ['OcuProbe1830Res', '%Service_DocDB', '%DocDB_Admin']]);
    expect([store.value('Namespace'), store.value('Name'), store.enabled()]).toEqual(['HSCUSTOM', '', true]);
    expect(store.dirty()).toBe(false);
  });

  it('B1: an edit holds the row, and the namespace and name take no input', async () => {
    const { store, calls } = mount();
    await store.open(ID);
    expect(calls.some((call) => call.path === `${DOCDB_APP_FORM_PATH}?id=${encodeURIComponent(ID)}`)).toBe(true);
    expect([store.mode(), store.id(), store.value('Description'), store.value('Resource'), store.enabled()]).toEqual(['edit', ID, 'probe', 'OcuProbe1830Res', true]);
    store.setValue('Namespace', 'HSCUSTOM');
    store.setValue('Name', 'Other');
    expect([store.value('Namespace'), store.value('Name')]).toEqual(['USER', 'OcuProbe1830A']);
  });

  it('B2, AD-4: an edit sends the changed fields alone, the flag as a boolean, and publishes the update naming its tool', async () => {
    const { store, calls, events, formDirty } = mount();
    await store.open(ID);
    store.setValue('Description', 'changed');
    store.setEnabled(false);
    expect(formDirty.dirty()).toBe(true);
    expect(await store.save()).toBe(true);
    const write = writes(calls)[0];
    expect([write.method, write.path]).toEqual(['PUT', `${DOCDB_APP_PATH}/${encodeEntityId(ID)}`]);
    expect(JSON.parse(write.body)).toEqual({ Description: 'changed', Enabled: false });
    expect(events.map((event) => `${event.type}|${event.scope}|${event.id}|${event.action}|${event.tool}`)).toEqual([`docdb-application|instance|${ID}|updated|webapp.docdbapps.update`]);
    expect([store.saved(), formDirty.dirty()]).toEqual([true, false]);
  });

  it('B2: a create posts the five fields exactly as typed and publishes the creation under the id the instance answered', async () => {
    const { store, calls, events } = mount({ form: EMPTY_ROW });
    await store.open('', 'user');
    store.setValue('Name', 'OcuProbe1830A');
    store.setValue('Description', 'probe');
    store.setValue('Resource', '%Service_DocDB');
    expect(await store.save()).toBe(true);
    const write = writes(calls)[0];
    expect([write.method, write.path]).toEqual(['POST', DOCDB_APP_PATH]);
    expect(JSON.parse(write.body)).toEqual({ Namespace: 'user', Name: 'OcuProbe1830A', Description: 'probe', Enabled: true, Resource: '%Service_DocDB' });
    expect(events.map((event) => `${event.id}|${event.action}|${event.tool}`)).toEqual([`${ID}|created|webapp.docdbapps.create`]);
    expect(store.createdId()).toBe(ID);
  });

  it('AD-39: a refused Save puts the server\u2019s violations on their fields and keeps what was entered; editing the field drops its violation', async () => {
    const refused: JsonResult<unknown> = {
      kind: 'error',
      status: 422,
      code: 'DOCDBAPP.VALIDATION',
      reason: 'The Doc DB application was refused.',
      detail: { violations: [{ field: 'Name', code: 'DOCDBAPP.TAKEN', reason: 'A Doc DB application with that name already exists in that namespace.' }] },
    };
    const { store, events } = mount({ form: EMPTY_ROW, save: refused });
    await store.open('', 'USER');
    store.setValue('Name', 'OcuProbe1830A');
    expect(await store.save()).toBe(false);
    expect([store.violationFor('Name'), store.value('Name'), events.length, store.saved()]).toEqual(['A Doc DB application with that name already exists in that namespace.', 'OcuProbe1830A', 0, false]);
    store.setValue('Name', 'OcuProbe1830B');
    expect(store.violationFor('Name')).toBe('');
  });

  it('AD-4: an edit that changed nothing writes nothing, and a record the instance does not hold blocks Save', async () => {
    const { store, calls } = mount();
    await store.open(ID);
    expect(await store.save()).toBe(true);
    expect(writes(calls)).toEqual([]);
    const absent = mount({ formResult: { kind: 'error', status: 404, code: 'PORT.NOTFOUND', reason: 'That item is no longer present on this instance', detail: null } });
    await absent.store.open(ID);
    expect([absent.store.absent(), absent.store.canSave()]).toEqual([true, false]);
  });

  it('B2: a privilege denial keeps its code and the pair it names', async () => {
    const denied: JsonResult<unknown> = { kind: 'error', status: 403, code: 'AUTH.NOPRIVILEGE', reason: 'denied', detail: { failedPair: '%Admin_Secure:USE' } };
    const { store } = mount({ save: denied });
    await store.open(ID);
    store.setValue('Description', 'other');
    expect(await store.save()).toBe(false);
    expect([store.refusalCode(), store.refusalPair()]).toEqual(['AUTH.NOPRIVILEGE', '%Admin_Secure:USE']);
  });

  it('a reset forgets what was typed, from the sign-out teardown', async () => {
    const { store } = mount({ form: EMPTY_ROW });
    await store.open('', 'USER');
    store.setValue('Name', 'ATHISPRINCIPALTYPED');
    store.reset();
    expect([store.value('Name'), store.value('Namespace'), store.loaded(), store.dirty()]).toEqual(['', '', false, false]);
  });
});
