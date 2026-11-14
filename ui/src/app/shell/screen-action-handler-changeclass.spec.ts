import { TestBed } from '@angular/core/testing';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type ApiRequestInit, type JsonResult } from '../core/api';
import { ChangeBus, type ChangeEvent } from '../core/change-bus';
import { joinCompositeId } from '../core/entity-id';
import { ScopeService } from '../core/scope';
import { ScreenActions } from '../core/screen-actions';
import { ScreenStores } from '../core/screen-store';
import { SCREENS } from '../core/screens.generated';
import { STRINGS } from '../core/strings';
import { stubAccountPreferences } from '../testing/account-preferences';
import { ScreenActionHandler } from './screen-action-handler';

/**
 * Production items' Change class through the generic handler (Story 20.41, AD-53): the page opens its own class dialog, and the class it
 * chooses is dry-run at `POST /screens/interop.items/dryrun`; the typed-name dialog opens over the review -- the class change and each
 * setting the new class does not take -- typed by the item's name, never its composite id; and the confirm sends the same action with the
 * chosen class and the digest of the review, then ends with the change event and no outcome dialog.
 */

const LIST = 'OcuPilot.Screen.Descriptor.InteropItemList';

const DRY_RUN_PATH = '/api/ocupilot/screens/interop.items/dryrun';

const ACTION_PATH = '/api/ocupilot/screens/interop.items/action';

const ID = joinCompositeId(['Probe.Production', 'ProbeOp']);

const DIGEST = 'd'.repeat(64);

interface Call {
  readonly path: string;
  readonly method: string;
  readonly body: Record<string, unknown>;
}

const ROW_CLASS = { field: 'ClassName', before: 'Probe.Op', after: 'Probe.TearOp' };

const ROW_PLAIN = { field: 'Host.HangSeconds', before: '5', after: '', removed: true };

const ROW_SECRET = { field: 'Host.ApiToken', before: '', after: '', removed: true };

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
  const items = SCREENS.find((entry) => entry.descriptor === LIST)!;
  const store = stores.for(items.descriptor, items.refreshRates);
  return { actions, handler, store, calls, events };
}

async function settle(): Promise<void> {
  for (let pass = 0; pass < 6; pass += 1) await new Promise((resolve) => setTimeout(resolve, 2));
}

afterEach(() => {
  TestBed.resetTestingModule();
});

