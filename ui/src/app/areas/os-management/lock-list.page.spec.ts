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
import { LOCK_LIST, LOCK_REMOVE, LOCK_REMOVE_CLIENT, LOCK_REMOVE_PROCESS } from '../../shell/screen-action-handler';
import { stubAccountPreferences } from '../../testing/account-preferences';
import { LockListPage } from './lock-list.page';

/**
 * The Locks list page's Remove locks (Story 16.12). The shared list page is replaced by an empty
 * stand-in, so only this page's own wiring runs: the one action it registers after the shell's
 * handler, the dialog over the selected row, the request each Remove sends, the in-transaction
 * warning and the override that follows it, and the change event an applied removal publishes. The
 * handler, the stores and the bus are real; only the server's answers are stubbed.
 */

@Component({ selector: 'app-list-page', template: '' })
class StubListPage {}

const LOCKS = SCREENS.find((screen) => screen.descriptor === LOCK_LIST)!;

const LOCAL_ID = '313131008,13,P905,';

const ROWS = [
  { Pid: 905, OSUserName: 'irisowner', RoutineInfo: '+1^X', ModeCount: 'Exclusive', Reference: '^OcuProbeLock("a",1)', Directory: '/d/', System: '', DeleteID: LOCAL_ID, RemoteOwner: false },
];

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
  readonly body: string;
}

