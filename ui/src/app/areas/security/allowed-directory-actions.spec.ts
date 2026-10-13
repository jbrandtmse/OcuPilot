import { TestBed } from '@angular/core/testing';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type ApiRequestInit, type JsonResult } from '../../core/api';
import { ChangeBus, type ChangeEvent } from '../../core/change-bus';
import { ScopeService } from '../../core/scope';
import { ScreenActions } from '../../core/screen-actions';
import { ScreenStores } from '../../core/screen-store';
import { SCREENS } from '../../core/screens.generated';
import { STRINGS } from '../../core/strings';
import { ALLOWED_DIRECTORIES_PATH, ALLOWED_DIRECTORY_LIST } from '../../shell/screen-action-handler';
import { stubAccountPreferences } from '../../testing/account-preferences';
import { AllowedDirectoryActions } from './allowed-directory-actions';

/**
 * The Allowed directories screen's service (Story 18.46): the instance's verdict on the write's key, the dialogs an action
 * opens, and the three sends. The real handler, stores, change bus and `ScreenActions` run; only the transport is stubbed.
 */

const SCREEN = SCREENS.find((entry) => entry.descriptor === ALLOWED_DIRECTORY_LIST)!;

const TARGET = { type: 'allowed-directory', scope: 'instance', id: '%GUIFileSelector' };

const MANAGER = '/iris/mgr/';

const FALLBACK_ROW = { Directory: MANAGER, Restricted: false };

const RESTRICTED_ROWS = [
  { Directory: MANAGER, Restricted: true },
  { Directory: '/data/a/', Restricted: true },
];

interface Call {
  readonly path: string;
  readonly method: string;
  readonly body: string;
}

async function settle(): Promise<void> {
  for (let pass = 0; pass < 4; pass += 1) await new Promise((resolve) => setTimeout(resolve, 2));
}

/** The verdict answers in turn; every POST answers `post`. */
function mount(verdicts: readonly (JsonResult<unknown> | Promise<JsonResult<unknown>>)[] = [{ kind: 'ok', status: 200, body: { enabled: true } }], post: JsonResult<unknown> = { kind: 'ok', status: 200, body: { action: 'created', target: TARGET, readBack: {} } }) {
  TestBed.resetTestingModule();
  const calls: Call[] = [];
  let reads = 0;
  const api = {
    requestJson: async <T,>(path: string, init: ApiRequestInit = {}): Promise<JsonResult<T>> => {
      const method = init.method ?? 'GET';
      calls.push({ path, method, body: init.body ?? '' });
      if (method === 'POST') return post as JsonResult<T>;
      const answer = verdicts[Math.min(reads, verdicts.length - 1)];
      reads += 1;
      return (await answer) as JsonResult<T>;
    },
  };
  const bus = new ChangeBus();
  const events: ChangeEvent[] = [];
  bus.subscribe((event) => events.push(event));
  const stores = new ScreenStores({ account: stubAccountPreferences() });
  TestBed.configureTestingModule({
    providers: [
      { provide: ApiService, useValue: api as unknown as ApiService },
      { provide: ChangeBus, useValue: bus },
      { provide: ScreenStores, useValue: stores },
      { provide: ScreenActions, useValue: new ScreenActions() },
      { provide: ScopeService, useValue: { namespace: () => 'USER' } as unknown as ScopeService },
    ],
  });
  const service = TestBed.inject(AllowedDirectoryActions);
  const store = stores.for(SCREEN.descriptor, SCREEN.refreshRates);
  return { service, store, calls, events, actions: TestBed.inject(ScreenActions) };
}

/** Give the screen's store the rows its read answered, then select `selected`. */
function show(store: ReturnType<typeof mount>['store'], rows: readonly unknown[], selected = ''): void {
  store.applyTick(rows as never, false, '', new Date());
  store.setSelection(selected === '' ? [] : [selected]);
}

afterEach(() => {
  TestBed.resetTestingModule();
});

