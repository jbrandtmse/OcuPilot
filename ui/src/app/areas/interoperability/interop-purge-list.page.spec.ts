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
import { STRINGS } from '../../core/strings';
import { ListPage } from '../../shell/list-page';
import { ScreenActionHandler } from '../../shell/screen-action-handler';
import { stubAccountPreferences } from '../../testing/account-preferences';
import { INTEROP_PURGE_ACTION, INTEROP_PURGE_LIST, InteropPurgeListPage } from './interop-purge-list.page';

/**
 * The Purge management data page (Story 24.16). The shared list page is replaced by an empty stand-in, so only this page's own wiring runs: the Purge action it
 * registers, the review it asks for first (which reads the three settings the purge will use and writes nothing), the dialog that shows them, the consequence it
 * states and the namespace's name it asks to be typed, the one request a Purge sends -- the days as text, the namespace its target -- a refusal kept in the dialog,
 * and the change event an applied purge publishes. The handler, the stores and the bus are real; only the server's answers are stubbed.
 */

@Component({ selector: 'app-list-page', template: '' })
class StubListPage {}

const LIST = SCREENS.find((screen) => screen.descriptor === INTEROP_PURGE_LIST)!;

const ROWS = [
  { Type: 'Event Log', Count: 12, Namespace: 'USER' },
  { Type: 'Messages', Count: 3, Namespace: 'USER' },
];

const review = (settings: Record<string, unknown>): JsonResult<unknown> => ({
  kind: 'ok',
  status: 200,
  body: { rows: [], review: { BodiesToo: false, KeepIntegrity: true, NamespaceBitmapMaint: false, Description: '', ...settings } },
});

