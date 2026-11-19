import { Component } from '@angular/core';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { Router } from '@angular/router';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type ApiRequestInit, type JsonResult } from '../../core/api';
import { ChangeBus } from '../../core/change-bus';
import { OverlayStack } from '../../core/overlay-stack';
import { ScopeService } from '../../core/scope';
import { ScreenActions } from '../../core/screen-actions';
import { ScreenStores } from '../../core/screen-store';
import { SCREENS } from '../../core/screens.generated';
import { STRINGS } from '../../core/strings';
import { DetailPage } from '../../shell/detail-page';
import { ScreenActionHandler } from '../../shell/screen-action-handler';
import { stubAccountPreferences } from '../../testing/account-preferences';
import { RUNTIME_VARIABLE_LIST, SETTING_ENTRY_SET_ACTION, USER_ICON_LIST } from './analytics-setting-entry-dialog';
import { AnalyticsSettingEntryListPage, SETTING_ENTRY_ADD_ACTION } from './analytics-setting-entry-list.page';

/**
 * The Run-time variables and User-defined icons page's own wiring (Story 24.13, Batch 3): the detail page is replaced by an empty stand-in, so only what the page registers and the dialog each
 * action opens runs. Add and Change are registered beside the handler's Remove; Change opens only on a selected row, on its values, the name fixed; the Remove types the name under its
 * consequence; an add posts to the route that resolves the agent's tool, and an expression and a path are drawn as text.
 */

@Component({ selector: 'app-detail-page', template: '' })
class StubDetailPage {}

const VARIABLE_URL = '/analytics/settings/variables';

const ICON_URL = '/analytics/settings/icons';

const VARIABLE_ROWS = [{ Name: 'OcuProbeVar', Value: '$Increment(^OcuProbeRan)', Comment: 'a comment', Context: 'ctx' }];

const ICON_ROWS = [{ Name: 'OcuProbeIcon', Path: '/OcuProbe/a.png' }];

const planted: HTMLElement[] = [];

async function settle(fixture: ComponentFixture<unknown>): Promise<void> {
  for (let pass = 0; pass < 4; pass += 1) {
    await new Promise((resolve) => setTimeout(resolve, 2));
    fixture.detectChanges();
    await fixture.whenStable();
  }
}

function mount(url: string, descriptor: string, rows: readonly Record<string, unknown>[], refusal: JsonResult<unknown> | null = null) {
  TestBed.resetTestingModule();
  const requests: { path: string; init: ApiRequestInit }[] = [];
  const api = {
    requestJson: async <T,>(path: string, init: ApiRequestInit = {}): Promise<JsonResult<T>> => {
      requests.push({ path, init });
      return refusal !== null && init.method === 'POST' ? (refusal as JsonResult<T>) : { kind: 'ok', status: 201, body: { id: 'OcuProbeNew' } as T };
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
      { provide: Router, useValue: { url, events: { subscribe: () => ({ unsubscribe: () => {} }) } } },
    ],
  });
  TestBed.overrideComponent(AnalyticsSettingEntryListPage, { remove: { imports: [DetailPage] }, add: { imports: [StubDetailPage] } });
  const screen = SCREENS.find((entry) => entry.descriptor === descriptor)!;
  const store = stores.for(screen.descriptor, screen.refreshRates);
  store.applyTick(rows, false, '', new Date());
  const fixture = TestBed.createComponent(AnalyticsSettingEntryListPage);
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  fixture.detectChanges();
  return { fixture, host: fixture.nativeElement as HTMLElement, store, requests, actions: TestBed.inject(ScreenActions), handler: TestBed.inject(ScreenActionHandler) };
}

const field = (host: HTMLElement, member: string): HTMLInputElement | HTMLTextAreaElement | null => host.querySelector(`[data-setting-entry-field="${member}"]`);

function type(host: HTMLElement, member: string, text: string): void {
  const control = field(host, member)!;
  control.value = text;
  control.dispatchEvent(new Event('input', { bubbles: true }));
}

afterEach(() => {
  for (const node of planted.splice(0)) node.remove();
  TestBed.resetTestingModule();
});

