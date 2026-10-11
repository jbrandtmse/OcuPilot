import { TestBed } from '@angular/core/testing';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type ApiRequestInit, type JsonResult } from '../../core/api';
import { ChangeBus, type ChangeEvent } from '../../core/change-bus';
import { STRINGS } from '../../core/strings';
import { INTEROP_LOOKUP_ENTRY_ADD_TOOL, INTEROP_LOOKUP_ENTRY_PATH, InteropLookupEntryStore } from './interop-lookup-entry.store';

/**
 * Lookup tables' add store (Story 20.5) over a stub of the Save: the body it posts for a new table and for an entry
 * of a table the route names, the namespace it scopes the post to, the change event an accepted add publishes, and the
 * two kinds of refusal it keeps -- one on a field, one naming none.
 */

interface Sent {
  readonly path: string;
  readonly scope: string | null | undefined;
  readonly body: unknown;
}

const ID = 'Probe.Table\u0001ProbeKey';

const CREATED: JsonResult<unknown> = {
  kind: 'ok',
  status: 201,
  body: { id: ID, target: { type: 'lookup-entry', scope: 'USER', id: ID }, readBack: { verdict: 'matches' } },
};

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
  return { store: TestBed.inject(InteropLookupEntryStore), sent, events };
}

afterEach(() => {
  TestBed.resetTestingModule();
});

describe('InteropLookupEntryStore', () => {
  it('posts the typed table, key and value for a new table to the namespace given, and publishes one created event for the entry the server names', async () => {
    const { store, sent, events } = mount(() => CREATED);
    store.set('table', 'Probe.Table');
    store.set('key', 'ProbeKey');
    store.set('value', 'a value');
    expect(await store.add('USER', null)).toBe(true);
    // Mutation (Rule 19): drop `scope: namespace` from the shared post -> the scope reads undefined and this goes red.
    expect(sent).toEqual([{ path: INTEROP_LOOKUP_ENTRY_PATH, scope: 'USER', body: { Table: 'Probe.Table', Key: 'ProbeKey', Value: 'a value' } }]);
    expect(events.map((event) => [event.kind, event.type, event.scope, event.id, event.action])).toEqual([['changed', 'lookup-entry', 'USER', ID, 'created']]);
    expect(store.readBack()?.verdict).toBe('matches');
  });

  it('posts the table it was given in place of the one typed, for an entry added to a table the route names', async () => {
    const { store, sent } = mount(() => CREATED);
    store.set('table', 'Typed.Elsewhere');
    store.set('key', 'ProbeKey');
    expect(await store.add('USER', 'Route.Table')).toBe(true);
    // Mutation (Rule 19): always send the typed table -> the route's table is lost and this goes red.
    expect((sent[0].body as Record<string, unknown>)['Table']).toBe('Route.Table');
  });

  it('sends an empty value as an empty string, which is an entry with no value', async () => {
    const { store, sent } = mount(() => CREATED);
    store.set('key', 'ProbeKey');
    expect(await store.add('USER', 'Route.Table')).toBe(true);
    expect(sent[0].body).toEqual({ Table: 'Route.Table', Key: 'ProbeKey', Value: '' });
  });

  it('names the add tool on the event it publishes, so its toast opens the entries and not another list of the type', async () => {
    const { store, events } = mount(() => CREATED);
    store.set('key', 'ProbeKey');
    expect(await store.add('USER', 'Route.Table')).toBe(true);
    // Mutation (Rule 19): drop `tool` from the published event -> the event carries none and this goes red.
    expect(events.map((event) => event.tool)).toEqual([INTEROP_LOOKUP_ENTRY_ADD_TOOL]);
    expect(INTEROP_LOOKUP_ENTRY_ADD_TOOL).toBe('interop.lookupentries.add');
  });

  it('keeps a refusal on a field and the fields entered, publishes nothing, and a new value clears it', async () => {
    const violation = { field: 'Key', code: 'INTEROP.LOOKUP.KEY', reason: STRINGS.interopLookupRefusalKey };
    const { store, events } = mount(() => ({ kind: 'error', status: 422, code: 'INTEROP.LOOKUP.KEY', reason: STRINGS.interopLookupRefusalKey, detail: { violations: [violation] } }));
    store.set('table', 'Probe.Table');
    store.set('key', 'bad\u0001key');
    store.set('value', 'kept');
    expect(await store.add('USER', null)).toBe(false);
    expect(store.violation('Key')).toBe(STRINGS.interopLookupRefusalKey);
    expect(store.reason()).toBe('');
    expect(store.key()).toBe('bad\u0001key');
    expect(store.value()).toBe('kept');
    expect(events).toEqual([]);
    store.set('key', 'good');
    expect(store.violation('Key')).toBe('');
  });

  it('keeps a refusal that names no field as the dialog\u2019s reason, until the dialog is reset', async () => {
    const { store, events } = mount(() => ({ kind: 'error', status: 409, code: 'INTEROP.LOOKUP.TAKEN', reason: STRINGS.interopLookupRefusalTaken, detail: null }));
    store.set('key', 'ProbeKey');
    expect(await store.add('USER', 'Route.Table')).toBe(false);
    expect(store.reason()).toBe(STRINGS.interopLookupRefusalTaken);
    expect(events).toEqual([]);
    store.reset();
    expect(store.reason()).toBe('');
    expect(store.key()).toBe('');
  });

  it('shows a refusal on a member the dialog draws no field for as the dialog\u2019s reason', async () => {
    // Mutation (Rule 19): count every member the store sends as drawn in `refuse` -> the reason reads '' and this goes red.
    const violation = { field: 'Namespace', code: 'PORT.FIELD.SHAPE', reason: 'The namespace is not named.' };
    const { store } = mount(() => ({ kind: 'error', status: 422, code: 'PORT.FIELD.SHAPE', reason: 'The namespace is not named.', detail: { violations: [violation] } }));
    store.set('key', 'ProbeKey');
    expect(await store.add('', 'Route.Table')).toBe(false);
    expect(store.reason()).toBe('The namespace is not named.');
  });

  it('announces an entry the instance added after the dialog was dismissed, and keeps nothing of the answer', async () => {
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
    const store = TestBed.inject(InteropLookupEntryStore);
    store.set('key', 'ProbeKey');
    const pending = store.add('USER', 'Route.Table');
    store.reset();
    release(CREATED);
    expect(await pending).toBe(false);
    expect(events.map((event) => [event.kind, event.type, event.scope, event.id, event.action])).toEqual([['changed', 'lookup-entry', 'USER', ID, 'created']]);
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
    const store = TestBed.inject(InteropLookupEntryStore);
    store.set('key', 'ProbeKey');
    const first = store.add('USER', 'Route.Table');
    expect(store.busy()).toBe(true);
    expect(await store.add('USER', 'Route.Table')).toBe(false);
    release({ kind: 'ok', status: 201, body: {} });
    expect(await first).toBe(true);
    expect(posts).toBe(1);
  });
});
