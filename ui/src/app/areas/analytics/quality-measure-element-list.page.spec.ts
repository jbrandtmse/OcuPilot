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
import { QUALITY_MEASURE_ELEMENT_LIST, QUALITY_MEASURE_PART_SET_ACTION } from './quality-measure-dialog';
import { QUALITY_MEASURE_ELEMENT_ADD_ACTION, QUALITY_MEASURE_GROUP_REMOVE_ACTION, QualityMeasureElementListPage } from './quality-measure-element-list.page';

/**
 * The Groups and elements page's own wiring (Story 24.12): the shared list page is replaced by an empty stand-in, so only what the page registers and the dialog each action opens runs.
 * Add element, Change element and Remove group are registered beside the handler's Remove element; Add element opens on the selected row's group, Change element on the selected row (a
 * group's row with no element changes the group alone), and Remove group starts the remove on the group's own id with the group's name to type.
 */

@Component({ selector: 'app-detail-page', template: '' })
class StubDetailPage {}

const SCREEN = SCREENS.find((screen) => screen.descriptor === QUALITY_MEASURE_ELEMENT_LIST)!;

const MEASURE = 'Probe/Set/Measure';

const SEP = '\u0001';

const ELEMENT_ID = `${MEASURE}${SEP}Long${SEP}Over30`;

const GROUP_ID = `${MEASURE}${SEP}Empty${SEP}`;

const ROWS = [
  { QualityMeasure: MEASURE, Group: 'Long', GroupCaption: 'Long stays', GroupDescription: 'Over the limit', GroupDisabled: false, Name: 'Over30', Caption: 'Over 30', MDX: '{[M].&[30]}', Disabled: true },
  { QualityMeasure: MEASURE, Group: 'Empty', GroupCaption: 'Nothing yet', GroupDescription: '', GroupDisabled: false, Name: '', Caption: '', MDX: '', Disabled: false },
];

const planted: HTMLElement[] = [];

const posted: { path: string; body: Record<string, unknown> }[] = [];

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
    requestJson: async <T,>(path: string, init: ApiRequestInit = {}): Promise<JsonResult<T>> => {
      if (init.method === 'POST' && typeof init.body === 'string') posted.push({ path, body: JSON.parse(init.body) as Record<string, unknown> });
      return { kind: 'ok', status: 200, body: {} as T };
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
      { provide: Router, useValue: { url: `/analytics/quality-measures/document/${encodeEntityId(MEASURE)}`, events: { subscribe: () => ({ unsubscribe: () => {} }) } } },
    ],
  });
  TestBed.overrideComponent(QualityMeasureElementListPage, { remove: { imports: [DetailPage] }, add: { imports: [StubDetailPage] } });
  const store = stores.for(SCREEN.descriptor, SCREEN.refreshRates);
  store.applyTick(ROWS, false, '', new Date());
  const fixture = TestBed.createComponent(QualityMeasureElementListPage);
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  fixture.detectChanges();
  return { fixture, host: fixture.nativeElement as HTMLElement, store, actions: TestBed.inject(ScreenActions), handler: TestBed.inject(ScreenActionHandler) };
}

const fieldValue = (host: HTMLElement, member: string): string => (host.querySelector(`[data-quality-measure-field="${member}"]`) as HTMLInputElement | null)?.value ?? '<absent>';

afterEach(() => {
  posted.length = 0;
  for (const node of planted.splice(0)) node.remove();
  TestBed.resetTestingModule();
});

