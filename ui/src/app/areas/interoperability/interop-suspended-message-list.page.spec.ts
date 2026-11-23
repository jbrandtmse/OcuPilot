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
import { ScreenActionDialogs } from '../../shell/screen-action-dialogs';
import { INTEROP_SUSPENDED_LIST, ScreenActionHandler, SUSPENDED_DISCARD, SUSPENDED_EDIT_RESUBMIT, SUSPENDED_RESUBMIT } from '../../shell/screen-action-handler';
import { stubAccountPreferences } from '../../testing/account-preferences';
import { InteropSuspendedMessageListPage } from './interop-suspended-message-list.page';

/**
 * The Suspended messages page (Story 24.16). The shared list page is replaced by a stand-in that draws the descriptor's dialogs, so only this page's own wiring
 * runs: the Edit and resubmit action it registers, the form over the selected message's fields, the dry run of the changed fields only, the typed-name review and
 * the one request its confirm sends. The page's checked-row actions are the handler's, so Resubmit's review and its typed count are driven through the handler the page
 * constructs. The handler, the stores, the bus and every dialog are real; only the instance's answers are stubbed.
 */

/** Stands in for the list page, which draws the dialogs of the descriptor it shows. */
@Component({
  selector: 'app-list-page',
  imports: [ScreenActionDialogs],
  template: `<app-screen-action-dialogs [descriptor]="descriptor" />`,
})
class StubListPage {
  readonly descriptor = INTEROP_SUSPENDED_LIST;
}

const LIST = SCREENS.find((screen) => screen.descriptor === INTEROP_SUSPENDED_LIST)!;

const MESSAGE = '12';

/** The separators a review line draws between a message's id, source and target. */
const DOT = String.fromCodePoint(0xb7);

const ARROW = String.fromCodePoint(0x2192);

const DIGEST = 'f'.repeat(64);

const DRY_RUN = '/api/ocupilot/screens/interop.suspendedmessages/dryrun';

const ACTION = '/api/ocupilot/screens/interop.suspendedmessages/action';

const ROWS = [
  { ID: '12', TimeCreated: '2026-11-22 10:00:00', SessionId: '12', Error: true, Type: 'Request', Source: 'Svc', Target: 'Op', BodyClass: 'Ens.StringRequest' },
  { ID: '11', TimeCreated: '2026-11-22 09:00:00', SessionId: '11', Error: false, Type: 'Request', Source: 'Svc', Target: 'Op', BodyClass: 'Ens.StringRequest' },
];

const FORM = [
  { RequestClass: 'Ens.StringRequest', Kind: 'object', Field: 'StringValue', Type: '%Library.String', Required: false, MaxLength: null, Values: [], Secret: false, Value: 'beta' },
];

const planted: HTMLElement[] = [];

async function settle(fixture: ComponentFixture<unknown>): Promise<void> {
  for (let pass = 0; pass < 5; pass += 1) {
    await new Promise((resolve) => setTimeout(resolve, 2));
    fixture.detectChanges();
    await fixture.whenStable();
  }
}

interface Call {
  readonly path: string;
  readonly method: string;
  readonly body: Record<string, unknown>;
}

