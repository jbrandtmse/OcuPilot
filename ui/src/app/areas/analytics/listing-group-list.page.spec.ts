import { Component } from '@angular/core';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { Router } from '@angular/router';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type ApiRequestInit, type JsonResult } from '../../core/api';
import { ChangeBus } from '../../core/change-bus';
import { joinCompositeId } from '../../core/entity-id';
import { OverlayStack } from '../../core/overlay-stack';
import { ScopeService } from '../../core/scope';
import { ScreenActions } from '../../core/screen-actions';
import { ScreenStores } from '../../core/screen-store';
import { SCREENS } from '../../core/screens.generated';
import { ListPage } from '../../shell/list-page';
import { stubAccountPreferences } from '../../testing/account-preferences';
import { LISTING_GROUP_COPY_ACTION } from './listing-group-copy-dialog';
import { LISTING_GROUP_LIST, LISTING_GROUP_LISTING_LIST, LISTING_GROUP_UPDATE_ACTION, LISTING_SET_ACTION } from './listing-group-dialog';
import { LISTING_GROUP_ADD_ACTION, ListingGroupListPage } from './listing-group-list.page';
import { LISTING_ADD_ACTION, ListingGroupListingListPage } from './listing-group-listing-list.page';

/**
 * The two listing group pages' own wiring (Story 24.11): the shared list page is replaced by an empty stand-in, so only what each page registers and the dialog each action opens
 * runs. Listing groups registers New listing group, Edit and Copy, and the Edit and Copy dialogs open only on a selected group; Listings registers Add listing and Change listing,
 * and Change listing opens on the members its selected row shows. Delete and Remove listing are the shell handler's declared row actions, which the pages inject and so construct:
 * neither page registers them, and both read as registered.
 */

@Component({ selector: 'app-list-page', template: '' })
class StubListPage {}

const GROUP_SCREEN = SCREENS.find((screen) => screen.descriptor === LISTING_GROUP_LIST)!;

const LISTING_SCREEN = SCREENS.find((screen) => screen.descriptor === LISTING_GROUP_LISTING_LIST)!;

const GROUP_ROWS = [{ Name: 'Probe.Group', Caption: 'Shown' }];

const LISTING_ROW = {
  ListingGroup: 'Probe.Group',
  Name: 'Probe.Listing',
  DisplayName: 'Shown listing',
  Type: 'map',
  Fields: 'Amount,Minutes',
  OrderBy: 'Amount DESC',
  Formats: 'Amount:#.##',
  Source: 'Probe.Connector',
  Resource: '%DeepSee_Portal',
  SelectMode: '1',
  Description: 'About it',
  SQL: 'SELECT ID FROM Probe.Visit',
  Disabled: true,
};

const LISTING_ID = joinCompositeId(['Probe.Group', 'Probe.Listing']);

const planted: HTMLElement[] = [];

async function settle(fixture: ComponentFixture<unknown>): Promise<void> {
  for (let pass = 0; pass < 4; pass += 1) {
    await new Promise((resolve) => setTimeout(resolve, 2));
    fixture.detectChanges();
    await fixture.whenStable();
  }
}

/** The providers both pages share; the API answers nothing the pages read, since the store is filled directly. */
function configure(): ScreenStores {
  TestBed.resetTestingModule();
  const api = {
    requestJson: async <T,>(_path: string, _init: ApiRequestInit = {}): Promise<JsonResult<T>> => ({
      kind: 'ok',
      status: 200,
      body: { Name: 'Probe.Group', Class: 'Probe.Class', Caption: 'Shown', Description: '', TargetCubes: 'Probe', Resource: '', DefaultResource: '', Disabled: false } as T,
    }),
  };
  const stores = new ScreenStores({ account: stubAccountPreferences() });
  TestBed.configureTestingModule({
    providers: [
      { provide: ApiService, useValue: api as unknown as ApiService },
      { provide: ChangeBus, useValue: new ChangeBus() },
      { provide: ScreenStores, useValue: stores },
      { provide: ScreenActions, useValue: new ScreenActions() },
      { provide: OverlayStack, useValue: new OverlayStack() },
      { provide: ScopeService, useValue: { loaded: () => true, namespace: () => 'USER', subscribe: () => () => {} } as unknown as ScopeService },
      { provide: Router, useValue: { url: '/analytics/listing-groups/listings/Probe.Group', events: { subscribe: () => ({ unsubscribe: () => {} }) } } },
    ],
  });
  return stores;
}

function mountGroups() {
  const stores = configure();
  TestBed.overrideComponent(ListingGroupListPage, { remove: { imports: [ListPage] }, add: { imports: [StubListPage] } });
  const store = stores.for(GROUP_SCREEN.descriptor, GROUP_SCREEN.refreshRates);
  store.applyTick(GROUP_ROWS, false, '', new Date());
  const fixture = TestBed.createComponent(ListingGroupListPage);
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  fixture.detectChanges();
  return { fixture, host: fixture.nativeElement as HTMLElement, store, actions: TestBed.inject(ScreenActions) };
}

