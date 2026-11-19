import { Component } from '@angular/core';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { Router } from '@angular/router';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type ApiRequestInit, type JsonResult } from '../../core/api';
import { ChangeBus } from '../../core/change-bus';
import { encodeEntityId } from '../../core/entity-id';
import { OverlayStack } from '../../core/overlay-stack';
import { ScopeService } from '../../core/scope';
import { ScreenActions } from '../../core/screen-actions';
import { ScreenStores } from '../../core/screen-store';
import { SCREENS } from '../../core/screens.generated';
import { STRINGS } from '../../core/strings';
import { DetailPage } from '../../shell/detail-page';
import { ScreenActionHandler } from '../../shell/screen-action-handler';
import { stubAccountPreferences } from '../../testing/account-preferences';
import { QUALITY_MEASURE_META_LIST, QUALITY_MEASURE_PART_SET_ACTION } from './quality-measure-dialog';
import { QUALITY_MEASURE_META_ADD_ACTION, QualityMeasureMetaListPage } from './quality-measure-meta-list.page';

/**
 * The Documentation page's own wiring (Story 24.12): the shared list page is replaced by an empty stand-in, so only what the page registers and the dialog each action opens runs.
 * Add documentation item and Change documentation item are registered beside the handler's Remove documentation item; Change opens only on a selected row, on its values, and the
 * Remove types the item's name under the removal consequence.
 */

@Component({ selector: 'app-detail-page', template: '' })
class StubDetailPage {}

const SCREEN = SCREENS.find((screen) => screen.descriptor === QUALITY_MEASURE_META_LIST)!;

const MEASURE = 'Probe/Set/Measure';

const ITEM_ID = `${MEASURE}\u0001Purpose`;

const ROWS = [{ QualityMeasure: MEASURE, Name: 'Purpose', Caption: 'Why', Section: 'Overview', Content: 'Counts the <b>long</b> visits.', Disabled: false }];

const planted: HTMLElement[] = [];

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
    requestJson: async <T,>(_path: string, _init: ApiRequestInit = {}): Promise<JsonResult<T>> => ({ kind: 'ok', status: 200, body: {} as T }),
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
      { provide: Router, useValue: { url: `/analytics/quality-measures/documentation/${encodeEntityId(MEASURE)}`, events: { subscribe: () => ({ unsubscribe: () => {} }) } } },
    ],
  });
  TestBed.overrideComponent(QualityMeasureMetaListPage, { remove: { imports: [DetailPage] }, add: { imports: [StubDetailPage] } });
  const store = stores.for(SCREEN.descriptor, SCREEN.refreshRates);
  store.applyTick(ROWS, false, '', new Date());
  const fixture = TestBed.createComponent(QualityMeasureMetaListPage);
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  fixture.detectChanges();
  return { fixture, host: fixture.nativeElement as HTMLElement, store, actions: TestBed.inject(ScreenActions), handler: TestBed.inject(ScreenActionHandler) };
}

const fieldValue = (host: HTMLElement, member: string): string => (host.querySelector(`[data-quality-measure-field="${member}"]`) as HTMLInputElement | null)?.value ?? '<absent>';

afterEach(() => {
  for (const node of planted.splice(0)) node.remove();
  TestBed.resetTestingModule();
});

describe('the Documentation page', () => {
  it('registers Add and Change beside the handler\'s Remove', () => {
    // Mutation (Rule 19): drop the `set` registration from the page's constructor -> this goes red.
    const { actions } = mount();
    expect([QUALITY_MEASURE_META_ADD_ACTION, QUALITY_MEASURE_PART_SET_ACTION, 'remove'].map((id) => actions.has(QUALITY_MEASURE_META_LIST, id))).toEqual([true, true, true]);
  });

  it('opens Add documentation item on the name, caption and content, with its confirm waiting for a name', async () => {
    // Mutation (Rule 19): draw the element form's group fieldset -> the legend and field assertions go red.
    const { fixture, host, actions } = mount();
    actions.run(QUALITY_MEASURE_META_LIST, QUALITY_MEASURE_META_ADD_ACTION);
    await settle(fixture);
    expect(['Name', 'Caption', 'Content'].map((member) => host.querySelector(`[data-quality-measure-field="${member}"]`) !== null)).toEqual([true, true, true]);
    expect(['Group', 'MDX'].map((member) => host.querySelector(`[data-quality-measure-field="${member}"]`))).toEqual([null, null]);
    expect(host.querySelector('legend')).toBeNull();
    expect(host.querySelector('[data-quality-measure-confirm]')?.getAttribute('aria-disabled')).toBe('true');
  });

  it('opens Change only on a selected row, on its values, with the name fixed', async () => {
    // Mutation (Rule 19): open Change without a selection -> the first assertion goes red; leave the content out of the initial values -> the content assertion goes red.
    const { fixture, host, store, actions } = mount();
    actions.run(QUALITY_MEASURE_META_LIST, QUALITY_MEASURE_PART_SET_ACTION);
    await settle(fixture);
    expect(host.querySelector('app-quality-measure-dialog')).toBeNull();
    store.setSelection([ITEM_ID]);
    actions.run(QUALITY_MEASURE_META_LIST, QUALITY_MEASURE_PART_SET_ACTION);
    await settle(fixture);
    expect(['Name', 'Caption', 'Content'].map((member) => fieldValue(host, member))).toEqual(['Purpose', 'Why', 'Counts the <b>long</b> visits.']);
    expect((host.querySelector('[data-quality-measure-field="Name"]') as HTMLInputElement).readOnly).toBe(true);
  });

  it('types the item\'s name under the removal consequence before the Remove is sent', () => {
    // Mutation (Rule 19): drop the Documentation's `TYPED_NAME_ROWS` entry -> the dialog asks for the row key and the name assertion goes red.
    const { store, actions, handler } = mount();
    store.setSelection([ITEM_ID]);
    actions.run(QUALITY_MEASURE_META_LIST, 'remove');
    expect([handler.pending()?.kind, handler.pending()?.name, handler.pending()?.consequence]).toEqual(['typed-name', 'Purpose', STRINGS.analyticsQualityMeasureRemoveConsequence]);
  });
});
