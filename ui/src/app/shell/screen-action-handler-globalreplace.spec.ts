import { TestBed } from '@angular/core/testing';
import { afterEach, describe, expect, it, vi } from 'vitest';

import { ApiService, type ApiRequestInit, type JsonResult } from '../core/api';
import { ChangeBus, type ChangeEvent } from '../core/change-bus';
import { ScopeService } from '../core/scope';
import { ScreenActions } from '../core/screen-actions';
import { ScreenStores } from '../core/screen-store';
import { SCREENS } from '../core/screens.generated';
import { STRINGS } from '../core/strings';
import { stubAccountPreferences } from '../testing/account-preferences';
import { ScreenActionHandler } from './screen-action-handler';

/**
 * The Globals list's Replace through the generic handler (Story 21.18, AD-53): the Global nodes page starts it, the action is dry-run at
 * `POST /screens/explorer.globals/dryrun`, the typed-name dialog opens over the counts the review answers -- the find, the replacement, whether case
 * matters, the nodes and the occurrences -- typed by the global's name and stating the replace's consequence, and the confirm sends the same action with
 * the three values and the digest of the review, then ends with the change event and no outcome dialog.
 */

const LIST = 'OcuPilot.Screen.Descriptor.ExplorerGlobalList';

const DRY_RUN_PATH = '/api/ocupilot/screens/explorer.globals/dryrun';

const ACTION_PATH = '/api/ocupilot/screens/explorer.globals/action';

const DIGEST = 'd'.repeat(64);

const VALUES = { Find: 'abc', Replace: 'xyz', MatchCase: 'true' };

interface Call {
  readonly path: string;
  readonly method: string;
  readonly body: Record<string, unknown>;
}

const ROWS = [
  { field: 'Find', before: '', after: 'abc' },
  { field: 'Replace', before: '', after: 'xyz' },
  { field: 'MatchCase', before: '', after: 'true' },
  { field: 'Nodes', before: '', after: '3' },
  { field: 'Occurrences', before: '', after: '5' },
];

function dryRun(rows: readonly Record<string, unknown>[], digest = DIGEST): JsonResult<unknown> {
  return { kind: 'ok', status: 200, body: { rows, review: { Digest: digest } } };
}

function mount(answer: (call: Call) => JsonResult<unknown>) {
  TestBed.resetTestingModule();
  const calls: Call[] = [];
  const api = {
    requestJson: async <T,>(path: string, init: ApiRequestInit = {}): Promise<JsonResult<T>> => {
      const call: Call = { path, method: init.method ?? 'GET', body: init.body ? (JSON.parse(init.body) as Record<string, unknown>) : {} };
      calls.push(call);
      return answer(call) as JsonResult<T>;
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
  const actions = TestBed.inject(ScreenActions);
  const handler = TestBed.inject(ScreenActionHandler);
  const globals = SCREENS.find((entry) => entry.descriptor === LIST)!;
  const store = stores.for(globals.descriptor, globals.refreshRates);
  return { actions, handler, store, calls, events };
}

async function settle(): Promise<void> {
  for (let pass = 0; pass < 6; pass += 1) await new Promise((resolve) => setTimeout(resolve, 2));
}

afterEach(() => {
  TestBed.resetTestingModule();
});

describe('Replace through the generic handler (Story 21.18)', () => {
  it('declares Replace on the list and draws it nowhere: the Global nodes page starts it', () => {
    // Mutation (Rule 19): drop `replace` from the `UNDRAWN_ACTIONS` entry of the list -> the handler registers it and this goes red.
    const { actions } = mount(() => dryRun(ROWS));
    expect(SCREENS.find((entry) => entry.descriptor === LIST)?.rowActions.map((action) => action.id)).toContain('replace');
    expect(actions.has(LIST, 'replace')).toBe(false);
    expect(actions.has(LIST, 'delete')).toBe(true);
  });

  it('dry-runs the replace with its three values and opens the review typed by the name of the global over the counts', async () => {
    // Mutation (Rule 19): drop the list from `DRY_RUN_ACTIONS` -> no request is made and this goes red; draw a row with no before-text as `- field:` -> the lines go red;
    // state the delete consequence -> the consequence assertion goes red.
    const { handler, store, calls } = mount(() => dryRun(ROWS));
    expect(await handler.startDryRun(LIST, 'replace', 'ZZG', VALUES, store, 'ZZG')).toBe(true);
    expect(calls).toHaveLength(1);
    expect(calls[0]).toMatchObject({ path: DRY_RUN_PATH, method: 'POST', body: { action: 'replace', id: 'ZZG', values: VALUES } });
    const pending = handler.pending();
    expect(pending?.kind).toBe('typed-name');
    expect(pending?.name).toBe('ZZG');
    expect(pending?.verb).toBe(STRINGS.explorerGlobalFindAndReplace);
    expect(pending?.consequence).toBe(STRINGS.globalReplaceConsequence);
    expect(pending?.review).toEqual(['Find: abc', 'Replace: xyz', 'MatchCase: true', 'Nodes: 3', 'Occurrences: 5']);
    expect(pending?.reviewed).toBe(DIGEST);
    expect(pending?.reviewValues).toEqual(VALUES);
  });

  it('puts a refused review on the banner of the list and opens no dialog', async () => {
    const { handler, store } = mount(() => ({ kind: 'error', status: 409, code: 'GLOBAL.REPLACE.NOCHANGE', reason: STRINGS.globalRefusalNoChange, detail: null }));
    expect(await handler.startDryRun(LIST, 'replace', 'ZZG', VALUES, store, 'ZZG')).toBe(false);
    expect(handler.pending()).toBeNull();
    expect(store.refusal()).toBe(STRINGS.globalRefusalNoChange);
  });

  it('sends the confirmed replace with its values and the digest of the review, publishes the change and opens no outcome dialog', async () => {
    // Mutation (Rule 19): drop `Reviewed` from the values -> the body assertion goes red.
    const { handler, store, calls, events } = mount((call) =>
      call.path === DRY_RUN_PATH ? dryRun(ROWS) : { kind: 'ok', status: 200, body: { action: 'updated', target: { type: 'global', scope: 'USER', id: 'ZZG' } } }
    );
    await handler.startDryRun(LIST, 'replace', 'ZZG', VALUES, store, 'ZZG');
    handler.confirmPending();
    await vi.waitFor(() => expect(calls).toHaveLength(2));
    await settle();
    expect(calls[1]).toMatchObject({ path: ACTION_PATH, method: 'POST', body: { action: 'replace', id: 'ZZG', values: { ...VALUES, Reviewed: DIGEST } } });
    expect(events.map((event) => `${event.kind}|${'action' in event ? event.action : ''}`)).toEqual(['changed|updated']);
    expect(handler.pending()).toBeNull();
  });

  it('reports the sentence of a confirmed replace the instance refused because the global moved, and publishes nothing', async () => {
    const { handler, store, events } = mount((call) =>
      call.path === DRY_RUN_PATH ? dryRun(ROWS) : { kind: 'error', status: 409, code: 'GLOBAL.REPLACE.REVIEWCHANGED', reason: STRINGS.globalRefusalReviewChanged, detail: null }
    );
    await handler.startDryRun(LIST, 'replace', 'ZZG', VALUES, store, 'ZZG');
    handler.confirmPending();
    await vi.waitFor(() => expect(handler.pending()?.kind).toBe('outcome'));
    expect(handler.pending()?.refusal).toBe(STRINGS.globalRefusalReviewChanged);
    expect(events).toEqual([]);
  });
});