describe('the Groups and elements page', () => {
  it('registers Add element, Change element and Remove group beside the handler\'s Remove element', () => {
    // Mutation (Rule 19): drop the `remove-group` registration from the page's constructor -> this goes red.
    const { actions } = mount();
    expect([QUALITY_MEASURE_ELEMENT_ADD_ACTION, QUALITY_MEASURE_PART_SET_ACTION, QUALITY_MEASURE_GROUP_REMOVE_ACTION, 'remove'].map((id) => actions.has(QUALITY_MEASURE_ELEMENT_LIST, id))).toEqual([true, true, true, true]);
  });

  it('opens Add element on two fieldsets, the group beside the element, with the selected row\'s group', async () => {
    // Mutation (Rule 19): leave the group out of the dialog's inputs -> the Group assertion goes red; draw one fieldset -> the legend assertion goes red.
    const { fixture, host, store, actions } = mount();
    store.setSelection([ELEMENT_ID]);
    actions.run(QUALITY_MEASURE_ELEMENT_LIST, QUALITY_MEASURE_ELEMENT_ADD_ACTION);
    await settle(fixture);
    expect([...host.querySelectorAll('legend')].map((legend) => legend.textContent?.trim())).toEqual([STRINGS.analyticsColumnGroup, STRINGS.analyticsQualityMeasureElementLegend]);
    expect(['Group', 'GroupCaption', 'GroupDescription', 'Name', 'Caption', 'MDX'].map((member) => host.querySelector(`[data-quality-measure-field="${member}"]`) !== null)).toEqual([true, true, true, true, true, true]);
    expect(['GroupDisabled', 'Disabled'].map((flag) => host.querySelector(`[data-quality-measure-flag="${flag}"]`) !== null)).toEqual([true, true]);
    expect(fieldValue(host, 'Group')).toBe('Long');
    expect((host.querySelector('[data-quality-measure-field="Group"]') as HTMLInputElement).readOnly).toBe(false);
    expect(host.querySelector('[data-quality-measure-confirm]')?.getAttribute('aria-disabled')).toBe('true');
  });

  it('opens Change element only on a selected row, on its values, with the group and name fixed', async () => {
    // Mutation (Rule 19): open Change element without a selection -> the first assertion goes red; leave the disabled flag out of the initial values -> the flag assertion goes red.
    const { fixture, host, store, actions } = mount();
    actions.run(QUALITY_MEASURE_ELEMENT_LIST, QUALITY_MEASURE_PART_SET_ACTION);
    await settle(fixture);
    expect(host.querySelector('app-quality-measure-dialog')).toBeNull();
    store.setSelection([ELEMENT_ID]);
    actions.run(QUALITY_MEASURE_ELEMENT_LIST, QUALITY_MEASURE_PART_SET_ACTION);
    await settle(fixture);
    expect(['Group', 'GroupCaption', 'GroupDescription', 'Name', 'Caption', 'MDX'].map((member) => fieldValue(host, member))).toEqual(['Long', 'Long stays', 'Over the limit', 'Over30', 'Over 30', '{[M].&[30]}']);
    expect(['Group', 'Name'].map((member) => (host.querySelector(`[data-quality-measure-field="${member}"]`) as HTMLInputElement).readOnly)).toEqual([true, true]);
    expect((host.querySelector('[data-quality-measure-flag="Disabled"]') as HTMLInputElement).checked).toBe(true);
  });

  it('opens Change element on a group\'s row with the group\'s fields alone', async () => {
    // Mutation (Rule 19): draw the element fieldset for a row with no element -> the legend and field assertions go red.
    const { fixture, host, store, actions } = mount();
    store.setSelection([GROUP_ID]);
    actions.run(QUALITY_MEASURE_ELEMENT_LIST, QUALITY_MEASURE_PART_SET_ACTION);
    await settle(fixture);
    expect([...host.querySelectorAll('legend')].map((legend) => legend.textContent?.trim())).toEqual([STRINGS.analyticsColumnGroup]);
    expect(['Group', 'GroupCaption'].map((member) => fieldValue(host, member))).toEqual(['Empty', 'Nothing yet']);
    expect(['Name', 'Caption', 'MDX'].map((member) => host.querySelector(`[data-quality-measure-field="${member}"]`))).toEqual([null, null, null]);
  });

  it('confirms Change element on a group\'s row with the group\'s fields alone', async () => {
    // Mutation (Rule 19): let the group-only change send the element's fields -> the sent-keys assertion goes red.
    const { fixture, host, store, actions } = mount();
    store.setSelection([GROUP_ID]);
    actions.run(QUALITY_MEASURE_ELEMENT_LIST, QUALITY_MEASURE_PART_SET_ACTION);
    await settle(fixture);
    (host.querySelector('[data-quality-measure-confirm]') as HTMLElement).click();
    await settle(fixture);
    const values = (posted.at(-1)?.body['values'] ?? {}) as Record<string, unknown>;
    expect(posted.at(-1)?.body['id']).toBe(GROUP_ID);
    expect(Object.keys(values).sort()).toEqual(['GroupCaption', 'GroupDescription', 'GroupDisabled']);
  });

  it('sends GroupDisabled with an added element only when it is set, so an existing disabled group is not enabled', async () => {
    // Mutation (Rule 19): send the unticked GroupDisabled flag with every add -> the first assertion goes red.
    const { fixture, host, store, actions } = mount();
    store.setSelection([ELEMENT_ID]);
    actions.run(QUALITY_MEASURE_ELEMENT_LIST, QUALITY_MEASURE_ELEMENT_ADD_ACTION);
    await settle(fixture);
    const name = host.querySelector('[data-quality-measure-field="Name"]') as HTMLInputElement;
    name.value = 'Fresh';
    name.dispatchEvent(new Event('input'));
    await settle(fixture);
    (host.querySelector('[data-quality-measure-confirm]') as HTMLElement).click();
    await settle(fixture);
    expect(posted.at(-1)?.body).toMatchObject({ Group: 'Long', Name: 'Fresh', Disabled: false });
    expect(Object.keys(posted.at(-1)?.body ?? {})).not.toContain('GroupDisabled');
  });

  it('starts Remove group on the group\'s id with the element name empty, and types the group\'s name', () => {
    // Mutation (Rule 19): keep the row's element name in the id -> the target assertion goes red; drop the `fallback` of the typed-name entry -> the name assertion goes red.
    const { store, actions, handler } = mount();
    store.setSelection([ELEMENT_ID]);
    actions.run(QUALITY_MEASURE_ELEMENT_LIST, QUALITY_MEASURE_GROUP_REMOVE_ACTION);
    expect([handler.pending()?.kind, handler.pending()?.name, handler.pending()?.target, handler.pending()?.consequence]).toEqual(['typed-name', 'Long', `${MEASURE}${SEP}Long${SEP}`, STRINGS.analyticsQualityMeasureRemoveConsequence]);
  });
});