/** Mount the page over `rows`; each request resolves to the next of `answers`, which may be held open. */
function mount(answers: (JsonResult<unknown> | Promise<JsonResult<unknown>>)[], rows: readonly Record<string, unknown>[] = ROWS) {
  TestBed.resetTestingModule();
  const calls: Call[] = [];
  const api = {
    requestJson: async <T,>(path: string, init: ApiRequestInit = {}): Promise<JsonResult<T>> => {
      calls.push({ path, body: init.body ?? '' });
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
  TestBed.overrideComponent(LockListPage, { remove: { imports: [ListPage] }, add: { imports: [StubListPage] } });
  const store = stores.for(LOCKS.descriptor, LOCKS.refreshRates);
  store.applyTick(rows, false, '', new Date());
  const fixture = TestBed.createComponent(LockListPage);
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  fixture.detectChanges();
  return { fixture, host: fixture.nativeElement as HTMLElement, store, calls, events, actions: TestBed.inject(ScreenActions) };
}

function typeName(fixture: ComponentFixture<unknown>, host: HTMLElement, value: string): void {
  const input = host.querySelector('.ocu-typed-name-field') as HTMLInputElement;
  input.value = value;
  input.dispatchEvent(new Event('input'));
  fixture.detectChanges();
}

afterEach(() => {
  for (const node of planted.splice(0)) node.remove();
  TestBed.resetTestingModule();
});

describe('the Locks list page', () => {
  // Mutation (Rule 19): drop this page's `actions.register` of `remove` -> the first assertion goes
  // red, and no surface offers Remove locks.
  it('registers Remove locks alone, whose dialog opens on the selected row', async () => {
    const { fixture, host, store, actions, calls } = mount([]);
    expect(actions.has(LOCK_LIST, LOCK_REMOVE)).toBe(true);
    expect(actions.has(LOCK_LIST, LOCK_REMOVE_PROCESS)).toBe(false);
    expect(actions.has(LOCK_LIST, LOCK_REMOVE_CLIENT)).toBe(false);
    actions.run(LOCK_LIST, LOCK_REMOVE);
    await settle(fixture);
    expect(host.querySelector('app-lock-remove-dialog')).toBeNull();

    store.setSelection([LOCAL_ID]);
    actions.run(LOCK_LIST, LOCK_REMOVE);
    await settle(fixture);
    expect(host.querySelector('.ocu-dialog-title')?.textContent?.trim()).toBe('Remove locks held by 905');
    expect(calls).toHaveLength(0);
  });

  it('AC2: a refusal in a transaction warns in the dialog, and Remove anyway overrides, closes the dialog and publishes the deleted event', async () => {
    const { fixture, host, store, actions, calls, events } = mount([
      { kind: 'error', status: 409, code: 'LOCK.INTRANSACTION', reason: STRINGS.lockRemoveInTransaction, detail: null } as JsonResult<unknown>,
      { kind: 'ok', status: 200, body: { action: 'deleted', target: { type: 'lock', scope: 'instance', id: LOCAL_ID }, readBack: { verdict: 'notFound' } } },
    ]);
    store.setSelection([LOCAL_ID]);
    actions.run(LOCK_LIST, LOCK_REMOVE);
    await settle(fixture);
    typeName(fixture, host, '905');
    (host.querySelector('.ocu-lock-remove-submit') as HTMLButtonElement).click();
    await settle(fixture);
    expect(JSON.parse(calls[0].body)).toEqual({ action: LOCK_REMOVE, id: LOCAL_ID, values: { RemoveInTransaction: 'false' } });
    expect(host.querySelector('app-lock-remove-dialog')).not.toBeNull();
    expect(host.querySelector('.ocu-lock-remove-warning .ocu-banner-message')?.textContent?.trim()).toBe(STRINGS.lockRemoveInTransaction);
    expect(store.refusal()).toBe('');

    (host.querySelector('.ocu-lock-remove-submit') as HTMLButtonElement).click();
    await settle(fixture);
    expect(JSON.parse(calls[1].body)).toEqual({ action: LOCK_REMOVE, id: LOCAL_ID, values: { RemoveInTransaction: 'true' } });
    expect(host.querySelector('app-lock-remove-dialog')).toBeNull();
    expect(events.map((event) => `${event.type}/${event.scope}/${event.id}/${event.action}`)).toEqual([`lock/instance/${LOCAL_ID}/deleted`]);
  });

  it('shows any other refusal in the dialog and sends the chosen scope', async () => {
    const { fixture, host, store, actions, calls } = mount([
      { kind: 'error', status: 403, code: 'PROHIBITED.OCUPILOTLOCK', reason: STRINGS.lockRefusalOcuPilot, detail: null } as JsonResult<unknown>,
    ]);
    store.setSelection([LOCAL_ID]);
    actions.run(LOCK_LIST, LOCK_REMOVE);
    await settle(fixture);
    (host.querySelector(`[data-scope="${LOCK_REMOVE_PROCESS}"] input`) as HTMLInputElement).click();
    fixture.detectChanges();
    typeName(fixture, host, '905');
    (host.querySelector('.ocu-lock-remove-submit') as HTMLButtonElement).click();
    await settle(fixture);
    expect(JSON.parse(calls[0].body)).toEqual({ action: LOCK_REMOVE_PROCESS, id: LOCAL_ID, values: { RemoveInTransaction: 'false' } });
    expect(host.querySelector('.ocu-lock-remove-refusal')?.textContent?.trim()).toBe(STRINGS.lockRefusalOcuPilot);
    expect(host.querySelector('.ocu-lock-remove-warning')).toBeNull();
    expect(store.refusal()).toBe('');
  });

  // A remote owner is unobservable without ECP, so the row is canned (DW-1074).
  //
  // Mutation (Rule 19): read `remote` as `false` in `onOpen` -> the process scope is offered and the
  // client scope withheld on a remote row, and this goes red.
  it('AC1: on a row a remote client owns, withholds every lock of the process and sends every lock of the client', async () => {
    const remoteId = '313131009,2,C4,';
    const { fixture, host, store, actions, calls } = mount([], [{ ...ROWS[0], DeleteID: remoteId, RemoteOwner: true }]);
    store.setSelection([remoteId]);
    actions.run(LOCK_LIST, LOCK_REMOVE);
    await settle(fixture);
    const process = host.querySelector(`[data-scope="${LOCK_REMOVE_PROCESS}"] input`) as HTMLInputElement;
    const client = host.querySelector(`[data-scope="${LOCK_REMOVE_CLIENT}"] input`) as HTMLInputElement;
    expect(process.getAttribute('aria-disabled')).toBe('true');
    expect(document.getElementById(process.getAttribute('aria-describedby') ?? '')?.textContent?.trim()).toBe(STRINGS.lockRemoveRefusalRemote);
    expect(client.getAttribute('aria-disabled')).toBeNull();
    client.click();
    fixture.detectChanges();
    typeName(fixture, host, '905');
    (host.querySelector('.ocu-lock-remove-submit') as HTMLButtonElement).click();
    await settle(fixture);
    expect(JSON.parse(calls[0].body)).toEqual({ action: LOCK_REMOVE_CLIENT, id: remoteId, values: { RemoveInTransaction: 'false' } });
  });

  // Mutation (Rule 19): drop `onRemove`'s check that its dialog is still the open one -> the late
  // in-transaction answer arms Remove anyway on the other row's dialog, and this goes red.
  it('ignores a Remove answered after its dialog was canceled and another row\u2019s opened', async () => {
    let answer: (result: JsonResult<unknown>) => void = () => undefined;
    const late = new Promise<JsonResult<unknown>>((resolve) => {
      answer = resolve;
    });
    const otherId = '313131010,1,P906,';
    const { fixture, host, store, actions } = mount([late], [...ROWS, { ...ROWS[0], Pid: 906, DeleteID: otherId, Reference: '^OcuProbeLock("b",1)' }]);
    store.setSelection([LOCAL_ID]);
    actions.run(LOCK_LIST, LOCK_REMOVE);
    await settle(fixture);
    typeName(fixture, host, '905');
    (host.querySelector('.ocu-lock-remove-submit') as HTMLButtonElement).click();
    await settle(fixture);
    (host.querySelector('.ocu-dialog-actions .ocu-button-secondary') as HTMLButtonElement).click();
    await settle(fixture);
    store.setSelection([otherId]);
    actions.run(LOCK_LIST, LOCK_REMOVE);
    await settle(fixture);
    expect(host.querySelector('.ocu-dialog-title')?.textContent?.trim()).toBe('Remove locks held by 906');
    answer({ kind: 'error', status: 409, code: 'LOCK.INTRANSACTION', reason: STRINGS.lockRemoveInTransaction, detail: null } as JsonResult<unknown>);
    await settle(fixture);
    expect(host.querySelector('app-lock-remove-dialog')).not.toBeNull();
    expect(host.querySelector('.ocu-lock-remove-warning')).toBeNull();
    expect(host.querySelector('.ocu-lock-remove-submit')?.textContent?.trim()).toBe(STRINGS.lockRemoveAction);
  });
});
