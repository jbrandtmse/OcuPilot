import { TestBed } from '@angular/core/testing';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type ApiRequestInit, type JsonResult } from '../../core/api';
import { ChangeBus, type ChangeEvent } from '../../core/change-bus';
import { encodeEntityId } from '../../core/entity-id';
import { FormDirty } from '../../core/form-dirty';
import { SCREENS } from '../../core/screens.generated';
import { STRINGS } from '../../core/strings';
import { AUDIT_EVENTS_FORM_PATH, AUDIT_EVENTS_PATH, AuditEventEditor } from './audit-event-editor.store';

/**
 * The user audit event editor's store (AD-4, AD-14, AD-39, AD-55).
 *
 * It pins what no browser leg can falsify: the change event a Save publishes with the server's
 * canonical triple, a create turning into an edit of the new event, an edit sending the Description
 * alone, the dirty flag, and a server refusal landing on the field it names. The bus is real and
 * only the server's answers are stubbed.
 */

const FORM = { maxLengths: { Source: 64, Type: 64, Name: 64, Description: 256 } };

const EVENT = { Source: 'App', Type: 'Kind', Name: 'One', Description: 'old', Enabled: false };

async function settle(): Promise<void> {
  for (let pass = 0; pass < 4; pass += 1) await new Promise((resolve) => setTimeout(resolve, 2));
}

