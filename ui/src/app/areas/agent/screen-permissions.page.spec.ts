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
import {
  SCREEN_PERMISSIONS,
  SCREEN_PERMISSIONS_ADD,
  SCREEN_PERMISSIONS_REMOVE,
  SCREEN_PERMISSIONS_RESET,
  ScreenActionHandler,
} from '../../shell/screen-action-handler';
import { stubAccountPreferences } from '../../testing/account-preferences';
import { ScreenPermissionsPage } from './screen-permissions.page';

/**
 * The Screen permissions page (Story 20.15). The shared list page is replaced by an empty stand-in, so only
 * this page's own wiring runs: the one action it registers after the shell's handler, the dialog drawn from
 * the selected row, the request each Add and Remove sends, a refusal kept in the dialog, and the change
 * event an applied change publishes. The handler, the stores and the bus are real; only the server's
 * answers are stubbed.
 */

@Component({ selector: 'app-list-page', template: '' })
class StubListPage {}

const LIST = SCREENS.find((screen) => screen.descriptor === SCREEN_PERMISSIONS)!;

const LOCKS = 'osmgmt.locks';

const ROWS = [
  { Screen: LOCKS, Area: 'os-management', Declared: '%Admin_Operate:USE, %DB_IRISSYS:READ', Adjustment: '', ClassicResource: '', Effective: '%Admin_Operate:USE, %DB_IRISSYS:READ', Holds: true, FailedPair: '', Adjustable: true },
  { Screen: 'shell.home', Area: 'home', Declared: '', Adjustment: '', ClassicResource: '', Effective: '', Holds: true, FailedPair: '', Adjustable: false },
  {
    Screen: 'osmgmt.processes',
    Area: 'os-management',
    Declared: '%Admin_Operate:USE, %Admin_Manage:USE',
    Adjustment: '%Admin_Operate:USE',
    ClassicResource: 'ProbeClassic',
    Effective: '%Admin_Operate:USE, ProbeClassic:USE',
    Holds: true,
    FailedPair: '',
    Adjustable: true,
  },
];

const UPDATED: JsonResult<unknown> = {
  kind: 'ok',
  status: 200,
  body: { action: 'updated', target: { type: 'screen-permission', scope: 'instance', id: LOCKS }, readBack: { verdict: 'nothingSent' } },
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
  TestBed.overrideComponent(ScreenPermissionsPage, { remove: { imports: [ListPage] }, add: { imports: [StubListPage] } });
  const store = stores.for(LIST.descriptor, LIST.refreshRates);
  store.applyTick(rows, false, '', new Date());
  const fixture = TestBed.createComponent(ScreenPermissionsPage);
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  fixture.detectChanges();
  return { fixture, host: fixture.nativeElement as HTMLElement, store, calls, events, actions: TestBed.inject(ScreenActions) };
}

async function open(fixture: ComponentFixture<unknown>, store: ReturnType<typeof mount>['store'], actions: ScreenActions, screen = LOCKS): Promise<void> {
  store.setSelection([screen]);
  actions.run(SCREEN_PERMISSIONS, SCREEN_PERMISSIONS_ADD);
  await settle(fixture);
}

const pairsOf = (host: HTMLElement): string[] =>
  Array.from(host.querySelectorAll('.ocu-screen-permissions-pair:not(.ocu-screen-permissions-classic) .ocu-screen-permissions-text')).map((node) => node.textContent?.trim() ?? '');

afterEach(() => {
  for (const node of planted.splice(0)) node.remove();
  TestBed.resetTestingModule();
});

