import { TestBed } from '@angular/core/testing';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type ApiRequestInit, type JsonResult } from '../../core/api';
import { ChangeBus, type ChangeEvent } from '../../core/change-bus';
import { STRINGS } from '../../core/strings';
import { INTEROP_ITEM_COPY_PATH, INTEROP_ITEM_COPY_TOOL, InteropItemCopyStore } from './interop-item-copy.store';

/**
 * Production items' copy store (Story 20.40) over a stub of the Save: the body it posts and the namespace it scopes
 * the post to, the change event an accepted copy publishes, and the two kinds of refusal it keeps -- one on the name,
 * one naming no field.
 */

interface Sent {
  readonly path: string;
  readonly scope: string | null | undefined;
  readonly body: unknown;
}

const ID = 'Probe.Production\u0001ProbeCopy';

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
  return { store: TestBed.inject(InteropItemCopyStore), sent, events };
}

afterEach(() => {
  TestBed.resetTestingModule();
});

describe('InteropItemCopyStore', () => {
  it('posts the production, the new name and the source to the namespace given, and publishes one created event for the item the server names', async () => {
    const { store, sent, events } = mount(() => ({ kind: 'ok', status: 201, body: { id: ID, target: { type: 'production-item', scope: 'USER', id: ID }, readBack: { verdict: 'matches' } } }));
    store.setName('ProbeCopy');
    expect(await store.copy('USER', 'Probe.Production', 'ProbeOp')).toBe(true);
    // Mutation (Rule 19): post to the add's route -> the path reads /interop/items and this goes red.
    expect(sent).toEqual([{ path: INTEROP_ITEM_COPY_PATH, scope: 'USER', body: { Production: 'Probe.Production', Name: 'ProbeCopy', CopyFrom: 'ProbeOp' } }]);
    expect(INTEROP_ITEM_COPY_PATH).toBe('/api/ocupilot/interop/items/copy');
    expect(events.map((event) => [event.kind, event.type, event.scope, event.id, event.action, event.tool])).toEqual([
      ['changed', 'production-item', 'USER', ID, 'created', INTEROP_ITEM_COPY_TOOL],
    ]);
    expect(INTEROP_ITEM_COPY_TOOL).toBe('interop.items.copy');
    expect(store.readBack()?.verdict).toBe('matches');
  });

  it('keeps a refusal on the name and the name entered, publishes nothing, and a new value clears it', async () => {
    const violation = { field: 'Name', code: 'INTEROP.ITEM.NAME', reason: STRINGS.interopItemRefusalName };
    const { store, events } = mount(() => ({ kind: 'error', status: 422, code: 'INTEROP.ITEM.NAME', reason: STRINGS.interopItemRefusalName, detail: { violations: [violation] } }));
    store.setName('-bad');
    expect(await store.copy('USER', 'Probe.Production', 'ProbeOp')).toBe(false);
    expect(store.violation('Name')).toBe(STRINGS.interopItemRefusalName);
    expect(store.reason()).toBe('');
    expect(store.name()).toBe('-bad');
    expect(events).toEqual([]);
    store.setName('good');
    expect(store.violation('Name')).toBe('');
  });

  it('shows a refusal on the source, and one that names no field, as the dialog\u2019s reason, until the dialog is reset', async () => {
    // Mutation (Rule 19): count every member as drawn in `refuse` -> the reason reads '' and this goes red.
    const violation = { field: 'CopyFrom', code: 'INTEROP.ITEM.COPYSOURCE', reason: STRINGS.interopItemRefusalCopySource };
    const { store } = mount(() => ({ kind: 'error', status: 422, code: 'INTEROP.ITEM.COPYSOURCE', reason: STRINGS.interopItemRefusalCopySource, detail: { violations: [violation] } }));
    store.setName('ProbeCopy');
    expect(await store.copy('USER', 'Probe.Production', 'Gone')).toBe(false);
    expect(store.reason()).toBe(STRINGS.interopItemRefusalCopySource);
    store.reset();
    expect(store.reason()).toBe('');
    expect(store.name()).toBe('');
    const taken = mount(() => ({ kind: 'error', status: 409, code: 'INTEROP.ITEM.TAKEN', reason: STRINGS.interopItemRefusalTaken, detail: null }));
    taken.store.setName('ProbeOp');
    expect(await taken.store.copy('USER', 'Probe.Production', 'ProbeOp')).toBe(false);
    expect(taken.store.reason()).toBe(STRINGS.interopItemRefusalTaken);
    expect(taken.events).toEqual([]);
  });

  it('announces a copy the instance added after the dialog was dismissed, and keeps nothing of the answer', async () => {
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
    const store = TestBed.inject(InteropItemCopyStore);
    store.setName('ProbeCopy');
    const pending = store.copy('USER', 'Probe.Production', 'ProbeOp');
    store.reset();
    release({ kind: 'ok', status: 201, body: { id: ID, target: { type: 'production-item', scope: 'USER', id: ID }, readBack: { verdict: 'matches' } } });
    expect(await pending).toBe(false);
    expect(events.map((event) => [event.kind, event.type, event.scope, event.id, event.action])).toEqual([['changed', 'production-item', 'USER', ID, 'created']]);
    expect(store.readBack()).toBeNull();
    expect(store.busy()).toBe(false);
  });

  it('posts once while a copy is in flight', async () => {
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
    const store = TestBed.inject(InteropItemCopyStore);
    store.setName('ProbeCopy');
    const first = store.copy('USER', 'Probe.Production', 'ProbeOp');
    expect(store.busy()).toBe(true);
    expect(await store.copy('USER', 'Probe.Production', 'ProbeOp')).toBe(false);
    release({ kind: 'ok', status: 201, body: {} });
    expect(await first).toBe(true);
    expect(posts).toBe(1);
  });
});
