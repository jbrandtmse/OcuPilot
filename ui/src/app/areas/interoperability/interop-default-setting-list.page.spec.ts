import { Component } from '@angular/core';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type ApiRequestInit, type JsonResult } from '../../core/api';
import { ChangeBus, type ChangeEvent } from '../../core/change-bus';
import { joinCompositeId } from '../../core/entity-id';
import { OverlayStack } from '../../core/overlay-stack';
import { ScopeService } from '../../core/scope';
import { ScreenActions } from '../../core/screen-actions';
import { ScreenStores } from '../../core/screen-store';
import { SCREENS } from '../../core/screens.generated';
import { STRINGS } from '../../core/strings';
import { ListPage } from '../../shell/list-page';
import { ScreenActionHandler } from '../../shell/screen-action-handler';
import { stubAccountPreferences } from '../../testing/account-preferences';
import {
  INTEROP_DEFAULT_SETTING_ADD_ACTION,
  INTEROP_DEFAULT_SETTING_EDIT_ACTION,
  INTEROP_DEFAULT_SETTING_LIST,
  InteropDefaultSettingListPage,
} from './interop-default-setting-list.page';

/**
 * The System default settings page (Story 24.15). The shared list page is replaced by an empty stand-in, so only this page's own wiring
 * runs: the two actions it registers after the shell's handler, the New default setting dialog that posts to the namespace the shell is
 * scoped to, the Edit dialog it opens over the selected row with the key read-only, the request each Edit sends -- only the values the
 * person changed, the flag as `true` or `false`, and never the key -- a refusal kept in the dialog, the change event an applied change
 * publishes, and the Remove the handler's construction registers, which types the setting's name. The handler, the stores and the bus are
 * real; only the server's answers are stubbed.
 */

@Component({ selector: 'app-list-page', template: '' })
class StubListPage {}

const LIST = SCREENS.find((screen) => screen.descriptor === INTEROP_DEFAULT_SETTING_LIST)!;

const row = (setting: string, extra: Record<string, unknown> = {}): Record<string, unknown> => ({
  Production: 'Demo.Production',
  Item: '*',
  HostClass: '*',
  Setting: setting,
  Value: '',
  Description: '',
  Deployable: false,
  Secret: false,
  ...extra,
});

const ROWS = [row('ArchiveIO', { Value: '1', Description: 'a\nb', Deployable: true }), row('PoolSize', { Value: '2' })];

const ID = joinCompositeId(['Demo.Production', '*', '*', 'ArchiveIO']);

const UPDATED: JsonResult<unknown> = {
  kind: 'ok',
  status: 200,
  body: { action: 'updated', target: { type: 'default-setting', scope: 'namespace:USER', id: ID }, readBack: { verdict: 'matches' } },
};

const planted: HTMLElement[] = [];

async function settle(fixture: ComponentFixture<unknown>): Promise<void> {
  for (let pass = 0; pass < 4; pass += 1) {
    await new Promise((resolve) => setTimeout(resolve, 2));
    fixture.detectChanges();
    await fixture.whenStable();
  }
}

interface Call {
  readonly path: string;
  readonly method: string;
  readonly scope: string | null | undefined;
  readonly body: string;
}

/** Configure the testing module over stubbed answers: each request resolves to the next of `answers`. */
function configure(answers: JsonResult<unknown>[]) {
  TestBed.resetTestingModule();
  const calls: Call[] = [];
  const api = {
    requestJson: async <T,>(path: string, init: ApiRequestInit = {}): Promise<JsonResult<T>> => {
      calls.push({ path, method: init.method ?? 'GET', scope: init.scope, body: init.body ?? '' });
      return (answers.shift() ?? { kind: 'ok', status: 200, body: {} }) as JsonResult<T>;
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
      { provide: OverlayStack, useValue: new OverlayStack() },
      { provide: ScopeService, useValue: { loaded: () => true, namespace: () => 'USER', subscribe: () => () => {} } as unknown as ScopeService },
    ],
  });
  return { calls, events, stores };
}

