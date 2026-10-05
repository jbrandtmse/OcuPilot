import { TestBed } from '@angular/core/testing';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type ApiRequestInit, type JsonResult } from '../../core/api';
import { ChangeBus, type ChangeEvent } from '../../core/change-bus';
import { STRINGS } from '../../core/strings';
import { DOCDB_CREATE_PATH, DocDbCreateStore } from './docdb-create.store';

/**
 * Document databases' create store (Story 19.17) over a stub of the Save: the one name it posts and
 * the namespace it scopes the post to, the change event an accepted create publishes, and the two
 * kinds of refusal it keeps -- one on Name, one naming no field.
 */

interface Sent {
  readonly path: string;
  readonly scope: string | null | undefined;
  readonly body: unknown;
}

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
  return { store: TestBed.inject(DocDbCreateStore), sent, events };
}

afterEach(() => {
  TestBed.resetTestingModule();
});

describe('DocDbCreateStore', () => {
  it('AC4: posts the name as typed to the namespace given, and publishes one created event in that namespace', async () => {
    const { store, sent, events } = mount(() => ({ kind: 'ok', status: 201, body: { name: 'OcuProbe1917A', readBack: { verdict: 'matches' } } }));
    store.setName('OcuProbe1917A');
    expect(await store.create('USER')).toBe(true);
    // Mutation (Rule 19): drop `scope: namespace` from the post -> the scope reads undefined and this goes red.
    expect(sent).toEqual([{ path: DOCDB_CREATE_PATH, scope: 'USER', body: { Name: 'OcuProbe1917A' } }]);
    expect(events.map((event) => [event.kind, event.type, event.scope, event.id, event.action])).toEqual([
      ['changed', 'docdb-database', 'USER', 'OcuProbe1917A', 'created'],
    ]);
    expect(store.readBack()?.verdict).toBe('matches');
  });

  it('AC4: keeps a refusal on Name and the name entered, publishes nothing, and a new name clears it', async () => {
    const violation = { field: 'Name', code: 'DOCDB.NAME.INVALID', reason: STRINGS.explorerDocDbNameInvalid };
    const { store, events } = mount(() => ({ kind: 'error', status: 422, code: 'DOCDB.NAME.INVALID', reason: STRINGS.explorerDocDbNameInvalid, detail: { violations: [violation] } }));
    store.setName('a_b');
    expect(await store.create('USER')).toBe(false);
    expect(store.nameViolation()).toBe(STRINGS.explorerDocDbNameInvalid);
    expect(store.reason()).toBe('');
    expect(store.name()).toBe('a_b');
    expect(events).toEqual([]);
    store.setName('ab');
    expect(store.nameViolation()).toBe('');
  });

  it('keeps a refusal that names no field as the dialog\u2019s reason', async () => {
    const { store, events } = mount(() => ({ kind: 'error', status: 409, code: 'DOCDB.NAME.TAKEN', reason: STRINGS.explorerDocDbNameTaken, detail: null }));
    store.setName('ocuprobe1917a');
    expect(await store.create('USER')).toBe(false);
    expect(store.reason()).toBe(STRINGS.explorerDocDbNameTaken);
    expect(store.nameViolation()).toBe('');
    expect(events).toEqual([]);
    store.reset();
    expect(store.reason()).toBe('');
    expect(store.name()).toBe('');
  });
});
