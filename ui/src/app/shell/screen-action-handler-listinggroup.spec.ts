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
 * The listing group editor's actions through the generic handler (Story 24.11, AD-53): Listing groups' Edit and Copy and a group's Listings' Change
 * listing are registered by their pages, whose dialogs send the values; Delete and Remove listing open the typed-name dialog under their published
 * consequence -- the group by its name, a listing by its name rather than its composite id -- and send nothing until it is confirmed.
 */

const GROUPS = 'OcuPilot.Screen.Descriptor.AnalyticsListingGroupList';

const LISTINGS = 'OcuPilot.Screen.Descriptor.AnalyticsListingGroupListingList';

const LISTING_ID = joinCompositeId(['Probe.Group', 'Probe.Listing']);

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
      return { kind: 'ok', status: 200, body: { action: 'deleted', target: { type: 'listing-group', scope: 'USER', id: 'Probe.Group' } } } as JsonResult<T>;
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

describe('the listing group editor through the generic handler (Story 24.11)', () => {
  it('leaves Edit, Copy and Change listing to their pages and registers Delete and Remove listing', () => {
    // Mutation (Rule 19): drop the Listing groups' entry from `UNDRAWN_ACTIONS` -> the handler registers `update` and `copy` and this goes red; drop the Listings' entry
    // -> it registers `set` and this goes red.
    const groups = mount(GROUPS);
    expect(groups.screen.rowActions.map((action) => action.id)).toEqual(['update', 'copy', 'delete']);
    expect(['update', 'copy', 'delete'].map((id) => groups.actions.has(GROUPS, id))).toEqual([false, false, true]);
    const listings = mount(LISTINGS);
    expect(listings.screen.rowActions.map((action) => action.id)).toEqual(['set', 'remove']);
    expect([listings.actions.has(LISTINGS, 'set'), listings.actions.has(LISTINGS, 'remove')]).toEqual([false, true]);
  });

  it('asks for the group\u2019s name typed under the delete consequence, and sends the delete only once confirmed', async () => {
    // Mutation (Rule 19): drop the group's `DESTRUCTIVE_CONSEQUENCES` entry -> the registration above and the consequence assertion go red.
    const { handler, store, calls, screen } = mount(GROUPS);
    handler.startFor(GROUPS, 'delete', 'Probe.Group', { Name: 'Probe.Group' }, store);
    expect([handler.pending()?.kind, handler.pending()?.name, handler.pending()?.consequence]).toEqual(['typed-name', 'Probe.Group', STRINGS.analyticsListingGroupDeleteConsequence]);
    expect(calls).toHaveLength(0);
    handler.confirmPending();
    await settle();
    expect(calls).toHaveLength(1);
    expect(calls[0].path).toBe(`/api/ocupilot/screens/${screen.toolIdentifier}/action`);
    expect(calls[0].body).toEqual({ action: 'delete', id: 'Probe.Group' });
  });

  it('asks for the name the row shows, not the key the write is sent with', async () => {
    // A listing group's row key is its name, so a real row cannot tell the entry from the key; this fixture gives the row a key that is not its name.
    // Mutation (Rule 19): drop the Listing groups' `TYPED_NAME_ROWS` entry -> the dialog asks for the key and this goes red.
    const { handler, store, calls } = mount(GROUPS);
    handler.startFor(GROUPS, 'delete', 'row-key', { Name: 'Probe.Group' }, store);
    expect([handler.pending()?.kind, handler.pending()?.name, handler.pending()?.target]).toEqual(['typed-name', 'Probe.Group', 'row-key']);
    handler.confirmPending();
    await settle();
    expect(calls).toHaveLength(1);
    expect(calls[0].body).toEqual({ action: 'delete', id: 'row-key' });
  });

  it('asks for a listing\u2019s name typed, never its composite id, under the remove consequence', async () => {
    // Mutation (Rule 19): drop the Listings' `TYPED_NAME_ROWS` entry -> the name reads the composite id and this goes red.
    const { handler, store, calls } = mount(LISTINGS);
    handler.startFor(LISTINGS, 'remove', LISTING_ID, { ListingGroup: 'Probe.Group', Name: 'Probe.Listing' }, store);
    expect([handler.pending()?.kind, handler.pending()?.name, handler.pending()?.target, handler.pending()?.consequence]).toEqual([
      'typed-name',
      'Probe.Listing',
      LISTING_ID,
      STRINGS.analyticsListingRemoveConsequence,
    ]);
    expect(calls).toHaveLength(0);
    handler.confirmPending();
    await settle();
    expect(calls).toHaveLength(1);
    expect(calls[0].body).toEqual({ action: 'remove', id: LISTING_ID });
  });
});
