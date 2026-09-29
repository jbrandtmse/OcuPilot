import { TestBed } from '@angular/core/testing';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type ApiRequestInit, type JsonResult } from '../../core/api';
import { ChangeBus, type ChangeEvent } from '../../core/change-bus';
import { FormDirty } from '../../core/form-dirty';
import { DATABASE_CHECK_PATH, DATABASE_FORM_PATH, DATABASE_PATH, DatabaseWizard } from './database-wizard.store';

/**
 * The create database wizard's store (AC1, AD-14, AD-39, AD-55): the path following the name, the
 * step check keeping only the current step's refusals, the create's body and the change event it
 * publishes. The bus is real and only the server's answers are stubbed.
 */

const FORM = {
  requiredFields: ['Name', 'root'],
  rules: [{ field: 'Name', code: 'DATABASE.NAME.REQUIRED', reason: 'Name the database.' }],
  resources: ['%DB_USER'],
};

interface Call {
  readonly path: string;
  readonly method: string;
  readonly body: string;
}

function mount(answers: { check?: readonly unknown[]; create?: JsonResult<unknown>; form?: JsonResult<unknown> } = {}) {
  TestBed.resetTestingModule();
  const calls: Call[] = [];
  const api = {
    requestJson: async <T,>(path: string, init: ApiRequestInit = {}): Promise<JsonResult<T>> => {
      calls.push({ path, method: init.method ?? 'GET', body: init.body ?? '' });
      if (path === DATABASE_FORM_PATH) return (answers.form ?? { kind: 'ok', status: 200, body: FORM }) as JsonResult<T>;
      if (path === DATABASE_CHECK_PATH) return { kind: 'ok', status: 200, body: { violations: answers.check ?? [] } } as unknown as JsonResult<T>;
      return (answers.create ?? { kind: 'ok', status: 201, body: { name: 'OCUPROBE183A', readBack: { verdict: 'holds' } } }) as JsonResult<T>;
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
  return { store: TestBed.inject(DatabaseWizard), calls, events, formDirty };
}

afterEach(() => {
  TestBed.resetTestingModule();
});

describe('the create database wizard store', () => {
  it('opens over the form read: the rules, the required fields and the resources', async () => {
    const { store, calls } = mount();
    await store.open();
    expect(calls.map((call) => call.path)).toEqual([DATABASE_FORM_PATH]);
    expect(store.loaded()).toBe(true);
    expect(store.required('Name')).toBe(true);
    expect(store.resources()).toEqual(['%DB_USER']);
    expect(store.resourcesRefused()).toBe('');
    expect(store.values()).toMatchObject({ Size: '1', GlobalJournalState: true, resourceChoice: 'new' });
  });

  it('the path follows the name, lower-cased, until the picker edits it', async () => {
    const { store } = mount();
    await store.open();
    store.setName('OcuProbe183A');
    expect(store.values().path).toBe('ocuprobe183a');
    expect(store.newResourceName()).toBe('%DB_OCUPROBE183A');
    // The picker's preselection of its one root reports the path it was given: not an edit.
    store.setLocation('/durable/iris/mgr/', 'ocuprobe183a');
    store.setName('OcuProbe183B');
    expect(store.values().path).toBe('ocuprobe183b');
    store.setLocation('/durable/iris/mgr/', 'dbs/b');
    store.setName('OcuProbe183C');
    expect(store.values()).toMatchObject({ root: '/durable/iris/mgr/', path: 'dbs/b' });
  });

  it('Next posts the step and its values, keeps only that step\u2019s refusals and advances on none', async () => {
    const { store, calls } = mount({
      check: [
        { field: 'path', code: 'PATH.MANAGERDIR', reason: 'Choose a subdirectory.' },
        { field: 'Size', code: 'DATABASE.SIZE.SHAPE', reason: 'Enter a whole number of megabytes, 1 or more.' },
      ],
    });
    await store.open();
    store.setName('OcuProbe183A');
    store.setLocation('/durable/iris/mgr/', '');
    expect(await store.next()).toBe(false);
    expect(JSON.parse(calls[1].body)).toEqual({
      step: 'name',
      values: { Name: 'OcuProbe183A', root: '/durable/iris/mgr/', path: '', Size: 1, GlobalJournalState: true },
    });
    expect(store.violations().map((entry) => entry.field)).toEqual(['path']);
    expect(store.violationFor('path')).toBe('Choose a subdirectory.');
    expect(store.step()).toBe('name');
    expect(store.reachable('size')).toBe(false);
  });

  it('a clean check advances, and Back keeps every value', async () => {
    const { store } = mount();
    await store.open();
    store.setName('OcuProbe183A');
    expect(await store.next()).toBe(true);
    expect(store.step()).toBe('size');
    store.setSize('20');
    expect(await store.next()).toBe(true);
    expect([store.step(), store.isLastStep()]).toEqual(['resource', true]);
    store.back();
    expect([store.step(), store.values().Size]).toEqual(['size', '20']);
  });

  it('AD-14: a create posts the values -- ResourceName only for an existing resource -- and publishes created under the instance\u2019s name', async () => {
    const { store, calls, events, formDirty } = mount();
    await store.open();
    store.setName('ocuprobe183a');
    store.setLocation('/durable/iris/mgr/', 'ocuprobe183a');
    expect(formDirty.dirty()).toBe(true);
    expect(await store.create()).toBe(true);
    const write = calls.find((call) => call.method === 'POST' && call.path === DATABASE_PATH);
    expect(JSON.parse(write?.body ?? '{}')).toEqual({ Name: 'ocuprobe183a', root: '/durable/iris/mgr/', path: 'ocuprobe183a', Size: 1, GlobalJournalState: true });
    expect(events.map(({ kind, type, scope, id, action }) => ({ kind, type, scope, id, action }))).toEqual([
      { kind: 'changed', type: 'database-configuration', scope: 'instance', id: 'OCUPROBE183A', action: 'created' },
    ]);
    expect(store.createdId()).toBe('OCUPROBE183A');
    expect(formDirty.dirty()).toBe(false);
  });

  it('AD-39: a refused create lands each violation on its field, keeps what was entered and opens every step', async () => {
    const { store, events } = mount({
      create: {
        kind: 'error',
        status: 422,
        code: 'DATABASE.VALIDATION',
        reason: 'The database was refused.',
        detail: { violations: [{ field: 'Name', code: 'DATABASE.NAME.TAKEN', reason: 'This instance already has a database with that name. Choose a different one.' }] },
      },
    });
    await store.open();
    store.setName('USER');
    expect(await store.create()).toBe(false);
    expect(store.violationFor('Name')).toBe('This instance already has a database with that name. Choose a different one.');
    expect(store.values().Name).toBe('USER');
    expect(store.reachable('resource')).toBe(true);
    expect(events).toEqual([]);
  });

  it('AD-8: a create refused for a missing pair keeps the envelope\u2019s code and pair', async () => {
    const { store } = mount({
      create: { kind: 'error', status: 403, code: 'AUTH.NOPRIVILEGE', reason: 'Forbidden', detail: { failedPair: '%DB_IRISSYS:WRITE' } },
    });
    await store.open();
    store.setName('OcuProbe183A');
    expect(await store.create()).toBe(false);
    expect([store.refusalCode(), store.refusalPair(), store.reason()]).toEqual(['AUTH.NOPRIVILEGE', '%DB_IRISSYS:WRITE', 'Forbidden']);
  });

  it('the existing-resource choice is refused while the resources could not be listed', async () => {
    const { store } = mount({ form: { kind: 'ok', status: 200, body: { ...FORM, resources: undefined, resourcesRefused: '%Admin_Secure:USE' } } });
    await store.open();
    store.setResourceChoice('existing');
    expect(store.values().resourceChoice).toBe('new');
    expect(store.resourcesRefused()).toBe('%Admin_Secure:USE');
  });
});
