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
import { INTEROP_AUTO_START_ACTION, INTEROP_PRODUCTION_LIST, INTEROP_SHUTDOWN_GROUP_ACTION, InteropProductionListPage } from './interop-production-list.page';

/**
 * The Productions page (Story 24.3). The shared list page is replaced by an empty stand-in, so only this page's own wiring runs: the two
 * actions it registers after the shell's handler, the dialog each opens over the selected row at that row's values, the request each
 * sends under the names its tool declares, a refusal kept in the dialog, the change event an applied change publishes, and the five
 * actions the handler's construction registers, which stay as the list sent them. The handler, the stores and the bus are real; only the
 * server's answers are stubbed.
 */

@Component({ selector: 'app-list-page', template: '' })
class StubListPage {}

const LIST = SCREENS.find((screen) => screen.descriptor === INTEROP_PRODUCTION_LIST)!;

const row = (name: string, extra: Record<string, unknown> = {}): Record<string, unknown> => ({
  Name: name,
  Status: 'Stopped',
  LastStartTime: '',
  LastStopTime: '',
  AutoStart: 'No',
  StartupPriority: '',
  ShutdownGroup: '2',
  ...extra,
});

const ROWS = [row('Demo.Auto', { AutoStart: 'Yes', StartupPriority: '5', ShutdownGroup: '3' }), row('Demo.Plain')];

const UPDATED: JsonResult<unknown> = {
  kind: 'ok',
  status: 200,
  body: { action: 'updated', target: { type: 'production', scope: 'namespace:USER', id: 'Demo.Plain' }, readBack: { verdict: 'matches' } },
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

/** Configure the testing module over stubbed answers: each request resolves to the next of `answers`. */
function configure(answers: JsonResult<unknown>[]) {
  TestBed.resetTestingModule();
  const calls: Call[] = [];
  const api = {
    requestJson: async <T,>(path: string, init: ApiRequestInit = {}): Promise<JsonResult<T>> => {
      calls.push({ path, method: init.method ?? 'GET', body: init.body ?? '' });
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
    ],
  });
  return { calls, events, stores };
}

/** Mount the page over `ROWS`. */
function mount(answers: JsonResult<unknown>[]) {
  const { calls, events, stores } = configure(answers);
  TestBed.overrideComponent(InteropProductionListPage, { remove: { imports: [ListPage] }, add: { imports: [StubListPage] } });
  const store = stores.for(LIST.descriptor, LIST.refreshRates);
  store.applyTick(ROWS, false, '', new Date());
  const fixture = TestBed.createComponent(InteropProductionListPage);
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  fixture.detectChanges();
  return { fixture, host: fixture.nativeElement as HTMLElement, store, calls, events, actions: TestBed.inject(ScreenActions), handler: TestBed.inject(ScreenActionHandler) };
}

async function open(fixture: ComponentFixture<unknown>, store: ReturnType<typeof mount>['store'], actions: ScreenActions, action: string, name: string): Promise<void> {
  store.setSelection([name]);
  actions.run(INTEROP_PRODUCTION_LIST, action);
  await settle(fixture);
}

const field = (host: HTMLElement): HTMLInputElement | null => host.querySelector('[data-interop-startup-value]');

function typeInto(fixture: ComponentFixture<unknown>, host: HTMLElement, value: string): void {
  const control = field(host) as HTMLInputElement;
  control.value = value;
  control.dispatchEvent(new Event('input'));
  fixture.detectChanges();
}

function tick(fixture: ComponentFixture<unknown>, host: HTMLElement, checked: boolean): void {
  const box = host.querySelector('[data-interop-startup-checkbox]') as HTMLInputElement;
  box.checked = checked;
  box.dispatchEvent(new Event('change'));
  fixture.detectChanges();
}

const confirmDialog = (host: HTMLElement): void => (host.querySelector('[data-interop-startup-confirm]') as HTMLButtonElement).click();

afterEach(() => {
  for (const node of planted.splice(0)) node.remove();
  TestBed.resetTestingModule();
});

