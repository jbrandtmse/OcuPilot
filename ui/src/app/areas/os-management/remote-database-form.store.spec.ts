import { TestBed } from '@angular/core/testing';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type ApiRequestInit, type JsonResult } from '../../core/api';
import { ChangeBus, type ChangeEvent } from '../../core/change-bus';
import { encodeEntityId } from '../../core/entity-id';
import { FormDirty } from '../../core/form-dirty';
import {
  REMOTE_DATABASE_DIRECTORIES_PATH,
  REMOTE_DATABASE_FORM_PATH,
  REMOTE_DATABASE_PATH,
  RemoteDatabaseForm,
} from './remote-database-form.store';

/**
 * The remote database form's store (Story 18.16, AC2, AC3, AC5, AD-4, AD-14, AD-39, AD-55).
 *
 * It pins what no browser leg on a Community instance can reach: a listing that answers rows, the
 * running state while one is in flight, a stale listing answer discarded, the create's one body, an
 * edit sending only the changed field, and the change event a Save publishes. The bus is real; the
 * server's answers are stubbed, and a listing answer is held until the test releases it.
 */

const UNREACHABLE = 'The data server could not be reached in time. Check that it is running and that this instance\'s license includes ECP.';

const RULES = {
  requiredFields: ['Name', 'Server', 'Directory'],
  rules: [
    { field: 'Name', code: 'DATABASE.NAME.REQUIRED', reason: 'Name the database.' },
    { field: 'Directory', code: 'DATABASE.REMOTEDIRECTORY.NONE', reason: 'Choose the database\'s directory on the data server.' },
  ],
  listSeconds: 7,
  servers: [
    { Name: 'DATASRV', Status: 'Normal' },
    { Name: 'OTHERSRV', Status: 'Not Connected' },
  ],
};

const CONFIGURATION = {
  Server: 'DATASRV',
  Directory: '/data/one/',
  StreamLocation: '/streams/',
  ClusterMountMode: false,
  MountAtStartup: false,
  MountRequired: false,
};

const LISTED = {
  server: 'DATASRV',
  rows: [
    { Name: 'ONE', Directory: '/data/one/' },
    { Name: 'TWO', Directory: '/data/two/' },
  ],
  truncated: false,
};

const REFUSED_LISTING = {
  kind: 'error',
  status: 422,
  code: 'DATABASE.SERVER.UNREACHABLE',
  reason: UNREACHABLE,
  detail: { violations: [{ field: 'Server', code: 'DATABASE.SERVER.UNREACHABLE', reason: UNREACHABLE }] },
};

async function settle(): Promise<void> {
  for (let pass = 0; pass < 4; pass += 1) await new Promise((resolve) => setTimeout(resolve, 2));
}

interface Call {
  readonly path: string;
  readonly method: string;
  readonly body: string;
}

/** A listing answer the test releases when it chooses. */
interface Held {
  readonly path: string;
  release(answer: unknown): void;
}

function mount(saveAnswer: unknown = { kind: 'ok', status: 201, body: { name: 'PROBEREMOTE' } }) {
  TestBed.resetTestingModule();
  const calls: Call[] = [];
  const held: Held[] = [];
  const api = {
    requestJson: async <T,>(path: string, init: ApiRequestInit = {}): Promise<JsonResult<T>> => {
      calls.push({ path, method: init.method ?? 'GET', body: init.body ?? '' });
      if (path === REMOTE_DATABASE_FORM_PATH) return { kind: 'ok', status: 200, body: RULES } as unknown as JsonResult<T>;
      if (path.startsWith(`${REMOTE_DATABASE_FORM_PATH}?`)) {
        return { kind: 'ok', status: 200, body: { ...RULES, Name: 'PROBEREMOTE', configuration: CONFIGURATION } } as unknown as JsonResult<T>;
      }
      if (path.startsWith(REMOTE_DATABASE_DIRECTORIES_PATH)) {
        return new Promise<JsonResult<T>>((resolve) => {
          held.push({ path, release: (answer) => resolve(answer as JsonResult<T>) });
        });
      }
      return saveAnswer as JsonResult<T>;
    },
  };
  const bus = new ChangeBus();
  const events: ChangeEvent[] = [];
  bus.subscribe((event) => events.push(event));
  const formDirty = new FormDirty();
  TestBed.configureTestingModule({
    providers: [
      { provide: ApiService, useValue: api as unknown as ApiService },
      { provide: ChangeBus, useValue: bus },
      { provide: FormDirty, useValue: formDirty },
    ],
  });
  return { store: TestBed.inject(RemoteDatabaseForm), calls, held, events, formDirty };
}

