import { TestBed } from '@angular/core/testing';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type ApiRequestInit, type JsonResult } from '../../core/api';
import { ChangeBus, type ChangeEvent } from '../../core/change-bus';
import { STRINGS } from '../../core/strings';
import {
  INTEROP_WORKFLOW_USER_ADD_TOOL,
  INTEROP_WORKFLOW_USER_CHOICES_PATH,
  INTEROP_WORKFLOW_USER_PATH,
  InteropWorkflowUserStore,
  choiceNamesOf,
} from './interop-workflow-user.store';

/**
 * Workflow users' form store (Story 24.17 Batch 3a) over a stub of the Save and the choices read: the body it posts, the namespace it scopes each call
 * to, the change event an accepted add publishes, the two kinds of refusal it keeps -- one on a field, one naming none -- the users it offers, and the
 * state an Edit leaves in it.
 */

interface Sent {
  readonly path: string;
  readonly method: string;
  readonly scope: string | null | undefined;
  readonly body: unknown;
}

const CREATED: JsonResult<unknown> = {
  kind: 'ok',
  status: 201,
  body: { id: 'OcuP2417wA', target: { type: 'interop-workflow-user', scope: 'USER', id: 'OcuP2417wA' }, readBack: { verdict: 'matches' } },
};

function mount(answer: (path: string) => JsonResult<unknown>) {
  TestBed.resetTestingModule();
  const sent: Sent[] = [];
  const api = {
    requestJson: async <T,>(path: string, init?: ApiRequestInit): Promise<JsonResult<T>> => {
      sent.push({ path, method: init?.method ?? 'GET', scope: init?.scope, body: typeof init?.body === 'string' ? JSON.parse(init.body) : null });
      return answer(path) as JsonResult<T>;
    },
  };
  const bus = new ChangeBus();
  const events: ChangeEvent[] = [];
  bus.subscribe((event) => events.push(event));
  TestBed.configureTestingModule({
    providers: [
      { provide: ApiService, useValue: api as unknown as ApiService },
      { provide: ChangeBus, useValue: bus },
    ],
  });
  return { store: TestBed.inject(InteropWorkflowUserStore), sent, events };
}

afterEach(() => {
  TestBed.resetTestingModule();
});

