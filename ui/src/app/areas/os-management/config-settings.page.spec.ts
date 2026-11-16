import { Component } from '@angular/core';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { Router } from '@angular/router';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type ApiRequestInit, type JsonResult } from '../../core/api';
import { ChangeBus, type ChangeEvent } from '../../core/change-bus';
import { OverlayStack } from '../../core/overlay-stack';
import { ScreenActions } from '../../core/screen-actions';
import { ScreenStores } from '../../core/screen-store';
import { SCREENS } from '../../core/screens.generated';
import { STRINGS } from '../../core/strings';
import { ListPage } from '../../shell/list-page';
import { ScreenActionHandler } from '../../shell/screen-action-handler';
import { stubAccountPreferences } from '../../testing/account-preferences';
import {
  COMPATIBILITY_SETTING_LIST,
  CONFIG_SET_ACTION,
  ConfigSettingsPage,
  DDL_MAPPING_ADD_ACTION,
  DDL_SYSTEM_MAPPING_LIST,
  DDL_USER_MAPPING_LIST,
  ISQL_SETTING_LIST,
  MEMORY_SETTING_LIST,
  SQL_SETTING_LIST,
  SQL_SHELL_SETTING_LIST,
  STARTUP_SETTING_LIST,
  TSQL_SETTING_LIST,
} from './config-settings.page';

/**
 * The startup, memory, compatibility, SQL, SQL Shell, TSQL and ISQL settings page (Stories 21.3, 21.4 and 21.13). The shared list page is replaced by an empty stand-in, so only this page's own
 * wiring runs: Set value registered on the screen the URL names, the dialog's statement over a row that needs a restart, no Set value over a row
 * that is never changed here, the one value each request carries, the restart sentence after an applied change, the purge sentence over and after a change of a setting that purges the cached queries, and the change event it publishes.
 * The handler, the stores and the bus are real; only the server's answers are stubbed.
 */

@Component({ selector: 'app-list-page', template: '' })
class StubListPage {}

const row = (name: string, extra: Record<string, unknown> = {}): Record<string, unknown> => ({
  Name: name,
  Value: '0',
  Kind: 'integer',
  Accepts: 'A whole number from 0 to 9.',
  Restart: false,
  ReadOnly: false,
  Purges: false,
  ...extra,
});

const ROWS = [
  row('ShutdownTimeout', { Value: '120', Accepts: 'A whole number from 120 to 100000.' }),
  row('ErrorPurge', { Value: '30', Restart: true, Accepts: 'A whole number from 1 to 365.' }),
  row('LineRecall', { Value: '1', Kind: 'boolean', Accepts: '0 (off) or 1 (on).' }),
  row('DefaultPort', { Value: '1972', ReadOnly: true, Accepts: 'Shown here and never changed here.' }),
  row('FastDistinct', { Value: '1', Kind: 'boolean', Accepts: '0 (off) or 1 (on).', Purges: true }),
  row('SaveMAC', { Value: '0', Kind: 'boolean', Accepts: '0 (off) or 1 (on).' }),
  row('BIGINT(%1)', { Value: '%Library.BigInt', Kind: 'datatype', Accepts: 'A datatype class name, with its parameters in parentheses if it takes any, of up to 256 characters.' }),
];

const UPDATED: JsonResult<unknown> = {
  kind: 'ok',
  status: 200,
  body: { action: 'updated', target: { type: 'startup-setting', scope: 'instance', id: 'ShutdownTimeout' }, readBack: { verdict: 'matches' } },
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
  readonly body: string;
}