describe('the Productions page (Story 24.3)', () => {
  it('registers Start with the instance and Shutdown group beside the handler\'s five, and opens a dialog for neither while no row is selected', async () => {
    const { fixture, host, actions } = mount([]);
    for (const id of ['start', 'stop', 'restart', 'update', 'recover', INTEROP_AUTO_START_ACTION, INTEROP_SHUTDOWN_GROUP_ACTION]) {
      expect(actions.has(INTEROP_PRODUCTION_LIST, id), id).toBe(true);
    }
    actions.run(INTEROP_PRODUCTION_LIST, INTEROP_AUTO_START_ACTION);
    await settle(fixture);
    expect(host.querySelector('app-interop-production-startup-dialog')).toBeNull();
  });

  it('opens Start with the instance over the selected row at its own state, and a production that does not start opens unchecked', async () => {
    const { fixture, host, store, actions } = mount([]);
    await open(fixture, store, actions, INTEROP_AUTO_START_ACTION, 'Demo.Auto');
    expect(host.querySelector('.ocu-dialog-title')?.textContent?.trim()).toBe(STRINGS.interopProductionAutoStartTitle.replace('<production>', 'Demo.Auto'));
    expect((host.querySelector('[data-interop-startup-checkbox]') as HTMLInputElement).checked).toBe(true);
    expect(field(host)?.value).toBe('5');
  });

  it('sends the box and the priority under the tool\'s names for the row, closes on an applied change and publishes the updated event', async () => {
    const { fixture, host, store, actions, calls, events } = mount([UPDATED]);
    await open(fixture, store, actions, INTEROP_AUTO_START_ACTION, 'Demo.Plain');
    tick(fixture, host, true);
    typeInto(fixture, host, '4');
    confirmDialog(host);
    await settle(fixture);
    expect(calls).toHaveLength(1);
    expect(calls[0].path).toBe(`/api/ocupilot/screens/${LIST.toolIdentifier}/action`);
    expect(JSON.parse(calls[0].body)).toEqual({ action: 'autostart', id: 'Demo.Plain', values: { AutoStart: '1', StartupPriority: '4' } });
    expect(host.querySelector('app-interop-production-startup-dialog')).toBeNull();
    expect(events.map((event) => `${event.type}/${event.action}`)).toEqual(['production/updated']);
  });

  it('sends the shutdown group typed for the row and nothing else', async () => {
    const { fixture, host, store, actions, calls } = mount([UPDATED]);
    await open(fixture, store, actions, INTEROP_SHUTDOWN_GROUP_ACTION, 'Demo.Auto');
    expect(field(host)?.value).toBe('3');
    typeInto(fixture, host, '2');
    confirmDialog(host);
    await settle(fixture);
    expect(JSON.parse(calls[0].body)).toEqual({ action: 'shutdowngroup', id: 'Demo.Auto', values: { ShutdownGroup: '2' } });
  });

  it('keeps a refusal on the value in the dialog as the instance\'s sentence, and one that names none above the fields, publishing nothing', async () => {
    const { fixture, host, store, actions, events } = mount([
      {
        kind: 'error',
        status: 422,
        code: 'INTEROP.STARTUP.GROUP',
        reason: STRINGS.interopStartupRefusalGroup,
        detail: { violations: [{ field: 'ShutdownGroup', code: 'INTEROP.STARTUP.GROUP', reason: STRINGS.interopStartupRefusalGroup }] },
      } as JsonResult<unknown>,
      { kind: 'error', status: 409, code: 'INTEROP.STARTUP.SAME', reason: STRINGS.interopStartupRefusalSame } as JsonResult<unknown>,
    ]);
    await open(fixture, store, actions, INTEROP_SHUTDOWN_GROUP_ACTION, 'Demo.Auto');
    typeInto(fixture, host, 'abc');
    confirmDialog(host);
    await settle(fixture);
    expect(host.querySelector('[data-interop-startup-violation]')?.textContent?.trim()).toBe(STRINGS.interopStartupRefusalGroup);
    expect(host.querySelector('[data-interop-startup-reason]')).toBeNull();
    confirmDialog(host);
    await settle(fixture);
    expect(host.querySelector('[data-interop-startup-violation]')).toBeNull();
    expect(host.querySelector('[data-interop-startup-reason]')?.textContent?.trim()).toBe(STRINGS.interopStartupRefusalSame);
    expect(events).toEqual([]);
    expect(store.refusal()).toBe('');
  });

  it('closes on Cancel, sending nothing, and opens no second dialog over an open one', async () => {
    const { fixture, host, store, actions, calls } = mount([]);
    await open(fixture, store, actions, INTEROP_SHUTDOWN_GROUP_ACTION, 'Demo.Auto');
    actions.run(INTEROP_PRODUCTION_LIST, INTEROP_AUTO_START_ACTION);
    await settle(fixture);
    expect(host.querySelectorAll('app-interop-production-startup-dialog')).toHaveLength(1);
    const cancel = [...host.querySelectorAll('.ocu-dialog-actions button')].find((button) => button.textContent?.trim() === STRINGS.actionCancel) as HTMLButtonElement;
    cancel.click();
    await settle(fixture);
    expect(host.querySelector('app-interop-production-startup-dialog')).toBeNull();
    expect(calls).toHaveLength(0);
  });
});