/** Mount the page over `ROWS`. */
function mount(answers: JsonResult<unknown>[]) {
  const { calls, events, stores } = configure(answers);
  TestBed.overrideComponent(InteropDefaultSettingListPage, { remove: { imports: [ListPage] }, add: { imports: [StubListPage] } });
  const store = stores.for(LIST.descriptor, LIST.refreshRates);
  store.applyTick(ROWS, false, '', new Date());
  const fixture = TestBed.createComponent(InteropDefaultSettingListPage);
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  fixture.detectChanges();
  return { fixture, host: fixture.nativeElement as HTMLElement, store, calls, events, actions: TestBed.inject(ScreenActions), handler: TestBed.inject(ScreenActionHandler) };
}

async function openEdit(fixture: ComponentFixture<unknown>, store: ReturnType<typeof mount>['store'], actions: ScreenActions, setting: string): Promise<void> {
  store.setSelection([joinCompositeId(['Demo.Production', '*', '*', setting])]);
  actions.run(INTEROP_DEFAULT_SETTING_LIST, INTEROP_DEFAULT_SETTING_EDIT_ACTION);
  await settle(fixture);
}

function typeInto(fixture: ComponentFixture<unknown>, host: HTMLElement, name: string, value: string): void {
  const control = host.querySelector(`[data-interop-default-setting-field="${name}"]`) as HTMLInputElement | HTMLTextAreaElement;
  control.value = value;
  control.dispatchEvent(new Event('input'));
  fixture.detectChanges();
}

const confirmDialog = (host: HTMLElement): void => (host.querySelector('[data-interop-default-setting-confirm]') as HTMLButtonElement).click();

afterEach(() => {
  for (const node of planted.splice(0)) node.remove();
  TestBed.resetTestingModule();
});