describe('InteropWorkflowUserStore', () => {
  it('posts the name, the full name and the flag as a boolean to the namespace given, and publishes the created event', async () => {
    const { store, sent, events } = mount(() => CREATED);
    store.setName('OcuP2417wA');
    store.setFullName('Ada Lovelace');
    store.setActive(false);
    expect(await store.add('USER')).toBe(true);
    // Mutation (Rule 19): drop `scope: namespace` from the shared post -> the scope reads undefined and this goes red.
    expect(sent).toHaveLength(1);
    expect(sent[0].path).toBe(INTEROP_WORKFLOW_USER_PATH);
    expect(sent[0].scope).toBe('USER');
    const body = sent[0].body as Record<string, unknown>;
    expect(Object.keys(body).sort()).toEqual(['FullName', 'IsActive', 'Name']);
    expect(body['Name']).toBe('OcuP2417wA');
    expect(body['FullName']).toBe('Ada Lovelace');
    // Mutation (Rule 19): send the flag as text -> the boolean assertion goes red.
    expect(body['IsActive']).toBe(false);
    // Mutation (Rule 19): drop `tool` from the published event -> the event carries none and this goes red.
    expect(events.map((event) => [event.kind, event.type, event.scope, event.action, event.tool])).toEqual([
      ['changed', 'interop-workflow-user', 'USER', 'created', INTEROP_WORKFLOW_USER_ADD_TOOL],
    ]);
    expect(INTEROP_WORKFLOW_USER_ADD_TOOL).toBe('interop.workflowusers.add');
    expect(store.readBack()?.verdict).toBe('matches');
  });

  it('leaves an empty full name out of the post and sends a new user as active', async () => {
    const { store, sent } = mount(() => CREATED);
    store.setName('OcuP2417wA');
    expect(await store.add('USER')).toBe(true);
    expect(sent[0].body).toEqual({ Name: 'OcuP2417wA', IsActive: true });
  });

  it('keeps a refusal on a field and the values entered, publishes nothing, and a new value clears it', async () => {
    const violation = { field: 'FullName', code: 'INTEROP.WORKFLOW.FULLNAME', reason: STRINGS.interopWorkflowUserRefusalFullName };
    const { store, events } = mount(() => ({
      kind: 'error',
      status: 422,
      code: 'INTEROP.WORKFLOW.FULLNAME',
      reason: STRINGS.interopWorkflowUserRefusalFullName,
      detail: { violations: [violation] },
    }));
    store.setName('OcuP2417wA');
    store.setFullName('x'.repeat(129));
    expect(await store.add('USER')).toBe(false);
    expect(store.violation('FullName')).toBe(STRINGS.interopWorkflowUserRefusalFullName);
    expect(store.reason()).toBe('');
    expect(store.fullName()).toBe('x'.repeat(129));
    expect(events).toEqual([]);
    store.setFullName('Ada');
    expect(store.violation('FullName')).toBe('');
  });

  it('keeps a refusal that names no field as the reason of the dialog, until the form is reset', async () => {
    const { store, events } = mount(() => ({
      kind: 'error',
      status: 409,
      code: 'INTEROP.WORKFLOW.USERTAKEN',
      reason: STRINGS.interopWorkflowUserRefusalTaken,
      detail: null,
    }));
    store.setName('OcuP2417wA');
    expect(await store.add('USER')).toBe(false);
    expect(store.reason()).toBe(STRINGS.interopWorkflowUserRefusalTaken);
    expect(events).toEqual([]);
    store.reset();
    expect(store.reason()).toBe('');
    expect(store.name()).toBe('');
    expect(store.active()).toBe(true);
  });

  it('reads the users to choose from for the namespace given, in the order the instance gave them', async () => {
    const { store, sent } = mount(() => ({
      kind: 'ok',
      status: 200,
      body: { rows: [{ Name: 'Admin', Namespace: 'USER' }, { Name: 'irisowner', Namespace: 'USER' }, { Name: '' }, 'junk', { Name: 7 }] },
    }));
    await store.loadChoices('USER');
    expect(sent.map((call) => [call.path, call.method, call.scope])).toEqual([[INTEROP_WORKFLOW_USER_CHOICES_PATH, 'GET', 'USER']]);
    expect(store.choices()).toEqual(['Admin', 'irisowner']);
    expect(store.choicesReason()).toBe('');
    expect(store.loadingChoices()).toBe(false);
  });

  it('keeps no choices and the instance\'s sentence when it would not list the users', async () => {
    const { store } = mount(() => ({ kind: 'error', status: 403, code: 'AUTH.NOPRIVILEGE', reason: 'You may not list the users.', detail: null }));
    await store.loadChoices('USER');
    expect(store.choices()).toEqual([]);
    expect(store.choicesReason()).toBe('You may not list the users.');
  });

  it('takes no answer from a choices read that lands after the form was reset', async () => {
    let release: (value: JsonResult<unknown>) => void = () => undefined;
    TestBed.resetTestingModule();
    const api = {
      requestJson: async <T,>(): Promise<JsonResult<T>> =>
        (await new Promise<JsonResult<unknown>>((resolve) => {
          release = resolve;
        })) as JsonResult<T>,
    };
    TestBed.configureTestingModule({ providers: [{ provide: ApiService, useValue: api as unknown as ApiService }, { provide: ChangeBus, useValue: new ChangeBus() }] });
    const store = TestBed.inject(InteropWorkflowUserStore);
    const pending = store.loadChoices('USER');
    expect(store.loadingChoices()).toBe(true);
    store.reset();
    release({ kind: 'ok', status: 200, body: { rows: [{ Name: 'Admin' }] } });
    await pending;
    expect(store.choices()).toEqual([]);
    expect(store.loadingChoices()).toBe(false);
  });

  it('holds the values an Edit starts from, and the refusal and the applied end of an Edit', () => {
    const { store } = mount(() => CREATED);
    store.reset({ name: 'OcuP2417wA', fullName: 'Ada', active: false });
    expect(store.values()).toEqual({ name: 'OcuP2417wA', fullName: 'Ada', active: false });
    const generation = store.begin();
    expect(store.busy()).toBe(true);
    expect(store.current(generation)).toBe(true);
    store.refuse([{ field: 'FullName', code: 'INTEROP.WORKFLOW.FULLNAME', reason: STRINGS.interopWorkflowUserRefusalFullName }], 'unused');
    expect(store.busy()).toBe(false);
    expect(store.violation('FullName')).toBe(STRINGS.interopWorkflowUserRefusalFullName);
    expect(store.reason()).toBe('');
    store.refuse([], STRINGS.interopWorkflowUserRefusalSourceControl);
    expect(store.reason()).toBe(STRINGS.interopWorkflowUserRefusalSourceControl);
    store.reset();
    expect(store.current(generation)).toBe(false);
    expect(store.active()).toBe(true);
  });

  it('announces a workflow user the instance added after the dialog was dismissed, and keeps nothing of the answer', async () => {
    // Mutation (Rule 19): return before publishing when the generation moved -> no event and this goes red.
    let release: (value: JsonResult<unknown>) => void = () => undefined;
    TestBed.resetTestingModule();
    const api = {
      requestJson: async <T,>(): Promise<JsonResult<T>> =>
        (await new Promise<JsonResult<unknown>>((resolve) => {
          release = resolve;
        })) as JsonResult<T>,
    };
    const bus = new ChangeBus();
    const events: ChangeEvent[] = [];
    bus.subscribe((event) => events.push(event));
    TestBed.configureTestingModule({
      providers: [
        { provide: ApiService, useValue: api as unknown as ApiService },
        { provide: ChangeBus, useValue: bus },
      ],
    });
    const store = TestBed.inject(InteropWorkflowUserStore);
    store.setName('OcuP2417wA');
    const pending = store.add('USER');
    store.reset();
    release(CREATED);
    expect(await pending).toBe(false);
    expect(events.map((event) => [event.type, event.action])).toEqual([['interop-workflow-user', 'created']]);
    expect(store.readBack()).toBeNull();
    expect(store.busy()).toBe(false);
  });

  it('posts once while an add is in flight', async () => {
    let release: (value: JsonResult<unknown>) => void = () => undefined;
    TestBed.resetTestingModule();
    let posts = 0;
    const api = {
      requestJson: async <T,>(): Promise<JsonResult<T>> => {
        posts += 1;
        return (await new Promise<JsonResult<unknown>>((resolve) => {
          release = resolve;
        })) as JsonResult<T>;
      },
    };
    TestBed.configureTestingModule({
      providers: [
        { provide: ApiService, useValue: api as unknown as ApiService },
        { provide: ChangeBus, useValue: new ChangeBus() },
      ],
    });
    const store = TestBed.inject(InteropWorkflowUserStore);
    store.setName('OcuP2417wA');
    const first = store.add('USER');
    expect(store.busy()).toBe(true);
    expect(await store.add('USER')).toBe(false);
    release({ kind: 'ok', status: 201, body: {} });
    expect(await first).toBe(true);
    expect(posts).toBe(1);
  });
});

describe('choiceNamesOf', () => {
  it('reads the names of the rows and nothing else', () => {
    expect(choiceNamesOf(null)).toEqual([]);
    expect(choiceNamesOf({})).toEqual([]);
    expect(choiceNamesOf({ rows: 'x' })).toEqual([]);
    expect(choiceNamesOf({ rows: [{ Name: 'a' }, { Name: 'b' }] })).toEqual(['a', 'b']);
  });
});
