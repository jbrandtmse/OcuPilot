import { Component } from '@angular/core';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type ApiRequestInit, type JsonResult } from '../../core/api';
import { ChangeBus, type ChangeEvent } from '../../core/change-bus';
import { OverlayStack } from '../../core/overlay-stack';
import { ScopeService } from '../../core/scope';
import { ScreenActions } from '../../core/screen-actions';
import { ScreenStores } from '../../core/screen-store';
import { SCREENS } from '../../core/screens.generated';
import { Session } from '../../core/session';
import { STRINGS } from '../../core/strings';
import { ListPage } from '../../shell/list-page';
import { stubAccountPreferences } from '../../testing/account-preferences';
import { INTEROP_MANAGED_ALERT_ACTION, INTEROP_MANAGED_ALERT_LIST, InteropManagedAlertListPage } from './interop-managed-alert-list.page';

/**
 * The Managed alerts page (Story 24.17 Batch 1). The shared list page is replaced by an empty stand-in, so only this page's own wiring runs: the Update alert action it registers,
 * the review it asks for first (which reads the selected alert's owner, open state and level and the owners the classic form offers, and writes nothing), the dialog that shows them,
 * the one request an update sends -- the changed values and the reason, the alert's ID its target -- a refusal kept in the dialog, and the change event an applied update
 * publishes. The handler, the stores and the bus are real; only the server's answers are stubbed.
 */

@Component({ selector: 'app-list-page', template: '' })
class StubListPage {}

const LIST = SCREENS.find((screen) => screen.descriptor === INTEROP_MANAGED_ALERT_LIST)!;

const ROWS = [{ ID: '7', AlertText: 'a probe alert', CurrentOwner: 'Probe', EscalationLevel: 1, IsOpen: true, Namespace: 'USER' }];

const review = (values: Record<string, unknown>): JsonResult<unknown> => ({
  kind: 'ok',
  status: 200,
  body: { rows: [], review: { CurrentOwner: 'Probe', IsOpen: true, EscalationLevel: 1, Owners: ['Admin', 'Probe'], ...values } },
});

const UPDATED: JsonResult<unknown> = {
  kind: 'ok',
  status: 200,
  body: { action: 'updated', target: { type: 'interop-managed-alert', scope: 'USER', id: '7' }, readBack: { verdict: 'matches' } },
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
  readonly body: string;
}

/** Mount the page over `ROWS`, each request resolving to the next of `answers`. */
function mount(answers: JsonResult<unknown>[]) {
  TestBed.resetTestingModule();
  const calls: Call[] = [];
  const api = {
    requestJson: async <T,>(path: string, init: ApiRequestInit = {}): Promise<JsonResult<T>> => {
      calls.push({ path, body: init.body ?? '' });
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
      { provide: Session, useValue: { userName: () => 'Me' } as unknown as Session },
      { provide: ScopeService, useValue: { loaded: () => true, namespace: () => 'USER', subscribe: () => () => {} } as unknown as ScopeService },
    ],
  });
  TestBed.overrideComponent(InteropManagedAlertListPage, { remove: { imports: [ListPage] }, add: { imports: [StubListPage] } });
  const store = stores.for(LIST.descriptor, LIST.refreshRates);
  store.applyTick(ROWS, false, '', new Date());
  const fixture = TestBed.createComponent(InteropManagedAlertListPage);
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  fixture.detectChanges();
  return { fixture, host: fixture.nativeElement as HTMLElement, store, calls, events, actions: TestBed.inject(ScreenActions) };
}

function typeInto(fixture: ComponentFixture<unknown>, host: HTMLElement, name: string, value: string): void {
  const control = host.querySelector(`[data-interop-alert-field="${name}"]`) as HTMLInputElement | HTMLSelectElement;
  control.value = value;
  control.dispatchEvent(new Event(control.tagName === 'SELECT' ? 'change' : 'input'));
  fixture.detectChanges();
}

const confirm = (host: HTMLElement): HTMLButtonElement => host.querySelector('[data-interop-alert-confirm]') as HTMLButtonElement;

async function openDialog(fixture: ComponentFixture<unknown>, store: ReturnType<typeof mount>['store'], actions: ScreenActions, id = '7'): Promise<void> {
  store.setSelection(id === '' ? [] : [id]);
  actions.run(INTEROP_MANAGED_ALERT_LIST, INTEROP_MANAGED_ALERT_ACTION);
  await settle(fixture);
}

afterEach(() => {
  for (const node of planted.splice(0)) node.remove();
  TestBed.resetTestingModule();
});

