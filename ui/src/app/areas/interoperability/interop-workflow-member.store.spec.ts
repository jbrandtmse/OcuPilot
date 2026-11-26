import { TestBed } from '@angular/core/testing';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type ApiRequestInit, type JsonResult } from '../../core/api';
import { ChangeBus, type ChangeEvent } from '../../core/change-bus';
import { STRINGS } from '../../core/strings';
import {
  INTEROP_WORKFLOW_MEMBER_ADD_TOOL,
  INTEROP_WORKFLOW_MEMBER_DEFAULT_RANK,
  INTEROP_WORKFLOW_MEMBER_PATH,
  InteropWorkflowMemberStore,
  workflowUserChoicesOf,
} from './interop-workflow-member.store';

/**
 * Role members' form store (Story 24.17 Batch 3b) over a stub of the Save and of the Workflow users read: the body it posts, the rank as a number that
 * starts at 3, the namespace it scopes each call to, the change event an accepted add publishes, the two kinds of refusal it keeps, and the users it
 * offers, which are the Workflow users list's rows less the members the role already holds.
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
  body: {
    id: 'OcuP2417rA\u0001OcuP2417wA',
    target: { type: 'interop-workflow-member', scope: 'USER', id: 'OcuP2417rA\u0001OcuP2417wA' },
    readBack: { verdict: 'matches' },
  },
};

const USERS: JsonResult<unknown> = {
  kind: 'ok',
  status: 200,
  body: { rows: [{ Name: 'OcuP2417wA', IsActive: true }, { Name: 'OcuP2417wB', IsActive: false }, { Name: 'ocup2417wc', IsActive: true }] },
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
  return { store: TestBed.inject(InteropWorkflowMemberStore), sent, events };
}

afterEach(() => {
  TestBed.resetTestingModule();
});

describe('InteropWorkflowMemberStore', () => {
  it('posts the role, the user, the rank as a number and the title to the namespace given, and publishes the created event', async () => {
    const { store, sent, events } = mount(() => CREATED);
    store.setUser('OcuP2417wA');
    store.setRanking('2');
    store.setTitle('Lead');
    expect(await store.add('USER', 'OcuP2417rA')).toBe(true);
    // Mutation (Rule 19): drop `scope: namespace` from the shared post -> the scope reads undefined and this goes red.
    expect(sent).toHaveLength(1);
    expect(sent[0].path).toBe(INTEROP_WORKFLOW_MEMBER_PATH);
    expect(sent[0].method).toBe('POST');
    expect(sent[0].scope).toBe('USER');
    // Mutation (Rule 19): send no rank, or the rank as text -> this goes red.
    expect(sent[0].body).toEqual({ Role: 'OcuP2417rA', User: 'OcuP2417wA', Ranking: 2, Title: 'Lead' });
    expect(events.map((event) => [event.kind, event.type, event.scope, event.action, event.tool])).toEqual([
      ['changed', 'interop-workflow-member', 'USER', 'created', INTEROP_WORKFLOW_MEMBER_ADD_TOOL],
    ]);
    expect(INTEROP_WORKFLOW_MEMBER_ADD_TOOL).toBe('interop.workflowmembers.add');
    expect(store.readBack()?.verdict).toBe('matches');
  });

  it('starts the rank at the vendor\'s 3, sends it, and leaves an empty title out of the post', async () => {
    const { store, sent } = mount(() => CREATED);
    expect(store.ranking()).toBe(INTEROP_WORKFLOW_MEMBER_DEFAULT_RANK);
    store.setUser('OcuP2417wA');
    expect(await store.add('USER', 'OcuP2417rA')).toBe(true);
    expect(sent[0].body).toEqual({ Role: 'OcuP2417rA', User: 'OcuP2417wA', Ranking: 3 });
  });

  it('keeps a refusal on a field and the values entered, publishes nothing, and a new value clears it', async () => {
    const violation = { field: 'Title', code: 'INTEROP.WORKFLOW.MEMBERTITLE', reason: STRINGS.interopWorkflowMemberRefusalTitle };
    const { store, events } = mount(() => ({
      kind: 'error',
      status: 422,
      code: 'INTEROP.WORKFLOW.MEMBERTITLE',
      reason: STRINGS.interopWorkflowMemberRefusalTitle,
      detail: { violations: [violation] },
    }));
    store.setUser('OcuP2417wA');
    store.setTitle('x'.repeat(129));
    expect(await store.add('USER', 'OcuP2417rA')).toBe(false);
    expect(store.violation('Title')).toBe(STRINGS.interopWorkflowMemberRefusalTitle);
    expect(store.reason()).toBe('');
    expect(store.title()).toBe('x'.repeat(129));
    expect(events).toEqual([]);
    store.setTitle('Lead');
    expect(store.violation('Title')).toBe('');
  });

  it('keeps a refusal that names no field as the reason of the dialog, until the form is reset', async () => {
    const { store, events } = mount(() => ({
      kind: 'error',
      status: 409,
      code: 'INTEROP.WORKFLOW.MEMBERTAKEN',
      reason: STRINGS.interopWorkflowMemberRefusalTaken,
      detail: null,
    }));
    store.setUser('OcuP2417wA');
    expect(await store.add('USER', 'OcuP2417rA')).toBe(false);
    expect(store.reason()).toBe(STRINGS.interopWorkflowMemberRefusalTaken);
    expect(events).toEqual([]);
    store.reset();
    expect(store.reason()).toBe('');
    expect(store.user()).toBe('');
    expect(store.ranking()).toBe(INTEROP_WORKFLOW_MEMBER_DEFAULT_RANK);
  });

  it("reads the Workflow users list for the namespace given and offers its users less the role's members, in any letter case", async () => {
    // Mutation (Rule 19): compare the members exactly rather than in any letter case -> `ocup2417wc` is still offered and this goes red.
    const { store, sent } = mount(() => USERS);
    await store.loadChoices('USER', ['OcuP2417WC']);
    expect(sent.map((call) => [call.path, call.method, call.scope])).toEqual([['/api/ocupilot/screens/interop.workflowusers/read?maxRows=1000', 'GET', 'USER']]);
    expect(store.choices()).toEqual([
      { name: 'OcuP2417wA', active: true },
      { name: 'OcuP2417wB', active: false },
    ]);
    expect(store.choicesReason()).toBe('');
    expect(store.loadingChoices()).toBe(false);
  });

  it("keeps no choices and the instance's sentence when it would not answer the read", async () => {
    const { store } = mount(() => ({ kind: 'error', status: 403, code: 'AUTH.NOPRIVILEGE', reason: 'You may not list the users.', detail: null }));
    await store.loadChoices('USER', []);
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
    const store = TestBed.inject(InteropWorkflowMemberStore);
    const pending = store.loadChoices('USER', []);
    expect(store.loadingChoices()).toBe(true);
    store.reset();
    release(USERS);
    await pending;
    expect(store.choices()).toEqual([]);
    expect(store.loadingChoices()).toBe(false);
  });

  it('announces a member the instance added after the dialog was dismissed, keeps nothing of the answer, and posts once while an add is in flight', async () => {
    // Mutation (Rule 19): return before publishing when the generation moved -> no event and this goes red.
    let release: (value: JsonResult<unknown>) => void = () => undefined;
    let posts = 0;
    TestBed.resetTestingModule();
    const api = {
      requestJson: async <T,>(): Promise<JsonResult<T>> => {
        posts += 1;
        return (await new Promise<JsonResult<unknown>>((resolve) => {
          release = resolve;
        })) as JsonResult<T>;
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
    const store = TestBed.inject(InteropWorkflowMemberStore);
    store.setUser('OcuP2417wA');
    const pending = store.add('USER', 'OcuP2417rA');
    expect(store.busy()).toBe(true);
    expect(await store.add('USER', 'OcuP2417rA')).toBe(false);
    store.reset();
    release(CREATED);
    expect(await pending).toBe(false);
    expect(posts).toBe(1);
    expect(events.map((event) => [event.type, event.action])).toEqual([['interop-workflow-member', 'created']]);
    expect(store.readBack()).toBeNull();
    expect(store.busy()).toBe(false);
  });
});

describe('workflowUserChoicesOf', () => {
  it('reads the names of the rows with their active flags and nothing else', () => {
    expect(workflowUserChoicesOf(null)).toEqual([]);
    expect(workflowUserChoicesOf({})).toEqual([]);
    expect(workflowUserChoicesOf({ rows: 'x' })).toEqual([]);
    expect(workflowUserChoicesOf({ rows: [{ Name: 'a', IsActive: true }, { Name: 'b', IsActive: false }, { Name: '' }, 'junk', { Name: 7 }, { Name: 'c' }] })).toEqual([
      { name: 'a', active: true },
      { name: 'b', active: false },
      { name: 'c', active: true },
    ]);
  });
});
