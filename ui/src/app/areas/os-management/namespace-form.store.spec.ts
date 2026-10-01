import { TestBed } from '@angular/core/testing';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type ApiRequestInit, type JsonResult } from '../../core/api';
import { ChangeBus, type ChangeEvent } from '../../core/change-bus';
import { encodeEntityId } from '../../core/entity-id';
import { FormDirty } from '../../core/form-dirty';
import { NAMESPACE_FORM_PATH, NAMESPACE_NAME_PATH, NAMESPACE_PATH, NAME_TAKEN_CODE, NamespaceForm } from './namespace-form.store';

/**
 * The namespace editor's store (AC1, AD-4, AD-14, AD-39, AD-55).
 *
 * It pins what no browser leg can falsify: the change event a Save publishes, the create's body with
 * an empty temporary database left out, an edit sending only the databases it changed after its fresh
 * read, a stored database the list no longer carries kept as a choice, and a server refusal landing
 * on the field it names. The bus is real and only the server's answers are stubbed.
 */

const RULES = {
  requiredFields: ['Name', 'Globals', 'Routines'],
  rules: [
    { field: 'Name', code: 'NAMESPACE.NAME.REQUIRED', reason: 'Name the namespace.' },
    { field: 'Globals', code: 'NAMESPACE.GLOBALS.REQUIRED', reason: 'Choose a database.' },
    { field: 'Routines', code: 'NAMESPACE.ROUTINES.REQUIRED', reason: 'Choose a database.' },
  ],
  databases: ['ENSLIB', 'HSCUSTOM', 'IRISTEMP', 'USER'],
};

const NAMESPACE = { Name: 'OCUPROBE182', Globals: 'USER', Routines: 'USER', TempGlobals: 'IRISTEMP' };

const TAKEN_SENTENCE = 'This instance already has a namespace with that name. Choose a different one.';

async function settle(): Promise<void> {
  for (let pass = 0; pass < 4; pass += 1) await new Promise((resolve) => setTimeout(resolve, 2));
}

interface Call {
  readonly path: string;
  readonly method: string;
  readonly body: string;
}