describe('Change class through the generic handler (Story 20.41)', () => {
  it('leaves Change class to the page, which opens its own dialog, and registers the list\u2019s other row actions', () => {
    // Mutation (Rule 19): drop `changeclass` from the list's `UNDRAWN_ACTIONS` entry -> the handler registers it and the page's registration is replaced.
    const { actions } = mount(() => dryRun([ROW_CLASS]));
    expect(SCREENS.find((entry) => entry.descriptor === LIST)?.rowActions.map((action) => action.id)).toContain('changeclass');
    expect(actions.has(LIST, 'changeclass')).toBe(false);
    expect(actions.has(LIST, 'copy')).toBe(false);
    expect(actions.has(LIST, 'remove')).toBe(true);
  });

  it('dry-runs only the declared action, posts the chosen class, and opens the review typed by the item\u2019s name over the class change and each dropped setting', async () => {
    // Mutation (Rule 19): drop the list from `DRY_RUN_ACTIONS` -> no request is made and this goes red; type the composite id -> the name reads Probe.Production\u0001ProbeOp;
    // draw only the first row -> the review lacks the dropped settings.
    const { handler, store, calls } = mount(() => dryRun([ROW_CLASS, ROW_PLAIN, ROW_SECRET]));
    expect(await handler.startDryRun(LIST, 'changeclass', ID, { NewClass: 'Probe.TearOp' }, store, 'ProbeOp')).toBe(true);
    expect(calls).toHaveLength(1);
    expect(calls[0]).toMatchObject({ path: DRY_RUN_PATH, method: 'POST', body: { action: 'changeclass', id: ID, values: { NewClass: 'Probe.TearOp' } } });
    const pending = handler.pending();
    expect(pending?.kind).toBe('typed-name');
    expect(pending?.name).toBe('ProbeOp');
    expect(pending?.consequence).toBe(STRINGS.interopItemChangeClassConsequence);
    expect(pending?.review).toEqual(['- ClassName: Probe.Op', '+ ClassName: Probe.TearOp', '- Host.HangSeconds: 5', '- Host.ApiToken:']);
    expect(pending?.reviewed).toBe(DIGEST);
    expect(pending?.reviewValues).toEqual({ NewClass: 'Probe.TearOp' });
  });

  it('reviews a change that drops nothing as the one class row, old line and new', async () => {
    // Mutation (Rule 19): render a one-row review as fields -> the lines read `- ClassName: ...` and this goes red.
    const { handler, store } = mount(() => dryRun([ROW_CLASS]));
    await handler.startDryRun(LIST, 'changeclass', ID, { NewClass: 'Probe.TearOp' }, store, 'ProbeOp');
    expect(handler.pending()?.review).toEqual(['- Probe.Op', '+ Probe.TearOp']);
  });

  it('puts a refused review on the list\u2019s banner and opens no dialog', async () => {
    const { handler, store, calls } = mount(() => ({ kind: 'error', status: 409, code: 'INTEROP.ITEM.NEWCLASS', reason: STRINGS.interopItemRefusalNewClass, detail: null }));
    expect(await handler.startDryRun(LIST, 'changeclass', ID, { NewClass: 'Probe.Gone' }, store, 'ProbeOp')).toBe(false);
    expect(handler.pending()).toBeNull();
    expect(store.refusal()).toBe(STRINGS.interopItemRefusalNewClass);
    expect(calls.every((call) => call.path === DRY_RUN_PATH)).toBe(true);
  });

  it('sends the confirmed change with the class and the review\u2019s digest, publishes the change and opens no outcome dialog', async () => {
    // Mutation (Rule 19): drop `Reviewed` from the values -> the body assertion goes red; open an outcome dialog for an action that answers no line -> the pending assertion goes red.
    const { handler, store, calls, events } = mount((call) =>
      call.path === DRY_RUN_PATH
        ? dryRun([ROW_CLASS, ROW_PLAIN])
        : { kind: 'ok', status: 200, body: { action: 'updated', target: { type: 'production-item', scope: 'USER', id: ID } } }
    );
    await handler.startDryRun(LIST, 'changeclass', ID, { NewClass: 'Probe.TearOp' }, store, 'ProbeOp');
    handler.confirmPending();
    await settle();
    expect(calls).toHaveLength(2);
    expect(calls[1]).toMatchObject({ path: ACTION_PATH, method: 'POST', body: { action: 'changeclass', id: ID, values: { NewClass: 'Probe.TearOp', Reviewed: DIGEST } } });
    expect(events.map((event) => `${event.kind}|${'action' in event ? event.action : ''}`)).toEqual(['changed|updated']);
    expect(handler.pending()).toBeNull();
  });

  it('reports the sentence of a confirmed change the instance refused, and publishes nothing', async () => {
    const { handler, store, events } = mount((call) =>
      call.path === DRY_RUN_PATH ? dryRun([ROW_CLASS, ROW_PLAIN]) : { kind: 'error', status: 409, code: 'INTEROP.ITEM.REVIEWCHANGED', reason: STRINGS.interopItemRefusalReviewChanged, detail: null }
    );
    await handler.startDryRun(LIST, 'changeclass', ID, { NewClass: 'Probe.TearOp' }, store, 'ProbeOp');
    handler.confirmPending();
    await settle();
    const outcome = handler.pending();
    expect(outcome?.kind).toBe('outcome');
    expect(outcome?.refusal).toBe(STRINGS.interopItemRefusalReviewChanged);
    expect(events).toEqual([]);
  });
});