const PURGED: JsonResult<unknown> = {
  kind: 'ok',
  status: 200,
  body: { action: 'updated', target: { type: 'interop-purge', scope: 'USER', id: 'USER' }, readBack: { verdict: 'matches' } },
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

/** Mount the page over `ROWS`, each request resolving to the next of `answers`. */
function mount(answers: JsonResult<unknown>[]) {
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
  TestBed.overrideComponent(InteropPurgeListPage, { remove: { imports: [ListPage] }, add: { imports: [StubListPage] } });
  const store = stores.for(LIST.descriptor, LIST.refreshRates);
  store.applyTick(ROWS, false, '', new Date());
  const fixture = TestBed.createComponent(InteropPurgeListPage);
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  fixture.detectChanges();
  return { fixture, host: fixture.nativeElement as HTMLElement, store, calls, events, actions: TestBed.inject(ScreenActions) };
}

function typeInto(fixture: ComponentFixture<unknown>, host: HTMLElement, selector: string, value: string): void {
  const control = host.querySelector(selector) as HTMLInputElement;
  control.value = value;
  control.dispatchEvent(new Event('input'));
  fixture.detectChanges();
}

const confirm = (host: HTMLElement): HTMLButtonElement => host.querySelector('[data-interop-purge-confirm]') as HTMLButtonElement;

async function openDialog(fixture: ComponentFixture<unknown>, actions: ScreenActions): Promise<void> {
  actions.run(INTEROP_PURGE_LIST, INTEROP_PURGE_ACTION);
  await settle(fixture);
}

afterEach(() => {
  for (const node of planted.splice(0)) node.remove();
  TestBed.resetTestingModule();
});

describe('the Purge management data page', () => {
  it('declares the list this page hosts, with Purge as its one row action', () => {
    expect(LIST.primaryAction?.id).toBe('');
    expect(LIST.rowActions.map((action) => action.id)).toEqual([INTEROP_PURGE_ACTION]);
  });

  // Mutation (Rule 19): drop this page's `actions.register` of `purge` -> the first assertion goes red.
  it('registers Purge, reviews the purge first and opens the dialog over the settings the review read, sending nothing but the review', async () => {
    const { fixture, host, actions, calls } = mount([review({ BodiesToo: true, Description: 'nightly clean-up' })]);
    expect(actions.has(INTEROP_PURGE_LIST, INTEROP_PURGE_ACTION)).toBe(true);
    await openDialog(fixture, actions);
    expect(calls).toHaveLength(1);
    expect(calls[0].path).toBe(`/api/ocupilot/screens/${LIST.toolIdentifier}/dryrun`);
    expect(JSON.parse(calls[0].body)).toEqual({ action: INTEROP_PURGE_ACTION, id: 'USER', values: { DaysToKeep: '0' } });
    expect(host.querySelector('.ocu-dialog-title')?.textContent?.trim()).toBe(STRINGS.auditDatabasePurgeConfirm);
    expect(host.querySelector('[data-interop-purge-setting="bodies"]')?.textContent?.trim()).toBe(`${STRINGS.interopPurgeSettingBodies}: ${STRINGS.tableStatusYes}`);
    expect(host.querySelector('[data-interop-purge-setting="integrity"]')?.textContent?.trim()).toBe(`${STRINGS.interopPurgeSettingIntegrity}: ${STRINGS.tableStatusYes}`);
    expect(host.querySelector('[data-interop-purge-setting="bitmap"]')?.textContent?.trim()).toBe(`${STRINGS.interopPurgeSettingBitmap}: ${STRINGS.tableStatusNo}`);
    expect(host.querySelector('[data-interop-purge-setting="description"]')?.textContent?.trim()).toBe(`${STRINGS.tableColumnDescription}: nightly clean-up`);
    expect(host.querySelector('[data-interop-purge-consequence]')?.textContent?.trim()).toBe(STRINGS.interopPurgeRunConsequence);
  });

  // Mutation (Rule 19): show the plain sentence whatever the setting -> this goes red.
  it('states the bitmap cleanup\'s sentence when the setting is on, and shows no description line for an empty one', async () => {
    const { fixture, host, actions } = mount([review({ NamespaceBitmapMaint: true })]);
    await openDialog(fixture, actions);
    expect(host.querySelector('[data-interop-purge-consequence]')?.textContent?.trim()).toBe(STRINGS.interopPurgeBitmapConsequence);
    expect(host.querySelector('[data-interop-purge-setting="description"]')).toBeNull();
  });

  it('opens nothing and shows the refusal on the list when the review is refused, as for a purge already running', async () => {
    const { fixture, host, store, actions, calls } = mount([
      { kind: 'error', status: 409, code: 'INTEROP.PURGE.RUNNING', reason: STRINGS.interopPurgeRefusalRunning } as JsonResult<unknown>,
    ]);
    await openDialog(fixture, actions);
    expect(calls).toHaveLength(1);
    expect(host.querySelector('app-interop-purge-dialog')).toBeNull();
    expect(store.refusal()).toBe(STRINGS.interopPurgeRefusalRunning);
  });

  // Mutation (Rule 19): make the Purge button's `aria-disabled` read the days alone -> the typed-name assertion goes red.
  it('holds Purge until the days are a whole number from 0 to 99999 and the namespace\'s name is typed exactly', async () => {
    const { fixture, host, actions, calls } = mount([review({})]);
    await openDialog(fixture, actions);
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
    const { fixture, host, actions, calls, events } = mount([review({}), PURGED]);
    await openDialog(fixture, actions);
    typeInto(fixture, host, '[data-interop-purge-days]', '3650');
    typeInto(fixture, host, '[data-interop-purge-typed]', 'USER');
    confirm(host).click();
    await settle(fixture);
    expect(calls).toHaveLength(2);
    expect(calls[1].path).toBe(`/api/ocupilot/screens/${LIST.toolIdentifier}/action`);
    expect(JSON.parse(calls[1].body)).toEqual({ action: INTEROP_PURGE_ACTION, id: 'USER', values: { DaysToKeep: '3650' } });
    expect(host.querySelector('app-interop-purge-dialog')).toBeNull();
    expect(events.map((event) => `${event.type}/${event.action}`)).toEqual(['interop-purge/updated']);
  });

  it('keeps a refusal on the days in the dialog as the instance\'s sentence, and one that names no field above the Purge button', async () => {
    const { fixture, host, actions, events } = mount([
      review({}),
      {
        kind: 'error',
        status: 422,
        code: 'INTEROP.PURGE.DAYS',
        reason: STRINGS.interopPurgeRefusalDays,
        detail: { violations: [{ field: 'DaysToKeep', code: 'INTEROP.PURGE.DAYS', reason: STRINGS.interopPurgeRefusalDays }] },
      } as JsonResult<unknown>,
      { kind: 'error', status: 409, code: 'INTEROP.PURGE.RUNNING', reason: STRINGS.interopPurgeRefusalRunning } as JsonResult<unknown>,
    ]);
    await openDialog(fixture, actions);
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

  it('closes on Cancel, sending nothing more and publishing nothing', async () => {
    const { fixture, host, actions, calls, events } = mount([review({})]);
    await openDialog(fixture, actions);
    const cancel = [...host.querySelectorAll('.ocu-dialog-actions button')].find((button) => button.textContent?.trim() === STRINGS.actionCancel) as HTMLButtonElement;
    cancel.click();
    await settle(fixture);
    expect(host.querySelector('app-interop-purge-dialog')).toBeNull();
    expect(calls).toHaveLength(1);
    expect(events).toEqual([]);
  });
});