/** Mount the page over `ROWS` with the first row selected; each request resolves to the next of `answers`. */
function mount(answers: JsonResult<unknown>[], selected = true) {
  TestBed.resetTestingModule();
  const calls: Call[] = [];
  const api = {
    requestJson: async <T,>(path: string, init: ApiRequestInit = {}): Promise<JsonResult<T>> => {
      calls.push({ path, method: init.method ?? 'GET', body: init.body ? (JSON.parse(init.body) as Record<string, unknown>) : {} });
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
  TestBed.overrideComponent(InteropSuspendedMessageListPage, { remove: { imports: [ListPage] }, add: { imports: [StubListPage] } });
  const store = stores.for(LIST.descriptor, LIST.refreshRates);
  store.applyTick(ROWS as never[], false, '', new Date());
  if (selected) store.setSelection([MESSAGE]);
  const fixture = TestBed.createComponent(InteropSuspendedMessageListPage);
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  fixture.detectChanges();
  return { fixture, host: fixture.nativeElement as HTMLElement, store, calls, events, actions: TestBed.inject(ScreenActions), handler: TestBed.inject(ScreenActionHandler) };
}

const formAnswer = (): JsonResult<unknown> => ({ kind: 'ok', status: 200, body: { rows: [], review: { Digest: DIGEST, Kind: 'object', Form: FORM } } });

const editAnswer = (): JsonResult<unknown> => ({
  kind: 'ok',
  status: 200,
  body: { rows: [{ field: 'Body', before: 'StringValue: beta', after: 'StringValue: edited' }], review: { Digest: DIGEST, Kind: 'object', Form: FORM } },
});

const reviewAnswer = (lines: readonly string[]): JsonResult<unknown> => ({
  kind: 'ok',
  status: 200,
  body: { rows: [{ field: 'Messages', before: '', after: lines.join('\n') }], review: { Digest: DIGEST } },
});

const sentAnswer = (lines: readonly string[]): JsonResult<unknown> => ({
  kind: 'ok',
  status: 200,
  body: { action: 'updated', target: { type: 'interop-message', scope: 'namespace:USER', id: MESSAGE }, output: { lines } },
});

function refusal(status: number, code: string, reason: string): JsonResult<unknown> {
  return { kind: 'error', status, code, reason, detail: null } as unknown as JsonResult<unknown>;
}

function typeInto(fixture: ComponentFixture<unknown>, host: HTMLElement, selector: string, value: string): void {
  const input = host.querySelector(selector) as HTMLInputElement;
  input.value = value;
  input.dispatchEvent(new Event('input'));
  fixture.detectChanges();
}

const destructive = (host: HTMLElement): HTMLButtonElement => host.querySelector('.ocu-button-destructive') as HTMLButtonElement;

afterEach(() => {
  for (const node of planted.splice(0)) node.remove();
  TestBed.resetTestingModule();
});

describe('the Suspended messages page (Story 24.16)', () => {
  it('declares the four actions with Delete last, the three that act on a set over the checked rows, and registers all four', () => {
    // Mutation (Rule 19): drop the `actions.register` -> the edit assertion goes red; drop the descriptor from `SCREEN_ACTION_DESCRIPTORS` -> the other three go red.
    expect(LIST.rowActions.map((action) => action.id)).toEqual([SUSPENDED_RESUBMIT, SUSPENDED_EDIT_RESUBMIT, SUSPENDED_DISCARD, 'delete']);
    expect(LIST.multiSelect).toEqual({ action: SUSPENDED_RESUBMIT, max: 100, extraActions: [SUSPENDED_DISCARD, 'delete'] });
    const { actions } = mount([]);
    expect(actions.has(INTEROP_SUSPENDED_LIST, SUSPENDED_EDIT_RESUBMIT)).toBe(true);
    for (const id of [SUSPENDED_RESUBMIT, SUSPENDED_DISCARD, 'delete']) expect(actions.has(INTEROP_SUSPENDED_LIST, id), `${id} is registered by the handler`).toBe(true);
  });

  it('opens the edit form over the fields of the selected message, titled and labeled for an edit and resubmit', async () => {
    // Mutation (Rule 19): open the form before the dry run answers -> a refusal leg goes red; read the id from another row -> the request body goes red.
    const { fixture, host, actions, calls } = mount([formAnswer()]);
    actions.run(INTEROP_SUSPENDED_LIST, SUSPENDED_EDIT_RESUBMIT);
    await settle(fixture);
    expect(calls).toEqual([{ path: DRY_RUN, method: 'POST', body: { action: 'editresubmit', id: MESSAGE } }]);
    expect(host.querySelector('.ocu-dialog-title')?.textContent?.trim()).toBe(STRINGS.interopSuspendedEditResubmitAction);
    expect(host.querySelector('[data-interop-test-send]')?.textContent?.trim()).toBe(STRINGS.interopEditResendReview);
    expect((host.querySelector('[data-field="StringValue"] [data-interop-test-input]') as HTMLInputElement).value).toBe('beta');
  });

  it('does nothing with no row selected', async () => {
    // Mutation (Rule 19): drop the empty-id test -> a request is made for no message and this goes red.
    const { fixture, host, actions, calls } = mount([formAnswer()], false);
    actions.run(INTEROP_SUSPENDED_LIST, SUSPENDED_EDIT_RESUBMIT);
    await settle(fixture);
    expect(calls).toHaveLength(0);
    expect(host.querySelector('app-interop-item-test-dialog')).toBeNull();
  });

  it('puts the refusal of the dry run that asks for the form on the banner of the list, with no form', async () => {
    // Mutation (Rule 19): drop the `refused` branch of `MessageEditFlow.begin` -> a form opens over nothing and this goes red.
    const { fixture, host, actions, store } = mount([refusal(409, 'INTEROP.SUSPENDED.NONE', STRINGS.interopSuspendedRefusalNone)]);
    actions.run(INTEROP_SUSPENDED_LIST, SUSPENDED_EDIT_RESUBMIT);
    await settle(fixture);
    expect(store.refusal()).toBe(STRINGS.interopSuspendedRefusalNone);
    expect(host.querySelector('app-interop-item-test-dialog')).toBeNull();
  });

  it('reviews only the changed fields, then the typed-name review sends the edit with the digest and reports the message resubmitted', async () => {
    // Mutation (Rule 19): send every field in place of the changed ones -> the dry-run body goes red; send the action to the Header tab's screen -> the paths go red.
    const { fixture, host, actions, calls, events } = mount([formAnswer(), editAnswer(), sentAnswer([`${MESSAGE}: ${STRINGS.interopSuspendedOutcomeResubmitted}`])]);
    actions.run(INTEROP_SUSPENDED_LIST, SUSPENDED_EDIT_RESUBMIT);
    await settle(fixture);
    (host.querySelector('[data-interop-test-send]') as HTMLButtonElement).click();
    await settle(fixture);
    expect(host.querySelector('[data-interop-test-reason]')?.textContent?.trim()).toBe(STRINGS.interopRefusalEditNoChange);
    expect(calls).toHaveLength(1);
    typeInto(fixture, host, '[data-field="StringValue"] [data-interop-test-input]', 'edited');
    (host.querySelector('[data-interop-test-send]') as HTMLButtonElement).click();
    await settle(fixture);
    const fields = JSON.stringify({ StringValue: 'edited' });
    expect(calls[1]).toEqual({ path: DRY_RUN, method: 'POST', body: { action: 'editresubmit', id: MESSAGE, values: { fields } } });
    expect(host.querySelector('app-interop-item-test-dialog')).toBeNull();
    expect(host.querySelector('.ocu-dialog-title')?.textContent?.trim()).toBe(`${STRINGS.interopSuspendedEditResubmitAction} ${MESSAGE}`);
    expect(host.querySelector('.ocu-typed-name-consequence')?.textContent?.trim()).toBe(STRINGS.interopSuspendedEditConsequence);
    expect([...host.querySelectorAll('[data-ocu-review] li')].map((item) => item.textContent)).toEqual(['- StringValue: beta', '+ StringValue: edited']);
    typeInto(fixture, host, '.ocu-typed-name-field', MESSAGE);
    destructive(host).click();
    await settle(fixture);
    expect(calls[2]).toEqual({ path: ACTION, method: 'POST', body: { action: 'editresubmit', id: MESSAGE, values: { fields, Reviewed: DIGEST } } });
    expect([...host.querySelectorAll('[data-ocu-outcome] li')].map((item) => item.textContent)).toEqual([`${MESSAGE}: ${STRINGS.interopSuspendedOutcomeResubmitted}`]);
    expect(events.map((event) => event.kind)).toEqual(['changed']);
  });

  it('types the count of the messages a Resubmit will act on, which are the lines that read will be resubmitted', async () => {
    // Mutation (Rule 19): count the resend's verdict in `openReview` for this screen -> no line counts, the typed name is 0 and this goes red.
    const lines = [
      `11 ${DOT} Svc ${ARROW} Op: ${STRINGS.interopSuspendedVerdictResubmit}`,
      `12 ${DOT} Svc ${ARROW} Op: ${STRINGS.interopSuspendedVerdictResubmit}`,
      `13: ${STRINGS.interopResendVerdictGone}`,
    ];
    const { fixture, host, handler, store, calls } = mount([reviewAnswer(lines), sentAnswer(['11: resubmitted', '12: resubmitted'])], false);
    await handler.startDryRun(INTEROP_SUSPENDED_LIST, SUSPENDED_RESUBMIT, '11,12,13', undefined, store);
    await settle(fixture);
    expect(calls[0]).toEqual({ path: DRY_RUN, method: 'POST', body: { action: 'resubmit', id: '11,12,13' } });
    expect(host.querySelector('.ocu-dialog-title')?.textContent?.trim()).toBe(`${STRINGS.interopSuspendedResubmitAction} 2`);
    expect(host.querySelector('.ocu-typed-name-consequence')?.textContent?.trim()).toBe(STRINGS.interopSuspendedResubmitConsequence);
    expect(destructive(host).getAttribute('aria-disabled')).toBe('true');
    typeInto(fixture, host, '.ocu-typed-name-field', '2');
    destructive(host).click();
    await settle(fixture);
    expect(calls[1]).toEqual({ path: ACTION, method: 'POST', body: { action: 'resubmit', id: '11,12,13', values: { Reviewed: DIGEST } } });
    expect([...host.querySelectorAll('[data-ocu-outcome] li')].map((item) => item.textContent)).toEqual(['11: resubmitted', '12: resubmitted']);
  });

  it('refuses a review whose problem is the published sentence with that sentence, not the generic refusal', async () => {
    // Mutation (Rule 19): drop the suspended sentence from `DRY_RUN_SENTENCES` -> the banner reads the generic refusal and this goes red.
    const problem = `${STRINGS.interopSuspendedRefusalNone}\n13: ${STRINGS.interopResendVerdictGone}`;
    const refused = { kind: 'error', status: 400, code: 'TOOL.ARGUMENTS', reason: 'x', detail: { problem } } as unknown as JsonResult<unknown>;
    const { fixture, host, handler, store } = mount([refused], false);
    await handler.startDryRun(INTEROP_SUSPENDED_LIST, SUSPENDED_DISCARD, '13', undefined, store);
    await settle(fixture);
    expect(store.refusal()).toBe(STRINGS.interopSuspendedRefusalNone);
    expect(host.querySelector('.ocu-dialog-title')).toBeNull();
  });
});
