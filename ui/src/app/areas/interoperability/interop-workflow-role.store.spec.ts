import { TestBed } from '@angular/core/testing';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type ApiRequestInit, type JsonResult } from '../../core/api';
import { ChangeBus, type ChangeEvent } from '../../core/change-bus';
import { STRINGS } from '../../core/strings';
import { INTEROP_WORKFLOW_ROLE_ADD_TOOL, INTEROP_WORKFLOW_ROLE_PATH, InteropWorkflowRoleStore, capacityValue } from './interop-workflow-role.store';

/**
 * Workflow roles' form store (Story 24.17 Batch 3b) over a stub of the Save: the body it posts, the capacity as a number, the namespace it scopes the
 * call to, the change event an accepted add publishes, the two kinds of refusal it keeps -- one on a field, one naming none -- and the state an Edit
 * leaves in it.
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
  body: { id: 'OcuP2417rA', target: { type: 'interop-workflow-role', scope: 'USER', id: 'OcuP2417rA' }, readBack: { verdict: 'matches' } },
};

function mount(answer: () => JsonResult<unknown>) {
  TestBed.resetTestingModule();
  const sent: Sent[] = [];
  const api = {
    requestJson: async <T,>(path: string, init?: ApiRequestInit): Promise<JsonResult<T>> => {
      sent.push({ path, method: init?.method ?? 'GET', scope: init?.scope, body: typeof init?.body === 'string' ? JSON.parse(init.body) : null });
      return answer() as JsonResult<T>;
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
  return { store: TestBed.inject(InteropWorkflowRoleStore), sent, events };
}

afterEach(() => {
  TestBed.resetTestingModule();
});

describe('InteropWorkflowRoleStore', () => {
  it('posts the name, the description and the capacity as a number to the namespace given, and publishes the created event', async () => {
    const { store, sent, events } = mount(() => CREATED);
    store.setName('OcuP2417rA');
    store.setDescription('Order approvals');
    store.setCapacity('40');
    expect(await store.add('USER')).toBe(true);
    // Mutation (Rule 19): drop `scope: namespace` from the shared post -> the scope reads undefined and this goes red.
    expect(sent).toHaveLength(1);
    expect(sent[0].path).toBe(INTEROP_WORKFLOW_ROLE_PATH);
    expect(sent[0].method).toBe('POST');
    expect(sent[0].scope).toBe('USER');
    // Mutation (Rule 19): send the capacity as the text typed -> the number assertion goes red.
    expect(sent[0].body).toEqual({ Name: 'OcuP2417rA', Description: 'Order approvals', Capacity: 40 });
    expect(typeof (sent[0].body as Record<string, unknown>)['Capacity']).toBe('number');
    // Mutation (Rule 19): drop `tool` from the published event -> the event carries none and this goes red.
    expect(events.map((event) => [event.kind, event.type, event.scope, event.action, event.tool])).toEqual([
      ['changed', 'interop-workflow-role', 'USER', 'created', INTEROP_WORKFLOW_ROLE_ADD_TOOL],
    ]);
    expect(INTEROP_WORKFLOW_ROLE_ADD_TOOL).toBe('interop.workflowroles.add');
    expect(store.readBack()?.verdict).toBe('matches');
  });

  it('leaves an empty description and an empty capacity out of the post', async () => {
    const { store, sent } = mount(() => CREATED);
    store.setName('OcuP2417rA');
    expect(await store.add('USER')).toBe(true);
    expect(sent[0].body).toEqual({ Name: 'OcuP2417rA' });
  });

  it('keeps a refusal on a field and the values entered, publishes nothing, and a new value clears it', async () => {
    const violation = { field: 'Capacity', code: 'INTEROP.WORKFLOW.ROLECAPACITY', reason: STRINGS.interopWorkflowRoleRefusalCapacity };
    const { store, events } = mount(() => ({
      kind: 'error',
      status: 422,
      code: 'INTEROP.WORKFLOW.ROLECAPACITY',
      reason: STRINGS.interopWorkflowRoleRefusalCapacity,
      detail: { violations: [violation] },
    }));
    store.setName('OcuP2417rA');
    store.setCapacity('101');
    expect(await store.add('USER')).toBe(false);
    expect(store.violation('Capacity')).toBe(STRINGS.interopWorkflowRoleRefusalCapacity);
    expect(store.reason()).toBe('');
    expect(store.capacity()).toBe('101');
    expect(events).toEqual([]);
    store.setCapacity('100');
    expect(store.violation('Capacity')).toBe('');
  });

  it('keeps a refusal that names no field as the reason of the dialog, until the form is reset', async () => {
    const { store, events } = mount(() => ({
      kind: 'error',
      status: 409,
      code: 'INTEROP.WORKFLOW.ROLETAKEN',
      reason: STRINGS.interopWorkflowRoleRefusalTaken,
      detail: null,
    }));
    store.setName('OcuP2417rA');
    expect(await store.add('USER')).toBe(false);
    expect(store.reason()).toBe(STRINGS.interopWorkflowRoleRefusalTaken);
    expect(events).toEqual([]);
    store.reset();
    expect(store.reason()).toBe('');
    expect(store.name()).toBe('');
  });

  it('holds the values an Edit starts from, and the refusal and the applied end of an Edit', () => {
    const { store } = mount(() => CREATED);
    store.reset({ name: 'OcuP2417rA', description: 'Orders', capacity: '40' });
    expect(store.values()).toEqual({ name: 'OcuP2417rA', description: 'Orders', capacity: '40' });
    const generation = store.begin();
    expect(store.busy()).toBe(true);
    expect(store.current(generation)).toBe(true);
    store.refuse([{ field: 'Description', code: 'INTEROP.WORKFLOW.ROLEDESCRIPTION', reason: STRINGS.interopWorkflowRoleRefusalDescription }], 'unused');
    expect(store.busy()).toBe(false);
    expect(store.violation('Description')).toBe(STRINGS.interopWorkflowRoleRefusalDescription);
    expect(store.reason()).toBe('');
    store.refuse([], STRINGS.interopWorkflowUserRefusalSourceControl);
    expect(store.reason()).toBe(STRINGS.interopWorkflowUserRefusalSourceControl);
    store.reset();
    expect(store.current(generation)).toBe(false);
    expect(store.capacity()).toBe('');
  });

  it('announces a workflow role the instance added after the dialog was dismissed, and keeps nothing of the answer', async () => {
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
    const store = TestBed.inject(InteropWorkflowRoleStore);
    store.setName('OcuP2417rA');
    const pending = store.add('USER');
    expect(store.busy()).toBe(true);
    expect(await store.add('USER')).toBe(false);
    store.reset();
    release(CREATED);
    expect(await pending).toBe(false);
    expect(events.map((event) => [event.type, event.action])).toEqual([['interop-workflow-role', 'created']]);
    expect(store.readBack()).toBeNull();
    expect(store.busy()).toBe(false);
  });
});

describe('capacityValue', () => {
  it('reads text that is a number as a number, and leaves anything else as typed for the server to refuse', () => {
    expect(capacityValue('40')).toBe(40);
    expect(capacityValue(' 7 ')).toBe(7);
    expect(capacityValue('1.5')).toBe(1.5);
    expect(capacityValue('many')).toBe('many');
    expect(capacityValue('0x10')).toBe('0x10');
    expect(capacityValue('1e1')).toBe('1e1');
  });
});
