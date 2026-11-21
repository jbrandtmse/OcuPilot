import { Component } from '@angular/core';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { Router } from '@angular/router';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type ApiRequestInit, type JsonResult } from '../../core/api';
import { ChangeBus, type ChangeEvent } from '../../core/change-bus';
import { joinCompositeId } from '../../core/entity-id';
import { OverlayStack } from '../../core/overlay-stack';
import { ScreenActions } from '../../core/screen-actions';
import { ScreenStores } from '../../core/screen-store';
import { SCREENS } from '../../core/screens.generated';
import { STRINGS } from '../../core/strings';
import { DetailPage } from '../../shell/detail-page';
import { ListPage } from '../../shell/list-page';
import { LOCALE_ADD_TABLE, LOCALE_LOAD_TABLE, LOCALE_PROPERTY_LIST, ScreenActionHandler } from '../../shell/screen-action-handler';
import { stubAccountPreferences } from '../../testing/account-preferences';
import {
  ANALYTICS_SETTING_LIST,
  COMPATIBILITY_SETTING_LIST,
  CONFIG_SET_ACTION,
  ConfigSettingsPage,
  DDL_MAPPING_ADD_ACTION,
  DDL_SYSTEM_MAPPING_LIST,
  DDL_USER_MAPPING_LIST,
  ISQL_SETTING_LIST,
  MEMORY_SETTING_LIST,
  NLS_DEFAULT_LIST,
  SQL_SETTING_LIST,
  SQL_SHELL_SETTING_LIST,
  STARTUP_SETTING_LIST,
  SYSTEM_SECURITY_SETTING_LIST,
  TASK_MAIL_SETTING_LIST,
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

@Component({ selector: 'app-detail-page', template: '' })
class StubDetailPage {}

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
  row('LocaleFormat', { Value: '0', Kind: 'boolean', Accepts: '0 (off) or 1 (on).', Source: 'locale' }),
  row('Collation', { Value: 'Cache standard', Kind: 'text', ReadOnly: true, Accepts: 'Shown here and never changed here.', Source: 'config' }),
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
function mount(answers: (JsonResult<unknown> | Promise<JsonResult<unknown>>)[], descriptor = STARTUP_SETTING_LIST, rows: readonly Record<string, unknown>[] = ROWS) {
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
  TestBed.overrideComponent(ConfigSettingsPage, { remove: { imports: [ListPage, DetailPage] }, add: { imports: [StubListPage, StubDetailPage] } });
  const store = stores.for(screen.descriptor, screen.refreshRates);
  store.applyTick(rows, false, '', new Date());
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
  // Mutation (Rule 19): drop `SYSTEM_SECURITY_SETTING_LIST` from `SERVED_LISTS` -> the first assertion goes red.
  it('serves System-wide security, and registers Set value on its own screen alone', () => {
    const { actions } = mount([], SYSTEM_SECURITY_SETTING_LIST);
    expect(actions.has(SYSTEM_SECURITY_SETTING_LIST, CONFIG_SET_ACTION)).toBe(true);
    expect(actions.has(STARTUP_SETTING_LIST, CONFIG_SET_ACTION)).toBe(false);
  });

  // Mutation (Rule 19): drop the `systemSecuritySetConsequence` suffix from `openTarget` -> the first assertion goes red, and the Startup dialog's statement is unchanged.
  it('states what a system-wide security change reaches after the line of the setting itself, and only on that screen', async () => {
    const security = mount([], SYSTEM_SECURITY_SETTING_LIST);
    await open(security.fixture, security.store, security.actions, SYSTEM_SECURITY_SETTING_LIST, 'LineRecall');
    expect(security.host.querySelector('[data-interop-setting-consequence]')?.textContent?.trim()).toBe(`0 (off) or 1 (on). ${STRINGS.systemSecuritySetConsequence}`);
    expect(STRINGS.systemSecuritySetConsequence).toBe('This changes how every user on this instance signs in, is locked out, or is checked.');
    const startup = mount([], STARTUP_SETTING_LIST);
    await open(startup.fixture, startup.store, startup.actions, STARTUP_SETTING_LIST, 'LineRecall');
    expect(startup.host.querySelector('[data-interop-setting-consequence]')?.textContent).not.toContain(STRINGS.systemSecuritySetConsequence);
  });

  describe('Task Manager email (Story 21.19)', () => {
    const MAIL_ROWS = [
      row('Port', { Value: '', Kind: 'text', Accepts: 'Text of up to 5 characters.' }),
      row('UseSTARTTLS', { Value: '', Kind: 'boolean', Accepts: '0 (off) or 1 (on).' }),
      row('SubjectSuccess', { Value: '', Kind: 'text', Accepts: 'Text of up to 255 characters.' }),
      row('MessageSuccess', { Value: 'Hello', Kind: 'text', Accepts: 'Text of up to 32000 characters.' }),
    ];
    const MAIL_UPDATED: JsonResult<unknown> = {
      kind: 'ok',
      status: 200,
      body: { action: 'updated', target: { type: 'task-mail-setting', scope: 'instance', id: 'Port' }, readBack: { verdict: 'matches' } },
    };

    // Mutation (Rule 19): drop `TASK_MAIL_SETTING_LIST` from `SERVED_LISTS` -> the first assertion goes red.
    it('serves Task Manager email, and registers Set value on its own screen alone', () => {
      const { actions } = mount([], TASK_MAIL_SETTING_LIST, MAIL_ROWS);
      expect(actions.has(TASK_MAIL_SETTING_LIST, CONFIG_SET_ACTION)).toBe(true);
      expect(actions.has(STARTUP_SETTING_LIST, CONFIG_SET_ACTION)).toBe(false);
    });

    it("sends the typed port as the one value to the screen's own route and publishes the updated event of its entity type", async () => {
      const { fixture, host, store, actions, calls, events } = mount([MAIL_UPDATED], TASK_MAIL_SETTING_LIST, MAIL_ROWS);
      await open(fixture, store, actions, TASK_MAIL_SETTING_LIST, 'Port');
      type(fixture, host, '587');
      confirm(host);
      await settle(fixture);
      expect(calls[0]).toEqual({
        path: '/api/ocupilot/screens/tasks.mail/action',
        method: 'POST',
        body: JSON.stringify({ action: 'set', id: 'Port', values: { Value: '587' } }),
      });
      expect(events.map((event) => `${event.type}/${event.action}`)).toEqual(['task-mail-setting/updated']);
      expect(host.querySelector('app-interop-item-setting-dialog')).toBeNull();
      expect(host.querySelector('[data-config-setting-restart]')).toBeNull();
    });

    it('sends 1 for the STARTTLS switch, drawn as a checkbox', async () => {
      const { fixture, host, store, actions, calls } = mount([MAIL_UPDATED], TASK_MAIL_SETTING_LIST, MAIL_ROWS);
      await open(fixture, store, actions, TASK_MAIL_SETTING_LIST, 'UseSTARTTLS');
      expect(host.querySelector('[data-interop-setting-checkbox]')).not.toBeNull();
      (host.querySelector('[data-interop-setting-checkbox]') as HTMLInputElement).click();
      fixture.detectChanges();
      confirm(host);
      await settle(fixture);
      expect(JSON.parse(calls[0].body).values).toEqual({ Value: '1' });
    });

    // Mutation (Rule 19): drop the `multiline` binding from the page's dialog -> the message row's text area assertion goes red.
    it('draws a message as a text area that sends its whole 32000 characters, and a subject as one line', async () => {
      const message = mount([MAIL_UPDATED], TASK_MAIL_SETTING_LIST, MAIL_ROWS);
      await open(message.fixture, message.store, message.actions, TASK_MAIL_SETTING_LIST, 'MessageSuccess');
      expect(message.host.querySelector('textarea[data-interop-setting-value]')).not.toBeNull();
      const long = `Line one\nLine two #(NAME)# ${'x'.repeat(32000 - 27)}`;
      expect(long).toHaveLength(32000);
      const field = message.host.querySelector('textarea[data-interop-setting-value]') as HTMLTextAreaElement;
      field.value = long;
      field.dispatchEvent(new Event('input'));
      message.fixture.detectChanges();
      confirm(message.host);
      await settle(message.fixture);
      expect(JSON.parse(message.calls[0].body).values).toEqual({ Value: long });
      const subject = mount([], TASK_MAIL_SETTING_LIST, MAIL_ROWS);
      await open(subject.fixture, subject.store, subject.actions, TASK_MAIL_SETTING_LIST, 'SubjectSuccess');
      expect(subject.host.querySelector('textarea[data-interop-setting-value]')).toBeNull();
      expect(subject.host.querySelector('input[type="text"][data-interop-setting-value]')).not.toBeNull();
    });

    it("keeps the instance's sentence naming the Task Manager's fields on the value when a subject holds another field, and publishes nothing", async () => {
      const reason = 'Use only these fields between #( and )#: ID, DESCRIPTION, NAME, SERVER, INSTANCE, LASTSTARTED, LASTFINISHED, SCHEDULED, CURRENTDATE, CURRENTTIME, STATUS, TASKCLASS, ERROR, SUCCESS.';
      const { fixture, host, store, actions, events } = mount(
        [{ kind: 'error', status: 400, code: 'CONFIG.SETTING.SUBSTITUTION', reason, detail: { violations: [{ field: 'Value', code: 'CONFIG.SETTING.SUBSTITUTION', reason }] } } as JsonResult<unknown>],
        TASK_MAIL_SETTING_LIST,
        MAIL_ROWS
      );
      await open(fixture, store, actions, TASK_MAIL_SETTING_LIST, 'SubjectSuccess');
      type(fixture, host, '#(BOGUS)#');
      confirm(host);
      await settle(fixture);
      expect(host.querySelector('[data-interop-setting-violation]')?.textContent?.trim()).toBe(reason);
      expect(events).toEqual([]);
    });

    const PASSWORD_UPDATED: JsonResult<unknown> = {
      kind: 'ok',
      status: 200,
      body: { action: 'updated', target: { type: 'task-mail-setting', scope: 'instance', id: 'AuthUser' }, readBack: { verdict: 'written' } },
    };

    // Mutation (Rule 19): drop this page's `actions.register` of `password` -> the first assertion goes red.
    it('registers Set mail password on its own screen alone, drawn with its ruled words', () => {
      const { actions } = mount([], TASK_MAIL_SETTING_LIST, MAIL_ROWS);
      expect(actions.has(TASK_MAIL_SETTING_LIST, 'password')).toBe(true);
      expect(actions.has(STARTUP_SETTING_LIST, 'password')).toBe(false);
      expect(STRINGS.taskMailPasswordAction).toBe('Set mail password');
    });

    // Mutation (Rule 19): send `setkey` and `GoogleMapsKey` for this screen -> the sent-action assertion goes red; open the dialog with `secret` false -> the masked-field assertions go red.
    it("opens the toolbar's dialog as an empty masked field titled Set mail password, whatever row is selected, and sends the password by the mail password's own action", async () => {
      const { fixture, host, store, actions, calls, events } = mount([PASSWORD_UPDATED], TASK_MAIL_SETTING_LIST, MAIL_ROWS);
      store.setSelection(['Port']);
      actions.run(TASK_MAIL_SETTING_LIST, 'password');
      await settle(fixture);
      expect(calls).toHaveLength(0);
      expect(host.querySelector('.ocu-dialog-title')?.textContent?.trim()).toBe('Set mail password');
      const field = host.querySelector('[data-interop-setting-secret]') as HTMLInputElement;
      expect(field).not.toBeNull();
      expect(field.type).toBe('password');
      expect(field.value).toBe('');
      expect(host.querySelector('[data-interop-setting-current]')).toBeNull();
      expect(host.querySelector('[data-interop-setting-consequence]')).toBeNull();
      expect(host.textContent?.split(STRINGS.interopSettingEmptyHint).length).toBe(2);
      type(fixture, host, 'a-mail-secret');
      confirm(host);
      await settle(fixture);
      expect(calls[0]).toEqual({
        path: '/api/ocupilot/screens/tasks.mail/action',
        method: 'POST',
        body: JSON.stringify({ action: 'password', id: 'AuthUser', values: { AuthPassword: 'a-mail-secret' } }),
      });
      expect(events.map((event) => `${event.type}/${event.action}`)).toEqual(['task-mail-setting/updated']);
      expect(host.querySelector('app-interop-item-setting-dialog')).toBeNull();
    });

    it('sends an empty value, which clears the password, and still sends a row\'s own Set value by Set value', async () => {
      const cleared = mount([PASSWORD_UPDATED], TASK_MAIL_SETTING_LIST, MAIL_ROWS);
      cleared.actions.run(TASK_MAIL_SETTING_LIST, 'password');
      await settle(cleared.fixture);
      confirm(cleared.host);
      await settle(cleared.fixture);
      expect(JSON.parse(cleared.calls[0].body)).toEqual({ action: 'password', id: 'AuthUser', values: { AuthPassword: '' } });
      const row = mount([MAIL_UPDATED], TASK_MAIL_SETTING_LIST, MAIL_ROWS);
      await open(row.fixture, row.store, row.actions, TASK_MAIL_SETTING_LIST, 'Port');
      expect(row.host.querySelector('[data-interop-setting-secret]')).toBeNull();
      type(row.fixture, row.host, '587');
      confirm(row.host);
      await settle(row.fixture);
      expect(JSON.parse(row.calls[0].body)).toEqual({ action: 'set', id: 'Port', values: { Value: '587' } });
    });
  });

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
  it('opens the New mapping dialog from the user list\u2019s primary action, and closes it on Cancel', async () => {
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

  it('sends the typed datatype as the one value for a DDL mapping, on the screen\u2019s own action route', async () => {
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

  // Mutation (Rule 19): drop `NLS_DEFAULT_LIST` from `SERVED_LISTS` -> the first assertion goes red.
  it('serves NLS configured defaults, and offers Set value on the locale-format switch alone', async () => {
    const { fixture, host, store, actions } = mount([], NLS_DEFAULT_LIST);
    expect(actions.has(NLS_DEFAULT_LIST, CONFIG_SET_ACTION)).toBe(true);
    store.setSelection(['Collation']);
    expect(actions.reason(NLS_DEFAULT_LIST, CONFIG_SET_ACTION)).toBe(STRINGS.configRefusalReadOnly);
    expect(actions.run(NLS_DEFAULT_LIST, CONFIG_SET_ACTION)).toBe(false);
    await settle(fixture);
    expect(host.querySelector('app-interop-item-setting-dialog')).toBeNull();
    store.setSelection(['LocaleFormat']);
    expect(actions.reason(NLS_DEFAULT_LIST, CONFIG_SET_ACTION)).toBe('');
  });

  // Mutation (Rule 19): drop the `reloads` branch from `onOpen`'s statement -> the dialog states the Accepts line alone and this goes red.
  it('states the reload sentence in the dialog and after an applied change of the locale-format switch', async () => {
    const { fixture, host, store, actions, calls } = mount([UPDATED], NLS_DEFAULT_LIST);
    await open(fixture, store, actions, NLS_DEFAULT_LIST, 'LocaleFormat');
    expect(host.querySelector('[data-interop-setting-consequence]')?.textContent?.trim()).toBe(`0 (off) or 1 (on). ${STRINGS.nlsDefaultReloadConsequence}`);
    (host.querySelector('[data-interop-setting-checkbox]') as HTMLInputElement).click();
    fixture.detectChanges();
    confirm(host);
    await settle(fixture);
    expect(calls[0]).toEqual({
      path: '/api/ocupilot/screens/osmgmt.nlsdefaults/action',
      method: 'POST',
      body: JSON.stringify({ action: 'set', id: 'LocaleFormat', values: { Value: '1' } }),
    });
    expect(host.querySelector('[data-config-setting-reload]')?.textContent?.trim()).toBe(STRINGS.nlsDefaultReloadConsequence);
    expect(host.querySelector('[data-config-setting-restart]')).toBeNull();
    expect(host.querySelector('[data-config-setting-purge]')).toBeNull();
  });

  describe('locale properties', () => {
    const property = (name: string, refusal = ''): Record<string, unknown> => ({
      Locale: 'yzzw',
      Group: 'tables',
      Name: name,
      Value: 'Unicode',
      Kind: 'table',
      Accepts: STRINGS.configAcceptsReadOnly,
      ReadOnly: true,
      Refusal: refusal,
      Loadable: false,
    });
    const rows = [property('PatternTables:Unicode')];
    const CREATED: JsonResult<unknown> = {
      kind: 'ok',
      status: 201,
      body: { id: 'x', target: { type: 'locale-property', scope: 'instance', id: 'yzzw\u0001PatternTables:Latin2' }, readBack: { verdict: 'matches' } },
    };

    const fill = (host: HTMLElement, field: string, value: string): void => {
      const control = host.querySelector(`[data-locale-table-field="${field}"]`) as HTMLInputElement | HTMLSelectElement;
      control.value = value;
      control.dispatchEvent(new Event(control instanceof HTMLSelectElement ? 'change' : 'input'));
    };

    it('registers Add table on the properties screen alone and gives the refusal its locale carries as its reason', () => {
      const current = mount([], LOCALE_PROPERTY_LIST, [property('PatternTables:Unicode', 'LOCALE.EDIT.CURRENT')]);
      expect(current.actions.has(LOCALE_PROPERTY_LIST, LOCALE_ADD_TABLE)).toBe(true);
      expect(current.actions.reason(LOCALE_PROPERTY_LIST, LOCALE_ADD_TABLE)).toBe(STRINGS.localeRefusalEditCurrent);
      const custom = mount([], LOCALE_PROPERTY_LIST, rows);
      expect(custom.actions.reason(LOCALE_PROPERTY_LIST, LOCALE_ADD_TABLE)).toBe('');
      expect(mount([], STARTUP_SETTING_LIST).actions.has(STARTUP_SETTING_LIST, LOCALE_ADD_TABLE)).toBe(false);
    });

    // Mutation (Rule 19): drop the `localeEditRefusal` branch from Set value's reason -> the shipped locale's sentence goes red.
    it('gives Set value the refusal its locale carries as its reason, and the read-only sentence only on a row that carries none', () => {
      const settable = (refusal: string): Record<string, unknown> => ({ ...property('DateFormat', refusal), Group: 'formats', Kind: 'integer', ReadOnly: false });
      const shipped = mount([], LOCALE_PROPERTY_LIST, [settable('LOCALE.EDIT.SYSTEM')]);
      shipped.store.setSelection([joinCompositeId(['yzzw', 'DateFormat'])]);
      expect(shipped.actions.reason(LOCALE_PROPERTY_LIST, CONFIG_SET_ACTION)).toBe(STRINGS.localeRefusalEditSystem);
      expect(shipped.actions.run(LOCALE_PROPERTY_LIST, CONFIG_SET_ACTION)).toBe(false);
      const custom = mount([], LOCALE_PROPERTY_LIST, [settable('')]);
      custom.store.setSelection([joinCompositeId(['yzzw', 'DateFormat'])]);
      expect(custom.actions.reason(LOCALE_PROPERTY_LIST, CONFIG_SET_ACTION)).toBe('');
      const shown = mount([], LOCALE_PROPERTY_LIST, rows);
      shown.store.setSelection([joinCompositeId(['yzzw', 'PatternTables:Unicode'])]);
      expect(shown.actions.reason(LOCALE_PROPERTY_LIST, CONFIG_SET_ACTION)).toBe(STRINGS.configRefusalReadOnly);
    });

    // Mutation (Rule 19): drop `LOCALE_PROPERTY_LIST` from `DESTRUCTIVE_ON` -> Load table is sent at once, no confirmation opens and this goes red.
    it('confirms Load table before it sends anything and states the published consequence', async () => {
      const id = joinCompositeId(['yzzw', 'PatternTables:Unicode']);
      const { fixture, store, actions, handler, calls } = mount([], LOCALE_PROPERTY_LIST, [{ ...property('PatternTables:Unicode'), Loadable: true }]);
      store.setSelection([id]);
      actions.run(LOCALE_PROPERTY_LIST, LOCALE_LOAD_TABLE);
      await settle(fixture);
      expect(handler.pending()?.kind).toBe('typed-name');
      expect(handler.pending()?.consequence).toBe(STRINGS.localeLoadConsequence);
      expect(handler.pending()?.target).toBe(id);
      expect(handler.pending()?.name).toBe('PatternTables:Unicode');
      expect(calls).toEqual([]);
      handler.confirmPending();
      await settle(fixture);
      expect(calls).toEqual([{ path: '/api/ocupilot/screens/osmgmt.localeproperties/action', method: 'POST', body: JSON.stringify({ action: LOCALE_LOAD_TABLE, id }) }]);
    });

    // Mutation (Rule 19): post to the screen's action route instead of `/api/ocupilot/locale-properties` -> the path and body assertions go red.
    it('posts an internal table of the locale on screen to the Save route and announces the row the server created', async () => {
      const { fixture, host, actions, calls, events } = mount([CREATED], LOCALE_PROPERTY_LIST, rows);
      actions.run(LOCALE_PROPERTY_LIST, LOCALE_ADD_TABLE);
      await settle(fixture);
      expect(host.querySelector('app-locale-table-dialog')).not.toBeNull();
      expect(host.querySelector('[data-locale-table-field="InputFrom"]')).toBeNull();
      fill(host, 'Table', 'Latin2');
      await settle(fixture);
      (host.querySelector('[data-locale-table-confirm]') as HTMLButtonElement).click();
      await settle(fixture);
      expect(calls).toEqual([{ path: '/api/ocupilot/locale-properties', method: 'POST', body: JSON.stringify({ Locale: 'yzzw', Name: 'PatternTables:Latin2' }) }]);
      expect(host.querySelector('app-locale-table-dialog')).toBeNull();
      expect(events.map((event) => `${event.type}|${event.scope}|${event.id}|${event.action}|${event.tool}`)).toEqual([
        'locale-property|instance|yzzw\u0001PatternTables:Latin2|created|osmgmt.localeproperties.add',
      ]);
    });

    it('sends the two sides of an input/output table and no others', async () => {
      const { fixture, host, actions, calls } = mount([CREATED], LOCALE_PROPERTY_LIST, rows);
      actions.run(LOCALE_PROPERTY_LIST, LOCALE_ADD_TABLE);
      await settle(fixture);
      fill(host, 'Type', 'XLTTables');
      await settle(fixture);
      fill(host, 'Table', 'myio');
      fill(host, 'InputFrom', 'Latin2');
      fill(host, 'OutputTo', 'Latin2');
      await settle(fixture);
      (host.querySelector('[data-locale-table-confirm]') as HTMLButtonElement).click();
      await settle(fixture);
      expect(JSON.parse(calls[0]?.body ?? '{}')).toEqual({ Locale: 'yzzw', Name: 'XLTTables:myio', InputFrom: 'Latin2', OutputTo: 'Latin2' });
    });

    it('keeps the dialog open with the sentence the server gave when the add is refused, and publishes nothing', async () => {
      const refused: JsonResult<unknown> = { kind: 'error', status: 409, code: 'LOCALE.TABLE.TAKEN', reason: STRINGS.localeRefusalTableTaken, detail: null };
      const { fixture, host, actions, events } = mount([refused], LOCALE_PROPERTY_LIST, rows);
      actions.run(LOCALE_PROPERTY_LIST, LOCALE_ADD_TABLE);
      await settle(fixture);
      fill(host, 'Table', 'Unicode');
      await settle(fixture);
      (host.querySelector('[data-locale-table-confirm]') as HTMLButtonElement).click();
      await settle(fixture);
      expect(host.querySelector('[data-locale-table-reason]')?.textContent?.trim()).toBe(STRINGS.localeRefusalTableTaken);
      expect(events).toEqual([]);
    });
  });
});

describe('the settings page over the analytics General tab (Story 24.13)', () => {
  const general = (name: string, extra: Record<string, unknown> = {}): Record<string, unknown> => ({
    Name: name,
    Value: '',
    Stored: true,
    Kind: 'text',
    Accepts: 'Text of up to 2000 characters.',
    ...extra,
  });
  const GENERAL_ROWS = [
    general('PageTitle', { Value: 'Title' }),
    general('GoogleMapsKey', { Value: '[redacted]', Kind: 'secret' }),
    general('DashboardNoTitle', { Kind: 'boolean', Accepts: '0 (off) or 1 (on).' }),
    general('Worklist', { Value: '0', Kind: 'boolean', Accepts: '0 (off) or 1 (on).' }),
  ];
  const UPDATED_SETTING: JsonResult<unknown> = {
    kind: 'ok',
    status: 200,
    body: { action: 'updated', target: { type: 'analytics-setting', scope: 'USER', id: 'PageTitle' }, readBack: { verdict: 'matches' } },
  };

  // Mutation (Rule 19): drop `ANALYTICS_SETTING_LIST` from `SERVED_LISTS` -> this goes red.
  it('registers Set value on the General tab', () => {
    const { actions } = mount([], ANALYTICS_SETTING_LIST, GENERAL_ROWS);
    expect(actions.has(ANALYTICS_SETTING_LIST, CONFIG_SET_ACTION)).toBe(true);
  });

  // Mutation (Rule 19): send `set` for a secret row -> the action leg goes red; prefill the field with the row's value -> the empty-field leg goes red.
  it('opens a secret row as an empty masked field with a reveal toggle and sends its text by the key\'s own action', async () => {
    const { fixture, host, store, actions, calls } = mount([UPDATED_SETTING], ANALYTICS_SETTING_LIST, GENERAL_ROWS);
    await open(fixture, store, actions, ANALYTICS_SETTING_LIST, 'GoogleMapsKey');
    const field = host.querySelector('[data-interop-setting-secret]') as HTMLInputElement;
    expect(field).not.toBeNull();
    expect(field.type).toBe('password');
    expect(field.value).toBe('');
    (host.querySelector('[data-interop-setting-reveal]') as HTMLButtonElement).click();
    fixture.detectChanges();
    expect((host.querySelector('[data-interop-setting-secret]') as HTMLInputElement).type).toBe('text');
    type(fixture, host, 'a-key-text');
    confirm(host);
    await settle(fixture);
    expect(calls[0]).toEqual({
      path: '/api/ocupilot/screens/analytics.settings/action',
      method: 'POST',
      body: JSON.stringify({ action: 'setkey', id: 'GoogleMapsKey', values: { GoogleMapsKey: 'a-key-text' } }),
    });
    expect(host.querySelector('app-interop-item-setting-dialog')).toBeNull();
  });

  // Mutation (Rule 19): make a text row secret in `onOpen` -> the plain-field leg goes red.
  it('opens a text row as the shared dialog does and sends Set value with its one value', async () => {
    const { fixture, host, store, actions, calls } = mount([UPDATED_SETTING], ANALYTICS_SETTING_LIST, GENERAL_ROWS);
    await open(fixture, store, actions, ANALYTICS_SETTING_LIST, 'PageTitle');
    expect(host.querySelector('[data-interop-setting-secret]')).toBeNull();
    expect((host.querySelector('[data-interop-setting-value]') as HTMLInputElement).value).toBe('Title');
    type(fixture, host, 'New title');
    confirm(host);
    await settle(fixture);
    expect(JSON.parse(calls[0]?.body ?? '{}')).toEqual({ action: 'set', id: 'PageTitle', values: { Value: 'New title' } });
  });

  // Mutation (Rule 19): drop the `saves` test from `onOpen`'s statement -> the dialog states the Accepts line alone and the first assertion goes red.
  it('states the save sentence in the dialog and after the change while a General row is not stored, and not once every row is', async () => {
    const unstored = GENERAL_ROWS.map((entry) => (entry['Name'] === 'DashboardNoTitle' ? { ...entry, Stored: false } : entry));
    const first = mount([UPDATED_SETTING], ANALYTICS_SETTING_LIST, unstored);
    await open(first.fixture, first.store, first.actions, ANALYTICS_SETTING_LIST, 'PageTitle');
    expect(first.host.querySelector('[data-interop-setting-consequence]')?.textContent?.trim()).toBe(`Text of up to 2000 characters. ${STRINGS.analyticsSettingSaveConsequence}`);
    type(first.fixture, first.host, 'x');
    confirm(first.host);
    await settle(first.fixture);
    expect(first.host.querySelector('[data-config-setting-save]')?.textContent?.trim()).toBe(STRINGS.analyticsSettingSaveConsequence);
    const second = mount([UPDATED_SETTING], ANALYTICS_SETTING_LIST, GENERAL_ROWS);
    await open(second.fixture, second.store, second.actions, ANALYTICS_SETTING_LIST, 'PageTitle');
    expect(second.host.querySelector('[data-interop-setting-consequence]')?.textContent).not.toContain(STRINGS.analyticsSettingSaveConsequence);
    const flag = mount([UPDATED_SETTING], ANALYTICS_SETTING_LIST, unstored);
    await open(flag.fixture, flag.store, flag.actions, ANALYTICS_SETTING_LIST, 'Worklist');
    expect(flag.host.querySelector('[data-interop-setting-consequence]')?.textContent).not.toContain(STRINGS.analyticsSettingSaveConsequence);
  });
});
