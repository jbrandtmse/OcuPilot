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
import { stubAccountPreferences } from '../../testing/account-preferences';
import { INTEROP_ARCHIVE_ACTION, INTEROP_ARCHIVE_LIST, InteropArchiveListPage } from './interop-archive-list.page';

/**
 * The Archive manager page (Story 24.16 Batch 4). The shared list page is replaced by an empty stand-in, so only this page's own wiring runs: the Run archive action it
 * registers, the review it asks for first (which reads the target, the days, the class and how many messages the run would move, and writes nothing), the dialog that shows
 * them, the consequence it states and the namespace's name it asks to be typed, the one request a run sends -- no value, the namespace its target -- a refusal kept in the
 * dialog, and the change event an applied run publishes. The handler, the stores and the bus are real; only the server's answers are stubbed.
 */

@Component({ selector: 'app-list-page', template: '' })
class StubListPage {}

const LIST = SCREENS.find((screen) => screen.descriptor === INTEROP_ARCHIVE_LIST)!;

const ROWS = [
  { Name: 'Archive start time', Value: '', Namespace: 'HSCUSTOM' },
  { Name: 'Archive status', Value: 'idle', Namespace: 'HSCUSTOM' },
];

const review = (values: Record<string, unknown>): JsonResult<unknown> => ({
  kind: 'ok',
  status: 200,
  body: { rows: [], review: { Target: 'USER', Classname: 'Ens.Archive.Manager', DaysToArchive: 3650, ToArchive: 12, Total: 40, ...values } },
});

const ARCHIVED: JsonResult<unknown> = {
  kind: 'ok',
  status: 200,
  body: { action: 'updated', target: { type: 'interop-archive', scope: 'HSCUSTOM', id: 'HSCUSTOM' }, readBack: { verdict: 'matches' } },
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
      { provide: ScopeService, useValue: { loaded: () => true, namespace: () => 'HSCUSTOM', subscribe: () => () => {} } as unknown as ScopeService },
    ],
  });
  TestBed.overrideComponent(InteropArchiveListPage, { remove: { imports: [ListPage] }, add: { imports: [StubListPage] } });
  const store = stores.for(LIST.descriptor, LIST.refreshRates);
  store.applyTick(ROWS, false, '', new Date());
  const fixture = TestBed.createComponent(InteropArchiveListPage);
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

const confirm = (host: HTMLElement): HTMLButtonElement => host.querySelector('[data-interop-archive-confirm]') as HTMLButtonElement;

async function openDialog(fixture: ComponentFixture<unknown>, actions: ScreenActions): Promise<void> {
  actions.run(INTEROP_ARCHIVE_LIST, INTEROP_ARCHIVE_ACTION);
  await settle(fixture);
}

afterEach(() => {
  for (const node of planted.splice(0)) node.remove();
  TestBed.resetTestingModule();
});