describe('the Allowed directories verdict', () => {
  it('reads GET /allowed-directories, and a disabled key is the sentence the instance wrote, announced to the surfaces', async () => {
    // Mutation (Rule 19): ignore `enabled` in `reasonOf` -> a disabled key leaves the actions drawn on, red.
    const sentence = 'Changing the allowed directories is switched off on this instance (probe).';
    const { service, calls, actions } = mount([{ kind: 'ok', status: 200, body: { enabled: false, code: 'ALLOWLIST.OFF', reason: sentence } }]);
    let heard = 0;
    actions.subscribe(() => (heard += 1));
    await service.load();
    expect(calls).toEqual([{ path: ALLOWED_DIRECTORIES_PATH, method: 'GET', body: '' }]);
    expect(service.reason()).toBe(sentence);
    expect(heard, 'once when cleared, once when answered').toBe(2);
  });

  it('is empty while the key is enabled, and a disabled key that carries no sentence is the published one for its code', async () => {
    const enabled = mount([{ kind: 'ok', status: 200, body: { enabled: true } }]);
    await enabled.service.load();
    expect(enabled.service.reason()).toBe('');

    const bare = mount([{ kind: 'ok', status: 200, body: { enabled: false, code: 'ALLOWLIST.OFF' } }]);
    await bare.service.load();
    expect(bare.service.reason()).toBe(STRINGS.allowListRefusalOff);
  });

  it('reads a refused read as its envelope\u2019s own sentence, and a read that did not answer as none', async () => {
    const refused = mount([{ kind: 'error', status: 403, code: 'AUTH.NOPRIVILEGE', reason: 'Requires %Admin_FileSystemAccess:USE', detail: null }]);
    await refused.service.load();
    expect(refused.service.reason()).toBe('Requires %Admin_FileSystemAccess:USE');

    const down = mount([{ kind: 'installing', status: 503, code: null }]);
    await down.service.load();
    expect(down.service.reason()).toBe('');
  });

  it('clears the verdict before it reads', async () => {
    const off = { kind: 'ok', status: 200, body: { enabled: false, reason: 'off' } } as JsonResult<unknown>;
    const on = { kind: 'ok', status: 200, body: { enabled: true } } as JsonResult<unknown>;
    const { service } = mount([off, on]);
    await service.load();
    expect(service.reason()).toBe('off');
    const next = service.load();
    expect(service.reason(), 'cleared while the next read is out').toBe('');
    await next;
    expect(service.reason()).toBe('');
  });

  it('settles only the newest read: an older answer that lands last is dropped', async () => {
    // Mutation (Rule 19): drop the `ask !== this.asked` guard in `load` -> the older answer overwrites the newer and this goes red.
    const off = { kind: 'ok', status: 200, body: { enabled: false, reason: 'older' } } as JsonResult<unknown>;
    const on = { kind: 'ok', status: 200, body: { enabled: true } } as JsonResult<unknown>;
    let release: (value: JsonResult<unknown>) => void = () => {};
    const slow = new Promise<JsonResult<unknown>>((resolve) => (release = resolve));
    const { service } = mount([slow, on]);
    const older = service.load();
    await service.load();
    expect(service.reason()).toBe('');
    release(off);
    await older;
    expect(service.reason(), 'the newest answer stands').toBe('');
  });
});

describe('the Allowed directories dialogs', () => {
  it('opens Add with the list noted as unrestricted when a row reads Restricted false, and as restricted otherwise', () => {
    const unrestricted = mount();
    show(unrestricted.store, [FALLBACK_ROW]);
    unrestricted.service.open('add');
    expect(unrestricted.service.pending()).toEqual({ action: 'add', directory: '', unrestricted: true });

    const restricted = mount();
    show(restricted.store, RESTRICTED_ROWS);
    restricted.service.open('add');
    expect(restricted.service.pending()).toEqual({ action: 'add', directory: '', unrestricted: false });
  });

  it('opens Change and Remove on the selected row, and on none when nothing is selected', () => {
    const { service, store } = mount();
    show(store, RESTRICTED_ROWS);
    service.open('change');
    service.open('remove');
    expect(service.pending(), 'no selected row opens nothing').toBeNull();

    show(store, RESTRICTED_ROWS, '/data/a/');
    service.open('change');
    expect(service.pending()).toEqual({ action: 'change', directory: '/data/a/', unrestricted: false });
    service.cancel();
    service.open('remove');
    expect(service.pending()).toEqual({ action: 'remove', directory: '/data/a/', unrestricted: false });
  });

  it('refuses Change and Remove on the unrestricted fallback row with the published sentence on the list\u2019s banner, and opens nothing', () => {
    // Mutation (Rule 19): skip the `selfProtectionReason` check in `open` -> the dialog opens on the fallback row, red.
    const { service, store, calls } = mount();
    show(store, [FALLBACK_ROW], MANAGER);
    for (const action of ['change', 'remove'] as const) {
      store.setRefusal('');
      service.open(action);
      expect(service.pending(), action).toBeNull();
      expect(store.refusal(), action).toBe(STRINGS.allowListRefusalFallback);
    }
    expect(calls).toEqual([]);
  });

  it('opens no dialog over another', () => {
    const { service, store } = mount();
    show(store, RESTRICTED_ROWS, '/data/a/');
    service.open('change');
    service.open('add');
    service.open('remove');
    expect(service.pending()?.action).toBe('change');
  });
});

