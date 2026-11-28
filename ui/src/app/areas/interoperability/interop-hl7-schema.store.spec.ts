import { TestBed } from '@angular/core/testing';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type ApiRequestInit, type JsonResult } from '../../core/api';
import { ChangeBus, type ChangeEvent } from '../../core/change-bus';
import { INTEROP_HL7_SCHEMA_ADD_TOOL, INTEROP_HL7_SCHEMA_PATH, InteropHl7SchemaStore } from './interop-hl7-schema.store';

/**
 * HL7 schemas' form store (Story 24.18 Batch 1) over a stub of the Save: the body it posts, which leaves out a base and a description left empty,
 * the namespace it scopes the call to, the change event an accepted add publishes, and the two kinds of refusal it keeps, one on a field and one
 * naming none.
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
  body: { id: 'OcuProbe2418b1', target: { type: 'interop-hl7-schema', scope: 'USER', id: 'OcuProbe2418b1' }, readBack: { verdict: 'matches' } },
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
  return { store: TestBed.inject(InteropHl7SchemaStore), sent, events };
}

afterEach(() => {
  TestBed.resetTestingModule();
});

describe('InteropHl7SchemaStore', () => {
  it('posts the name, the base and the description to the namespace given, and publishes the created event', async () => {
    const { store, sent, events } = mount(() => CREATED);
    store.setName('OcuProbe2418b1');
    store.setBase('2.5.1');
    store.setDescription('Probe');
    expect(await store.add('USER')).toBe(true);
    // Mutation (Rule 19): drop `scope: namespace` from the shared post -> the scope reads undefined and this goes red.
    expect(sent.map((call) => [call.path, call.method, call.scope, call.body])).toEqual([
      [INTEROP_HL7_SCHEMA_PATH, 'POST', 'USER', { Name: 'OcuProbe2418b1', Base: '2.5.1', Description: 'Probe' }],
    ]);
    expect(events.map((event) => [event.type, event.id, event.action, event.tool])).toEqual([['interop-hl7-schema', 'OcuProbe2418b1', 'created', INTEROP_HL7_SCHEMA_ADD_TOOL]]);
    expect(INTEROP_HL7_SCHEMA_ADD_TOOL).toBe('interop.hl7schemas.add');
  });

  it('leaves a base and a description left empty out of the post', async () => {
    const { store, sent } = mount(() => CREATED);
    store.setName('OcuProbe2418b1');
    await store.add('USER');
    expect(sent[0].body).toEqual({ Name: 'OcuProbe2418b1' });
  });

  it('keeps a refusal on a field under that field, with no envelope reason, and clears it when the field changes', async () => {
    const violation = { field: 'Base', code: 'INTEROP.HL7.BASE', reason: 'Choose a base schema this namespace holds, or none.' };
    const { store, events } = mount(() => ({ kind: 'error', status: 422, code: 'INTEROP.HL7.BASE', reason: violation.reason, detail: { violations: [violation] } }));
    store.setName('OcuProbe2418b1');
    store.setBase('9.9');
    expect(await store.add('USER')).toBe(false);
    expect(store.violation('Base')).toBe(violation.reason);
    expect(store.reason()).toBe('');
    expect(store.busy()).toBe(false);
    expect(events).toEqual([]);
    store.setBase('');
    expect(store.violation('Base')).toBe('');
  });

  it('keeps a refusal that names no field as the dialog\'s reason', async () => {
    const reason = 'This namespace already has an HL7 schema with that name, in some letter case.';
    const { store } = mount(() => ({ kind: 'error', status: 409, code: 'INTEROP.HL7.TAKEN', reason, detail: null }));
    store.setName('OcuProbe2418b1');
    expect(await store.add('USER')).toBe(false);
    expect(store.reason()).toBe(reason);
    expect(store.violation('Name')).toBe('');
  });

  it('forgets everything on reset, and does not post twice while a post is in flight', async () => {
    let release: (result: JsonResult<unknown>) => void = () => undefined;
    const sent: unknown[] = [];
    TestBed.resetTestingModule();
    const api = {
      requestJson: <T,>(path: string): Promise<JsonResult<T>> => {
        sent.push(path);
        return new Promise((resolve) => {
          release = resolve as (result: JsonResult<unknown>) => void;
        });
      },
    };
    TestBed.configureTestingModule({ providers: [{ provide: ApiService, useValue: api as unknown as ApiService }, { provide: ChangeBus, useValue: new ChangeBus() }] });
    const store = TestBed.inject(InteropHl7SchemaStore);
    store.setName('OcuProbe2418b1');
    const first = store.add('USER');
    expect(store.busy()).toBe(true);
    expect(await store.add('USER')).toBe(false);
    expect(sent).toHaveLength(1);
    release(CREATED);
    expect(await first).toBe(true);
    store.reset();
    expect([store.name(), store.base(), store.description(), store.busy()]).toEqual(['', '', '', false]);
  });
});
