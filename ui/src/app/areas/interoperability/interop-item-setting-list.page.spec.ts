import { Component } from '@angular/core';
import { ComponentFixture, TestBed } from '@angular/core/testing';
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
import { INTEROP_ITEM_SETTING_LIST, INTEROP_SETTING_SET_ACTION, InteropItemSettingListPage } from './interop-item-setting-list.page';

/**
 * The Item settings page (Story 20.22). The shared list page is replaced by an empty stand-in, so only this page's
 * own wiring runs: the one action it registers after the shell's handler, the dialog it opens over the selected row,
 * no dialog over a secret setting, the request each Set value sends -- an empty value included -- a refusal kept in the
 * dialog and the change event an applied change publishes. The handler, the stores and the bus are real; only the
 * server's answers are stubbed.
 */

@Component({ selector: 'app-list-page', template: '' })
class StubListPage {}

const LIST = SCREENS.find((screen) => screen.descriptor === INTEROP_ITEM_SETTING_LIST)!;

const SEP = '\u0001';

const row = (target: string, name: string, extra: Record<string, unknown> = {}): Record<string, unknown> => ({
  Production: 'P.Prod',
  Item: 'Item',
  Target: target,
  Name: name,
  Value: '',
  Source: 'classDefault',
  Default: '',
  DefaultSource: 'classDefault',
  Type: '%Library.String',
  Category: 'Basic',
  Location: false,
  Secret: false,
  ...extra,
});

const ROWS = [
  row('Host', 'InitSeconds', { Value: '7', Source: 'production', Default: '0', Type: '%Library.Integer' }),
  row('Host', 'ProbeDirectory', { Location: true }),
  row('Host', 'ApiToken', { Secret: true }),
  row('Core', 'LogTraceEvents', { Value: '0', Default: '0', Type: '%Library.Boolean' }),
];

const id = (target: string, name: string): string => ['P.Prod', 'Item', target, name].join(SEP);

const UPDATED: JsonResult<unknown> = {
  kind: 'ok',
  status: 200,
  body: { action: 'updated', target: { type: 'production-item-setting', scope: 'namespace:USER', id: id('Host', 'InitSeconds') }, readBack: { verdict: 'matches' } },
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

/** Mount the page over `ROWS`; each request resolves to the next of `answers`. */
function mount(answers: (JsonResult<unknown> | Promise<JsonResult<unknown>>)[]) {
  TestBed.resetTestingModule();
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
    ],
  });
  TestBed.overrideComponent(InteropItemSettingListPage, { remove: { imports: [ListPage] }, add: { imports: [StubListPage] } });
  const store = stores.for(LIST.descriptor, LIST.refreshRates);
  store.applyTick(ROWS, false, '', new Date());
  const fixture = TestBed.createComponent(InteropItemSettingListPage);
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  fixture.detectChanges();
  return { fixture, host: fixture.nativeElement as HTMLElement, store, calls, events, actions: TestBed.inject(ScreenActions), handler: TestBed.inject(ScreenActionHandler) };
}

