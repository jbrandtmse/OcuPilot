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
import { ECP_CHANGE_STATUS, ECP_DATA_SERVER_LIST, ScreenActionHandler } from '../../shell/screen-action-handler';
import { stubAccountPreferences } from '../../testing/account-preferences';
import { ECP_DATA_SERVER_FORM_PATH } from './ecp-data-server-form.store';
import { EcpDataServerListPage } from './ecp-data-server-list.page';

/**
 * The ECP data servers page (Story 18.20). The shared list page is replaced by an empty stand-in, so
 * only this page's own wiring runs: the caveat line, the one action it registers after the shell's
 * handler, the form read the dialog opens over, the request each Change status sends, a refusal kept
 * in the dialog, the running and still-running lines, and the change event an applied change
 * publishes. The handler, the stores and the bus are real; only the server's answers are stubbed.
 */

@Component({ selector: 'app-list-page', template: '' })
class StubListPage {}

const LIST = SCREENS.find((screen) => screen.descriptor === ECP_DATA_SERVER_LIST)!;

const NAME = 'OCUPROBEECPA';

const ROWS = [
  { Name: NAME, RemoteAddress: '192.0.2.10', RemotePort: 1972, Status: 'Not Connected', MirrorConnection: false, SSLConfig: false, BatchMode: false },
  { Name: 'OCUPROBEECPB', RemoteAddress: '192.0.2.10', RemotePort: 1972, Status: 'Disabled', MirrorConnection: false, SSLConfig: false, BatchMode: false },
];

/** The form read's answer for `name` with `status`, on an instance whose license `licensed` or not. */
function formRead(name: string, status: string, licensed = false): JsonResult<unknown> {
  return {
    kind: 'ok',
    status: 200,
    body: {
      requiredFields: ['Name', 'Address', 'Port'],
      maxLengths: { Name: 64, Address: 255 },
      rules: [],
      licensed,
      server: { Name: name, Address: '192.0.2.10', Port: 1972, MirrorConnection: 0, SSLConfig: false, BatchMode: false, Status: status },
    },
  };
}

