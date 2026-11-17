import { TestBed } from '@angular/core/testing';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type ApiRequestInit, type JsonResult } from '../core/api';
import { ChangeBus } from '../core/change-bus';
import { joinCompositeId } from '../core/entity-id';
import { ScopeService } from '../core/scope';
import { ScreenActions } from '../core/screen-actions';
import { ScreenStores } from '../core/screen-store';
import { SCREENS } from '../core/screens.generated';
import { STRINGS } from '../core/strings';
import { stubAccountPreferences } from '../testing/account-preferences';
import { ScreenActionHandler } from './screen-action-handler';

/**
 * The term-list editor's actions through the generic handler (Story 24.2, AD-53): Term lists' Edit term list and an entry list's Change
 * entry are registered by their pages, whose dialogs send the values; Delete term list and Remove entry open the typed-name dialog under their
 * published consequence -- the list by its name, an entry by its key rather than its composite id -- and send nothing until it is confirmed.
 */

const LISTS = 'OcuPilot.Screen.Descriptor.AnalyticsTermListList';

const ENTRIES = 'OcuPilot.Screen.Descriptor.AnalyticsTermListEntryList';

const ENTRY_ID = joinCompositeId(['Probe.List', 'K1']);

interface Call {
  readonly path: string;
  readonly method: string;
  readonly body: Record<string, unknown>;
}

function mount(descriptor: string) {
  TestBed.resetTestingModule();
  const calls: Call[] = [];
  const api = {
    requestJson: async <T,>(path: string, init: ApiRequestInit = {}): Promise<JsonResult<T>> => {
      calls.push({ path, method: init.method ?? 'GET', body: init.body ? (JSON.parse(init.body) as Record<string, unknown>) : {} });
      return { kind: 'ok', status: 200, body: { action: 'deleted', target: { type: 'term-list', scope: 'USER', id: 'Probe.List' } } } as JsonResult<T>;
    },
  };
  const stores = new ScreenStores({ account: stubAccountPreferences() });
  TestBed.configureTestingModule({
    providers: [
      { provide: ApiService, useValue: api as unknown as ApiService },
      { provide: ChangeBus, useValue: new ChangeBus() },
      { provide: ScreenStores, useValue: stores },
      { provide: ScreenActions, useValue: new ScreenActions() },
      { provide: ScopeService, useValue: { namespace: () => 'USER' } as unknown as ScopeService },
    ],
  });
  const actions = TestBed.inject(ScreenActions);
  const handler = TestBed.inject(ScreenActionHandler);
  const screen = SCREENS.find((entry) => entry.descriptor === descriptor)!;
  return { actions, handler, store: stores.for(screen.descriptor, screen.refreshRates), calls, screen };
}

async function settle(): Promise<void> {
  for (let pass = 0; pass < 6; pass += 1) await new Promise((resolve) => setTimeout(resolve, 2));
}

afterEach(() => {
  TestBed.resetTestingModule();
});

describe('the term-list editor through the generic handler (Story 24.2)', () => {
  it('leaves Edit term list and Change entry to their pages and registers Delete term list and Remove entry', () => {
    // Mutation (Rule 19): drop the Term lists' entry from `UNDRAWN_ACTIONS` -> the handler registers `update` and this goes red; drop the
    // entries' entry -> it registers `set` and this goes red; drop `'copy'` or `'export'` from the Term lists' entry -> the handler registers it and this
    // goes red.
    // Story 24.10: the page also registers Copy term list and Export itself and draws Import, so the handler registers only Delete.
    const lists = mount(LISTS);
    expect(lists.screen.rowActions.map((action) => action.id)).toEqual(['update', 'delete', 'export', 'export-browser', 'copy', 'import', 'import-local']);
    expect(['update', 'delete', 'export', 'export-browser', 'copy', 'import', 'import-local'].map((id) => lists.actions.has(LISTS, id))).toEqual([false, true, false, false, false, false, false]);
    const entries = mount(ENTRIES);
    expect(entries.screen.rowActions.map((action) => action.id)).toEqual(['set', 'remove']);
    expect([entries.actions.has(ENTRIES, 'set'), entries.actions.has(ENTRIES, 'remove')]).toEqual([false, true]);
  });

  it('asks for the list\u2019s name typed under the delete consequence, and sends the delete only once confirmed', async () => {
    // Mutation (Rule 19): drop the list's `DESTRUCTIVE_CONSEQUENCES` entry -> the registration above and the consequence assertion go red.
    const { handler, store, calls, screen } = mount(LISTS);
    handler.startFor(LISTS, 'delete', 'Probe.List', { Name: 'Probe.List' }, store);
    expect([handler.pending()?.kind, handler.pending()?.name, handler.pending()?.consequence]).toEqual(['typed-name', 'Probe.List', STRINGS.analyticsTermListDeleteConsequence]);
    expect(calls).toHaveLength(0);
    handler.confirmPending();
    await settle();
    expect(calls).toHaveLength(1);
    expect(calls[0].path).toBe(`/api/ocupilot/screens/${screen.toolIdentifier}/action`);
    expect(calls[0].body).toEqual({ action: 'delete', id: 'Probe.List' });
  });

  it('asks for an entry\u2019s key typed, never its composite id, under the remove consequence', async () => {
    // Mutation (Rule 19): drop the entries' `TYPED_NAME_ROWS` entry -> the name reads the composite id and this goes red.
    const { handler, store, calls } = mount(ENTRIES);
    handler.startFor(ENTRIES, 'remove', ENTRY_ID, { TermList: 'Probe.List', Key: 'K1' }, store);
    expect([handler.pending()?.kind, handler.pending()?.name, handler.pending()?.target, handler.pending()?.consequence]).toEqual([
      'typed-name',
      'K1',
      ENTRY_ID,
      STRINGS.analyticsTermListRemoveConsequence,
    ]);
    expect(calls).toHaveLength(0);
    handler.confirmPending();
    await settle();
    expect(calls).toHaveLength(1);
    expect(calls[0].body).toEqual({ action: 'remove', id: ENTRY_ID });
  });
});
