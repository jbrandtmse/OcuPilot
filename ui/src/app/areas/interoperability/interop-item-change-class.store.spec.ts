import { TestBed } from '@angular/core/testing';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type ApiRequestInit, type JsonResult } from '../../core/api';
import { STRINGS } from '../../core/strings';
import { INTEROP_ITEM_CLASSES_PATH, INTEROP_ITEM_CLASSES_TOOL, InteropItemChangeClassStore } from './interop-item-change-class.store';

/**
 * Production items' change class picker store (Story 20.41) over a stub of the Classes tab's read: the request it makes, the rows it keeps
 * less the item's own class, the choice it holds, and the refusal it reports.
 */

const ROWS = [
  { Production: 'Probe.Production', Item: 'ProbeOp', ClassName: 'Probe.Op', Type: 'operation', Current: true },
  { Production: 'Probe.Production', Item: 'ProbeOp', ClassName: 'Probe.TearOp', Type: 'operation', Current: false },
  { Production: 'Probe.Production', Item: 'ProbeOp', ClassName: 'Probe.RetryOp', Type: 'operation', Current: false },
];

function mount(answer: () => JsonResult<unknown>) {
  TestBed.resetTestingModule();
  const sent: string[] = [];
  const api = {
    requestJson: async <T,>(path: string, _init?: ApiRequestInit): Promise<JsonResult<T>> => {
      sent.push(path);
      return answer() as JsonResult<T>;
    },
  };
  TestBed.configureTestingModule({ providers: [{ provide: ApiService, useValue: api as unknown as ApiService }] });
  return { store: TestBed.inject(InteropItemChangeClassStore), sent };
}

afterEach(() => {
  TestBed.resetTestingModule();
});

describe('InteropItemChangeClassStore', () => {
  it('reads the Classes tab\u2019s screen read for the item, and offers every class but the item\u2019s own', async () => {
    // Mutation (Rule 19): read `interop.items` in place of the Classes tab's tool -> the path assertion goes red; keep the `Current` row -> the offered list holds Probe.Op.
    const { store, sent } = mount(() => ({ kind: 'ok', status: 200, body: { rows: ROWS } }));
    await store.load('Probe.Production', 'ProbeOp');
    expect(INTEROP_ITEM_CLASSES_TOOL).toBe('interop.itemclasses');
    expect(sent).toEqual([`${INTEROP_ITEM_CLASSES_PATH}?maxRows=1000&item=Probe.Production%7C%7CProbeOp`]);
    expect(INTEROP_ITEM_CLASSES_PATH).toBe('/api/ocupilot/screens/interop.itemclasses/read');
    expect(store.options().map((option) => option.name)).toEqual(['Probe.TearOp', 'Probe.RetryOp']);
    expect(store.options()[0]).toEqual({ name: 'Probe.TearOp', type: 'operation' });
    expect(store.loaded()).toBe(true);
    expect(store.loading()).toBe(false);
    expect(store.reason()).toBe('');
  });

  it('holds a choice only among the classes offered, and a reset forgets the rows, the choice and the refusal', async () => {
    const { store } = mount(() => ({ kind: 'ok', status: 200, body: { rows: ROWS } }));
    await store.load('Probe.Production', 'ProbeOp');
    store.choose('Probe.TearOp');
    expect(store.choice()).toBe('Probe.TearOp');
    store.choose('Probe.Op');
    expect(store.choice(), 'the item\u2019s own class is not offered, so it is no choice').toBe('');
    store.choose('Probe.RetryOp');
    store.reset();
    expect([store.choice(), store.options().length, store.loaded(), store.reason()]).toEqual(['', 0, false, '']);
  });

  it('reports the server\u2019s sentence for a read it refuses and offers nothing', async () => {
    const { store } = mount(() => ({ kind: 'error', status: 409, code: 'INTEROP.ITEM.AMBIGUOUS', reason: STRINGS.interopItemRefusalAmbiguous, detail: null }));
    await store.load('Probe.Production', 'ProbeOp');
    expect(store.reason()).toBe(STRINGS.interopItemRefusalAmbiguous);
    expect(store.options()).toEqual([]);
    expect(store.loaded()).toBe(false);
  });

  it('answers an empty list as loaded and refused by nothing, and drops a read that a reset superseded', async () => {
    const { store } = mount(() => ({ kind: 'ok', status: 200, body: { rows: [ROWS[0]] } }));
    const pending = store.load('Probe.Production', 'ProbeOp');
    store.reset();
    await pending;
    expect(store.loaded(), 'a superseded read leaves nothing').toBe(false);
    await store.load('Probe.Production', 'ProbeOp');
    expect([store.loaded(), store.options().length, store.reason()]).toEqual([true, 0, '']);
  });
});