const UPDATED: JsonResult<unknown> = {
  kind: 'ok',
  status: 200,
  body: { action: 'updated', target: { type: 'ecp-data-server', scope: 'instance', id: NAME }, readBack: { verdict: 'nothingSent' } },
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

/** Mount the page over `rows`; each request resolves to the next of `answers`, which may be held open. */
function mount(answers: (JsonResult<unknown> | Promise<JsonResult<unknown>>)[], rows: readonly Record<string, unknown>[] = ROWS) {
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
  TestBed.overrideComponent(EcpDataServerListPage, { remove: { imports: [ListPage] }, add: { imports: [StubListPage] } });
  const store = stores.for(LIST.descriptor, LIST.refreshRates);
  store.applyTick(rows, false, '', new Date());
  const fixture = TestBed.createComponent(EcpDataServerListPage);
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  fixture.detectChanges();
  return { fixture, host: fixture.nativeElement as HTMLElement, store, calls, events, actions: TestBed.inject(ScreenActions) };
}

async function open(fixture: ComponentFixture<unknown>, store: ReturnType<typeof mount>['store'], actions: ScreenActions, name = NAME): Promise<void> {
  store.setSelection([name]);
  actions.run(ECP_DATA_SERVER_LIST, ECP_CHANGE_STATUS);
  await settle(fixture);
}

function choose(fixture: ComponentFixture<unknown>, host: HTMLElement, status: string): void {
  (host.querySelector(`[data-status="${status}"] input`) as HTMLInputElement).click();
  fixture.detectChanges();
}

function submit(host: HTMLElement): void {
  (host.querySelector('.ocu-ecp-status-submit') as HTMLButtonElement).click();
}

afterEach(() => {
  for (const node of planted.splice(0)) node.remove();
  TestBed.resetTestingModule();
});

describe('the ECP data servers page', () => {
  it('B1: says under the status line that each status is what the instance reported when the list was read', () => {
    const { host } = mount([]);
    expect(host.querySelector('[data-ecp="caveat"]')?.textContent?.trim()).toBe(STRINGS.ecpDataServerStatusCaveat);
    expect(host.querySelector('[data-ecp="operation"]')?.getAttribute('role')).toBe('status');
  });

  // Mutation (Rule 19): drop this page's `actions.register` of `changestatus` -> the first assertion
  // goes red, and no surface offers Change status.
  it('registers Change status, whose dialog opens over the form read of the selected row', async () => {
    const { fixture, host, store, actions, calls } = mount([formRead(NAME, 'Not Connected')]);
    expect(actions.has(ECP_DATA_SERVER_LIST, ECP_CHANGE_STATUS)).toBe(true);
    // The handler registers the Delete beside it, so the list keeps its generic typed-name delete.
    expect(actions.has(ECP_DATA_SERVER_LIST, 'delete')).toBe(true);
    actions.run(ECP_DATA_SERVER_LIST, ECP_CHANGE_STATUS);
    await settle(fixture);
    expect(host.querySelector('app-ecp-data-server-status-dialog')).toBeNull();
    expect(calls).toHaveLength(0);

    await open(fixture, store, actions);
    expect(calls.map((call) => call.path)).toEqual([`${ECP_DATA_SERVER_FORM_PATH}?name=${NAME}`]);
    expect(host.querySelector('.ocu-dialog-title')?.textContent?.trim()).toBe(`Change the status of ${NAME}`);
    expect(host.querySelector('.ocu-ecp-status-current')?.textContent?.trim()).toBe('Current status: Not Connected');
    const normal = host.querySelector('[data-status="normal"] input') as HTMLInputElement;
    expect(normal.getAttribute('aria-disabled')).toBe('true');
    expect(document.getElementById(normal.getAttribute('aria-describedby') ?? '')?.textContent?.trim()).toBe(STRINGS.ecpLicenseRefusal);
  });

  it('B4: sends the chosen status as the one value, closes on an applied change and publishes the updated event', async () => {
    let answer: (result: JsonResult<unknown>) => void = () => undefined;
    const held = new Promise<JsonResult<unknown>>((resolve) => {
      answer = resolve;
    });
    const { fixture, host, store, actions, calls, events } = mount([formRead(NAME, 'Not Connected'), held]);
    await open(fixture, store, actions);
    choose(fixture, host, 'disabled');
    submit(host);
    await settle(fixture);
    expect(calls[1]).toEqual({
      path: '/api/ocupilot/screens/osmgmt.ecpdataservers/action',
      method: 'POST',
      body: JSON.stringify({ action: ECP_CHANGE_STATUS, id: NAME, values: { Status: 'disabled' } }),
    });
    // While the write runs, the line above the list reads the running line.
    const running = host.querySelector('[data-ecp="operation"]')?.textContent?.trim() ?? '';
    expect(running.startsWith(`${STRINGS.ecpDataServerChangeStatus} running on the instance since `)).toBe(true);
    expect((host.querySelector('.ocu-ecp-status-submit') as HTMLButtonElement).getAttribute('aria-disabled')).toBe('true');

    answer(UPDATED);
    await settle(fixture);
    expect(host.querySelector('app-ecp-data-server-status-dialog')).toBeNull();
    expect(host.querySelector('[data-ecp="operation"]')?.textContent?.trim()).toBe(`${STRINGS.ecpDataServerChangeStatus} finished.`);
    expect(events.map((event) => `${event.type}/${event.scope}/${event.id}/${event.action}`)).toEqual([`ecp-data-server/instance/${NAME}/updated`]);
    expect(store.refusal()).toBe('');
  });

  it('B4: a change the instance answers is still running reads the still-running sentence', async () => {
    const { fixture, host, store, actions } = mount([formRead(NAME, 'Not Connected'), { ...UPDATED, status: 202, body: { ...(UPDATED as { body: object }).body, continues: true } } as JsonResult<unknown>]);
    await open(fixture, store, actions);
    choose(fixture, host, 'disabled');
    submit(host);
    await settle(fixture);
    expect(host.querySelector('app-ecp-data-server-status-dialog')).toBeNull();
    expect(host.querySelector('[data-ecp="operation"]')?.textContent?.trim()).toBe(STRINGS.auditDatabaseStillRunning);
  });

  it("B5: a refusal on Status stays in the dialog as the instance's sentence, and nothing is published", async () => {
    const license = "This instance's license does not include ECP.";
    const { fixture, host, store, actions, events } = mount([
      formRead('OCUPROBEECPB', 'Disabled', true),
      {
        kind: 'error',
        status: 422,
        code: 'ECP.LICENSE',
        reason: license,
        detail: { violations: [{ field: 'Status', code: 'ECP.LICENSE', reason: license }] },
      } as JsonResult<unknown>,
    ]);
    await open(fixture, store, actions, 'OCUPROBEECPB');
    choose(fixture, host, 'normal');
    submit(host);
    await settle(fixture);
    expect(host.querySelector('app-ecp-data-server-status-dialog')).not.toBeNull();
    expect(host.querySelector('.ocu-ecp-status-refusal')?.textContent?.trim()).toBe(license);
    expect(host.querySelector('[data-ecp="operation"]')?.textContent?.trim()).toBe('');
    expect(store.refusal()).toBe('');
    expect(events).toEqual([]);
  });

  it('a refusal with no field, such as the instance refusing the change, shows its envelope reason in the dialog', async () => {
    const { fixture, host, store, actions } = mount([
      formRead(NAME, 'Not Connected'),
      { kind: 'error', status: 409, code: 'ECP.STATUS.REFUSED', reason: 'The instance refused that status change.', detail: null } as JsonResult<unknown>,
    ]);
    await open(fixture, store, actions);
    choose(fixture, host, 'disabled');
    submit(host);
    await settle(fixture);
    expect(host.querySelector('.ocu-ecp-status-refusal')?.textContent?.trim()).toBe('The instance refused that status change.');
  });

  it("a form read that fails opens nothing and puts its reason on the list's banner", async () => {
    const { fixture, host, store, actions } = mount([
      { kind: 'error', status: 404, code: 'PORT.NOTFOUND', reason: 'The requested resource was not found.', detail: null } as JsonResult<unknown>,
    ]);
    await open(fixture, store, actions);
    expect(host.querySelector('app-ecp-data-server-status-dialog')).toBeNull();
    expect(store.refusal()).toBe('The requested resource was not found.');
  });

  // Mutation (Rule 19): drop `onChange`'s check that its dialog is still the open one -> the late
  // refusal lands in the other row's dialog, and this goes red.
  it("ignores a change answered after its dialog was canceled and another row's opened", async () => {
    let answer: (result: JsonResult<unknown>) => void = () => undefined;
    const late = new Promise<JsonResult<unknown>>((resolve) => {
      answer = resolve;
    });
    const { fixture, host, store, actions } = mount([formRead(NAME, 'Not Connected'), late, formRead('OCUPROBEECPB', 'Disabled')]);
    await open(fixture, store, actions);
    choose(fixture, host, 'disabled');
    submit(host);
    await settle(fixture);
    (host.querySelector('.ocu-dialog-actions .ocu-button-secondary') as HTMLButtonElement).click();
    await settle(fixture);
    await open(fixture, store, actions, 'OCUPROBEECPB');
    expect(host.querySelector('.ocu-dialog-title')?.textContent?.trim()).toBe('Change the status of OCUPROBEECPB');
    answer({ kind: 'error', status: 409, code: 'ECP.STATUS.REFUSED', reason: 'The instance refused that status change.', detail: null } as JsonResult<unknown>);
    await settle(fixture);
    expect(host.querySelector('app-ecp-data-server-status-dialog')).not.toBeNull();
    expect(host.querySelector('.ocu-ecp-status-refusal')).toBeNull();
  });

  // Mutation (Rule 19): drop the `UNDRAWN_ACTIONS` entry for ECP data servers -> the handler
  // registers Change status as a send-at-once action and the first assertion goes red.
  it("the handler leaves Change status undrawn and registers the Delete, so only this page's dialog sends a status", () => {
    TestBed.resetTestingModule();
    const stores = new ScreenStores({ account: stubAccountPreferences() });
    TestBed.configureTestingModule({
      providers: [
        { provide: ScreenStores, useValue: stores },
        { provide: ScreenActions, useValue: new ScreenActions() },
      ],
    });
    TestBed.inject(ScreenActionHandler);
    const actions = TestBed.inject(ScreenActions);
    expect(actions.has(ECP_DATA_SERVER_LIST, ECP_CHANGE_STATUS)).toBe(false);
    expect(actions.has(ECP_DATA_SERVER_LIST, 'delete')).toBe(true);
    expect(LIST.rowActions.map((action) => action.id)).toEqual([ECP_CHANGE_STATUS, 'delete']);
  });
});
