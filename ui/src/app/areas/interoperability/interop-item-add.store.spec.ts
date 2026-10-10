import { TestBed } from '@angular/core/testing';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type ApiRequestInit, type JsonResult } from '../../core/api';
import { ChangeBus, type ChangeEvent } from '../../core/change-bus';
import { STRINGS } from '../../core/strings';
import { INTEROP_ITEM_ADD_PATH, InteropItemAddStore } from './interop-item-add.store';

/**
 * Production items' add store (Story 20.3) over a stub of the Save: the body it posts and the namespace it scopes
 * the post to, the change event an accepted add publishes, and the two kinds of refusal it keeps -- one on a
 * field, one naming none.
 */

interface Sent {
  readonly path: string;
  readonly scope: string | null | undefined;
  readonly body: unknown;
}

const ID = 'Probe.Production\u0001ProbeNew';

function mount(answer: () => JsonResult<unknown>) {
  TestBed.resetTestingModule();
  const sent: Sent[] = [];
  const api = {
    requestJson: async <T,>(path: string, init?: ApiRequestInit): Promise<JsonResult<T>> => {
      sent.push({ path, scope: init?.scope, body: typeof init?.body === 'string' ? JSON.parse(init.body) : null });
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
  return { store: TestBed.inject(InteropItemAddStore), sent, events };
}

afterEach(() => {
  TestBed.resetTestingModule();
});

describe('InteropItemAddStore', () => {
  it('posts the six fields as typed to the namespace given, and publishes one created event for the item the server names', async () => {
    const { store, sent, events } = mount(() => ({ kind: 'ok', status: 201, body: { id: ID, target: { type: 'production-item', scope: 'USER', id: ID }, readBack: { verdict: 'matches' } } }));
    store.set('name', 'ProbeNew');
    store.set('className', 'Probe.Op');
    store.set('poolSize', '2');
    store.setEnabled(true);
    store.set('category', 'Probe');
    store.set('comment', 'a comment');
    expect(await store.add('USER', 'Probe.Production')).toBe(true);
    // Mutation (Rule 19): drop `scope: namespace` from the post -> the scope reads undefined and this goes red.
    expect(sent).toEqual([
      {
        path: INTEROP_ITEM_ADD_PATH,
        scope: 'USER',
        body: { Production: 'Probe.Production', Name: 'ProbeNew', ClassName: 'Probe.Op', Enabled: true, PoolSize: 2, Category: 'Probe', Comment: 'a comment' },
      },
    ]);
    expect(events.map((event) => [event.kind, event.type, event.scope, event.id, event.action])).toEqual([['changed', 'production-item', 'USER', ID, 'created']]);
    expect(store.readBack()?.verdict).toBe('matches');
  });

  it('sends only the fields typed, with the item disabled, and a pool size that is not a whole number as typed', async () => {
    const { store, sent } = mount(() => ({ kind: 'ok', status: 201, body: {} }));
    store.set('name', 'ProbeNew');
    store.set('className', 'Probe.Op');
    expect(await store.add('USER', 'Probe.Production')).toBe(true);
    expect(sent[0].body).toEqual({ Production: 'Probe.Production', Name: 'ProbeNew', ClassName: 'Probe.Op', Enabled: false });
    store.set('poolSize', 'many');
    await store.add('USER', 'Probe.Production');
    expect((sent[1].body as Record<string, unknown>)['PoolSize']).toBe('many');
  });

  it('keeps a refusal on a field and the fields entered, publishes nothing, and a new value clears it', async () => {
    const violation = { field: 'Name', code: 'INTEROP.ITEM.NAME', reason: STRINGS.interopItemRefusalName };
    const { store, events } = mount(() => ({ kind: 'error', status: 422, code: 'INTEROP.ITEM.NAME', reason: STRINGS.interopItemRefusalName, detail: { violations: [violation] } }));
    store.set('name', '-bad');
    store.set('className', 'Probe.Op');
    expect(await store.add('USER', 'Probe.Production')).toBe(false);
    expect(store.violation('Name')).toBe(STRINGS.interopItemRefusalName);
    expect(store.reason()).toBe('');
    expect(store.name()).toBe('-bad');
    expect(events).toEqual([]);
    store.set('name', 'good');
    expect(store.violation('Name')).toBe('');
  });

  it('keeps a refusal that names no field as the dialog\u2019s reason, until the dialog is reset', async () => {
    const { store, events } = mount(() => ({ kind: 'error', status: 409, code: 'INTEROP.ITEM.TAKEN', reason: STRINGS.interopItemRefusalTaken, detail: null }));
    store.set('name', 'ProbeOp');
    store.set('className', 'Probe.Op');
    expect(await store.add('USER', 'Probe.Production')).toBe(false);
    expect(store.reason()).toBe(STRINGS.interopItemRefusalTaken);
    expect(events).toEqual([]);
    store.reset();
    expect(store.reason()).toBe('');
    expect(store.name()).toBe('');
  });

  it('shows a refusal on a member the dialog draws no field for as the dialog\u2019s reason', async () => {
    // Mutation (Rule 19): count every member the store sends as drawn in `refuse` -> the reason reads '' and this goes red.
    const violation = { field: 'Production', code: 'PORT.FIELD.SHAPE', reason: 'The production is not named.' };
    const { store } = mount(() => ({ kind: 'error', status: 422, code: 'PORT.FIELD.SHAPE', reason: 'The production is not named.', detail: { violations: [violation] } }));
    store.set('name', 'ProbeNew');
    store.set('className', 'Probe.Op');
    expect(await store.add('USER', '')).toBe(false);
    expect(store.reason()).toBe('The production is not named.');
  });

  it('announces an item the instance added after the dialog was dismissed, and keeps nothing of the answer', async () => {
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
    const store = TestBed.inject(InteropItemAddStore);
    store.set('name', 'ProbeNew');
    store.set('className', 'Probe.Op');
    const pending = store.add('USER', 'Probe.Production');
    store.reset();
    release({ kind: 'ok', status: 201, body: { id: ID, target: { type: 'production-item', scope: 'USER', id: ID }, readBack: { verdict: 'matches' } } });
    expect(await pending).toBe(false);
    expect(events.map((event) => [event.kind, event.type, event.scope, event.id, event.action])).toEqual([['changed', 'production-item', 'USER', ID, 'created']]);
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
    const store = TestBed.inject(InteropItemAddStore);
    store.set('name', 'ProbeNew');
    store.set('className', 'Probe.Op');
    const first = store.add('USER', 'Probe.Production');
    expect(store.busy()).toBe(true);
    expect(await store.add('USER', 'Probe.Production')).toBe(false);
    release({ kind: 'ok', status: 201, body: {} });
    expect(await first).toBe(true);
    expect(posts).toBe(1);
  });
});