/** Mount the page at `descriptor`'s route over `ROWS`; each request resolves to the next of `answers`. */
function mount(answers: (JsonResult<unknown> | Promise<JsonResult<unknown>>)[], descriptor = STARTUP_SETTING_LIST) {
  TestBed.resetTestingModule();
  const screen = SCREENS.find((entry) => entry.descriptor === descriptor)!;
  const calls: Call[] = [];
  const api = {
    requestJson: async <T,>(path: string, init: ApiRequestInit = {}): Promise<JsonResult<T>> => {
      calls.push({ path, method: init.method ?? 'GET', body: init.body ?? '' });
      return (await (answers.shift() ?? { kind: 'ok', status: 200, body: {} })) as JsonResult<T>;
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
      { provide: Router, useValue: { url: `/${screen.route}`, events: { subscribe: () => ({ unsubscribe: () => undefined }) } } },
    ],
  });
  TestBed.overrideComponent(ConfigSettingsPage, { remove: { imports: [ListPage] }, add: { imports: [StubListPage] } });
  const store = stores.for(screen.descriptor, screen.refreshRates);
  store.applyTick(ROWS, false, '', new Date());
  const fixture = TestBed.createComponent(ConfigSettingsPage);
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  fixture.detectChanges();
  return { fixture, host: fixture.nativeElement as HTMLElement, store, screen, calls, events, actions: TestBed.inject(ScreenActions), handler: TestBed.inject(ScreenActionHandler) };
}

async function open(fixture: ComponentFixture<unknown>, store: ReturnType<typeof mount>['store'], actions: ScreenActions, descriptor: string, rowId: string): Promise<void> {
  store.setSelection([rowId]);
  actions.run(descriptor, CONFIG_SET_ACTION);
  await settle(fixture);
}

function type(fixture: ComponentFixture<unknown>, host: HTMLElement, value: string): void {
  const field = host.querySelector('[data-interop-setting-value]') as HTMLInputElement;
  field.value = value;
  field.dispatchEvent(new Event('input'));
  fixture.detectChanges();
}

const confirm = (host: HTMLElement): void => (host.querySelector('[data-interop-setting-confirm]') as HTMLButtonElement).click();

afterEach(() => {
  for (const node of planted.splice(0)) node.remove();
  TestBed.resetTestingModule();
});

