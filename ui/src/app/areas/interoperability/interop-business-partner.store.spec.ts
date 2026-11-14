import { TestBed } from '@angular/core/testing';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type ApiRequestInit, type JsonResult } from '../../core/api';
import { ChangeBus, type ChangeEvent } from '../../core/change-bus';
import { STRINGS } from '../../core/strings';
import { INTEROP_PARTNER_ADD_TOOL, INTEROP_PARTNER_PATH, INTEROP_PARTNER_VALUE_FIELDS, InteropBusinessPartnerStore } from './interop-business-partner.store';

/**
 * Business partners' form store (Story 20.26) over a stub of the Save: the body it posts, the namespace it scopes the post to,
 * the change event an accepted add publishes, the two kinds of refusal it keeps -- one on a field, one naming none -- and the
 * state an Edit leaves in it.
 */

interface Sent {
  readonly path: string;
  readonly scope: string | null | undefined;
  readonly body: unknown;
}

const CREATED: JsonResult<unknown> = {
  kind: 'ok',
  status: 201,
  body: { id: 'Probe Partner', target: { type: 'business-partner', scope: 'USER', id: 'Probe Partner' }, readBack: { verdict: 'matches' } },
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
  return { store: TestBed.inject(InteropBusinessPartnerStore), sent, events };
}

afterEach(() => {
  TestBed.resetTestingModule();
});

describe('InteropBusinessPartnerStore', () => {
  it('posts the name and all thirteen fields as typed, empty ones included, to the namespace given, and publishes one created event naming the add tool', async () => {
    const { store, sent, events } = mount(() => CREATED);
    store.set('Name', 'Probe Partner');
    store.set('Description', 'a description');
    store.set('PrimaryPhone', '555-0100');
    expect(await store.add('USER')).toBe(true);
    // Mutation (Rule 19): drop `scope: namespace` from the shared post -> the scope reads undefined and this goes red.
    expect(sent).toHaveLength(1);
    expect(sent[0].path).toBe(INTEROP_PARTNER_PATH);
    expect(sent[0].scope).toBe('USER');
    const body = sent[0].body as Record<string, string>;
    expect(Object.keys(body).sort()).toEqual(['Name', ...INTEROP_PARTNER_VALUE_FIELDS].sort());
    expect(body['Name']).toBe('Probe Partner');
    expect(body['Description']).toBe('a description');
    expect(body['PrimaryPhone']).toBe('555-0100');
    expect(body['AlternativeNotes']).toBe('');
    // Mutation (Rule 19): drop `tool` from the published event -> the event carries none and this goes red.
    expect(events.map((event) => [event.kind, event.type, event.scope, event.id, event.action, event.tool])).toEqual([
      ['changed', 'business-partner', 'USER', 'Probe Partner', 'created', INTEROP_PARTNER_ADD_TOOL],
    ]);
    expect(INTEROP_PARTNER_ADD_TOOL).toBe('interop.businesspartners.add');
    expect(store.readBack()?.verdict).toBe('matches');
  });

  it('keeps a refusal on a field and the fields entered, publishes nothing, and a new value clears it', async () => {
    const violation = { field: 'PrimaryPhone', code: 'INTEROP.PARTNER.LENGTH', reason: STRINGS.interopPartnerRefusalLength };
    const { store, events } = mount(() => ({ kind: 'error', status: 422, code: 'INTEROP.PARTNER.LENGTH', reason: STRINGS.interopPartnerRefusalLength, detail: { violations: [violation] } }));
    store.set('Name', 'Probe Partner');
    store.set('PrimaryPhone', 'x'.repeat(51));
    expect(await store.add('USER')).toBe(false);
    expect(store.violation('PrimaryPhone')).toBe(STRINGS.interopPartnerRefusalLength);
    expect(store.reason()).toBe('');
    expect(store.value('PrimaryPhone')).toBe('x'.repeat(51));
    expect(events).toEqual([]);
    store.set('PrimaryPhone', '555');
    expect(store.violation('PrimaryPhone')).toBe('');
  });

  it('keeps a refusal that names no field as the dialog\u2019s reason, until the form is reset', async () => {
    const { store, events } = mount(() => ({ kind: 'error', status: 409, code: 'INTEROP.PARTNER.TAKEN', reason: STRINGS.interopPartnerRefusalTaken, detail: null }));
    store.set('Name', 'Probe Partner');
    expect(await store.add('USER')).toBe(false);
    expect(store.reason()).toBe(STRINGS.interopPartnerRefusalTaken);
    expect(events).toEqual([]);
    store.reset();
    expect(store.reason()).toBe('');
    expect(store.value('Name')).toBe('');
  });

  it('holds the values an Edit starts from, and an Edit\u2019s refusal and applied end', () => {
    const { store } = mount(() => CREATED);
    store.reset({ Name: 'Probe Partner', Description: 'held' });
    expect(store.values()['Name']).toBe('Probe Partner');
    expect(store.value('Description')).toBe('held');
    expect(store.value('PrimaryContact')).toBe('');
    const generation = store.begin();
    expect(store.busy()).toBe(true);
    expect(store.current(generation)).toBe(true);
    store.refuse([{ field: 'Description', code: 'INTEROP.PARTNER.LENGTH', reason: STRINGS.interopPartnerRefusalLength }], 'unused');
    expect(store.busy()).toBe(false);
    expect(store.violation('Description')).toBe(STRINGS.interopPartnerRefusalLength);
    expect(store.reason()).toBe('');
    store.refuse([], STRINGS.interopPartnerRefusalSourceControl);
    expect(store.reason()).toBe(STRINGS.interopPartnerRefusalSourceControl);
    store.reset();
    expect(store.current(generation)).toBe(false);
  });

  it('announces a partner the instance added after the dialog was dismissed, and keeps nothing of the answer', async () => {
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
    const store = TestBed.inject(InteropBusinessPartnerStore);
    store.set('Name', 'Probe Partner');
    const pending = store.add('USER');
    store.reset();
    release(CREATED);
    expect(await pending).toBe(false);
    expect(events.map((event) => [event.type, event.id, event.action])).toEqual([['business-partner', 'Probe Partner', 'created']]);
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
    const store = TestBed.inject(InteropBusinessPartnerStore);
    store.set('Name', 'Probe Partner');
    const first = store.add('USER');
    expect(store.busy()).toBe(true);
    expect(await store.add('USER')).toBe(false);
    release({ kind: 'ok', status: 201, body: {} });
    expect(await first).toBe(true);
    expect(posts).toBe(1);
  });
});