describe('the Run-time variables and User-defined icons page', () => {
  it('registers Add and Change beside the handler\'s Remove, on the descriptor its URL names', () => {
    // Mutation (Rule 19): drop the `set` registration from the page's constructor -> the first line goes red; serve the icons descriptor from the variables URL -> the second goes red.
    const variables = mount(VARIABLE_URL, RUNTIME_VARIABLE_LIST, VARIABLE_ROWS);
    expect([SETTING_ENTRY_ADD_ACTION, SETTING_ENTRY_SET_ACTION, 'remove'].map((id) => variables.actions.has(RUNTIME_VARIABLE_LIST, id))).toEqual([true, true, true]);
    expect(variables.actions.has(USER_ICON_LIST, SETTING_ENTRY_ADD_ACTION)).toBe(false);
    const icons = mount(ICON_URL, USER_ICON_LIST, ICON_ROWS);
    expect([SETTING_ENTRY_ADD_ACTION, SETTING_ENTRY_SET_ACTION, 'remove'].map((id) => icons.actions.has(USER_ICON_LIST, id))).toEqual([true, true, true]);
    expect(icons.actions.has(RUNTIME_VARIABLE_LIST, SETTING_ENTRY_ADD_ACTION)).toBe(false);
  });

  it('opens Add run-time variable on the name, the expression as a text area, the comment and the context, with its confirm waiting for a name', async () => {
    // Mutation (Rule 19): draw the expression as a single-line input -> the text area assertion goes red.
    const { fixture, host, actions } = mount(VARIABLE_URL, RUNTIME_VARIABLE_LIST, VARIABLE_ROWS);
    actions.run(RUNTIME_VARIABLE_LIST, SETTING_ENTRY_ADD_ACTION);
    await settle(fixture);
    expect(['Name', 'Value', 'Comment', 'Context'].map((member) => field(host, member) !== null)).toEqual([true, true, true, true]);
    expect(field(host, 'Path')).toBeNull();
    expect(field(host, 'Value')?.tagName).toBe('TEXTAREA');
    expect(host.querySelector('[data-setting-entry-code]')?.textContent).toContain(STRINGS.analyticsVariableCodeConsequence);
    expect(host.querySelector('app-dialog')?.textContent).toContain(STRINGS.analyticsRuntimeVariableAddAction);
    expect(host.querySelector('[data-setting-entry-confirm]')?.getAttribute('aria-disabled')).toBe('true');
  });

  it('opens Add icon on the name and the path alone, the path drawn as a text field and nothing loaded', async () => {
    // Mutation (Rule 19): draw a link for the typed path in the dialog -> the last assertion goes red, here and in the Change dialog's test.
    const { fixture, host, actions } = mount(ICON_URL, USER_ICON_LIST, ICON_ROWS);
    actions.run(USER_ICON_LIST, SETTING_ENTRY_ADD_ACTION);
    await settle(fixture);
    expect(['Name', 'Path'].map((member) => field(host, member) !== null)).toEqual([true, true]);
    expect(['Value', 'Comment', 'Context'].map((member) => field(host, member))).toEqual([null, null, null]);
    expect(field(host, 'Path')?.tagName).toBe('INPUT');
    expect(host.querySelector('[data-setting-entry-code]')).toBeNull();
    type(host, 'Path', '/OcuProbe/typed.png');
    await settle(fixture);
    expect(field(host, 'Path')?.value).toBe('/OcuProbe/typed.png');
    expect(host.querySelector('app-dialog')).not.toBeNull();
    expect(host.querySelectorAll('img, a, iframe').length).toBe(0);
  });

  it('posts an add to the route the agent\'s tool is resolved through, as typed, and closes on the accepted write', async () => {
    // Mutation (Rule 19): post the variable to the icons route -> the path assertion goes red; trim the expression -> the body assertion goes red.
    const { fixture, host, requests, actions } = mount(VARIABLE_URL, RUNTIME_VARIABLE_LIST, VARIABLE_ROWS);
    actions.run(RUNTIME_VARIABLE_LIST, SETTING_ENTRY_ADD_ACTION);
    await settle(fixture);
    type(host, 'Name', 'OcuProbeNew');
    type(host, 'Value', ' $Increment(^OcuProbeRan) ');
    type(host, 'Context', 'ctx');
    await settle(fixture);
    (host.querySelector('[data-setting-entry-confirm]') as HTMLButtonElement).click();
    await settle(fixture);
    const posted = requests.find((request) => request.init.method === 'POST');
    expect(posted?.path).toBe('/api/ocupilot/analytics/runtime-variables');
    expect(JSON.parse(String(posted?.init.body))).toEqual({ Name: 'OcuProbeNew', Value: ' $Increment(^OcuProbeRan) ', Comment: '', Context: 'ctx' });
    expect(host.querySelector('app-dialog')).toBeNull();
  });

  it('posts an icon add to its own route', async () => {
    const { fixture, host, requests, actions } = mount(ICON_URL, USER_ICON_LIST, ICON_ROWS);
    actions.run(USER_ICON_LIST, SETTING_ENTRY_ADD_ACTION);
    await settle(fixture);
    type(host, 'Name', 'OcuProbeNewIcon');
    type(host, 'Path', '/a/b.png');
    await settle(fixture);
    (host.querySelector('[data-setting-entry-confirm]') as HTMLButtonElement).click();
    await settle(fixture);
    const posted = requests.find((request) => request.init.method === 'POST');
    expect(posted?.path).toBe('/api/ocupilot/analytics/user-icons');
    expect(JSON.parse(String(posted?.init.body))).toEqual({ Name: 'OcuProbeNewIcon', Path: '/a/b.png' });
  });

  it('keeps the dialog open on a refusal and draws the server\'s sentence under the field it names, or above the fields', async () => {
    // Mutation (Rule 19): drop the violation list from the dialog's refusal handling -> the field sentence goes red; show the reason when violations exist -> the banner assertion goes red.
    const field400 = { kind: 'error', status: 400, code: 'ANALYTICS.VARIABLE.EXPRESSION', reason: STRINGS.analyticsRefusalVariableExpression, detail: { violations: [{ field: 'Value', code: 'ANALYTICS.VARIABLE.EXPRESSION', reason: STRINGS.analyticsRefusalVariableExpression }] } } as const;
    const named = mount(VARIABLE_URL, RUNTIME_VARIABLE_LIST, VARIABLE_ROWS, field400);
    named.actions.run(RUNTIME_VARIABLE_LIST, SETTING_ENTRY_ADD_ACTION);
    await settle(named.fixture);
    type(named.host, 'Name', 'OcuProbeNew');
    type(named.host, 'Value', '1+');
    await settle(named.fixture);
    (named.host.querySelector('[data-setting-entry-confirm]') as HTMLButtonElement).click();
    await settle(named.fixture);
    expect(named.host.querySelector('[data-setting-entry-violation="Value"]')?.textContent).toContain(STRINGS.analyticsRefusalVariableExpression);
    expect(named.host.querySelector('[data-setting-entry-reason]')).toBeNull();
    expect(named.host.querySelector('app-dialog')).not.toBeNull();
    const taken = { kind: 'error', status: 409, code: 'ANALYTICS.VARIABLE.TAKEN', reason: STRINGS.analyticsRefusalVariableTaken, detail: null } as const;
    const held = mount(VARIABLE_URL, RUNTIME_VARIABLE_LIST, VARIABLE_ROWS, taken);
    held.actions.run(RUNTIME_VARIABLE_LIST, SETTING_ENTRY_ADD_ACTION);
    await settle(held.fixture);
    type(held.host, 'Name', 'OcuProbeVar');
    await settle(held.fixture);
    (held.host.querySelector('[data-setting-entry-confirm]') as HTMLButtonElement).click();
    await settle(held.fixture);
    expect(held.host.querySelector('[data-setting-entry-reason]')?.textContent).toContain(STRINGS.analyticsRefusalVariableTaken);
    expect(held.host.querySelector('app-dialog')).not.toBeNull();
  });

  it('opens Change only on a selected row, on its values, with the name fixed', async () => {
    // Mutation (Rule 19): open Change without a selection -> the first assertion goes red; leave the context out of the initial values -> the values assertion goes red.
    const { fixture, host, store, actions } = mount(VARIABLE_URL, RUNTIME_VARIABLE_LIST, VARIABLE_ROWS);
    actions.run(RUNTIME_VARIABLE_LIST, SETTING_ENTRY_SET_ACTION);
    await settle(fixture);
    expect(host.querySelector('app-analytics-setting-entry-dialog')).toBeNull();
    store.setSelection(['OcuProbeVar']);
    actions.run(RUNTIME_VARIABLE_LIST, SETTING_ENTRY_SET_ACTION);
    await settle(fixture);
    expect(['Name', 'Value', 'Comment', 'Context'].map((member) => field(host, member)?.value)).toEqual(['OcuProbeVar', '$Increment(^OcuProbeRan)', 'a comment', 'ctx']);
    expect((field(host, 'Name') as HTMLInputElement).readOnly).toBe(true);
    expect(host.querySelector('app-dialog')?.textContent).toContain(STRINGS.analyticsRuntimeVariableChangeAction);
  });

  it('keeps Change open on a refusal and draws the server\'s sentence under the field it names', async () => {
    // Mutation (Rule 19): drop the violation list from the Change branch of the dialog's refusal handling -> the field sentence goes red.
    const field400 = { kind: 'error', status: 400, code: 'ANALYTICS.VARIABLE.EXPRESSION', reason: STRINGS.analyticsRefusalVariableExpression, detail: { violations: [{ field: 'Value', code: 'ANALYTICS.VARIABLE.EXPRESSION', reason: STRINGS.analyticsRefusalVariableExpression }] } } as const;
    const { fixture, host, store, actions, requests } = mount(VARIABLE_URL, RUNTIME_VARIABLE_LIST, VARIABLE_ROWS, field400);
    store.setSelection(['OcuProbeVar']);
    actions.run(RUNTIME_VARIABLE_LIST, SETTING_ENTRY_SET_ACTION);
    await settle(fixture);
    type(host, 'Value', '1+');
    await settle(fixture);
    (host.querySelector('[data-setting-entry-confirm]') as HTMLButtonElement).click();
    await settle(fixture);
    expect(requests.some((request) => request.init.method === 'POST')).toBe(true);
    expect(host.querySelector('[data-setting-entry-violation="Value"]')?.textContent).toContain(STRINGS.analyticsRefusalVariableExpression);
    expect(host.querySelector('app-dialog')).not.toBeNull();
  });

  it('opens Change icon on the icon\'s path', async () => {
    const { fixture, host, store, actions } = mount(ICON_URL, USER_ICON_LIST, ICON_ROWS);
    store.setSelection(['OcuProbeIcon']);
    actions.run(USER_ICON_LIST, SETTING_ENTRY_SET_ACTION);
    await settle(fixture);
    expect(['Name', 'Path'].map((member) => field(host, member)?.value)).toEqual(['OcuProbeIcon', '/OcuProbe/a.png']);
    expect(host.querySelector('app-dialog')?.textContent).toContain(STRINGS.analyticsUserIconChangeAction);
    type(host, 'Path', '/OcuProbe/changed.png');
    await settle(fixture);
    expect(field(host, 'Path')?.value).toBe('/OcuProbe/changed.png');
    expect(host.querySelectorAll('img, a, iframe').length).toBe(0);
  });

  it('types the name under the removal consequence before the Remove is sent', () => {
    // Mutation (Rule 19): drop the descriptor's `TYPED_NAME_ROWS` entry -> the dialog asks for the row key and the name assertion goes red; swap the two consequences -> the last one goes red.
    const variables = mount(VARIABLE_URL, RUNTIME_VARIABLE_LIST, VARIABLE_ROWS);
    variables.store.setSelection(['OcuProbeVar']);
    variables.actions.run(RUNTIME_VARIABLE_LIST, 'remove');
    expect([variables.handler.pending()?.kind, variables.handler.pending()?.name, variables.handler.pending()?.consequence]).toEqual(['typed-name', 'OcuProbeVar', STRINGS.analyticsVariableRemoveConsequence]);
    const icons = mount(ICON_URL, USER_ICON_LIST, ICON_ROWS);
    icons.store.setSelection(['OcuProbeIcon']);
    icons.actions.run(USER_ICON_LIST, 'remove');
    expect([icons.handler.pending()?.kind, icons.handler.pending()?.name, icons.handler.pending()?.consequence]).toEqual(['typed-name', 'OcuProbeIcon', STRINGS.analyticsIconRemoveConsequence]);
  });
});
