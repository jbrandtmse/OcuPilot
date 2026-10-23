import { Component } from '@angular/core';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { Router } from '@angular/router';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type ApiRequestInit, type JsonResult } from '../../core/api';
import { ChangeBus, type ChangeEvent } from '../../core/change-bus';
import { encodeEntityId } from '../../core/entity-id';
import { OverlayStack } from '../../core/overlay-stack';
import { ScreenActions } from '../../core/screen-actions';
import { ScreenStores } from '../../core/screen-store';
import { SCREENS } from '../../core/screens.generated';
import { STRINGS } from '../../core/strings';
import { DetailPage } from '../../shell/detail-page';
import { ScreenActionDialogs } from '../../shell/screen-action-dialogs';
import { INTEROP_MESSAGE_HEADER, MESSAGE_EDIT_RESEND, MESSAGE_RESEND } from '../../shell/screen-action-handler';
import { stubAccountPreferences } from '../../testing/account-preferences';
import { InteropMessageHeaderPage } from './interop-message-header.page';

/**
 * A message's Header tab page (Story 20.31). The detail page that hosts the list is replaced by an empty stand-in, so only this page's
 * own wiring runs: the two actions it registers, the first row it keeps selected, Resend's dry run and typed-name review at the
 * Messages screen, and Edit and resend's form, its dry run of the changed fields only, its review and its confirm. The handler, the
 * stores, the bus and every dialog are real; only the instance's answers are stubbed.
 */

/** Stands in for the detail page, which draws the dialogs of the descriptor it shows through its list page. */
@Component({
  selector: 'app-detail-page',
  imports: [ScreenActionDialogs],
  template: `<app-screen-action-dialogs [descriptor]="descriptor" />`,
})
class StubDetailPage {
  readonly descriptor = INTEROP_MESSAGE_HEADER;
}

const TAB = SCREENS.find((screen) => screen.descriptor === INTEROP_MESSAGE_HEADER)!;

const MESSAGE = '12';

const CLASS = 'Ens.StringRequest';

const DIGEST = 'e'.repeat(64);

const DRY_RUN = '/api/ocupilot/screens/interop.messages/dryrun';

const ACTION = '/api/ocupilot/screens/interop.messages/action';

const HEADER_DRY_RUN = '/api/ocupilot/screens/interop.messageheader/dryrun';

const HEADER_ACTION = '/api/ocupilot/screens/interop.messageheader/action';

const PROPERTIES = [{ Name: 'ID', Value: '12' }, { Name: 'Status', Value: 'Completed' }];

const FORM = [
  { RequestClass: CLASS, Kind: 'object', Field: 'StringValue', Type: '%Library.String', Required: false, MaxLength: null, Values: [], Secret: false, Value: 'beta' },
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

/** Mount the page on the route that names `MESSAGE`; each request resolves to the next of `answers`. */
function mount(answers: JsonResult<unknown>[], rows: readonly unknown[] = PROPERTIES) {
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
      { provide: Router, useValue: { url: `/${TAB.route}/${encodeEntityId(MESSAGE)}` } as unknown as Router },
    ],
  });
  TestBed.overrideComponent(InteropMessageHeaderPage, { remove: { imports: [DetailPage] }, add: { imports: [StubDetailPage] } });
  const store = stores.for(TAB.descriptor, TAB.refreshRates);
  store.applyTick(rows as never[], false, '', new Date());
  const fixture = TestBed.createComponent(InteropMessageHeaderPage);
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  fixture.detectChanges();
  return { fixture, host: fixture.nativeElement as HTMLElement, store, calls, events, actions: TestBed.inject(ScreenActions) };
}

const reviewAnswer = (lines: readonly string[]): JsonResult<unknown> => ({
  kind: 'ok',
  status: 200,
  body: { rows: [{ field: 'Messages', before: '', after: lines.join('\n') }], review: { Digest: DIGEST } },
});

const formAnswer = (): JsonResult<unknown> => ({ kind: 'ok', status: 200, body: { rows: [], review: { Digest: DIGEST, Kind: 'object', Form: FORM } } });

const editAnswer = (): JsonResult<unknown> => ({
  kind: 'ok',
  status: 200,
  body: { rows: [{ field: 'Body', before: 'StringValue: beta', after: 'StringValue: edited' }], review: { Digest: DIGEST, Kind: 'object', Form: FORM } },
});

const sentAnswer = (id: string, target: string): JsonResult<unknown> => ({
  kind: 'ok',
  status: 200,
  body: { action: 'created', target: { type: 'interop-message', scope: 'namespace:USER', id: target }, output: { lines: [`${id}: resent as 40`] } },
});