describe('the System default settings page', () => {
  it('declares the list this page hosts, with New default setting as its primary action and Edit and Remove as its row actions', () => {
    expect(LIST.primaryAction?.id).toBe(INTEROP_DEFAULT_SETTING_ADD_ACTION);
    expect(LIST.rowActions.map((action) => action.id)).toEqual([INTEROP_DEFAULT_SETTING_EDIT_ACTION, 'remove']);
  });

  // Mutation (Rule 19): drop this page's `actions.register` of `edit` or `add` -> the first assertions go red.
  it('registers New default setting and Edit beside the handler\'s Remove, and opens New default setting for a new setting', async () => {
    const { fixture, host, actions, calls } = mount([]);
    expect(actions.has(INTEROP_DEFAULT_SETTING_LIST, INTEROP_DEFAULT_SETTING_ADD_ACTION)).toBe(true);
    expect(actions.has(INTEROP_DEFAULT_SETTING_LIST, INTEROP_DEFAULT_SETTING_EDIT_ACTION)).toBe(true);
    expect(actions.has(INTEROP_DEFAULT_SETTING_LIST, 'remove')).toBe(true);
    actions.run(INTEROP_DEFAULT_SETTING_LIST, INTEROP_DEFAULT_SETTING_ADD_ACTION);
    await settle(fixture);
    expect(calls).toHaveLength(0);
    expect(host.querySelector('.ocu-dialog-title')?.textContent?.trim()).toBe(STRINGS.interopDefaultSettingAddAction);
    expect((host.querySelector('[data-interop-default-setting-field="Setting"]') as HTMLInputElement).readOnly).toBe(false);
  });

  it('posts New default setting\'s fields in the namespace the shell is scoped to and closes, publishing the created event', async () => {
    const created: JsonResult<unknown> = { kind: 'ok', status: 201, body: { id: ID, target: { type: 'default-setting', scope: 'USER', id: ID } } };
    const { fixture, host, actions, calls, events } = mount([created]);
    actions.run(INTEROP_DEFAULT_SETTING_LIST, INTEROP_DEFAULT_SETTING_ADD_ACTION);
    await settle(fixture);
    typeInto(fixture, host, 'Production', 'Demo.Production');
    typeInto(fixture, host, 'Setting', 'ArchiveIO');
    confirmDialog(host);
    await settle(fixture);
    expect(calls.map((call) => [call.path, call.scope, (JSON.parse(call.body) as Record<string, unknown>)['Setting']])).toEqual([['/api/ocupilot/interop/default-settings', 'USER', 'ArchiveIO']]);
    expect(host.querySelector('app-interop-default-setting-dialog')).toBeNull();
    expect(events.map((event) => [event.type, event.action, event.tool])).toEqual([['default-setting', 'created', 'interop.defaultsettings.add']]);
  });

  it('opens Edit over the selected row only, with its key read-only and the values its row reported', async () => {
    const { fixture, host, store, actions, calls } = mount([]);
    actions.run(INTEROP_DEFAULT_SETTING_LIST, INTEROP_DEFAULT_SETTING_EDIT_ACTION);
    await settle(fixture);
    expect(host.querySelector('app-interop-default-setting-dialog')).toBeNull();
    await openEdit(fixture, store, actions, 'ArchiveIO');
    expect(calls).toHaveLength(0);
    expect(host.querySelector('.ocu-dialog-title')?.textContent?.trim()).toBe(STRINGS.interopDefaultSettingEditTitle.replace('<setting>', 'ArchiveIO'));
    const key = host.querySelector('[data-interop-default-setting-field="Setting"]') as HTMLInputElement;
    expect(key.value).toBe('ArchiveIO');
    expect(key.readOnly).toBe(true);
    expect((host.querySelector('[data-interop-default-setting-field="Value"]') as HTMLInputElement).value).toBe('1');
    expect((host.querySelector('[data-interop-default-setting-field="Description"]') as HTMLTextAreaElement).value).toBe('a\nb');
    expect((host.querySelector('[data-interop-default-setting-field="Deployable"]') as HTMLInputElement).checked).toBe(true);
  });

  it('sends only the values the person changed and never the key, an emptied one included and the flag as text, closes on an applied change and publishes the updated event', async () => {
    const { fixture, host, store, actions, calls, events } = mount([UPDATED]);
    await openEdit(fixture, store, actions, 'ArchiveIO');
    typeInto(fixture, host, 'Description', '');
    const flag = host.querySelector('[data-interop-default-setting-field="Deployable"]') as HTMLInputElement;
    flag.checked = false;
    flag.dispatchEvent(new Event('change'));
    fixture.detectChanges();
    confirmDialog(host);
    await settle(fixture);
    expect(calls).toHaveLength(1);
    expect(calls[0].path).toBe(`/api/ocupilot/screens/${LIST.toolIdentifier}/action`);
    const sent = JSON.parse(calls[0].body) as { action: string; id: string; values: Record<string, string> };
    expect([sent.action, sent.id]).toEqual(['edit', ID]);
    // Mutation (Rule 19): send the flag as a boolean -> the screen action route refuses it and this goes red.
    expect(sent.values).toEqual({ Description: '', Deployable: 'false' });
    expect(Object.keys(sent.values)).not.toContain('Setting');
    expect(host.querySelector('app-interop-default-setting-dialog')).toBeNull();
    expect(events.map((event) => `${event.type}/${event.action}`)).toEqual(['default-setting/updated']);
  });

  it('closes a dialog that changed nothing without sending or publishing anything', async () => {
    const { fixture, host, store, actions, calls, events } = mount([]);
    await openEdit(fixture, store, actions, 'ArchiveIO');
    confirmDialog(host);
    await settle(fixture);
    expect(calls).toHaveLength(0);
    expect(events).toEqual([]);
    expect(host.querySelector('app-interop-default-setting-dialog')).toBeNull();
  });

  it('closes on Cancel, sending nothing and publishing nothing', async () => {
    const { fixture, host, store, actions, calls, events } = mount([]);
    await openEdit(fixture, store, actions, 'ArchiveIO');
    const cancel = [...host.querySelectorAll('.ocu-dialog-actions button')].find((button) => button.textContent?.trim() === STRINGS.actionCancel) as HTMLButtonElement;
    cancel.click();
    await settle(fixture);
    expect(host.querySelector('app-interop-default-setting-dialog')).toBeNull();
    expect(calls).toHaveLength(0);
    expect(events).toEqual([]);
  });

  it('keeps a refusal on a field in the dialog as the instance\'s sentence, and one that names none above the fields, publishing nothing', async () => {
    const { fixture, host, store, actions, events } = mount([
      {
        kind: 'error',
        status: 422,
        code: 'INTEROP.DEFAULTSETTING.VALUE',
        reason: STRINGS.interopDefaultSettingRefusalValue,
        detail: { violations: [{ field: 'Value', code: 'INTEROP.DEFAULTSETTING.VALUE', reason: STRINGS.interopDefaultSettingRefusalValue }] },
      } as JsonResult<unknown>,
      { kind: 'error', status: 409, code: 'INTEROP.DEFAULTSETTING.SOURCECONTROL', reason: STRINGS.interopDefaultSettingRefusalSourceControl } as JsonResult<unknown>,
    ]);
    await openEdit(fixture, store, actions, 'ArchiveIO');
    typeInto(fixture, host, 'Value', '0');
    confirmDialog(host);
    await settle(fixture);
    expect(host.querySelector('[data-interop-default-setting-violation="Value"]')?.textContent?.trim()).toBe(STRINGS.interopDefaultSettingRefusalValue);
    expect(host.querySelector('[data-interop-default-setting-reason]')).toBeNull();
    confirmDialog(host);
    await settle(fixture);
    expect(host.querySelector('[data-interop-default-setting-violation]')).toBeNull();
    expect(host.querySelector('[data-interop-default-setting-reason]')?.textContent?.trim()).toBe(STRINGS.interopDefaultSettingRefusalSourceControl);
    expect(events).toEqual([]);
    expect(store.refusal()).toBe('');
  });

  it('types the setting\'s name before Remove, states what removing it does, and sends the row key', async () => {
    // Mutation (Rule 19): drop the list's TYPED_NAME_ROWS entry -> the dialog asks for no name and the name assertion goes red; drop its
    // DESTRUCTIVE_CONSEQUENCES entry -> the consequence assertion goes red.
    const removed: JsonResult<unknown> = { kind: 'ok', status: 200, body: { action: 'deleted', target: { type: 'default-setting', scope: 'USER', id: ID } } };
    const { fixture, store, actions, handler, calls, events } = mount([removed]);
    store.setSelection([ID]);
    actions.run(INTEROP_DEFAULT_SETTING_LIST, 'remove');
    await settle(fixture);
    expect(handler.pending()?.kind).toBe('typed-name');
    expect(handler.pending()?.name).toBe('ArchiveIO');
    expect(handler.pending()?.target).toBe(ID);
    expect(handler.pending()?.consequence).toBe(STRINGS.interopDefaultSettingRemoveConsequence);
    expect(calls).toHaveLength(0);
    handler.confirmPending();
    await settle(fixture);
    expect(calls).toHaveLength(1);
    expect(JSON.parse(calls[0].body)).toEqual({ action: 'remove', id: ID });
    expect(events.map((event) => `${event.action} ${event.type}`)).toEqual(['deleted default-setting']);
  });

  // Mutation (Rule 19): drop the list's entry from `UNDRAWN_ACTIONS` -> the handler registers Edit itself and this goes red.
  it('leaves New default setting and Edit to this page: the handler alone registers Remove only', () => {
    configure([]);
    const actions = TestBed.inject(ScreenActions);
    TestBed.inject(ScreenActionHandler);
    expect(actions.has(INTEROP_DEFAULT_SETTING_LIST, 'remove')).toBe(true);
    expect(actions.has(INTEROP_DEFAULT_SETTING_LIST, INTEROP_DEFAULT_SETTING_EDIT_ACTION)).toBe(false);
    expect(actions.has(INTEROP_DEFAULT_SETTING_LIST, INTEROP_DEFAULT_SETTING_ADD_ACTION)).toBe(false);
  });

  it('opens neither dialog over the other', async () => {
    const { fixture, host, store, actions } = mount([]);
    await openEdit(fixture, store, actions, 'ArchiveIO');
    actions.run(INTEROP_DEFAULT_SETTING_LIST, INTEROP_DEFAULT_SETTING_ADD_ACTION);
    await settle(fixture);
    expect(host.querySelectorAll('app-interop-default-setting-dialog')).toHaveLength(1);
    expect(host.querySelector('.ocu-dialog-title')?.textContent?.trim()).toBe(STRINGS.interopDefaultSettingEditTitle.replace('<setting>', 'ArchiveIO'));
  });
});
