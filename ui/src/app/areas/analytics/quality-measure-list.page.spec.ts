import { Component } from '@angular/core';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { By } from '@angular/platform-browser';
import { Router } from '@angular/router';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type ApiRequestInit, type JsonResult } from '../../core/api';
import { ChangeBus } from '../../core/change-bus';
import { OverlayStack } from '../../core/overlay-stack';
import { ScopeService } from '../../core/scope';
import { ScreenActions } from '../../core/screen-actions';
import { ScreenStores } from '../../core/screen-store';
import { SCREENS } from '../../core/screens.generated';
import { ListPage } from '../../shell/list-page';
import { stubAccountPreferences } from '../../testing/account-preferences';
import { LISTING_GROUP_COPY_ACTION, ListingGroupCopyDialog } from './listing-group-copy-dialog';
import { QUALITY_MEASURE_LIST, QUALITY_MEASURE_UPDATE_ACTION } from './quality-measure-dialog';
import { QUALITY_MEASURE_ADD_ACTION, QualityMeasureListPage } from './quality-measure-list.page';

/**
 * The Quality measures page's own wiring (Story 24.12): the shared list page is replaced by an empty stand-in, so only what the page registers and the dialog each action opens runs.
 * New quality measure, Edit and Copy are registered beside the handler's Delete; Edit and Copy open only on a selected measure, Edit on the form the instance answers, and Copy is the
 * listing groups' dialog over this screen with the two fields a measure's copy takes.
 */

@Component({ selector: 'app-list-page', template: '' })
class StubListPage {}

const SCREEN = SCREENS.find((screen) => screen.descriptor === QUALITY_MEASURE_LIST)!;

const NAME = 'Probe/Set/Measure';

const FORM = { Name: NAME, Catalog: 'Probe', Set: 'Set', Id: 'Measure', Class: 'Probe.Class', Caption: 'Shown', Description: '', SubjectArea: 'Probe', Expression: '[A]/[B]', LinkedTo: '', Published: true, Format: '#', Href: '' };

const planted: HTMLElement[] = [];

const asked: string[] = [];

async function settle(fixture: ComponentFixture<unknown>): Promise<void> {
  for (let pass = 0; pass < 4; pass += 1) {
    await new Promise((resolve) => setTimeout(resolve, 2));
    fixture.detectChanges();
    await fixture.whenStable();
  }
}

function mount() {
  TestBed.resetTestingModule();
  const api = {
    requestJson: async <T,>(path: string, _init: ApiRequestInit = {}): Promise<JsonResult<T>> => {
      asked.push(path);
      return { kind: 'ok', status: 200, body: FORM as T };
    },
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
      { provide: Router, useValue: { url: '/analytics/quality-measures', events: { subscribe: () => ({ unsubscribe: () => {} }) } } },
    ],
  });
  TestBed.overrideComponent(QualityMeasureListPage, { remove: { imports: [ListPage] }, add: { imports: [StubListPage] } });
  const store = stores.for(SCREEN.descriptor, SCREEN.refreshRates);
  store.applyTick([{ Name: NAME, Caption: 'Shown' }], false, '', new Date());
  const fixture = TestBed.createComponent(QualityMeasureListPage);
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  fixture.detectChanges();
  return { fixture, host: fixture.nativeElement as HTMLElement, store, actions: TestBed.inject(ScreenActions) };
}

const fieldValue = (host: HTMLElement, member: string): string => (host.querySelector(`[data-quality-measure-field="${member}"]`) as HTMLInputElement | null)?.value ?? '<absent>';

afterEach(() => {
  for (const node of planted.splice(0)) node.remove();
  asked.length = 0;
  TestBed.resetTestingModule();
});

describe('the Quality measures page', () => {
  it('registers New quality measure, Edit and Copy beside the handler\'s Delete', () => {
    // Mutation (Rule 19): drop the `copy` registration from the page's constructor -> this goes red.
    const { actions } = mount();
    expect([QUALITY_MEASURE_ADD_ACTION, QUALITY_MEASURE_UPDATE_ACTION, LISTING_GROUP_COPY_ACTION, 'delete'].map((id) => actions.has(QUALITY_MEASURE_LIST, id))).toEqual([true, true, true, true]);
  });

  it('opens New quality measure on the name\'s three parts, and Edit and Copy only on a selected measure', async () => {
    // Mutation (Rule 19): open Edit and Copy without a selection -> the first dialog assertion goes red.
    const { fixture, host, actions } = mount();
    actions.run(QUALITY_MEASURE_LIST, QUALITY_MEASURE_UPDATE_ACTION);
    actions.run(QUALITY_MEASURE_LIST, LISTING_GROUP_COPY_ACTION);
    await settle(fixture);
    expect([host.querySelector('app-quality-measure-dialog'), host.querySelector('app-listing-group-copy-dialog')]).toEqual([null, null]);
    actions.run(QUALITY_MEASURE_LIST, QUALITY_MEASURE_ADD_ACTION);
    await settle(fixture);
    expect(['Catalog', 'Set', 'Id', 'Class', 'Caption', 'Description', 'SubjectArea'].map((member) => host.querySelector(`[data-quality-measure-field="${member}"]`) !== null)).toEqual(
      [true, true, true, true, true, true, true]
    );
    expect(host.querySelector('[data-quality-measure-field="Expression"]')).toBeNull();
  });

  it('opens Edit on the form the instance answers, with the name fixed', async () => {
    // Mutation (Rule 19): read the form from the listing groups' route -> the path assertion goes red.
    const { fixture, host, store, actions } = mount();
    store.setSelection([NAME]);
    actions.run(QUALITY_MEASURE_LIST, QUALITY_MEASURE_UPDATE_ACTION);
    await settle(fixture);
    expect(asked).toEqual([`/api/ocupilot/analytics/quality-measures/form?name=${encodeURIComponent(NAME)}`]);
    expect(['Name', 'Caption', 'SubjectArea', 'Expression', 'LinkedTo', 'Format', 'Href'].map((member) => fieldValue(host, member))).toEqual([NAME, 'Shown', 'Probe', '[A]/[B]', '', '#', '']);
    expect((host.querySelector('[data-quality-measure-field="Name"]') as HTMLInputElement).readOnly).toBe(true);
    expect((host.querySelector('[data-quality-measure-published]') as HTMLInputElement).checked).toBe(true);
    expect(host.querySelector('app-listing-group-copy-dialog')).toBeNull();
  });

  it('opens Copy on the selected measure with this screen and the two fields a measure\'s copy takes', async () => {
    // Mutation (Rule 19): give the copy dialog `[source]="namespace"` -> the source assertion goes red; leave the descriptor at its default -> the descriptor assertion goes red.
    const { fixture, host, store, actions } = mount();
    store.setSelection([NAME]);
    actions.run(QUALITY_MEASURE_LIST, LISTING_GROUP_COPY_ACTION);
    await settle(fixture);
    const copy = fixture.debugElement.query(By.directive(ListingGroupCopyDialog)).componentInstance as ListingGroupCopyDialog;
    expect([copy.source(), copy.descriptor(), copy.fields().map((field) => field.value)]).toEqual([NAME, QUALITY_MEASURE_LIST, ['NewName', 'NewClass']]);
    expect(host.querySelector('[data-listing-group-copy-field="NewCubes"]')).toBeNull();
    expect(host.querySelector('app-quality-measure-dialog')).toBeNull();
  });
});