describe('the settings page', () => {
  // Mutation (Rule 19): drop this page's `actions.register` of `set` -> the first assertion goes red.
  it('registers Set value on the screen its URL names and on no other of the three', () => {
    const { actions } = mount([], MEMORY_SETTING_LIST);
    expect(actions.has(MEMORY_SETTING_LIST, CONFIG_SET_ACTION)).toBe(true);
    expect(actions.has(STARTUP_SETTING_LIST, CONFIG_SET_ACTION)).toBe(false);
    expect(actions.has(COMPATIBILITY_SETTING_LIST, CONFIG_SET_ACTION)).toBe(false);
  });

  // Mutation (Rule 19): drop a descriptor from `SERVED_LISTS` -> the loop's assertion for it goes red.
  it('serves each of the four SQL settings screens, on its own screen only', () => {
    for (const served of [SQL_SETTING_LIST, SQL_SHELL_SETTING_LIST, TSQL_SETTING_LIST, ISQL_SETTING_LIST]) {
      const { actions } = mount([], served);
      expect(actions.has(served, CONFIG_SET_ACTION)).toBe(true);
      expect(actions.has(STARTUP_SETTING_LIST, CONFIG_SET_ACTION)).toBe(false);
    }
  });

  it('opens its dialog over the selected row with the row\'s Accepts line and sends nothing', async () => {
    const { fixture, host, store, actions, calls } = mount([]);
    actions.run(STARTUP_SETTING_LIST, CONFIG_SET_ACTION);
    await settle(fixture);
    expect(host.querySelector('app-interop-item-setting-dialog')).toBeNull();
    await open(fixture, store, actions, STARTUP_SETTING_LIST, 'ShutdownTimeout');
    expect(calls).toHaveLength(0);
    expect(host.querySelector('.ocu-dialog-title')?.textContent?.trim()).toBe('Set value of ShutdownTimeout');
    expect(host.querySelector('[data-interop-setting-current]')?.textContent?.trim()).toBe('Current value: 120');
    expect(host.querySelector('[data-interop-setting-consequence]')?.textContent?.trim()).toBe('A whole number from 120 to 100000.');
    expect(host.querySelector('[data-interop-setting-default]')).toBeNull();
  });

  // Mutation (Rule 19): drop the `Restart` test from `onOpen`'s statement -> the dialog states the Accepts line alone and this goes red.
  it('states the restart sentence in the dialog for a row whose change takes effect at the next restart, and for no other', async () => {
    const { fixture, host, store, actions } = mount([]);
    await open(fixture, store, actions, STARTUP_SETTING_LIST, 'ErrorPurge');
    expect(host.querySelector('[data-interop-setting-consequence]')?.textContent?.trim()).toBe(`A whole number from 1 to 365. ${STRINGS.encryptionStartupRestart}`);
    expect(STRINGS.encryptionStartupRestart).toBe('Takes effect at the next restart.');
    (host.querySelector('.ocu-dialog-actions button') as HTMLButtonElement).click();
    await settle(fixture);
    await open(fixture, store, actions, STARTUP_SETTING_LIST, 'ShutdownTimeout');
    expect(host.querySelector('[data-interop-setting-consequence]')?.textContent).not.toContain(STRINGS.encryptionStartupRestart);
  });

  // Mutation (Rule 19): drop the purge sentence from `onOpen`'s statement -> the dialog states the Accepts line alone and this goes red.
  it('states the purge sentence in the dialog for a row whose change purges the cached queries, and for no other', async () => {
    const { fixture, host, store, actions } = mount([], SQL_SETTING_LIST);
    await open(fixture, store, actions, SQL_SETTING_LIST, 'FastDistinct');
    expect(host.querySelector('[data-interop-setting-consequence]')?.textContent?.trim()).toBe(`0 (off) or 1 (on). ${STRINGS.configSettingPurge}`);
    expect(STRINGS.configSettingPurge).toBe('Changing this setting purges the cached queries in every namespace.');
    (host.querySelector('.ocu-dialog-actions button') as HTMLButtonElement).click();
    await settle(fixture);
    await open(fixture, store, actions, SQL_SETTING_LIST, 'SaveMAC');
    expect(host.querySelector('[data-interop-setting-consequence]')?.textContent).not.toContain(STRINGS.configSettingPurge);
  });

  // Mutation (Rule 19): drop the `purgeNote.set` after an applied change -> the first assertion goes red.
  it('states the purge sentence above the list after an applied change of such a setting, and after no other', async () => {
    const { fixture, host, store, actions } = mount([UPDATED, UPDATED], SQL_SETTING_LIST);
    await open(fixture, store, actions, SQL_SETTING_LIST, 'FastDistinct');
    (host.querySelector('[data-interop-setting-checkbox]') as HTMLInputElement).click();
    fixture.detectChanges();
    confirm(host);
    await settle(fixture);
    expect(host.querySelector('[data-config-setting-purge]')?.textContent?.trim()).toBe(STRINGS.configSettingPurge);
    expect(host.querySelector('[data-config-setting-restart]')).toBeNull();
    await open(fixture, store, actions, SQL_SETTING_LIST, 'SaveMAC');
    expect(host.querySelector('[data-config-setting-purge]')).toBeNull();
    (host.querySelector('[data-interop-setting-checkbox]') as HTMLInputElement).click();
    fixture.detectChanges();
    confirm(host);
    await settle(fixture);
    expect(host.querySelector('[data-config-setting-purge]')).toBeNull();
  });

  // Mutation (Rule 19): drop `&& value !== target.current` from the purge note's condition -> this goes red.
  it('states no purge sentence after a Save that sends the value the purging setting already holds', async () => {
    const { fixture, host, store, actions } = mount([UPDATED], SQL_SETTING_LIST);
    await open(fixture, store, actions, SQL_SETTING_LIST, 'FastDistinct');
    confirm(host);
    await settle(fixture);
    expect(host.querySelector('[data-config-setting-purge]')).toBeNull();
  });

  // Mutation (Rule 19): drop the `reason` argument from the registration -> the first assertion goes red.
  it('offers no Set value on a row shown and never changed, and opens nothing over it', async () => {
    const { fixture, host, store, actions } = mount([]);
    store.setSelection(['DefaultPort']);
    expect(actions.reason(STARTUP_SETTING_LIST, CONFIG_SET_ACTION)).toBe(STRINGS.configRefusalReadOnly);
    expect(actions.run(STARTUP_SETTING_LIST, CONFIG_SET_ACTION)).toBe(false);
    await settle(fixture);
    expect(host.querySelector('app-interop-item-setting-dialog')).toBeNull();
    store.setSelection(['ShutdownTimeout']);
    expect(actions.reason(STARTUP_SETTING_LIST, CONFIG_SET_ACTION)).toBe('');
  });

  it('sends the typed value as the one value, closes on an applied change and publishes the updated event', async () => {
    const { fixture, host, store, actions, calls, events } = mount([UPDATED]);
    await open(fixture, store, actions, STARTUP_SETTING_LIST, 'ShutdownTimeout');
    type(fixture, host, '301');
    confirm(host);
    await settle(fixture);
    expect(calls[0]).toEqual({
      path: '/api/ocupilot/screens/osmgmt.startupsettings/action',
      method: 'POST',
      body: JSON.stringify({ action: 'set', id: 'ShutdownTimeout', values: { Value: '301' } }),
    });
    expect(host.querySelector('app-interop-item-setting-dialog')).toBeNull();
    expect(events.map((event) => `${event.type}/${event.action}`)).toEqual(['startup-setting/updated']);
    expect(host.querySelector('[data-config-setting-restart]')).toBeNull();
  });

  // Mutation (Rule 19): drop the `restartNote.set` after an applied change -> this goes red.
  it('states the restart sentence above the list after an applied change that needs one', async () => {
    const { fixture, host, store, actions } = mount([UPDATED]);
    await open(fixture, store, actions, STARTUP_SETTING_LIST, 'ErrorPurge');
    type(fixture, host, '31');
    confirm(host);
    await settle(fixture);
    expect(host.querySelector('[data-config-setting-restart]')?.textContent?.trim()).toBe(STRINGS.encryptionStartupRestart);
  });

  it('sends 1 or 0 for a boolean setting', async () => {
    const { fixture, host, store, actions, calls } = mount([UPDATED]);
    await open(fixture, store, actions, STARTUP_SETTING_LIST, 'LineRecall');
    (host.querySelector('[data-interop-setting-checkbox]') as HTMLInputElement).click();
    fixture.detectChanges();
    confirm(host);
    await settle(fixture);
    expect(JSON.parse(calls[0].body).values).toEqual({ Value: '0' });
  });

  it('closes on Cancel, sending nothing and publishing nothing', async () => {
    const { fixture, host, store, actions, calls, events } = mount([]);
    await open(fixture, store, actions, STARTUP_SETTING_LIST, 'ShutdownTimeout');
    const cancel = [...host.querySelectorAll('.ocu-dialog-actions button')].find((button) => button.textContent?.trim() === STRINGS.actionCancel) as HTMLButtonElement;
    cancel.click();
    await settle(fixture);
    expect(host.querySelector('app-interop-item-setting-dialog')).toBeNull();
    expect(calls).toHaveLength(0);
    expect(events).toEqual([]);
  });

  it("keeps a refusal on the value in the dialog as the instance's sentence, and publishes nothing", async () => {
    const reason = 'This setting does not accept that value.';
    const { fixture, host, store, actions, events } = mount([
      { kind: 'error', status: 400, code: 'CONFIG.SETTING.VALUE', reason, detail: { violations: [{ field: 'Value', code: 'CONFIG.SETTING.VALUE', reason }] } } as JsonResult<unknown>,
    ]);
    await open(fixture, store, actions, STARTUP_SETTING_LIST, 'ShutdownTimeout');
    type(fixture, host, '119');
    confirm(host);
    await settle(fixture);
    expect(host.querySelector('[data-interop-setting-violation]')?.textContent?.trim()).toBe(reason);
    expect(events).toEqual([]);
    expect(host.querySelector('[data-config-setting-restart]')).toBeNull();
  });

  it("keeps a refusal that names no field in the dialog as the envelope's own sentence, as the port answers it", async () => {
    const reason = 'This setting does not accept that value.';
    const { fixture, host, store, actions, events } = mount([{ kind: 'error', status: 400, code: 'CONFIG.SETTING.VALUE', reason } as JsonResult<unknown>]);
    await open(fixture, store, actions, STARTUP_SETTING_LIST, 'ShutdownTimeout');
    type(fixture, host, '119');
    confirm(host);
    await settle(fixture);
    expect(host.querySelector('app-interop-item-setting-dialog')).not.toBeNull();
    expect(host.querySelector('[data-interop-setting-reason]')?.textContent?.trim()).toBe(reason);
    expect(events).toEqual([]);
  });

  // Mutation (Rule 19): drop `DDL_USER_MAPPING_LIST` from `SERVED_LISTS` -> the user list's assertions go red.
  it('serves both DDL mapping screens, and registers New mapping on the user list alone', () => {
    const system = mount([], DDL_SYSTEM_MAPPING_LIST);
    expect(system.actions.has(DDL_SYSTEM_MAPPING_LIST, CONFIG_SET_ACTION)).toBe(true);
    expect(system.actions.has(DDL_SYSTEM_MAPPING_LIST, DDL_MAPPING_ADD_ACTION)).toBe(false);
    const user = mount([], DDL_USER_MAPPING_LIST);
    expect(user.actions.has(DDL_USER_MAPPING_LIST, CONFIG_SET_ACTION)).toBe(true);
    expect(user.actions.has(DDL_USER_MAPPING_LIST, DDL_MAPPING_ADD_ACTION)).toBe(true);
    expect(user.actions.has(DDL_SYSTEM_MAPPING_LIST, DDL_MAPPING_ADD_ACTION)).toBe(false);
  });

  // Mutation (Rule 19): drop the `addOpen.set(true)` from `onOpenAdd` -> the dialog assertion goes red.
  it('opens the New mapping dialog from the user list\u2019s primary action, and closes it on Cancel and on an applied create', async () => {
    const { fixture, host, actions, calls } = mount([], DDL_USER_MAPPING_LIST);
    expect(host.querySelector('app-ddl-mapping-dialog')).toBeNull();
    actions.run(DDL_USER_MAPPING_LIST, DDL_MAPPING_ADD_ACTION);
    await settle(fixture);
    expect(host.querySelector('app-ddl-mapping-dialog')).not.toBeNull();
    expect(host.querySelector('.ocu-dialog-title')?.textContent?.trim()).toBe(STRINGS.ddlMappingDialogTitle);
    expect(calls).toHaveLength(0);
    const cancel = [...host.querySelectorAll('.ocu-dialog-actions button')].find((button) => button.textContent?.trim() === STRINGS.actionCancel) as HTMLButtonElement;
    cancel.click();
    await settle(fixture);
    expect(host.querySelector('app-ddl-mapping-dialog')).toBeNull();
  });

  it('opens Set value over a DDL mapping row with the datatype sentence as its statement and no restart or purge sentence', async () => {
    const { fixture, host, store, actions } = mount([], DDL_SYSTEM_MAPPING_LIST);
    await open(fixture, store, actions, DDL_SYSTEM_MAPPING_LIST, 'BIGINT(%1)');
    expect(host.querySelector('.ocu-dialog-title')?.textContent?.trim()).toBe('Set value of BIGINT(%1)');
    expect(host.querySelector('[data-interop-setting-consequence]')?.textContent?.trim()).toBe(STRINGS.configAcceptsDatatype);
    expect(host.querySelector('[data-interop-setting-current]')?.textContent?.trim()).toBe('Current value: %Library.BigInt');
  });

  it('sends the typed datatype as the one value for a DDL mapping and publishes the updated event for its entity type', async () => {
    const { fixture, host, store, actions, calls } = mount([UPDATED], DDL_SYSTEM_MAPPING_LIST);
    await open(fixture, store, actions, DDL_SYSTEM_MAPPING_LIST, 'BIGINT(%1)');
    type(fixture, host, '%Library.Integer');
    confirm(host);
    await settle(fixture);
    expect(calls[0]).toEqual({
      path: '/api/ocupilot/screens/osmgmt.systemddlmappings/action',
      method: 'POST',
      body: JSON.stringify({ action: 'set', id: 'BIGINT(%1)', values: { Value: '%Library.Integer' } }),
    });
  });
});