async function open(fixture: ComponentFixture<unknown>, store: ReturnType<typeof mount>['store'], actions: ScreenActions, rowId: string): Promise<void> {
  store.setSelection([rowId]);
  actions.run(INTEROP_ITEM_SETTING_LIST, INTEROP_SETTING_SET_ACTION);
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

describe('the Item settings page', () => {
  // Mutation (Rule 19): drop this page's `actions.register` of `set` -> the first assertion goes red.
  it('registers Set value beside the handler\'s Reset to default, and opens its dialog over the selected row', async () => {
    const { fixture, host, store, actions, calls } = mount([]);
    expect(actions.has(INTEROP_ITEM_SETTING_LIST, INTEROP_SETTING_SET_ACTION)).toBe(true);
    expect(actions.has(INTEROP_ITEM_SETTING_LIST, 'reset')).toBe(true);
    actions.run(INTEROP_ITEM_SETTING_LIST, INTEROP_SETTING_SET_ACTION);
    await settle(fixture);
    expect(host.querySelector('app-interop-item-setting-dialog')).toBeNull();
    await open(fixture, store, actions, id('Host', 'InitSeconds'));
    expect(calls).toHaveLength(0);
    expect(host.querySelector('.ocu-dialog-title')?.textContent?.trim()).toBe('Set value of InitSeconds');
    expect(host.querySelector('[data-interop-setting-current]')?.textContent?.trim()).toBe('Current value: 7');
  });

  // Mutation (Rule 19): drop the secret test from `onOpen` -> this goes red.
  it('opens no dialog over a secret setting and puts its sentence on the list', async () => {
    const { fixture, host, store, actions } = mount([]);
    await open(fixture, store, actions, id('Host', 'ApiToken'));
    expect(host.querySelector('app-interop-item-setting-dialog')).toBeNull();
    expect(store.refusal()).toBe(STRINGS.interopSettingRefusalSecret);
  });

  it('sends the typed value as the one value, closes on an applied change and publishes the updated event', async () => {
    const { fixture, host, store, actions, calls, events } = mount([UPDATED]);
    await open(fixture, store, actions, id('Host', 'InitSeconds'));
    type(fixture, host, '9');
    confirm(host);
    await settle(fixture);
    expect(calls[0]).toEqual({
      path: '/api/ocupilot/screens/interop.itemsettings/action',
      method: 'POST',
      body: JSON.stringify({ action: 'set', id: id('Host', 'InitSeconds'), values: { Value: '9' } }),
    });
    expect(host.querySelector('app-interop-item-setting-dialog')).toBeNull();
    expect(events.map((event) => `${event.type}/${event.action}`)).toEqual(['production-item-setting/updated']);
    expect(store.refusal()).toBe('');
  });

  // Mutation (Rule 19): drop `(cancelled)="onClose()"` from the page's template -> the dialog stays and this goes red.
  it('closes on Cancel, sending nothing and publishing nothing', async () => {
    const { fixture, host, store, actions, calls, events } = mount([]);
    await open(fixture, store, actions, id('Host', 'InitSeconds'));
    expect(host.querySelector('app-interop-item-setting-dialog')).not.toBeNull();
    const cancel = [...host.querySelectorAll('.ocu-dialog-actions button')].find((button) => button.textContent?.trim() === STRINGS.actionCancel) as HTMLButtonElement;
    cancel.click();
    await settle(fixture);
    expect(host.querySelector('app-interop-item-setting-dialog')).toBeNull();
    expect(calls).toHaveLength(0);
    expect(events).toEqual([]);
  });

  it('sends an empty value, which clears the setting', async () => {
    const { fixture, host, store, actions, calls } = mount([UPDATED]);
    await open(fixture, store, actions, id('Host', 'InitSeconds'));
    type(fixture, host, '');
    confirm(host);
    await settle(fixture);
    expect(JSON.parse(calls[0].body)).toEqual({ action: 'set', id: id('Host', 'InitSeconds'), values: { Value: '' } });
  });

  it('sends 1 or 0 for a boolean setting', async () => {
    const { fixture, host, store, actions, calls } = mount([UPDATED]);
    await open(fixture, store, actions, id('Core', 'LogTraceEvents'));
    (host.querySelector('[data-interop-setting-checkbox]') as HTMLInputElement).click();
    fixture.detectChanges();
    confirm(host);
    await settle(fixture);
    expect(JSON.parse(calls[0].body).values).toEqual({ Value: '1' });
  });

  it("keeps a refusal on the value in the dialog as the instance's sentence, and publishes nothing", async () => {
    const reason = "The item's class does not accept this value for this setting.";
    const { fixture, host, store, actions, events } = mount([
      {
        kind: 'error',
        status: 422,
        code: 'INTEROP.SETTING.VALUE',
        reason,
        detail: { violations: [{ field: 'Value', code: 'INTEROP.SETTING.VALUE', reason }] },
      } as JsonResult<unknown>,
    ]);
    await open(fixture, store, actions, id('Host', 'InitSeconds'));
    type(fixture, host, 'abc');
    confirm(host);
    await settle(fixture);
    expect(host.querySelector('[data-interop-setting-violation]')?.textContent?.trim()).toBe(reason);
    expect(events).toEqual([]);
    expect(store.refusal()).toBe('');
  });

  it('draws a refusal that names no field above the value', async () => {
    const { fixture, host, store, actions } = mount([
      { kind: 'error', status: 409, code: 'INTEROP.SETTING.SAME', reason: STRINGS.interopSettingRefusalSame } as JsonResult<unknown>,
    ]);
    await open(fixture, store, actions, id('Host', 'InitSeconds'));
    confirm(host);
    await settle(fixture);
    expect(host.querySelector('[data-interop-setting-reason]')?.textContent?.trim()).toBe(STRINGS.interopSettingRefusalSame);
  });
});