function refusal(status: number, code: string, reason: string, detail: Record<string, unknown> | null = null): JsonResult<unknown> {
  return { kind: 'error', status, code, reason, detail } as unknown as JsonResult<unknown>;
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

describe('a message\u2019s Header tab page (Story 20.31)', () => {
  it('declares Resend as the tab\u2019s primary action beside Edit and resend, and registers both', () => {
    // Mutation (Rule 19): drop either `actions.register` -> its assertion goes red.
    expect(TAB.primaryAction?.id).toBe(MESSAGE_RESEND);
    expect(TAB.rowActions.map((action) => action.id)).toEqual([MESSAGE_RESEND, MESSAGE_EDIT_RESEND]);
    const { actions } = mount([]);
    expect(actions.has(INTEROP_MESSAGE_HEADER, MESSAGE_RESEND)).toBe(true);
    expect(actions.has(INTEROP_MESSAGE_HEADER, MESSAGE_EDIT_RESEND)).toBe(true);
  });

  it('keeps the first row selected, so the row action is never unavailable for want of a selection', () => {
    // Mutation (Rule 19): drop `keepSelection` from the store subscription -> the late-rows leg goes red.
    const early = mount([]);
    expect(early.store.selection()).toEqual(['ID']);
    TestBed.resetTestingModule();
    const late = mount([], []);
    expect(late.store.selection()).toEqual([]);
    late.store.applyTick(PROPERTIES as never[], false, '', new Date());
    expect(late.store.selection()).toEqual(['ID']);
    late.store.setSelection(['Status']);
    late.store.applyTick(PROPERTIES as never[], false, '', new Date());
    expect(late.store.selection()).toEqual(['Status']);
  });

  it('reviews a resend at the Messages screen, opens the typed-name dialog typed by the message id, and reports what was sent', async () => {
    // Mutation (Rule 19): post the dry run to this tab's own screen -> the path assertion goes red; drop the page's own
    // `app-screen-action-dialogs` for the list -> no dialog opens and the rest goes red.
    const line = `12 \u00B7 Svc \u2192 Op: ${STRINGS.interopResendVerdictResend}`;
    const { fixture, host, actions, calls, events } = mount([reviewAnswer([line]), sentAnswer('12', '12')]);
    actions.run(INTEROP_MESSAGE_HEADER, MESSAGE_RESEND);
    await settle(fixture);
    expect(calls[0]).toEqual({ path: DRY_RUN, method: 'POST', body: { action: 'resend', id: '12' } });
    expect(host.querySelector('.ocu-dialog-title')?.textContent?.trim()).toBe(`${STRINGS.interopMessagesResendAction} 12`);
    expect([...host.querySelectorAll('[data-ocu-review] li')].map((item) => item.textContent)).toEqual([line]);
    expect(host.querySelector('.ocu-typed-name-consequence')?.textContent?.trim()).toBe(STRINGS.interopMessageResendConsequence);
    expect(destructive(host).getAttribute('aria-disabled')).toBe('true');
    typeInto(fixture, host, '.ocu-typed-name-field', '12');
    destructive(host).click();
    await settle(fixture);
    expect(calls[1]).toEqual({ path: ACTION, method: 'POST', body: { action: 'resend', id: '12', values: { Reviewed: DIGEST } } });
    expect([...host.querySelectorAll('[data-ocu-outcome] li')].map((item) => item.textContent)).toEqual(['12: resent as 40']);
    expect(events.map((event) => event.kind)).toEqual(['changed']);
  });

  it('puts the refusal of a review on the tab\u2019s banner and opens no dialog', async () => {
    // Mutation (Rule 19): open the dialog on a refusal -> the dialog assertion goes red.
    const { fixture, host, actions, store } = mount([refusal(409, 'INTEROP.PRODUCTION.NOTRUNNING', STRINGS.interopRefusalNotRunning)]);
    actions.run(INTEROP_MESSAGE_HEADER, MESSAGE_RESEND);
    await settle(fixture);
    expect(store.refusal()).toBe(STRINGS.interopRefusalNotRunning);
    expect(host.querySelector('.ocu-dialog-title')).toBeNull();
  });

  it('opens the edit form over the message\u2019s fields on the values they hold, titled and labeled for an edit', async () => {
    // Mutation (Rule 19): open the form before the dry run answers -> the form assertion goes red on a refusal leg; drop the
    // `values` binding -> the prefill goes red.
    const { fixture, host, actions, calls } = mount([formAnswer()]);
    actions.run(INTEROP_MESSAGE_HEADER, MESSAGE_EDIT_RESEND);
    await settle(fixture);
    expect(calls).toEqual([{ path: HEADER_DRY_RUN, method: 'POST', body: { action: 'editresend', id: '12' } }]);
    expect(host.querySelector('.ocu-dialog-title')?.textContent?.trim()).toBe(STRINGS.interopEditResendHeading);
    expect(host.querySelector('[data-interop-test-send]')?.textContent?.trim()).toBe(STRINGS.interopEditResendReview);
    expect((host.querySelector('[data-field="StringValue"] [data-interop-test-input]') as HTMLInputElement).value).toBe('beta');
  });

  it('puts the refusal of the form\u2019s dry run on the banner, with no form', async () => {
    // Mutation (Rule 19): drop the `refused` branch of `onEdit` -> a form opens over nothing and this goes red.
    const { fixture, host, actions, store } = mount([refusal(409, 'INTEROP.EDIT.NOTEDITABLE', STRINGS.interopRefusalEditNotEditable)]);
    actions.run(INTEROP_MESSAGE_HEADER, MESSAGE_EDIT_RESEND);
    await settle(fixture);
    expect(store.refusal()).toBe(STRINGS.interopRefusalEditNotEditable);
    expect(host.querySelector('app-interop-item-test-dialog')).toBeNull();
  });

  it('reviews only the changed fields: a form that changed nothing says so without a request, a change is dry-run, then reviewed and sent with the digest', async () => {
    // Mutation (Rule 19): send every field in place of the changed ones -> the dry-run body goes red; skip the no-change test -> a
    // request is made and the sentence is missing.
    const { fixture, host, actions, calls, events } = mount([formAnswer(), editAnswer(), sentAnswer('12', '12')]);
    actions.run(INTEROP_MESSAGE_HEADER, MESSAGE_EDIT_RESEND);
    await settle(fixture);
    (host.querySelector('[data-interop-test-send]') as HTMLButtonElement).click();
    await settle(fixture);
    expect(host.querySelector('[data-interop-test-reason]')?.textContent?.trim()).toBe(STRINGS.interopRefusalEditNoChange);
    expect(calls).toHaveLength(1);

    typeInto(fixture, host, '[data-field="StringValue"] [data-interop-test-input]', 'edited');
    (host.querySelector('[data-interop-test-send]') as HTMLButtonElement).click();
    await settle(fixture);
    const fields = JSON.stringify({ StringValue: 'edited' });
    expect(calls[1]).toEqual({ path: HEADER_DRY_RUN, method: 'POST', body: { action: 'editresend', id: '12', values: { fields } } });
    // The form gives way to the review: dialogs never stack.
    expect(host.querySelector('app-interop-item-test-dialog')).toBeNull();
    expect(host.querySelector('.ocu-dialog-title')?.textContent?.trim()).toBe(`${STRINGS.interopMessagesEditResendAction} 12`);
    expect([...host.querySelectorAll('[data-ocu-review] li')].map((item) => item.textContent)).toEqual(['- StringValue: beta', '+ StringValue: edited']);
    typeInto(fixture, host, '.ocu-typed-name-field', '12');
    destructive(host).click();
    await settle(fixture);
    expect(calls[2]).toEqual({ path: HEADER_ACTION, method: 'POST', body: { action: 'editresend', id: '12', values: { fields, Reviewed: DIGEST } } });
    expect([...host.querySelectorAll('[data-ocu-outcome] li')].map((item) => item.textContent)).toEqual(['12: resent as 40']);
    expect(events.map((event) => event.kind)).toEqual(['changed']);
  });

  it('keeps a field the instance refused in the form, drawn on the field, and sends nothing', async () => {
    // Mutation (Rule 19): close the form on a refusal -> the form assertion goes red.
    const violation = refusal(422, 'INTEROP.EDIT.VALUE', STRINGS.interopRefusalEditValue, {
      violations: [{ field: 'StringValue', code: 'INTEROP.EDIT.VALUE', reason: STRINGS.interopRefusalEditValue }],
    });
    const { fixture, host, actions, calls } = mount([formAnswer(), violation]);
    actions.run(INTEROP_MESSAGE_HEADER, MESSAGE_EDIT_RESEND);
    await settle(fixture);
    typeInto(fixture, host, '[data-field="StringValue"] [data-interop-test-input]', 'bad');
    (host.querySelector('[data-interop-test-send]') as HTMLButtonElement).click();
    await settle(fixture);
    expect(host.querySelector('app-interop-item-test-dialog')).not.toBeNull();
    expect(host.querySelector('[data-field="StringValue"] [data-interop-test-violation]')?.textContent?.trim()).toBe(STRINGS.interopRefusalEditValue);
    expect(calls.map((call) => call.path)).toEqual([HEADER_DRY_RUN, HEADER_DRY_RUN]);
  });

  it('opens no second dialog over a standing one, and Cancel closes the form without a request', async () => {
    // Mutation (Rule 19): drop the `pending() !== null` test -> the second Resend opens a dry run and this goes red.
    const line = `12 \u00B7 Svc \u2192 Op: ${STRINGS.interopResendVerdictResend}`;
    const { fixture, host, actions, calls } = mount([reviewAnswer([line])]);
    actions.run(INTEROP_MESSAGE_HEADER, MESSAGE_RESEND);
    await settle(fixture);
    actions.run(INTEROP_MESSAGE_HEADER, MESSAGE_EDIT_RESEND);
    await settle(fixture);
    expect(calls).toHaveLength(1);
    const cancel = [...host.querySelectorAll('.ocu-dialog-actions button')].find((button) => button.textContent?.trim() === STRINGS.actionCancel) as HTMLButtonElement;
    cancel.click();
    await settle(fixture);
    expect(host.querySelector('.ocu-dialog-title')).toBeNull();
    expect(calls).toHaveLength(1);
  });
});
