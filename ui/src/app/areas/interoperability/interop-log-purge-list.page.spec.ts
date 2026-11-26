import { Component } from '@angular/core';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { Router } from '@angular/router';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type ApiRequestInit, type JsonResult } from '../../core/api';
import { ChangeBus, type ChangeEvent } from '../../core/change-bus';
import { OverlayStack } from '../../core/overlay-stack';
import { ScopeService } from '../../core/scope';
import { ScreenActions } from '../../core/screen-actions';
import { ScreenStores } from '../../core/screen-store';
import { SCREENS } from '../../core/screens.generated';
import { STRINGS } from '../../core/strings';
import { ListPage } from '../../shell/list-page';
import { ScreenActionHandler } from '../../shell/screen-action-handler';
import { stubAccountPreferences } from '../../testing/account-preferences';
import { INTEROP_PROCESS_LOG_LIST, INTEROP_RULE_LOG_LIST, InteropLogPurgeListPage } from './interop-log-purge-list.page';
import { INTEROP_PURGE_ACTION } from './interop-purge-list.page';

/**
 * The Business rule log and Business process log pages (Story 24.17 Batch 2), one class over two screens. The shared list page is replaced by an empty stand-in, so only
 * this page's own wiring runs: the Purge action it registers on the screen the URL names, the review it asks for first (which reads the log's count and writes nothing),
 * the dialog that shows the count and the screen's own consequence, the namespace's name it asks to be typed, the one request a Purge sends -- the days as text, the
 * namespace its target -- a refusal kept in the dialog, and the change event an applied purge publishes. The handler, the stores and the bus are real; only the
 * server's answers are stubbed.
 */

@Component({ selector: 'app-list-page', template: '' })
class StubListPage {}

const SERVED = [
  { descriptor: INTEROP_RULE_LOG_LIST, entity: 'interop-rule-log', consequence: STRINGS.interopRuleLogPurgeConsequence },
  { descriptor: INTEROP_PROCESS_LOG_LIST, entity: 'interop-process-log', consequence: STRINGS.interopProcessLogPurgeConsequence },
] as const;

const review = (count: unknown): JsonResult<unknown> => ({
  kind: 'ok',
  status: 200,
  body: { rows: [], review: { Count: count, DaysToKeep: '', Namespace: 'USER' } },
});

const purged = (entity: string): JsonResult<unknown> => ({
  kind: 'ok',
  status: 200,
  body: { action: 'updated', target: { type: entity, scope: 'USER', id: 'USER' }, readBack: { verdict: 'matches' } },
});

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

/** Mount the page on the route of `descriptor`, each request resolving to the next of `answers`. */
function mount(descriptor: string, answers: JsonResult<unknown>[]) {
  const screen = SCREENS.find((entry) => entry.descriptor === descriptor)!;
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
      { provide: Router, useValue: { url: `/${screen.route}?ns=USER` } },
      { provide: ScopeService, useValue: { loaded: () => true, namespace: () => 'USER', subscribe: () => () => {} } as unknown as ScopeService },
    ],
  });
  TestBed.overrideComponent(InteropLogPurgeListPage, { remove: { imports: [ListPage] }, add: { imports: [StubListPage] } });
  const store = stores.for(screen.descriptor, screen.refreshRates);
  store.applyTick([], false, '', new Date());
  const fixture = TestBed.createComponent(InteropLogPurgeListPage);
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  fixture.detectChanges();
  return { fixture, host: fixture.nativeElement as HTMLElement, store, calls, events, actions: TestBed.inject(ScreenActions), screen };
}

function typeInto(fixture: ComponentFixture<unknown>, host: HTMLElement, selector: string, value: string): void {
  const control = host.querySelector(selector) as HTMLInputElement;
  control.value = value;
  control.dispatchEvent(new Event('input'));
  fixture.detectChanges();
}

const confirm = (host: HTMLElement): HTMLButtonElement => host.querySelector('[data-interop-purge-confirm]') as HTMLButtonElement;

async function openDialog(fixture: ComponentFixture<unknown>, actions: ScreenActions, descriptor: string): Promise<void> {
  actions.run(descriptor, INTEROP_PURGE_ACTION);
  await settle(fixture);
}

