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
 * The quality measure editor's actions through the generic handler (Story 24.12, AD-53): Quality measures' Edit and Copy are registered by their page, whose dialogs send the values;
 * Delete opens the typed-name dialog under its published consequence, the measure by the full name its row shows, and sends nothing until it is confirmed.
 */

const MEASURES = 'OcuPilot.Screen.Descriptor.AnalyticsQualityMeasureList';

const NAME = 'Probe/Set/Measure';

interface Call {
  readonly path: string;
  readonly body: Record<string, unknown>;
}

function mount() {
  TestBed.resetTestingModule();
  const calls: Call[] = [];
  const api = {
    requestJson: async <T,>(path: string, init: ApiRequestInit = {}): Promise<JsonResult<T>> => {
      calls.push({ path, body: init.body ? (JSON.parse(init.body) as Record<string, unknown>) : {} });
      return { kind: 'ok', status: 200, body: { action: 'deleted', target: { type: 'quality-measure', scope: 'USER', id: NAME } } } as JsonResult<T>;
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
  const screen = SCREENS.find((entry) => entry.descriptor === MEASURES)!;
  return { actions, handler, store: stores.for(screen.descriptor, screen.refreshRates), calls, screen };
}

async function settle(): Promise<void> {
  for (let pass = 0; pass < 6; pass += 1) await new Promise((resolve) => setTimeout(resolve, 2));
}

afterEach(() => {
  TestBed.resetTestingModule();
});

describe('the quality measure editor through the generic handler (Story 24.12)', () => {
  it('leaves Edit and Copy to their page and registers Delete', () => {
    // Mutation (Rule 19): drop the Quality measures' entry from `UNDRAWN_ACTIONS` -> the handler registers `update` and `copy` and this goes red.
    const { actions, screen } = mount();
    expect(screen.rowActions.map((action) => action.id)).toEqual(['update', 'copy', 'delete']);
    expect(['update', 'copy', 'delete'].map((id) => actions.has(MEASURES, id))).toEqual([false, false, true]);
  });

  it('asks for the name the row shows, typed under the delete consequence, and sends the delete only once confirmed', async () => {
    // The row's key is its name here too, so this fixture gives the row a key that is not its name.
    // Mutation (Rule 19): drop the `DESTRUCTIVE_CONSEQUENCES` entry -> the consequence assertion goes red; drop the `TYPED_NAME_ROWS` entry -> the dialog asks for the key and this goes red.
    const { handler, store, calls, screen } = mount();
    handler.startFor(MEASURES, 'delete', 'row-key', { Name: NAME }, store);
    expect([handler.pending()?.kind, handler.pending()?.name, handler.pending()?.target, handler.pending()?.consequence]).toEqual(['typed-name', NAME, 'row-key', STRINGS.analyticsQualityMeasureDeleteConsequence]);
    expect(calls).toHaveLength(0);
    handler.confirmPending();
    await settle();
    expect(calls).toHaveLength(1);
    expect(calls[0].path).toBe(`/api/ocupilot/screens/${screen.toolIdentifier}/action`);
    expect(calls[0].body).toEqual({ action: 'delete', id: 'row-key' });
  });
});
