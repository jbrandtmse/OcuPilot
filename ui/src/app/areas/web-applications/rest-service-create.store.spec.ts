import { TestBed } from '@angular/core/testing';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type ApiRequestInit, type JsonResult } from '../../core/api';
import { ChangeBus, type ChangeEvent } from '../../core/change-bus';
import { REST_SERVICE_CREATE_PATH, RestServiceCreateStore } from './rest-service-create.store';

/**
 * The REST API explorer's create store (Story 18.34) over a stub of the Save: the package and the
 * document text it posts as typed and the namespace it scopes the post to, the change event an
 * accepted create publishes, also once the dialog is gone, and the three kinds of refusal it keeps -- one on Name, one on
 * Document, one naming neither.
 */

interface Sent {
  readonly path: string;
  readonly scope: string | null | undefined;
  readonly body: unknown;
}

const TEXT = '{"swagger": "2.0", "info": {"title": "probe", "version": "1"}, "x": 12345678901234567890}';

function mount(answer: () => JsonResult<unknown> | Promise<JsonResult<unknown>>) {
  TestBed.resetTestingModule();
  const sent: Sent[] = [];
  const api = {
    requestJson: async <T,>(path: string, init?: ApiRequestInit): Promise<JsonResult<T>> => {
      sent.push({ path, scope: init?.scope, body: typeof init?.body === 'string' ? JSON.parse(init.body) : null });
      return (await answer()) as JsonResult<T>;
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
  return { store: TestBed.inject(RestServiceCreateStore), sent, events };
}

function refusal(status: number, code: string, reason: string, violations: readonly { field: string; code: string; reason: string }[]): JsonResult<unknown> {
  return { kind: 'error', status, code, reason, detail: violations.length === 0 ? null : { violations } } as JsonResult<unknown>;
}

afterEach(() => {
  TestBed.resetTestingModule();
});

describe('RestServiceCreateStore', () => {
  it('posts the package and the document text exactly as typed to the namespace given, and publishes one created event in that namespace', async () => {
    const { store, sent, events } = mount(() => ({ kind: 'ok', status: 201, body: { name: 'OcuProbe1832A', readBack: { verdict: 'matches' } } }));
    store.setName('OcuProbe1832A');
    store.setDocumentText(TEXT);
    expect(await store.create('USER')).toBe(true);
    // Mutation (Rule 19): drop `scope: namespace` from the post -> the scope reads undefined and this goes red.
    expect(sent).toEqual([{ path: REST_SERVICE_CREATE_PATH, scope: 'USER', body: { Name: 'OcuProbe1832A', Document: TEXT } }]);
    // Mutation (Rule 19): drop `readBack` from the published event -> the row's read-back is lost and this goes red.
    expect(events.map((event) => [event.kind, event.type, event.scope, event.id, event.action, event.readBack?.verdict])).toEqual([
      ['changed', 'rest-service', 'USER', 'OcuProbe1832A', 'created', 'matches'],
    ]);
    expect(store.readBack()?.verdict).toBe('matches');
  });

  it('publishes the created event for a create the instance answers after the dialog was dismissed, and keeps nothing', async () => {
    let release: (result: JsonResult<unknown>) => void = () => undefined;
    const pending = new Promise<JsonResult<unknown>>((resolve) => {
      release = resolve;
    });
    const { store, events } = mount(() => pending);
    store.setName('OcuProbe1832A');
    store.setDocumentText(TEXT);
    const created = store.create('USER');
    store.reset();
    release({ kind: 'ok', status: 201, body: { name: 'OcuProbe1832A', readBack: { verdict: 'matches' } } });
    expect(await created).toBe(false);
    // Mutation (Rule 19): publish nothing once the generation moved -> the list stays stale and this goes red.
    expect(events.map((event) => [event.type, event.scope, event.id, event.action, event.readBack?.verdict])).toEqual([['rest-service', 'USER', 'OcuProbe1832A', 'created', 'matches']]);
    expect([store.name(), store.documentText(), store.busy(), store.readBack()]).toEqual(['', '', false, null]);
  });

  it('keeps a refusal on Name and one on Document, and both fields, publishes nothing, and a new value in either field clears them', async () => {
    const violations = [
      { field: 'Name', code: 'RESTSERVICE.TAKEN', reason: 'name sentence' },
      { field: 'Document', code: 'RESTSERVICE.DOCUMENT', reason: 'document sentence' },
    ];
    const { store, events } = mount(() => refusal(422, 'RESTSERVICE.TAKEN', 'name sentence', violations));
    store.setName('OcuProbe1832A');
    store.setDocumentText('not json');
    expect(await store.create('USER')).toBe(false);
    expect(store.nameViolation()).toBe('name sentence');
    expect(store.documentViolation()).toBe('document sentence');
    expect(store.reason()).toBe('');
    expect([store.name(), store.documentText()]).toEqual(['OcuProbe1832A', 'not json']);
    expect(events).toEqual([]);
    store.setDocumentText('{}');
    expect([store.nameViolation(), store.documentViolation()]).toEqual(['', '']);
    expect(await store.create('USER')).toBe(false);
    // Mutation (Rule 19): drop `clearRefusal` from `setName` -> the refusals outlive a new package and this goes red.
    store.setName('OcuProbe1832B');
    expect([store.nameViolation(), store.documentViolation()]).toEqual(['', '']);
  });

  it('keeps a refusal that names no field as the dialog\u2019s reason, and a reset forgets everything', async () => {
    const { store, events } = mount(() => refusal(409, 'WRITE.TARGETBUSY', 'busy sentence', []));
    store.setName('OcuProbe1832A');
    store.setDocumentText(TEXT);
    expect(await store.create('USER')).toBe(false);
    expect(store.reason()).toBe('busy sentence');
    expect([store.nameViolation(), store.documentViolation()]).toEqual(['', '']);
    expect(events).toEqual([]);
    store.reset();
    expect([store.reason(), store.name(), store.documentText()]).toEqual(['', '', '']);
  });
});