afterEach(() => {
  for (const node of planted.splice(0)) node.remove();
  TestBed.resetTestingModule();
});

describe.each(SERVED)('the $descriptor page', ({ descriptor, entity, consequence }) => {
  it('declares Purge as its one row action', () => {
    const screen = SCREENS.find((entry) => entry.descriptor === descriptor)!;
    expect(screen.primaryAction?.id).toBe('');
    expect(screen.rowActions.map((action) => action.id)).toEqual([INTEROP_PURGE_ACTION]);
  });

  // Mutation (Rule 19): drop this page's `actions.register` of `purge` -> the first assertion goes red.
  it('registers Purge on its own screen only, reviews the purge first and opens the dialog over the count, sending nothing but the review', async () => {
    const { fixture, host, actions, calls, screen } = mount(descriptor, [review(12)]);
    expect(actions.has(descriptor, INTEROP_PURGE_ACTION)).toBe(true);
    expect(actions.has(SERVED.find((other) => other.descriptor !== descriptor)!.descriptor, INTEROP_PURGE_ACTION)).toBe(false);
    await openDialog(fixture, actions, descriptor);
    expect(calls).toHaveLength(1);
    expect(calls[0].path).toBe(`/api/ocupilot/screens/${screen.toolIdentifier}/dryrun`);
    expect(JSON.parse(calls[0].body)).toEqual({ action: INTEROP_PURGE_ACTION, id: 'USER', values: { DaysToKeep: '0' } });
    expect(host.querySelector('.ocu-dialog-title')?.textContent?.trim()).toBe(STRINGS.auditDatabasePurgeConfirm);
    expect(host.querySelector('[data-interop-purge-count]')?.textContent?.trim()).toBe(`${STRINGS.interopColumnCount}: 12`);
    expect(host.querySelector('[data-interop-purge-settings]')).toBeNull();
    expect(host.querySelector('[data-interop-purge-consequence]')?.textContent?.trim()).toBe(consequence);
  });

  it('opens nothing and shows the refusal on the list when the review is refused', async () => {
    const { fixture, host, store, actions, calls } = mount(descriptor, [
      { kind: 'error', status: 403, code: 'AUTH.NOPRIVILEGE', reason: 'You need a privilege.' } as JsonResult<unknown>,
    ]);
    await openDialog(fixture, actions, descriptor);
    expect(calls).toHaveLength(1);
    expect(host.querySelector('app-interop-purge-dialog')).toBeNull();
    expect(store.refusal()).toBe('You need a privilege.');
  });

  // Mutation (Rule 19): make the Purge button's `aria-disabled` read the days alone -> the typed-name assertion goes red.
  it('holds Purge until the days are a whole number from 0 to 99999 and the namespace\'s name is typed exactly', async () => {
    const { fixture, host, actions, calls } = mount(descriptor, [review(0)]);
    await openDialog(fixture, actions, descriptor);
    expect(host.querySelector('[data-interop-purge-count]')?.textContent?.trim()).toBe(`${STRINGS.interopColumnCount}: 0`);
    expect(confirm(host).getAttribute('aria-disabled')).toBe('true');
    typeInto(fixture, host, '[data-interop-purge-days]', '3650');
    expect(confirm(host).getAttribute('aria-disabled')).toBe('true');
    typeInto(fixture, host, '[data-interop-purge-typed]', 'user');
    expect(confirm(host).getAttribute('aria-disabled')).toBe('true');
    typeInto(fixture, host, '[data-interop-purge-typed]', 'USER');
    expect(confirm(host).getAttribute('aria-disabled')).toBeNull();
    for (const days of ['-1', '1.5', '100000', 'x', '', '07']) {
      typeInto(fixture, host, '[data-interop-purge-days]', days);
      expect(confirm(host).getAttribute('aria-disabled')).toBe('true');
    }
    confirm(host).click();
    await settle(fixture);
    expect(calls).toHaveLength(1);
  });

  // Mutation (Rule 19): send the days as a number or leave the namespace out of the target -> this goes red.
  it('sends one Purge with the days as text, the namespace its target, closes on an applied purge and publishes the updated event', async () => {
    const { fixture, host, actions, calls, events, screen } = mount(descriptor, [review(5), purged(entity)]);
    await openDialog(fixture, actions, descriptor);
    typeInto(fixture, host, '[data-interop-purge-days]', '3650');
    typeInto(fixture, host, '[data-interop-purge-typed]', 'USER');
    confirm(host).click();
    await settle(fixture);
    expect(calls).toHaveLength(2);
    expect(calls[1].path).toBe(`/api/ocupilot/screens/${screen.toolIdentifier}/action`);
    expect(JSON.parse(calls[1].body)).toEqual({ action: INTEROP_PURGE_ACTION, id: 'USER', values: { DaysToKeep: '3650' } });
    expect(host.querySelector('app-interop-purge-dialog')).toBeNull();
    expect(events.map((event) => `${event.type}/${event.action}`)).toEqual([`${entity}/updated`]);
  });

  it('keeps a refusal on the days in the dialog as the instance\'s sentence, and one that names no field above the Purge button', async () => {
    const { fixture, host, actions, events } = mount(descriptor, [
      review(5),
      {
        kind: 'error',
        status: 422,
        code: 'INTEROP.PURGE.DAYS',
        reason: STRINGS.interopPurgeRefusalDays,
        detail: { violations: [{ field: 'DaysToKeep', code: 'INTEROP.PURGE.DAYS', reason: STRINGS.interopPurgeRefusalDays }] },
      } as JsonResult<unknown>,
      { kind: 'error', status: 409, code: 'INTEROP.PURGE.RUNNING', reason: STRINGS.interopPurgeRefusalRunning } as JsonResult<unknown>,
    ]);
    await openDialog(fixture, actions, descriptor);
    typeInto(fixture, host, '[data-interop-purge-days]', '3650');
    typeInto(fixture, host, '[data-interop-purge-typed]', 'USER');
    confirm(host).click();
    await settle(fixture);
    expect(host.querySelector('[data-interop-purge-violation]')?.textContent?.trim()).toBe(STRINGS.interopPurgeRefusalDays);
    expect(host.querySelector('[data-interop-purge-refusal]')).toBeNull();
    confirm(host).click();
    await settle(fixture);
    expect(host.querySelector('[data-interop-purge-violation]')).toBeNull();
    expect(host.querySelector('[data-interop-purge-refusal]')?.textContent?.trim()).toBe(STRINGS.interopPurgeRefusalRunning);
    expect(events).toEqual([]);
  });

  // Mutation (Rule 19): close the dialog on any answer -> the dialog assertion goes red.
  it('keeps the dialog open with the answer\'s sentence when the purge failed, and publishes nothing', async () => {
    const reason = 'The request failed inside the instance.';
    const { fixture, host, actions, events } = mount(descriptor, [review(5), { kind: 'error', status: 500, code: 'INTERNAL', reason } as JsonResult<unknown>]);
    await openDialog(fixture, actions, descriptor);
    typeInto(fixture, host, '[data-interop-purge-days]', '3650');
    typeInto(fixture, host, '[data-interop-purge-typed]', 'USER');
    confirm(host).click();
    await settle(fixture);
    expect(host.querySelector('app-interop-purge-dialog')).not.toBeNull();
    expect(host.querySelector('[data-interop-purge-refusal]')?.textContent?.trim()).toBe(reason);
    expect(events).toEqual([]);
  });

  it('closes on Cancel, sending nothing more and publishing nothing', async () => {
    const { fixture, host, actions, calls, events } = mount(descriptor, [review(5)]);
    await openDialog(fixture, actions, descriptor);
    const cancel = [...host.querySelectorAll('.ocu-dialog-actions button')].find((button) => button.textContent?.trim() === STRINGS.actionCancel) as HTMLButtonElement;
    cancel.click();
    await settle(fixture);
    expect(host.querySelector('app-interop-purge-dialog')).toBeNull();
    expect(calls).toHaveLength(1);
    expect(events).toEqual([]);
  });
});