/** The five fields a change event carries about the write, the bus's own bookkeeping aside. */
function shape(event: ChangeEvent): Record<string, unknown> {
  const { kind, type, scope, id, action } = event as unknown as Record<string, unknown>;
  return { kind, type, scope, id, action };
}

function writes(calls: readonly Call[]): Call[] {
  return calls.filter((call) => call.method !== 'GET');
}

afterEach(() => {
  TestBed.resetTestingModule();
});

describe('the remote database form store', () => {
  it('a create opens with the bound and the data servers the form read answered, and lists nothing', async () => {
    const { store, calls } = mount();
    await store.open('');
    expect(store.mode()).toBe('create');
    // The form read's bound, not the client's fallback (REMOTE_DATABASE_LIST_SECONDS, 20).
    expect(store.listSeconds()).toBe(7);
    expect(store.servers()).toEqual(['DATASRV', 'OTHERSRV']);
    expect(store.directories()).toEqual([]);
    expect(store.listing()).toEqual({ kind: 'idle' });
    expect(calls.map((call) => call.path)).toEqual([REMOTE_DATABASE_FORM_PATH]);
  });

  it('AC5: choosing a server clears the directory, records the running listing and then offers its rows', async () => {
    const { store, calls, held, formDirty } = mount();
    await store.open('');
    const before = Date.now();
    const choosing = store.chooseServer('DATASRV');
    expect(calls.at(-1)?.path).toBe(`${REMOTE_DATABASE_DIRECTORIES_PATH}?server=DATASRV`);
    const running = store.running();
    expect(running?.server).toBe('DATASRV');
    expect(running?.since.getTime()).toBeGreaterThanOrEqual(before);
    expect(store.canSave()).toBe(false);
    expect(formDirty.dirty()).toBe(true);

    held[0]?.release({ kind: 'ok', status: 200, body: LISTED });
    await choosing;
    expect(store.running()).toBeNull();
    expect(store.directories()).toEqual([
      { name: 'ONE', directory: '/data/one/' },
      { name: 'TWO', directory: '/data/two/' },
    ]);
    expect(store.listedNone()).toBe('');
  });

  it('AC5: a refused listing offers nothing and renders its reason on Data server', async () => {
    const { store, held } = mount();
    await store.open('');
    const choosing = store.chooseServer('OTHERSRV');
    held[0]?.release(REFUSED_LISTING);
    await choosing;
    expect(store.listing()).toEqual({ kind: 'refused', server: 'OTHERSRV' });
    expect(store.violationFor('Server')).toBe(UNREACHABLE);
    expect(store.directories()).toEqual([]);
    expect(store.reason()).toBe('');
    expect(store.canSave()).toBe(true);
  });

  it('an empty listing says the server lists no databases', async () => {
    const { store, held } = mount();
    await store.open('');
    const choosing = store.chooseServer('DATASRV');
    held[0]?.release({ kind: 'ok', status: 200, body: { server: 'DATASRV', rows: [], truncated: false } });
    await choosing;
    expect(store.listedNone()).toBe('DATASRV');
    expect(store.directories()).toEqual([]);
  });

  it('a listing answer a later choice superseded is discarded', async () => {
    const { store, held } = mount();
    await store.open('');
    const first = store.chooseServer('DATASRV');
    const second = store.chooseServer('OTHERSRV');
    held[1]?.release(REFUSED_LISTING);
    await second;
    // Mutation (Rule 19): drop the `listingGeneration` check after the listing answers -> DATASRV's late
    // rows replace OTHERSRV's refusal and this goes red.
    held[0]?.release({ kind: 'ok', status: 200, body: LISTED });
    await first;
    expect(store.value('Server')).toBe('OTHERSRV');
    expect(store.listing()).toEqual({ kind: 'refused', server: 'OTHERSRV' });
    expect(store.directories()).toEqual([]);
  });

  it('AC2, AD-14: a create posts the name, the server and the listed directory, and publishes one created event', async () => {
    const { store, calls, held, events, formDirty } = mount();
    await store.open('');
    store.setValue('Name', 'PROBEREMOTE');
    const choosing = store.chooseServer('DATASRV');
    held[0]?.release({ kind: 'ok', status: 200, body: LISTED });
    await choosing;
    store.setValue('Directory', '/data/two/');
    const saving = store.save();
    expect(store.running()?.server).toBe('DATASRV');
    expect(await saving).toBe(true);
    await settle();
    const [write] = writes(calls);
    expect(write?.path).toBe(REMOTE_DATABASE_PATH);
    expect(write?.method).toBe('POST');
    expect(JSON.parse(write?.body ?? '{}')).toEqual({ Name: 'PROBEREMOTE', Server: 'DATASRV', Directory: '/data/two/' });
    // Mutation (Rule 19): drop `this.publish(...)` from `save()` -> no event and this goes red.
    expect(events.map(shape)).toEqual([
      { kind: 'changed', type: 'database-configuration', scope: 'instance', id: 'PROBEREMOTE', action: 'created' },
    ]);
    expect(store.running()).toBeNull();
    expect(store.createdId()).toBe('PROBEREMOTE');
    expect(formDirty.dirty()).toBe(false);
  });

  it('AC3, AD-4: an edit offers just the stored directory until a server is chosen, and puts only what changed', async () => {
    const { store, calls, events } = mount({ kind: 'ok', status: 200, body: { name: 'PROBEREMOTE' } });
    await store.open('PROBEREMOTE');
    // Mutation (Rule 19): the form read names the configuration under another key than `name` -> red.
    expect(calls[0]?.path).toBe(`${REMOTE_DATABASE_FORM_PATH}?name=${encodeURIComponent('PROBEREMOTE')}`);
    expect(store.mode()).toBe('edit');
    expect([store.value('Name'), store.value('Server'), store.value('Directory'), store.value('StreamLocation')]).toEqual([
      'PROBEREMOTE',
      'DATASRV',
      '/data/one/',
      '/streams/',
    ]);
    expect(store.directories()).toEqual([{ name: '', directory: '/data/one/' }]);
    store.setValue('Name', 'RENAMED');
    store.setValue('StreamLocation', '/elsewhere/');
    expect([store.value('Name'), store.value('StreamLocation')]).toEqual(['PROBEREMOTE', '/streams/']);
    expect(await store.save()).toBe(true);
    expect(writes(calls)).toEqual([]);

    store.setValue('Directory', '/data/two/');
    expect(await store.save()).toBe(true);
    const [write] = writes(calls);
    expect(write?.path).toBe(`${REMOTE_DATABASE_PATH}/${encodeEntityId('PROBEREMOTE')}`);
    expect(write?.method).toBe('PUT');
    expect(JSON.parse(write?.body ?? '{}')).toEqual({ Directory: '/data/two/' });
    expect(events.map(shape)).toEqual([
      { kind: 'changed', type: 'database-configuration', scope: 'instance', id: 'PROBEREMOTE', action: 'updated' },
    ]);
  });

  it('AC3: List databases lists an edit\'s stored server, keeps its directory, and retries a refused listing', async () => {
    const { store, calls, held, formDirty } = mount();
    await store.open('PROBEREMOTE');
    const listing = store.listAgain();
    expect(calls.at(-1)?.path).toBe(`${REMOTE_DATABASE_DIRECTORIES_PATH}?server=DATASRV`);
    expect(store.running()?.server).toBe('DATASRV');
    held[0]?.release(REFUSED_LISTING);
    await listing;
    expect(store.violationFor('Server')).toBe(UNREACHABLE);
    // Mutation (Rule 19): make `listAgain` return at once -> no second listing is sent and this goes red.
    const retry = store.listAgain();
    expect(held.length).toBe(2);
    expect(store.violationFor('Server')).toBe('');
    held[1]?.release({ kind: 'ok', status: 200, body: LISTED });
    await retry;
    expect(store.value('Directory')).toBe('/data/one/');
    expect(store.directories()).toEqual([
      { name: 'ONE', directory: '/data/one/' },
      { name: 'TWO', directory: '/data/two/' },
    ]);
    expect(formDirty.dirty()).toBe(false);
  });

  it('AD-39: a refused Save lands each violation on its field and keeps what was entered', async () => {
    const { store, events } = mount({
      kind: 'error',
      status: 422,
      code: 'DATABASE.VALIDATION',
      reason: 'The database was refused.',
      detail: {
        violations: [
          { field: 'Name', code: 'DATABASE.NAME.SHAPE', reason: 'A database name starts with a letter.' },
          { field: 'Directory', code: 'DATABASE.REMOTEDIRECTORY.NONE', reason: 'Choose the database\'s directory on the data server.' },
        ],
      },
    });
    await store.open('');
    store.setValue('Name', '1AB');
    expect(await store.save()).toBe(false);
    expect(store.violationFor('Name')).toBe('A database name starts with a letter.');
    expect(store.violationFor('Directory')).toBe('Choose the database\'s directory on the data server.');
    expect(store.value('Name')).toBe('1AB');
    expect(store.reason()).toBe('');
    expect(events).toEqual([]);
  });

  it('a reset discards a listing still in flight', async () => {
    const { store, held } = mount();
    await store.open('');
    const choosing = store.chooseServer('DATASRV');
    store.reset();
    held[0]?.release({ kind: 'ok', status: 200, body: LISTED });
    await choosing;
    expect(store.listing()).toEqual({ kind: 'idle' });
    expect(store.value('Server')).toBe('');
  });
});