describe('the Screen permissions page', () => {
  // Mutation (Rule 19): drop this page's `actions.register` of `add-pair` -> the first assertion goes red,
  // and no surface offers Change permissions.
  it("registers Change permissions, whose dialog opens over the selected row's set", async () => {
    const { fixture, host, store, actions, calls } = mount([]);
    expect(actions.has(SCREEN_PERMISSIONS, SCREEN_PERMISSIONS_ADD)).toBe(true);
    // The handler registers the Reset beside it, and leaves Remove undrawn: only the dialog sends it.
    expect(actions.has(SCREEN_PERMISSIONS, SCREEN_PERMISSIONS_RESET)).toBe(true);
    expect(actions.has(SCREEN_PERMISSIONS, SCREEN_PERMISSIONS_REMOVE)).toBe(false);
    actions.run(SCREEN_PERMISSIONS, SCREEN_PERMISSIONS_ADD);
    await settle(fixture);
    expect(host.querySelector('app-screen-permissions-dialog')).toBeNull();

    await open(fixture, store, actions);
    expect(calls).toHaveLength(0);
    expect(host.querySelector('.ocu-dialog-title')?.textContent?.trim()).toBe(`Change the permissions of ${LOCKS}`);
    expect(pairsOf(host)).toEqual(['%Admin_Operate:USE', '%DB_IRISSYS:READ']);
  });

  it("draws an adjusted screen's adjustment, not its declaration, and its classic resource as fixed", async () => {
    const { fixture, host, store, actions } = mount([]);
    await open(fixture, store, actions, 'osmgmt.processes');
    expect(pairsOf(host)).toEqual(['%Admin_Operate:USE']);
    expect(host.querySelector('.ocu-screen-permissions-classic')?.textContent?.trim()).toBe('The classic portal also requires ProbeClassic:USE here, and only the classic portal changes it.');
  });

  it('opens a screen that cannot be adjusted with its set and neither control', async () => {
    const { fixture, host, store, actions } = mount([]);
    await open(fixture, store, actions, 'shell.home');
    expect(host.querySelector('.ocu-screen-permissions-fixed')?.textContent?.trim()).toBe(STRINGS.screenPermissionsFixed);
    expect(host.querySelector('.ocu-screen-permissions-add-button')).toBeNull();
    expect(host.querySelectorAll('.ocu-screen-permissions-remove')).toHaveLength(0);
  });

  // Mutation (Rule 19): send `remove-pair` under another value name -> the body assertion goes red.
  it('sends an Add as the one value Pair, stays open and clears the typed resource on an applied change', async () => {
    const { fixture, host, store, actions, calls, events } = mount([UPDATED]);
    await open(fixture, store, actions);
    const input = host.querySelector('[data-field="resource"]') as HTMLInputElement;
    input.value = '%Admin_Secure';
    input.dispatchEvent(new Event('input'));
    fixture.detectChanges();
    (host.querySelector('.ocu-screen-permissions-add-button') as HTMLButtonElement).click();
    await settle(fixture);
    expect(calls).toEqual([
      { path: '/api/ocupilot/screens/agent.screenpermissions/action', method: 'POST', body: JSON.stringify({ action: SCREEN_PERMISSIONS_ADD, id: LOCKS, values: { Pair: '%Admin_Secure:USE' } }) },
    ]);
    expect(host.querySelector('app-screen-permissions-dialog')).not.toBeNull();
    expect((host.querySelector('[data-field="resource"]') as HTMLInputElement).value).toBe('');
    expect(events.map((event) => `${event.type}/${event.scope}/${event.id}/${event.action}`)).toEqual([`screen-permission/instance/${LOCKS}/updated`]);
  });

  it('sends a Remove as remove-pair with the pair the button names', async () => {
    const { fixture, host, store, actions, calls } = mount([UPDATED]);
    await open(fixture, store, actions);
    (host.querySelectorAll('.ocu-screen-permissions-remove')[1] as HTMLButtonElement).click();
    await settle(fixture);
    expect(JSON.parse(calls[0].body)).toEqual({ action: SCREEN_PERMISSIONS_REMOVE, id: LOCKS, values: { Pair: '%DB_IRISSYS:READ' } });
  });

  it("keeps a refusal on Pair in the dialog as the instance's sentence, and publishes nothing", async () => {
    const sentence = 'This instance defines no resource of that name.';
    const { fixture, host, store, actions, events } = mount([
      {
        kind: 'error',
        status: 422,
        code: 'ACCESS.RESOURCE.UNKNOWN',
        reason: 'The request could not be accepted.',
        detail: { violations: [{ field: 'Pair', code: 'ACCESS.RESOURCE.UNKNOWN', reason: sentence }] },
      } as JsonResult<unknown>,
    ]);
    await open(fixture, store, actions);
    const input = host.querySelector('[data-field="resource"]') as HTMLInputElement;
    input.value = 'NoSuchRes';
    input.dispatchEvent(new Event('input'));
    fixture.detectChanges();
    (host.querySelector('.ocu-screen-permissions-add-button') as HTMLButtonElement).click();
    await settle(fixture);
    expect(host.querySelector('.ocu-screen-permissions-refusal')?.textContent?.trim()).toBe(sentence);
    expect(store.refusal()).toBe('');
    expect(events).toEqual([]);
  });

  it('draws the dialog from the latest read: the set it shows follows the list when the list re-reads', async () => {
    const { fixture, host, store, actions } = mount([]);
    await open(fixture, store, actions);
    expect(pairsOf(host)).toEqual(['%Admin_Operate:USE', '%DB_IRISSYS:READ']);
    store.applyTick([{ ...ROWS[0], Adjustment: '%Admin_Operate:USE', Effective: '%Admin_Operate:USE' }, ROWS[1], ROWS[2]], false, '', new Date());
    await settle(fixture);
    expect(pairsOf(host)).toEqual(['%Admin_Operate:USE']);
  });

  it('closes the dialog when the selected row leaves the list', async () => {
    const { fixture, host, store, actions } = mount([]);
    await open(fixture, store, actions);
    store.applyTick([ROWS[1]], false, '', new Date());
    await settle(fixture);
    expect(host.querySelector('app-screen-permissions-dialog')).toBeNull();
  });

  // Mutation (Rule 19): drop the `UNDRAWN_ACTIONS` entry for Screen permissions -> the handler registers
  // Remove as a send-at-once action and the first assertion goes red.
  it("the handler leaves Add and Remove undrawn and registers the Reset, so only this page's dialog sends a pair", () => {
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
    expect(actions.has(SCREEN_PERMISSIONS, SCREEN_PERMISSIONS_ADD)).toBe(false);
    expect(actions.has(SCREEN_PERMISSIONS, SCREEN_PERMISSIONS_REMOVE)).toBe(false);
    expect(actions.has(SCREEN_PERMISSIONS, SCREEN_PERMISSIONS_RESET)).toBe(true);
    expect(LIST.rowActions.map((action) => action.id)).toEqual([SCREEN_PERMISSIONS_ADD, SCREEN_PERMISSIONS_REMOVE, SCREEN_PERMISSIONS_RESET]);
  });
});
