import { TestBed } from '@angular/core/testing';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type ApiRequestInit, type JsonResult } from '../../core/api';
import { ChangeBus, type ChangeEvent } from '../../core/change-bus';
import { encodeEntityId, joinCompositeId } from '../../core/entity-id';
import { FormDirty } from '../../core/form-dirty';
import { MAPPING_PATH, MappingForm, NAME_TAKEN_CODE, mappingKind, type MappingKindDeclaration } from './mapping-form.store';

/**
 * The namespace mapping editor's store (Story 18.14; AD-4, AD-14, AD-39, AD-54, AD-55).
 *
 * It pins what no browser leg can falsify: the create's body with an empty lock database and
 * collation left out and a whole-number collation sent as a number, an edit addressed by the
 * composite id and sending only the template fields it changed, the change event each Save
 * publishes, the kind's own field set, the system-global line's condition, and a server refusal
 * landing on the field it names. The bus is real and only the server's answers are stubbed.
 */

const RULES = {
  requiredFields: ['Name', 'Database'],
  rules: [
    { field: 'Name', code: 'MAPPING.NAME.REQUIRED', reason: 'Name what to map.' },
    { field: 'Database', code: 'MAPPING.DATABASE.REQUIRED', reason: 'Choose a database.' },
  ],
  databases: ['ENSLIB', 'IRISTEMP', 'USER'],
};

const GLOBAL = mappingKind('global') as MappingKindDeclaration;
const ROUTINE = mappingKind('routine') as MappingKindDeclaration;

const STORED = { Name: 'OcuProbe1814G', Database: 'USER', LockDatabase: '', Collation: 5 };

const TAKEN_SENTENCE = 'This namespace already has that mapping.';

async function settle(): Promise<void> {
  for (let pass = 0; pass < 4; pass += 1) await new Promise((resolve) => setTimeout(resolve, 2));
}

interface Call {
  readonly path: string;
  readonly method: string;
  readonly body: string;
}