describe('the Managed alerts page', () => {
  it('declares the list this page hosts, with Update alert as its one row action', () => {
    expect(LIST.primaryAction?.id).toBe('');
    expect(LIST.rowActions.map((action) => action.id)).toEqual([INTEROP_MANAGED_ALERT_ACTION]);
  });

  // Mutation (Rule 19): drop this page's `actions.register` of `update` -> the first assertion goes red.
  it('registers Update alert, reviews the selected alert first and opens the dialog over what the review read', async () => {
    const { fixture, host, store, actions, calls } = mount([review({})]);
    expect(actions.has(INTEROP_MANAGED_ALERT_LIST, INTEROP_MANAGED_ALERT_ACTION)).toBe(true);
    await openDialog(fixture, store, actions);
    expect(calls).toHaveLength(1);
    expect(calls[0].path).toBe(`/api/ocupilot/screens/${LIST.toolIdentifier}/dryrun`);
    expect(JSON.parse(calls[0].body)).toEqual({ action: INTEROP_MANAGED_ALERT_ACTION, id: '7' });
    expect(host.querySelector('.ocu-dialog-title')?.textContent?.trim()).toBe(STRINGS.interopManagedAlertUpdateAction);
    expect((host.querySelector('[data-interop-alert-field="Owner"]') as HTMLSelectElement).value).toBe('Probe');
    expect([...host.querySelectorAll('[data-interop-alert-field="Owner"] option')].map((option) => (option as HTMLOptionElement).value)).toEqual(['', 'Me', 'Probe', 'Admin']);
    expect((host.querySelector('[data-interop-alert-field="Open"]') as HTMLInputElement).checked).toBe(true);
    expect((host.querySelector('[data-interop-alert-field="EscalationLevel"]') as HTMLSelectElement).value).toBe('1');
  });

  it('asks for nothing with no alert selected', async () => {
    const { fixture, host, store, actions, calls } = mount([review({})]);
    await openDialog(fixture, store, actions, '');
    expect(calls).toHaveLength(0);
    expect(host.querySelector('app-interop-managed-alert-dialog')).toBeNull();
  });

  it('opens nothing and shows the refusal on the list when the review is refused, as for an alert that is gone', async () => {
    const { fixture, host, store, actions, calls } = mount([
      { kind: 'error', status: 404, code: 'INTEROP.ALERT.NOTFOUND', reason: STRINGS.interopManagedAlertRefusalNotFound } as JsonResult<unknown>,
    ]);
    await openDialog(fixture, store, actions);
    expect(calls).toHaveLength(1);
    expect(host.querySelector('app-interop-managed-alert-dialog')).toBeNull();
    expect(store.refusal()).toBe(STRINGS.interopManagedAlertRefusalNotFound);
  });

  // Mutation (Rule 19): send the dialog without its reason, or the unchanged owner with it -> this goes red.
  it('sends one Update alert with the changed values and the reason, the alert\'s ID its target, closes on an applied update and publishes the updated event', async () => {
    const { fixture, host, store, actions, calls, events } = mount([review({}), UPDATED]);
    await openDialog(fixture, store, actions);
    typeInto(fixture, host, 'Owner', 'Me');
    typeInto(fixture, host, 'Reason', 'taking it');
    confirm(host).click();
    await settle(fixture);
    expect(calls).toHaveLength(2);
    expect(calls[1].path).toBe(`/api/ocupilot/screens/${LIST.toolIdentifier}/action`);
    expect(JSON.parse(calls[1].body)).toEqual({ action: INTEROP_MANAGED_ALERT_ACTION, id: '7', values: { Owner: 'Me', Reason: 'taking it' } });
    expect(host.querySelector('app-interop-managed-alert-dialog')).toBeNull();
    expect(events.map((event) => `${event.type}/${event.action}`)).toEqual(['interop-managed-alert/updated']);
  });

  // Mutation (Rule 19): close the dialog on any answer -> the dialog assertion goes red.
  it('keeps the dialog open with the answer\'s sentence when the update was refused, and publishes nothing', async () => {
    const { fixture, host, store, actions, events } = mount([
      review({}),
      { kind: 'error', status: 422, code: 'INTEROP.ALERT.REASON', reason: STRINGS.interopManagedAlertRefusalReason } as JsonResult<unknown>,
    ]);
    await openDialog(fixture, store, actions);
    confirm(host).click();
    await settle(fixture);
    expect(host.querySelector('app-interop-managed-alert-dialog')).not.toBeNull();
    expect(host.querySelector('[data-interop-alert-refusal]')?.textContent?.trim()).toBe(STRINGS.interopManagedAlertRefusalReason);
    expect(events).toEqual([]);
  });

  it('closes on Cancel without sending, and opens no second dialog over the first', async () => {
    const { fixture, host, store, actions, calls } = mount([review({}), review({})]);
    await openDialog(fixture, store, actions);
    await openDialog(fixture, store, actions);
    expect(calls).toHaveLength(1);
    const cancel = [...host.querySelectorAll('.ocu-dialog-actions button')].find((button) => button.textContent?.trim() === STRINGS.actionCancel) as HTMLButtonElement;
    cancel.click();
    await settle(fixture);
    expect(host.querySelector('app-interop-managed-alert-dialog')).toBeNull();
    expect(calls).toHaveLength(1);
  });
});