function mountListings() {
  const stores = configure();
  TestBed.overrideComponent(ListingGroupListingListPage, { remove: { imports: [ListPage] }, add: { imports: [StubListPage] } });
  const store = stores.for(LISTING_SCREEN.descriptor, LISTING_SCREEN.refreshRates);
  store.applyTick([LISTING_ROW], false, '', new Date());
  const fixture = TestBed.createComponent(ListingGroupListingListPage);
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  fixture.detectChanges();
  return { fixture, host: fixture.nativeElement as HTMLElement, store, actions: TestBed.inject(ScreenActions) };
}

const fieldValue = (host: HTMLElement, member: string): string => (host.querySelector(`[data-listing-group-field="${member}"]`) as HTMLInputElement | null)?.value ?? '<absent>';

afterEach(() => {
  for (const node of planted.splice(0)) node.remove();
  TestBed.resetTestingModule();
});

describe('the Listing groups page', () => {
  it('registers New listing group, Edit and Copy beside the handler\'s Delete, and opens Edit and Copy only on a selected group', async () => {
    // Mutation (Rule 19): drop the `copy` registration from the page's constructor -> the first assertion goes red.
    const { fixture, host, store, actions } = mountGroups();
    expect([LISTING_GROUP_ADD_ACTION, LISTING_GROUP_UPDATE_ACTION, LISTING_GROUP_COPY_ACTION, 'delete'].map((id) => actions.has(LISTING_GROUP_LIST, id))).toEqual([true, true, true, true]);
    actions.run(LISTING_GROUP_LIST, LISTING_GROUP_UPDATE_ACTION);
    actions.run(LISTING_GROUP_LIST, LISTING_GROUP_COPY_ACTION);
    await settle(fixture);
    expect([host.querySelector('app-listing-group-dialog'), host.querySelector('app-listing-group-copy-dialog')]).toEqual([null, null]);
    actions.run(LISTING_GROUP_LIST, LISTING_GROUP_ADD_ACTION);
    await settle(fixture);
    expect(host.querySelector('app-listing-group-dialog [data-listing-group-field="Class"]')).not.toBeNull();

    const second = mountGroups();
    second.store.setSelection(['Probe.Group']);
    second.actions.run(LISTING_GROUP_LIST, LISTING_GROUP_UPDATE_ACTION);
    await settle(second.fixture);
    expect(fieldValue(second.host, 'Name')).toBe('Probe.Group');
    expect(second.host.querySelector('app-listing-group-copy-dialog')).toBeNull();

    const third = mountGroups();
    third.store.setSelection(['Probe.Group']);
    third.actions.run(LISTING_GROUP_LIST, LISTING_GROUP_COPY_ACTION);
    await settle(third.fixture);
    expect(third.host.querySelector('app-listing-group-copy-dialog')).not.toBeNull();
    expect(third.host.querySelector('app-listing-group-dialog')).toBeNull();
  });
});

describe('the Listings page', () => {
  it('registers Add listing and Change listing beside the handler\'s Remove listing, and Change listing opens on the members its selected row shows', async () => {
    // Mutation (Rule 19): drop the `set` registration from the page's constructor -> the first assertion goes red; read `Type` as '' in `onOpenSet` -> the Type assertion goes red.
    const { fixture, host, store, actions } = mountListings();
    expect([LISTING_ADD_ACTION, LISTING_SET_ACTION, 'remove'].map((id) => actions.has(LISTING_GROUP_LISTING_LIST, id))).toEqual([true, true, true]);
    actions.run(LISTING_GROUP_LISTING_LIST, LISTING_SET_ACTION);
    await settle(fixture);
    expect(host.querySelector('app-listing-group-dialog')).toBeNull();
    store.setSelection([LISTING_ID]);
    actions.run(LISTING_GROUP_LISTING_LIST, LISTING_SET_ACTION);
    await settle(fixture);
    const members = ['Name', 'DisplayName', 'Type', 'Fields', 'OrderBy', 'Formats', 'Source', 'Resource', 'SelectMode', 'Description', 'SQL'];
    expect(members.map((member) => fieldValue(host, member))).toEqual(members.map((member) => (LISTING_ROW as unknown as Record<string, string>)[member]));
    expect((host.querySelector('[data-listing-group-disabled]') as HTMLInputElement).checked).toBe(true);
  });

  it('Add listing opens on a blank form for the group the route names', async () => {
    const { fixture, host, actions } = mountListings();
    actions.run(LISTING_GROUP_LISTING_LIST, LISTING_ADD_ACTION);
    await settle(fixture);
    expect(host.querySelector('app-listing-group-dialog')).not.toBeNull();
    expect(fieldValue(host, 'Name')).toBe('');
    expect(fieldValue(host, 'Fields')).toBe('');
  });
});
