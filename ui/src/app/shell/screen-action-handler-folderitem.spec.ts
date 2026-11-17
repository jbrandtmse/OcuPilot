import { TestBed } from '@angular/core/testing';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type ApiRequestInit, type JsonResult } from '../core/api';
import { ChangeBus } from '../core/change-bus';
import { ScopeService } from '../core/scope';
import { ScreenActions } from '../core/screen-actions';
import { ScreenStores } from '../core/screen-store';
import { SCREENS } from '../core/screens.generated';
import { STRINGS } from '../core/strings';
import { stubAccountPreferences } from '../testing/account-preferences';
import { ScreenActionHandler } from './screen-action-handler';

/**
 * The folder manager's actions through the generic handler (Story 24.10, AD-53): the Folder items page registers Export itself and draws Import,
 * whose dialogs send the values; Delete opens the typed-name dialog under its published consequence -- the item by its full name -- and sends nothing
 * until it is confirmed.
 */

const ITEMS = 'OcuPilot.Screen.Descriptor.AnalyticsFolderItemList';

const ITEM = 'Sales/Q1 Review.dashboard';

interface Call {
  readonly path: string;
  readonly method: string;
  readonly body: Record<string, unknown>;
}

function mount() {
  TestBed.resetTestingModule();
  const calls: Call[] = [];
  const api = {
    requestJson: async <T,>(path: string, init: ApiRequestInit = {}): Promise<JsonResult<T>> => {
      calls.push({ path, method: init.method ?? 'GET', body: init.body ? (JSON.parse(init.body) as Record<string, unknown>) : {} });
      return { kind: 'ok', status: 200, body: { action: 'deleted', target: { type: 'folder-item', scope: 'USER', id: ITEM } } } as JsonResult<T>;
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
  const screen = SCREENS.find((entry) => entry.descriptor === ITEMS)!;
  return { actions, handler, store: stores.for(screen.descriptor, screen.refreshRates), calls, screen };
}

async function settle(): Promise<void> {
  for (let pass = 0; pass < 6; pass += 1) await new Promise((resolve) => setTimeout(resolve, 2));
}

afterEach(() => {
  TestBed.resetTestingModule();
});

describe('the folder manager through the generic handler (Story 24.10)', () => {
  it('leaves Export and Import to the Folder items page and registers Delete', () => {
    // Mutation (Rule 19): drop the Folder items' entry from `UNDRAWN_ACTIONS` -> the handler registers the four transfer actions and this goes red.
    const { screen, actions } = mount();
    expect(screen.rowActions.map((action) => action.id)).toEqual(['export', 'export-browser', 'import', 'import-local', 'delete']);
    expect(['export', 'export-browser', 'import', 'import-local', 'delete'].map((id) => actions.has(ITEMS, id))).toEqual([false, false, false, false, true]);
  });

  it('asks for the item\u2019s full name typed under the delete consequence, and sends the delete only once confirmed', async () => {
    // Mutation (Rule 19): drop the Folder items' `DESTRUCTIVE_CONSEQUENCES` entry -> the consequence assertion goes red.
    const { handler, store, calls, screen } = mount();
    handler.startFor(ITEMS, 'delete', ITEM, { Name: ITEM }, store);
    expect([handler.pending()?.kind, handler.pending()?.name, handler.pending()?.consequence]).toEqual(['typed-name', ITEM, STRINGS.analyticsFolderItemDeleteConsequence]);
    expect(calls).toHaveLength(0);
    handler.confirmPending();
    await settle();
    expect(calls).toHaveLength(1);
    expect(calls[0].path).toBe(`/api/ocupilot/screens/${screen.toolIdentifier}/action`);
    expect(calls[0].body).toEqual({ action: 'delete', id: ITEM });
  });

  it('types the name the row shows, and sends the row key', async () => {
    // Mutation (Rule 19): drop the Folder items' `TYPED_NAME_ROWS` entry -> the dialog asks for the row key and the name assertion goes red.
    const { handler, store, calls } = mount();
    handler.startFor(ITEMS, 'delete', 'Key/Other.dashboard', { Name: ITEM }, store);
    expect([handler.pending()?.kind, handler.pending()?.name, handler.pending()?.target]).toEqual(['typed-name', ITEM, 'Key/Other.dashboard']);
    handler.confirmPending();
    await settle();
    expect(calls[0].body).toEqual({ action: 'delete', id: 'Key/Other.dashboard' });
  });
});