function mount(saveAnswer: JsonResult<unknown> = { kind: 'ok', status: 201, body: { target: { type: 'audit-user-event', scope: 'instance', id: 'app/kind/one' } } }) {
  TestBed.resetTestingModule();
  const calls: { path: string; method: string; body: string }[] = [];
  const api = {
    requestJson: async <T,>(path: string, init: ApiRequestInit = {}): Promise<JsonResult<T>> => {
      calls.push({ path, method: init.method ?? 'GET', body: init.body ?? '' });
      if (path === AUDIT_EVENTS_FORM_PATH) return { kind: 'ok', status: 200, body: FORM } as unknown as JsonResult<T>;
      if (path.startsWith(`${AUDIT_EVENTS_FORM_PATH}?`)) return { kind: 'ok', status: 200, body: { ...FORM, event: EVENT } } as unknown as JsonResult<T>;
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
  return { store: TestBed.inject(AuditEventEditor), calls, events, formDirty };
}

function lastWrite(calls: { path: string; method: string; body: string }[]) {
  const write = calls.filter((call) => call.method !== 'GET').at(-1);
  expect(write).toBeDefined();
  return { path: write!.path, method: write!.method, body: JSON.parse(write!.body) as Record<string, unknown> };
}

afterEach(() => {
  TestBed.resetTestingModule();
});

describe('the user audit event editor store', () => {
  it('AC1, AD-14: a create posts the five fields, publishes one created event with the server triple, and becomes an edit', async () => {
    const { store, calls, events, formDirty } = mount();
    await store.openCreate();
    expect(store.enabled()).toBe(true);
    expect(store.maxLength('Name')).toBe(64);
    store.setPart('Source', 'App');
    store.setPart('Type', 'Kind');
    store.setPart('Name', 'One');
    store.setDescription('d');
    store.setEnabled(false);
    expect(formDirty.dirty()).toBe(true);
    expect(await store.save()).toBe(true);
    await settle();
    expect(lastWrite(calls)).toEqual({
      path: AUDIT_EVENTS_PATH,
      method: 'POST',
      body: { Source: 'App', Type: 'Kind', Name: 'One', Description: 'd', Enabled: false },
    });
    // Mutation (Rule 19): drop the `publish` call from `save()` -> this goes red, and an open User
    // events list never re-fetches the event the editor just created.
    expect(events.map((event) => [event.type, event.scope, event.id, event.kind === 'changed' ? event.action : ''])).toEqual([
      ['audit-user-event', 'instance', 'app/kind/one', 'created'],
    ]);
    expect(SCREENS.find((screen) => screen.descriptor === 'OcuPilot.Screen.Descriptor.AuditUserEventList')?.entityType).toBe('audit-user-event');
    expect(store.mode()).toBe('edit');
    expect(store.editedName()).toBe('App/Kind/One');
    expect(formDirty.dirty()).toBe(false);
    expect(store.takeCreatedId()).toBe('App/Kind/One');
    expect(store.takeCreatedId()).toBe('');
  });

  it('AC2, AD-4: an edit reads the event, keeps its identity fixed, and puts the Description alone', async () => {
    const { store, calls, events } = mount({ kind: 'ok', status: 200, body: { target: { type: 'audit-user-event', scope: 'instance', id: 'app/kind/one' } } });
    await store.openEdit('App/Kind/One');
    expect(calls[0].path).toBe(`${AUDIT_EVENTS_FORM_PATH}?event=${encodeURIComponent('App/Kind/One')}`);
    expect([store.source(), store.type(), store.name(), store.description(), store.enabled()]).toEqual(['App', 'Kind', 'One', 'old', false]);
    store.setPart('Name', 'Other');
    store.setEnabled(true);
    expect([store.name(), store.enabled()]).toEqual(['One', false]);
    store.setDescription('new');
    expect(await store.save()).toBe(true);
    await settle();
    // Mutation (Rule 19): send Enabled beside the Description -> the body carries it and this goes red.
    expect(lastWrite(calls)).toEqual({
      path: `${AUDIT_EVENTS_PATH}/${encodeEntityId('App/Kind/One')}`,
      method: 'PUT',
      body: { Description: 'new' },
    });
    expect(events.map((event) => (event.kind === 'changed' ? event.action : ''))).toEqual(['updated']);
  });

  it('an edit saved with nothing changed writes nothing and publishes nothing', async () => {
    const { store, calls, events } = mount();
    await store.openEdit('App/Kind/One');
    expect(await store.save()).toBe(true);
    expect(calls.filter((call) => call.method !== 'GET')).toEqual([]);
    expect(events).toEqual([]);
  });

  it('AD-39: a refusal lands on the field it names, and one on the event itself is the dialog line', async () => {
    const refusal = {
      kind: 'error',
      status: 422,
      code: 'AUDITEVENT.VALIDATION',
      reason: 'The audit event was refused.',
      detail: { violations: [{ field: 'Source', code: 'AUDITEVENT.PART.RESERVED', reason: STRINGS.auditEventRefusalPartReserved }] },
    } as unknown as JsonResult<unknown>;
    const { store, events, formDirty } = mount(refusal);
    await store.openCreate();
    store.setPart('Source', '%Mine');
    expect(await store.save()).toBe(false);
    expect(store.violationFor('Source')).toBe(STRINGS.auditEventRefusalPartReserved);
    expect(store.reason()).toBe('');
    expect(store.mode()).toBe('create');
    expect(events).toEqual([]);
    expect(formDirty.dirty()).toBe(true);
    store.setPart('Source', 'Mine');
    expect(store.violationFor('Source')).toBe('');

    const gone = {
      kind: 'error',
      status: 404,
      code: 'AUDITEVENT.ABSENT',
      reason: STRINGS.auditEventRefusalAbsent,
      detail: { violations: [{ field: 'EventName', code: 'AUDITEVENT.ABSENT', reason: STRINGS.auditEventRefusalAbsent }] },
    } as unknown as JsonResult<unknown>;
    const second = mount(gone);
    await second.store.openEdit('App/Kind/One');
    second.store.setDescription('new');
    expect(await second.store.save()).toBe(false);
    expect(second.store.violations()).toEqual([]);
    expect(second.store.reason()).toBe(STRINGS.auditEventRefusalAbsent);
  });

  it('a close with a held change asks first, and staying keeps the edits', async () => {
    const { store, formDirty } = mount();
    await store.openCreate();
    store.setPart('Name', 'One');
    const first = store.requestClose();
    expect(formDirty.pending()).toBe(true);
    formDirty.answer(false);
    expect(await first).toBe(false);
    expect(store.name()).toBe('One');
    const second = store.requestClose();
    formDirty.answer(true);
    expect(await second).toBe(true);
    expect(store.mode()).toBe('closed');
  });

  it('an edit of an event the instance does not hold blocks its Save and says so', async () => {
    TestBed.resetTestingModule();
    const api = {
      requestJson: async <T,>(): Promise<JsonResult<T>> =>
        ({ kind: 'error', status: 404, code: 'AUDITEVENT.ABSENT', reason: STRINGS.auditEventRefusalAbsent, detail: null }) as JsonResult<T>,
    };
    TestBed.configureTestingModule({
      providers: [
        { provide: ApiService, useValue: api as unknown as ApiService },
        { provide: FormDirty, useValue: new FormDirty() },
      ],
    });
    const store = TestBed.inject(AuditEventEditor);
    await store.openEdit('App/Kind/Gone');
    expect(store.absent()).toBe(true);
    expect(store.reason()).toBe(STRINGS.auditEventRefusalAbsent);
    expect(store.canSave()).toBe(false);
    expect(await store.save()).toBe(false);
  });

  it('an edit whose read failed for any other reason holds no event, so its Save stays blocked', async () => {
    TestBed.resetTestingModule();
    const api = {
      requestJson: async <T,>(): Promise<JsonResult<T>> =>
        ({ kind: 'error', status: 500, code: 'INTERNAL', reason: 'An internal error occurred', detail: null }) as JsonResult<T>,
    };
    TestBed.configureTestingModule({
      providers: [
        { provide: ApiService, useValue: api as unknown as ApiService },
        { provide: FormDirty, useValue: new FormDirty() },
      ],
    });
    const store = TestBed.inject(AuditEventEditor);
    await store.openEdit('App/Kind/One');
    expect(store.absent()).toBe(false);
    // Mutation (Rule 19): make `canSave()` ignore the held read -> this goes red.
    expect(store.canSave()).toBe(false);
  });
});