describe('the Allowed directories sends', () => {
  it('sends an Add with the typed directory as its target, publishes the one change event, and reads the verdict again', async () => {
    // Mutation (Rule 19): drop the `load()` after the send -> no second GET, red.
    const { service, store, calls, events } = mount();
    show(store, RESTRICTED_ROWS);
    service.open('add');
    await service.confirm('/data/b/');
    await settle();
    expect(service.pending()).toBeNull();
    expect(calls.map((call) => [call.method, call.path, call.body === '' ? null : JSON.parse(call.body)])).toEqual([
      ['POST', ALLOWED_DIRECTORIES_PATH, { Action: 'add', Directory: '/data/b/' }],
      ['GET', ALLOWED_DIRECTORIES_PATH, null],
    ]);
    expect(events).toHaveLength(1);
    expect(events[0]).toMatchObject({ kind: 'changed', type: 'allowed-directory', id: '%GUIFileSelector' });
  });

  it('sends a Change with the selected row as its directory and the typed one as NewDirectory', async () => {
    // Mutation (Rule 19): drop `NewDirectory` from the send -> the body loses it and this goes red.
    const { service, store, calls } = mount();
    show(store, RESTRICTED_ROWS, '/data/a/');
    service.open('change');
    await service.confirm('/data/b/');
    await settle();
    expect(JSON.parse(calls[0].body)).toEqual({ Action: 'change', Directory: '/data/a/', NewDirectory: '/data/b/' });
  });

  it('sends a Remove with the selected row as its directory and nothing else', async () => {
    const { service, store, calls } = mount();
    show(store, RESTRICTED_ROWS, '/data/a/');
    service.open('remove');
    await service.confirm();
    await settle();
    expect(JSON.parse(calls[0].body)).toEqual({ Action: 'remove', Directory: '/data/a/' });
  });

  it('sends nothing for an Add or a Change that names no directory, and nothing at all once the dialog was cancelled', async () => {
    // Mutation (Rule 19): guard only the Add against a blank value in `confirm` -> the blank Change is sent and this goes red.
    const { service, store, calls } = mount();
    show(store, RESTRICTED_ROWS, '/data/a/');
    service.open('add');
    await service.confirm('');
    service.open('change');
    await service.confirm('');
    service.open('change');
    service.cancel();
    await service.confirm('/data/b/');
    await settle();
    expect(calls).toEqual([]);
  });

  it('puts a refused write\u2019s sentence on the list\u2019s banner, publishes nothing, and reads the verdict again', async () => {
    const refused = { kind: 'error', status: 403, code: 'ALLOWLIST.OFF', reason: STRINGS.allowListRefusalOff, detail: null } as JsonResult<unknown>;
    const off = { kind: 'ok', status: 200, body: { enabled: false, code: 'ALLOWLIST.OFF', reason: STRINGS.allowListRefusalOff } } as JsonResult<unknown>;
    const { service, store, calls, events } = mount([off], refused);
    show(store, RESTRICTED_ROWS);
    service.open('add');
    await service.confirm('/data/b/');
    await settle();
    expect(store.refusal()).toBe(STRINGS.allowListRefusalOff);
    expect(events).toEqual([]);
    expect(calls.map((call) => call.method)).toEqual(['POST', 'GET']);
    expect(service.reason(), 'and the actions are now drawn off').toBe(STRINGS.allowListRefusalOff);
  });
});