function mount(saveAnswer: JsonResult<unknown> = { kind: 'ok', status: 201, body: { id: 'OCUPROBE1814BA\u0001OcuProbe1814G', namespace: 'OCUPROBE1814BA', name: 'OcuProbe1814G' } }, readAnswer?: JsonResult<unknown>) {
  TestBed.resetTestingModule();
  const calls: Call[] = [];
  const api = {
    requestJson: async <T,>(path: string, init: ApiRequestInit = {}): Promise<JsonResult<T>> => {
      calls.push({ path, method: init.method ?? 'GET', body: init.body ?? '' });
      if ((init.method ?? 'GET') !== 'GET') return saveAnswer as JsonResult<T>;
      if (path.includes('/name?')) {
        return { kind: 'ok', status: 200, body: { name: 'OcuProbe1814G', taken: true, reason: TAKEN_SENTENCE } } as unknown as JsonResult<T>;
      }
      if (readAnswer !== undefined) return readAnswer as JsonResult<T>;
      const query = new URLSearchParams(path.split('?')[1] ?? '');
      const namespace = (query.get('namespace') ?? '').toUpperCase();
      const body = query.has('name') ? { ...RULES, namespace, mapping: STORED } : { ...RULES, namespace };
      return { kind: 'ok', status: 200, body } as unknown as JsonResult<T>;
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
  return { store: TestBed.inject(MappingForm), calls, events, formDirty };
}

/** The five fields a change event carries about the write, the bus's own bookkeeping aside. */
function shape(event: ChangeEvent): Record<string, unknown> {
  const { kind, type, scope, id, action } = event as unknown as Record<string, unknown>;
  return { kind, type, scope, id, action };
}

function writes(calls: readonly Call[]): Call[] {
  return calls.filter((call) => call.method !== 'GET');
}

afterEach(() => {
  TestBed.resetTestingModule();
});

describe('the namespace mapping editor store', () => {
  it('a create reads the kind\u2019s form for the query\u2019s namespace and offers an empty choice before each database', async () => {
    const { store, calls } = mount();
    await store.open(GLOBAL, '', 'ocuprobe1814ba');
    expect(calls.map((call) => call.path)).toEqual([`${MAPPING_PATH}/global/form?namespace=ocuprobe1814ba`]);
    expect(store.mode()).toBe('create');
    expect(store.namespace()).toBe('OCUPROBE1814BA');
    expect(store.fields()).toEqual(['Database', 'LockDatabase', 'Collation']);
    expect(store.choices('Database')).toEqual(['', 'ENSLIB', 'IRISTEMP', 'USER']);
    expect(store.choices('LockDatabase')).toEqual(['', 'ENSLIB', 'IRISTEMP', 'USER']);
    expect(store.required('Name')).toBe(true);
    expect(store.required('Database')).toBe(true);
  });

  it('AD-54, AD-14: a create posts the namespace, the name and the database, leaves out empty optional fields, and publishes created', async () => {
    // Mutation (Rule 19): always send `LockDatabase` in `createBody` -> the body assertion goes red.
    const { store, calls, events } = mount();
    await store.open(GLOBAL, '', 'OCUPROBE1814BA');
    store.setValue('Name', 'OcuProbe1814G');
    store.setValue('Database', 'USER');
    expect(await store.save()).toBe(true);
    const [write] = writes(calls);
    expect(write.method).toBe('POST');
    expect(write.path).toBe(`${MAPPING_PATH}/global`);
    expect(JSON.parse(write.body)).toEqual({ Namespace: 'OCUPROBE1814BA', Name: 'OcuProbe1814G', Database: 'USER' });
    expect(store.createdId()).toBe('OCUPROBE1814BA\u0001OcuProbe1814G');
    expect(events.map(shape)).toEqual([
      { kind: 'changed', type: 'global-mapping', scope: 'instance', id: 'OCUPROBE1814BA\u0001OcuProbe1814G', action: 'created' },
    ]);
  });

  it('a global create sends a chosen lock database, and a whole-number collation as a number, anything else as typed', async () => {
    const { store, calls } = mount();
    await store.open(GLOBAL, '', 'OCUPROBE1814BA');
    store.setValue('Name', 'OcuProbe1814G');
    store.setValue('Database', 'USER');
    store.setValue('LockDatabase', 'IRISTEMP');
    store.setValue('Collation', '5');
    await store.save();
    expect(JSON.parse(writes(calls)[0].body)).toEqual({
      Namespace: 'OCUPROBE1814BA',
      Name: 'OcuProbe1814G',
      Database: 'USER',
      LockDatabase: 'IRISTEMP',
      Collation: 5,
    });
    const second = mount();
    await second.store.open(GLOBAL, '', 'OCUPROBE1814BA');
    second.store.setValue('Name', 'OcuProbe1814G');
    second.store.setValue('Database', 'USER');
    second.store.setValue('Collation', 'five');
    await second.store.save();
    expect(JSON.parse(writes(second.calls)[0].body).Collation).toBe('five');
  });

  it('AD-4: an edit opens over the fresh read of the composite id and puts only the fields it changed, then publishes updated', async () => {
    // Mutation (Rule 19): send the buffer whole in `changedFields` -> the body assertion goes red.
    const id = joinCompositeId(['user', 'OcuProbe1814G']);
    const { store, calls, events } = mount({ kind: 'ok', status: 200, body: { id: 'USER\u0001OcuProbe1814G' } });
    await store.open(GLOBAL, id);
    expect(calls[0].path).toBe(`${MAPPING_PATH}/global/form?namespace=user&name=OcuProbe1814G`);
    expect(store.mode()).toBe('edit');
    expect(store.value('Name')).toBe('OcuProbe1814G');
    expect(store.value('Collation')).toBe('5');
    expect(store.choices('Database')).toEqual(['ENSLIB', 'IRISTEMP', 'USER']);
    expect(store.choices('LockDatabase')).toEqual(['', 'ENSLIB', 'IRISTEMP', 'USER']);
    store.setValue('Name', 'SomethingElse');
    expect(store.value('Name')).toBe('OcuProbe1814G');
    store.setValue('Database', 'IRISTEMP');
    await store.save();
    const [write] = writes(calls);
    expect(write.method).toBe('PUT');
    expect(write.path).toBe(`${MAPPING_PATH}/global/${encodeEntityId('USER\u0001OcuProbe1814G')}`);
    expect(JSON.parse(write.body)).toEqual({ Database: 'IRISTEMP' });
    expect(events.map(shape)).toEqual([
      { kind: 'changed', type: 'global-mapping', scope: 'instance', id: 'USER\u0001OcuProbe1814G', action: 'updated' },
    ]);
  });

  it('AD-4: an edit that changed nothing writes nothing', async () => {
    const { store, calls } = mount();
    await store.open(GLOBAL, joinCompositeId(['USER', 'OcuProbe1814G']));
    expect(await store.save()).toBe(true);
    expect(writes(calls)).toHaveLength(0);
    expect(store.saved()).toBe(true);
  });

  it('a routine mapping has only the database beside its name, and names no system global', async () => {
    const { store, calls } = mount({ kind: 'ok', status: 201, body: { id: 'OCUPROBE1814BA\u0001OcuProbe1814R', name: 'OcuProbe1814R' } });
    await store.open(ROUTINE, '', 'OCUPROBE1814BA');
    expect(store.fields()).toEqual(['Database']);
    store.setValue('Name', '%OcuProbe1814R');
    store.setValue('LockDatabase', 'USER');
    expect(store.value('LockDatabase')).toBe('');
    expect(store.systemGlobal()).toBe(false);
    store.setValue('Database', 'USER');
    await store.save();
    expect(writes(calls)[0].path).toBe(`${MAPPING_PATH}/routine`);
    expect(JSON.parse(writes(calls)[0].body)).toEqual({ Namespace: 'OCUPROBE1814BA', Name: '%OcuProbe1814R', Database: 'USER' });
  });

  it('AD-10: a global whose name begins with % names a system global, and no other does', async () => {
    // Mutation (Rule 19): drop the kind check from `systemGlobal` -> the routine leg above goes red;
    // test `includes('%')` instead of `startsWith` -> the subscript leg below goes red.
    const { store } = mount();
    await store.open(GLOBAL, '', 'OCUPROBE1814BA');
    store.setValue('Name', '%OcuProbe1814');
    expect(store.systemGlobal()).toBe(true);
    store.setValue('Name', '%OcuProbe1814("a")');
    expect(store.systemGlobal()).toBe(true);
    store.setValue('Name', 'OcuProbe1814("%a")');
    expect(store.systemGlobal()).toBe(false);
  });

  it('AD-39: a refused Save lands each violation on its field and keeps what was entered', async () => {
    const refusal = {
      kind: 'error',
      status: 422,
      code: 'MAPPING.VALIDATION',
      reason: 'The request was refused',
      detail: { violations: [{ field: 'Database', code: 'MAPPING.DATABASE.ABSENT', reason: 'No database on this instance has that name.' }] },
    } as unknown as JsonResult<unknown>;
    const { store, events } = mount(refusal);
    await store.open(GLOBAL, '', 'OCUPROBE1814BA');
    store.setValue('Name', 'OcuProbe1814G');
    store.setValue('Database', 'NOSUCHDB');
    expect(await store.save()).toBe(false);
    expect(store.violationFor('Database')).toBe('No database on this instance has that name.');
    expect(store.value('Database')).toBe('NOSUCHDB');
    expect(events).toHaveLength(0);
  });

  it('a name the namespace holds is marked taken on blur, with the server sentence, asked in that namespace', async () => {
    const { store, calls } = mount();
    await store.open(GLOBAL, '', 'OCUPROBE1814BA');
    store.setValue('Name', 'OcuProbe1814G');
    await store.onBlur('Name');
    await settle();
    expect(calls.at(-1)?.path).toBe(`${MAPPING_PATH}/global/name?namespace=OCUPROBE1814BA&name=OcuProbe1814G`);
    expect(store.violations()).toEqual([{ field: 'Name', code: NAME_TAKEN_CODE, reason: TAKEN_SENTENCE }]);
    await store.onBlur('Database');
    expect(store.violationFor('Database')).toBe('Choose a database.');
  });

  it('an edit of a mapping the instance does not hold blocks Save, with the server\u2019s own reason', async () => {
    const absent = { kind: 'error', status: 404, code: 'MAPPING.NAME.ABSENT', reason: 'This namespace has no mapping with that name.', detail: null } as unknown as JsonResult<unknown>;
    const { store } = mount(undefined, absent);
    await store.open(GLOBAL, joinCompositeId(['USER', 'Gone']));
    expect(store.absent()).toBe(true);
    expect(store.canSave()).toBe(false);
    expect(store.reason()).toBe('This namespace has no mapping with that name.');
  });

  it('a create lands on the new mapping\u2019s edit with the saved confirmation', async () => {
    const { store } = mount();
    await store.open(GLOBAL, '', 'OCUPROBE1814BA');
    store.setValue('Name', 'OcuProbe1814G');
    store.setValue('Database', 'USER');
    await store.save();
    store.retainAcrossRouteReplacement();
    await store.open(GLOBAL, store.createdId());
    expect(store.mode()).toBe('edit');
    expect(store.saved()).toBe(true);
  });
});