function mount(saveAnswer: JsonResult<unknown> = { kind: 'ok', status: 201, body: { name: 'OCUPROBE182' } }, stored = NAMESPACE) {
  TestBed.resetTestingModule();
  const calls: Call[] = [];
  const api = {
    requestJson: async <T,>(path: string, init: ApiRequestInit = {}): Promise<JsonResult<T>> => {
      calls.push({ path, method: init.method ?? 'GET', body: init.body ?? '' });
      if (path === NAMESPACE_FORM_PATH) return { kind: 'ok', status: 200, body: RULES } as unknown as JsonResult<T>;
      if (path.startsWith(`${NAMESPACE_FORM_PATH}?`)) {
        return { kind: 'ok', status: 200, body: { ...RULES, namespace: stored } } as unknown as JsonResult<T>;
      }
      if (path.startsWith(NAMESPACE_NAME_PATH)) {
        return { kind: 'ok', status: 200, body: { name: 'USER', taken: true, reason: TAKEN_SENTENCE } } as unknown as JsonResult<T>;
      }
      return saveAnswer as JsonResult<T>;
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
  return { store: TestBed.inject(NamespaceForm), calls, events, formDirty };
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

describe('the namespace editor store', () => {
  it('a create starts every database empty, offering an empty choice before the instance\u2019s databases', async () => {
    const { store } = mount();
    await store.open('');
    expect(store.mode()).toBe('create');
    expect(['Name', 'Globals', 'Routines', 'TempGlobals'].map((field) => store.value(field))).toEqual(['', '', '', '']);
    expect(store.choices('TempGlobals')).toEqual(['', 'ENSLIB', 'HSCUSTOM', 'IRISTEMP', 'USER']);
    expect(store.choices('Globals')).toEqual(['', 'ENSLIB', 'HSCUSTOM', 'IRISTEMP', 'USER']);
    expect(store.required('Globals')).toBe(true);
    expect(store.required('TempGlobals')).toBe(false);
    expect(store.canSave()).toBe(true);
  });

  it('AC1, AD-14: a create posts the name, the globals and the routines database, leaves out an empty temporary one, and publishes created', async () => {
    const { store, calls, events, formDirty } = mount();
    await store.open('');
    store.setValue('Name', 'ocuprobe182');
    store.setValue('Globals', 'USER');
    store.setValue('Routines', 'USER');
    expect(formDirty.dirty()).toBe(true);
    expect(await store.save()).toBe(true);
    await settle();

    const [write] = writes(calls);
    expect(write?.path).toBe(NAMESPACE_PATH);
    expect(write?.method).toBe('POST');
    // Mutation (Rule 19): send TempGlobals unconditionally in `createBody` -> this goes red, and the
    // instance refuses the create with NAMESPACE.TEMPGLOBALS.ABSENT.
    expect(JSON.parse(write?.body ?? '{}')).toEqual({ Name: 'ocuprobe182', Globals: 'USER', Routines: 'USER' });
    // The id is the instance's own spelling, which it answered upper case.
    // Mutation (Rule 19): drop `this.publish(...)` from `save()` -> no event and this goes red.
    expect(events.map(shape)).toEqual([{ kind: 'changed', type: 'namespace', scope: 'instance', id: 'OCUPROBE182', action: 'created' }]);
    expect(store.createdId()).toBe('OCUPROBE182');
    expect(store.saved()).toBe(true);
    expect(formDirty.dirty()).toBe(false);
  });

  it('a create that chose a temporary database sends it', async () => {
    const { store, calls } = mount();
    await store.open('');
    store.setValue('Name', 'OCUPROBE182');
    store.setValue('Globals', 'USER');
    store.setValue('Routines', 'USER');
    store.setValue('TempGlobals', 'IRISTEMP');
    expect(await store.save()).toBe(true);
    expect(JSON.parse(writes(calls)[0]?.body ?? '{}')).toEqual({ Name: 'OCUPROBE182', Globals: 'USER', Routines: 'USER', TempGlobals: 'IRISTEMP' });
  });

  it('AD-4: an edit opens over the fresh read and puts only the databases it changed, then publishes updated', async () => {
    const { store, calls, events } = mount({ kind: 'ok', status: 200, body: { name: 'OCUPROBE182' } });
    await store.open('OCUPROBE182');
    expect(store.mode()).toBe('edit');
    expect([store.value('Globals'), store.value('Routines'), store.value('TempGlobals')]).toEqual(['USER', 'USER', 'IRISTEMP']);
    expect(store.choices('TempGlobals')).toEqual(['ENSLIB', 'HSCUSTOM', 'IRISTEMP', 'USER']);
    store.setValue('Name', 'RENAMED');
    expect(store.value('Name')).toBe('OCUPROBE182');
    store.setValue('Routines', 'HSCUSTOM');
    expect(await store.save()).toBe(true);
    const [write] = writes(calls);
    expect(write?.path).toBe(`${NAMESPACE_PATH}/${encodeEntityId('OCUPROBE182')}`);
    expect(write?.method).toBe('PUT');
    expect(JSON.parse(write?.body ?? '{}')).toEqual({ Routines: 'HSCUSTOM' });
    expect(events.map(shape)).toEqual([{ kind: 'changed', type: 'namespace', scope: 'instance', id: 'OCUPROBE182', action: 'updated' }]);
  });

  it('AD-4: an edit that changed nothing writes nothing', async () => {
    const { store, calls, events } = mount();
    await store.open('OCUPROBE182');
    store.setValue('Routines', 'HSCUSTOM');
    store.setValue('Routines', 'USER');
    expect(await store.save()).toBe(true);
    expect(writes(calls)).toEqual([]);
    expect(events).toEqual([]);
  });

  it('a stored database the list no longer carries is kept as a choice', async () => {
    const { store } = mount(undefined, { ...NAMESPACE, Routines: 'GONEDB' });
    await store.open('OCUPROBE182');
    // Mutation (Rule 19): drop the held value from `choices` -> the select could not show GONEDB and
    // this goes red.
    expect(store.choices('Routines')).toEqual(['GONEDB', 'ENSLIB', 'HSCUSTOM', 'IRISTEMP', 'USER']);
    expect(store.value('Routines')).toBe('GONEDB');
  });

  it('AD-39: a refused Save lands each violation on its field and keeps what was entered', async () => {
    const { store, events } = mount({
      kind: 'error',
      status: 422,
      code: 'NAMESPACE.VALIDATION',
      reason: 'The namespace was refused.',
      detail: { violations: [{ field: 'Globals', code: 'NAMESPACE.GLOBALS.ABSENT', reason: 'No database on this instance has that name.' }] },
    } as unknown as JsonResult<unknown>);
    await store.open('');
    store.setValue('Name', 'OCUPROBE182');
    store.setValue('Globals', 'NOSUCHDB');
    store.setValue('Routines', 'USER');
    expect(await store.save()).toBe(false);
    expect(store.violationFor('Globals')).toBe('No database on this instance has that name.');
    expect(store.value('Globals')).toBe('NOSUCHDB');
    expect(events).toEqual([]);
  });

  it('a name the instance holds is marked taken on blur, with the server sentence, and an empty database takes the required sentence', async () => {
    const { store, calls } = mount();
    await store.open('');
    store.setValue('Name', 'user');
    await store.onBlur('Name');
    expect(calls.map((call) => call.path)).toContain(`${NAMESPACE_NAME_PATH}?name=user`);
    expect(store.violations()).toEqual([{ field: 'Name', code: NAME_TAKEN_CODE, reason: TAKEN_SENTENCE }]);
    await store.onBlur('Globals');
    expect(store.violationFor('Globals')).toBe('Choose a database.');
    expect(store.violationFor('TempGlobals')).toBe('');
  });

  it('an edit asks nothing on the name\u2019s blur', async () => {
    const { store, calls } = mount();
    await store.open('OCUPROBE182');
    await store.onBlur('Name');
    expect(calls.filter((call) => call.path.startsWith(NAMESPACE_NAME_PATH))).toEqual([]);
  });

  it('a create lands on the new namespace\u2019s edit with the saved confirmation', async () => {
    const { store } = mount();
    await store.open('');
    store.setValue('Name', 'OCUPROBE182');
    store.setValue('Globals', 'USER');
    store.setValue('Routines', 'USER');
    expect(await store.save()).toBe(true);
    store.retainAcrossRouteReplacement();
    await store.open(store.createdId());
    // Mutation (Rule 19): drop `if (arriving)` from `open()` -> `saved()` reads false and this goes red.
    expect([store.mode(), store.saved(), store.retaining(), store.value('Name')]).toEqual(['edit', true, false, 'OCUPROBE182']);
  });

  it('DW-1824: retainForHandOff keeps the create retained across the wizard and leaves the form clean', async () => {
    const { store, formDirty } = mount();
    await store.open('');
    store.setValue('Name', 'OCUPROBE1817N');
    expect(formDirty.dirty()).toBe(true);
    store.retainForHandOff();
    expect([store.retaining(), formDirty.dirty()]).toEqual([true, false]);
  });

  it('DW-1824: the return restores what was typed and chooses the created database as Globals in the list\u2019s spelling, dirty', async () => {
    const { store, formDirty } = mount();
    await store.open('');
    store.setValue('Name', 'OCUPROBE1817N');
    store.setValue('Routines', 'USER');
    store.retainForHandOff();
    // Mutation (Rule 19): `open` ignores `returning` and resets -> Name and Routines read '' and this goes red.
    await store.open('', { database: 'enslib' });
    expect([store.mode(), store.value('Name'), store.value('Routines'), store.value('Globals')]).toEqual(['create', 'OCUPROBE1817N', 'USER', 'ENSLIB']);
    expect([formDirty.dirty(), store.retaining()]).toEqual([true, false]);
  });

  it('DW-1824: a database the read does not list leaves Globals as typed', async () => {
    const { store } = mount();
    await store.open('');
    store.setValue('Globals', 'HSCUSTOM');
    store.retainForHandOff();
    await store.open('', { database: 'OCUPROBE1817W' });
    expect(store.value('Globals')).toBe('HSCUSTOM');
  });

  it('DW-1824: a return with nothing held is an empty create with the database chosen; an open without one resets', async () => {
    const { store, formDirty } = mount();
    await store.open('', { database: 'USER' });
    expect([store.value('Name'), store.value('Globals'), formDirty.dirty()]).toEqual(['', 'USER', true]);
    store.setValue('Name', 'OCUPROBE1817N');
    store.retainForHandOff();
    await store.open('');
    expect([store.value('Name'), store.value('Globals'), store.retaining(), formDirty.dirty()]).toEqual(['', '', false, false]);
  });

  it('DW-1824: reset drops the held copy', async () => {
    const { store } = mount();
    await store.open('');
    store.setValue('Name', 'OCUPROBE1817N');
    store.retainForHandOff();
    store.reset();
    expect(store.retaining()).toBe(false);
    await store.open('', { database: '' });
    expect(store.value('Name')).toBe('');
  });

  it('an edit of a namespace the instance does not hold blocks Save', async () => {
    TestBed.resetTestingModule();
    const api = {
      requestJson: async <T,>(path: string): Promise<JsonResult<T>> =>
        (path === NAMESPACE_FORM_PATH
          ? { kind: 'ok', status: 200, body: RULES }
          : { kind: 'error', status: 404, code: 'NAMESPACE.NAME.ABSENT', reason: 'This instance has no namespace with that name.', detail: null }) as unknown as JsonResult<T>,
    };
    TestBed.configureTestingModule({
      providers: [
        { provide: ApiService, useValue: api as unknown as ApiService },
        { provide: ChangeBus, useValue: new ChangeBus() },
        { provide: FormDirty, useValue: new FormDirty() },
      ],
    });
    const store = TestBed.inject(NamespaceForm);
    await store.open('NOSUCHNS');
    expect(store.absent()).toBe(true);
    expect(store.canSave()).toBe(false);
    expect(store.reason()).toBe('This instance has no namespace with that name.');
  });

  it('AC6, SA-13: a database created or deleted re-reads the choices while the form is open, keeping what was entered', async () => {
    // Mutation (Rule 19): make the store ignore the `database-configuration` event -> the re-read and
    // the new choice go red.
    TestBed.resetTestingModule();
    const calls: Call[] = [];
    let databases = ['ENSLIB', 'USER'];
    const api = {
      requestJson: async <T,>(path: string, init: ApiRequestInit = {}): Promise<JsonResult<T>> => {
        calls.push({ path, method: init.method ?? 'GET', body: init.body ?? '' });
        return { kind: 'ok', status: 200, body: { ...RULES, databases } } as unknown as JsonResult<T>;
      },
    };
    const bus = new ChangeBus();
    TestBed.configureTestingModule({
      providers: [
        { provide: ApiService, useValue: api as unknown as ApiService },
        { provide: ChangeBus, useValue: bus },
        { provide: FormDirty, useValue: new FormDirty() },
      ],
    });
    const store = TestBed.inject(NamespaceForm);
    await store.open('');
    store.setValue('Name', 'OCUPROBE183NS');
    store.setValue('Globals', 'USER');
    expect(store.choices('Routines')).toEqual(['', 'ENSLIB', 'USER']);

    // An update, and another type's create, change which databases exist not at all.
    bus.publish({ kind: 'changed', type: 'database-configuration', scope: 'instance', id: 'USER', action: 'updated' });
    bus.publish({ kind: 'changed', type: 'namespace', scope: 'instance', id: 'OTHERNS', action: 'created' });
    await settle();
    expect(calls).toHaveLength(1);

    databases = ['ENSLIB', 'OCUPROBE183A', 'USER'];
    bus.publish({ kind: 'changed', type: 'database-configuration', scope: 'instance', id: 'OCUPROBE183A', action: 'created' });
    await settle();
    expect(calls.map((call) => call.path)).toEqual([NAMESPACE_FORM_PATH, NAMESPACE_FORM_PATH]);
    expect(store.choices('Routines')).toEqual(['', 'ENSLIB', 'OCUPROBE183A', 'USER']);
    expect([store.value('Name'), store.value('Globals')]).toEqual(['OCUPROBE183NS', 'USER']);

    databases = ['ENSLIB', 'USER'];
    bus.publish({ kind: 'changed', type: 'database-configuration', scope: 'instance', id: 'OCUPROBE183A', action: 'deleted' });
    await settle();
    expect(calls).toHaveLength(3);
    expect(store.choices('Routines')).toEqual(['', 'ENSLIB', 'USER']);

    // A form no longer open is not read: its next open reads the choices anyway.
    store.reset();
    bus.publish({ kind: 'changed', type: 'database-configuration', scope: 'instance', id: 'OCUPROBE183B', action: 'created' });
    await settle();
    expect(calls).toHaveLength(3);
  });
});