describe('the Archive manager page', () => {
  it('declares the list this page hosts, with Run archive as its one row action', () => {
    expect(LIST.primaryAction?.id).toBe('');
    expect(LIST.rowActions.map((action) => action.id)).toEqual([INTEROP_ARCHIVE_ACTION]);
  });

  // Mutation (Rule 19): drop this page's `actions.register` of `archive` -> the first assertion goes red.
  it('registers Run archive, reviews the run first and opens the dialog over what the review read, sending nothing but the review', async () => {
    const { fixture, host, actions, calls } = mount([review({})]);
    expect(actions.has(INTEROP_ARCHIVE_LIST, INTEROP_ARCHIVE_ACTION)).toBe(true);
    await openDialog(fixture, actions);
    expect(calls).toHaveLength(1);
    expect(calls[0].path).toBe(`/api/ocupilot/screens/${LIST.toolIdentifier}/dryrun`);
    expect(JSON.parse(calls[0].body)).toEqual({ action: INTEROP_ARCHIVE_ACTION, id: 'HSCUSTOM' });
    expect(host.querySelector('.ocu-dialog-title')?.textContent?.trim()).toBe(STRINGS.interopArchiveAction);
    expect(host.querySelector('[data-interop-archive-setting="target"]')?.textContent?.trim()).toBe(`${STRINGS.interopArchiveSettingTarget}: USER`);
    expect(host.querySelector('[data-interop-archive-setting="days"]')?.textContent?.trim()).toBe(`${STRINGS.interopArchiveSettingDays}: 3650`);
    expect(host.querySelector('[data-interop-archive-setting="class"]')?.textContent?.trim()).toBe(`${STRINGS.interopArchiveSettingClass}: Ens.Archive.Manager`);
    expect(host.querySelector('[data-interop-archive-setting="messages"]')?.textContent?.trim()).toBe(`${STRINGS.interopArchiveMessages}: 12`);
    expect(host.querySelector('[data-interop-archive-consequence]')?.textContent?.trim()).toBe(STRINGS.interopArchiveRunConsequence);
  });

  it('opens nothing and shows the refusal on the list when the review is refused, as for a run already running', async () => {
    const { fixture, host, store, actions, calls } = mount([
      { kind: 'error', status: 409, code: 'INTEROP.ARCHIVE.RUNNING', reason: STRINGS.interopArchiveRefusalRunning } as JsonResult<unknown>,
    ]);
    await openDialog(fixture, actions);
    expect(calls).toHaveLength(1);
    expect(host.querySelector('app-interop-archive-dialog')).toBeNull();
    expect(store.refusal()).toBe(STRINGS.interopArchiveRefusalRunning);
  });

  // Mutation (Rule 19): make the Run archive button's `aria-disabled` ignore the typed text -> this goes red.
  it('holds Run archive until the namespace\'s name is typed exactly', async () => {
    const { fixture, host, actions, calls } = mount([review({})]);
    await openDialog(fixture, actions);
    expect(confirm(host).getAttribute('aria-disabled')).toBe('true');
    typeInto(fixture, host, '[data-interop-archive-typed]', 'hscustom');
    expect(confirm(host).getAttribute('aria-disabled')).toBe('true');
    confirm(host).click();
    await settle(fixture);
    expect(calls).toHaveLength(1);
    typeInto(fixture, host, '[data-interop-archive-typed]', 'HSCUSTOM');
    expect(confirm(host).getAttribute('aria-disabled')).toBeNull();
  });

  // Mutation (Rule 19): send a value with the run or leave the namespace out of the target -> this goes red.
  it('sends one Run archive with no value, the namespace its target, closes on an applied run and publishes the updated event', async () => {
    const { fixture, host, actions, calls, events } = mount([review({}), ARCHIVED]);
    await openDialog(fixture, actions);
    typeInto(fixture, host, '[data-interop-archive-typed]', 'HSCUSTOM');
    confirm(host).click();
    await settle(fixture);
    expect(calls).toHaveLength(2);
    expect(calls[1].path).toBe(`/api/ocupilot/screens/${LIST.toolIdentifier}/action`);
    expect(JSON.parse(calls[1].body)).toEqual({ action: INTEROP_ARCHIVE_ACTION, id: 'HSCUSTOM', values: {} });
    expect(host.querySelector('app-interop-archive-dialog')).toBeNull();
    expect(events.map((event) => `${event.type}/${event.action}`)).toEqual(['interop-archive/updated']);
  });

  // Mutation (Rule 19): close the dialog on any answer -> the dialog assertion goes red.
  it('keeps the dialog open with the answer\'s sentence when the run failed, and publishes nothing', async () => {
    const reason = 'An internal error occurred';
    const { fixture, host, actions, events } = mount([review({}), { kind: 'error', status: 500, code: 'INTERNAL', reason } as JsonResult<unknown>]);
    await openDialog(fixture, actions);
    typeInto(fixture, host, '[data-interop-archive-typed]', 'HSCUSTOM');
    confirm(host).click();
    await settle(fixture);
    expect(host.querySelector('app-interop-archive-dialog')).not.toBeNull();
    expect(host.querySelector('[data-interop-archive-refusal]')?.textContent?.trim()).toBe(reason);
    expect(events).toEqual([]);
  });

  it('closes on Cancel without sending, and opens no second dialog over the first', async () => {
    const { fixture, host, actions, calls } = mount([review({}), review({})]);
    await openDialog(fixture, actions);
    await openDialog(fixture, actions);
    expect(calls).toHaveLength(1);
    const cancel = [...host.querySelectorAll('.ocu-dialog-actions button')].find((button) => button.textContent?.trim() === STRINGS.actionCancel) as HTMLButtonElement;
    cancel.click();
    await settle(fixture);
    expect(host.querySelector('app-interop-archive-dialog')).toBeNull();
    expect(calls).toHaveLength(1);
  });
});
