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
import { ScreenActionHandler } from '../../shell/screen-action-handler';
import { stubAccountPreferences } from '../../testing/account-preferences';
import { INTEROP_ITEM_TEST, INTEROP_ITEM_TEST_ACTION, InteropItemTestPage } from './interop-item-test.page';

/**
 * The item Test tab's page (Story 20.6). The detail page that hosts the list is replaced by an empty stand-in, so only this page's own
 * wiring runs: the one action it registers, the dialog it opens over the tab's rows, no dialog on an item that lists none, the
 * request each Send test posts with the item's route id, the answer an applied send leaves in the dialog as text, a refusal kept
 * in the dialog and the change event an applied test publishes. The handler, the stores and the bus are real; only the server's
 * answers are stubbed.
 */

@Component({ selector: 'app-detail-page', template: '' })
class StubDetailPage {}

const TAB = SCREENS.find((screen) => screen.descriptor === INTEROP_ITEM_TEST)!;

const ITEM = ['P.Prod', 'OcuPilotProbeEchoOp'].join('\u0001');

const REQUEST = 'OcuPilotProbe.Interop.TestRequest';

const row = (field: string, extra: Record<string, unknown> = {}): Record<string, unknown> => ({
  Production: 'P.Prod',
  Item: 'OcuPilotProbeEchoOp',
  RequestClass: REQUEST,
  Kind: 'object',
  Field: field,
  Type: '%Library.String',
  Required: false,
  MaxLength: null,
  Values: [],
  Secret: false,
  ...extra,
});

const ROWS = [row('Text', { Required: true, MaxLength: 50 }), row('Password', { Secret: true })];

const SENT: JsonResult<unknown> = {
  kind: 'ok',
  status: 200,
  body: {
    action: 'updated',
    target: { type: 'production-item', scope: 'namespace:USER', id: ITEM },
    readBack: { verdict: 'nothingSent', fields: [], written: [] },
    output: { status: 'done', sessionId: '41', responseClass: 'Ens.StringResponse', lines: ['StringValue: echo:<b>x</b>'], errors: false },
  },
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

/** Mount the page over `rows` on the route that names `ITEM`; each request resolves to the next of `answers`. */
function mount(answers: JsonResult<unknown>[], rows: readonly unknown[] = ROWS) {
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
      { provide: Router, useValue: { url: `/${TAB.route}/${encodeEntityId(ITEM)}` } as unknown as Router },
    ],
  });
  TestBed.overrideComponent(InteropItemTestPage, { remove: { imports: [DetailPage] }, add: { imports: [StubDetailPage] } });
  const store = stores.for(TAB.descriptor, TAB.refreshRates);
  store.applyTick(rows as never[], false, '', new Date());
  const fixture = TestBed.createComponent(InteropItemTestPage);
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  fixture.detectChanges();
  return { fixture, host: fixture.nativeElement as HTMLElement, store, calls, events, actions: TestBed.inject(ScreenActions) };
}

async function open(fixture: ComponentFixture<unknown>, actions: ScreenActions): Promise<void> {
  actions.run(INTEROP_ITEM_TEST, INTEROP_ITEM_TEST_ACTION);
  await settle(fixture);
}

function type(fixture: ComponentFixture<unknown>, host: HTMLElement, field: string, value: string): void {
  const control = host.querySelector(`[data-interop-test-field][data-field="${field}"] [data-interop-test-input]`) as HTMLInputElement;
  control.value = value;
  control.dispatchEvent(new Event('input'));
  fixture.detectChanges();
}

const send = (host: HTMLElement): void => (host.querySelector('[data-interop-test-send]') as HTMLButtonElement).click();

afterEach(() => {
  for (const node of planted.splice(0)) node.remove();
  TestBed.resetTestingModule();
});

describe('the item Test tab page', () => {
  it('declares the tab this page hosts, with Send test as its primary and only row action', () => {
    expect(TAB.primaryAction?.id).toBe(INTEROP_ITEM_TEST_ACTION);
    expect(TAB.rowActions.map((action) => action.id)).toEqual([INTEROP_ITEM_TEST_ACTION]);
    expect(TAB.tab?.position).toBe(7);
  });

  // Mutation (Rule 19): drop this page's `actions.register` of `test` -> the first assertion goes red.
  it('registers Send test, and opens its dialog on the item the route names over the rows the tab lists', async () => {
    const { fixture, host, actions, calls } = mount([]);
    expect(actions.has(INTEROP_ITEM_TEST, INTEROP_ITEM_TEST_ACTION)).toBe(true);
    expect(host.querySelector('app-interop-item-test-dialog')).toBeNull();
    await open(fixture, actions);
    expect(calls).toHaveLength(0);
    expect(host.querySelector('.ocu-dialog-title')?.textContent?.trim()).toBe('Test OcuPilotProbeEchoOp');
    expect([...host.querySelectorAll('[data-interop-test-field]')].map((entry) => entry.getAttribute('data-field'))).toEqual(['Text', 'Password']);
  });

  // Mutation (Rule 19): drop the empty-rows test from `onOpen` -> the dialog opens over nothing and this goes red.
  it('opens no dialog on an item that lists no row, and puts the target-type sentence on the list', async () => {
    const { fixture, host, store, actions } = mount([], []);
    await open(fixture, actions);
    expect(host.querySelector('app-interop-item-test-dialog')).toBeNull();
    expect(store.refusal()).toBe(STRINGS.interopTestRefusalTargetType);
  });

  it('posts the item\'s route id with the class and the fields as JSON text, leaves the dialog open on the answer as text, and publishes the updated event', async () => {
    const { fixture, host, actions, calls, events } = mount([SENT]);
    await open(fixture, actions);
    type(fixture, host, 'Text', 'hello <b>x</b>');
    send(host);
    await settle(fixture);
    expect(calls[0]).toEqual({
      path: '/api/ocupilot/screens/interop.itemtest/action',
      method: 'POST',
      body: JSON.stringify({ action: 'test', id: ITEM, values: { requestClass: REQUEST, fields: JSON.stringify({ Text: 'hello <b>x</b>' }) } }),
    });
    expect(host.querySelector('app-interop-item-test-dialog')).not.toBeNull();
    expect(host.querySelector('[data-interop-test-status]')?.textContent?.trim()).toBe(STRINGS.interopTestDone.replace('<session>', '41').replace('<class>', 'Ens.StringResponse'));
    expect(host.querySelector('[data-interop-test-result] pre')?.textContent).toBe('StringValue: echo:<b>x</b>');
    expect(host.querySelector('[data-interop-test-result] b')).toBeNull();
    expect(events.map((event) => `${event.type}/${event.action}`)).toEqual(['production-item/updated']);
  });

  // Mutation (Rule 19): drop the `violations.set` from `onSend` -> the field leg goes red.
  it('keeps a refusal in the dialog: on the field the instance names, else above the fields, and sends nothing more', async () => {
    const refusal = (code: string, reason: string, violations: unknown[] = []): JsonResult<unknown> => ({
      kind: 'error',
      status: 422,
      code,
      reason,
      detail: { violations },
    } as unknown as JsonResult<unknown>);
    const { fixture, host, actions, calls, events } = mount([refusal('INTEROP.TEST.VALUE', STRINGS.interopTestRefusalValue, [{ field: 'Text', code: 'INTEROP.TEST.VALUE', reason: STRINGS.interopTestRefusalValue }]), refusal('INTEROP.TEST.DISABLED', STRINGS.interopTestRefusalDisabled)]);
    await open(fixture, actions);
    send(host);
    await settle(fixture);
    expect(host.querySelector('[data-interop-test-field][data-field="Text"] [data-interop-test-violation]')?.textContent?.trim()).toBe(STRINGS.interopTestRefusalValue);
    expect(host.querySelector('[data-interop-test-reason]')).toBeNull();
    expect(host.querySelector('[data-interop-test-result]')).toBeNull();
    send(host);
    await settle(fixture);
    expect(host.querySelector('[data-interop-test-reason]')?.textContent?.trim()).toBe(STRINGS.interopTestRefusalDisabled);
    expect(host.querySelector('[data-interop-test-violation]')).toBeNull();
    expect(calls).toHaveLength(2);
    expect(events).toEqual([]);
  });

  // Mutation (Rule 19): drop the `elsewhere` reason from `onSend` -> the dialog shows nothing and this goes red.
  it('says why above the fields when the instance names a refusal on a field the dialog does not draw, such as the class itself', async () => {
    const built: JsonResult<unknown> = {
      kind: 'error',
      status: 422,
      code: 'AGENT.VALIDATION',
      reason: 'One or more values were refused.',
      detail: { violations: [{ field: 'RequestClass', code: 'INTEROP.TEST.REQUEST', reason: STRINGS.interopTestRefusalRequest }] },
    } as unknown as JsonResult<unknown>;
    const { fixture, host, actions } = mount([built]);
    await open(fixture, actions);
    type(fixture, host, 'Text', 'x');
    send(host);
    await settle(fixture);
    expect(host.querySelector('[data-interop-test-reason]')?.textContent?.trim()).toBe(STRINGS.interopTestRefusalRequest);
    expect(host.querySelector('[data-interop-test-violation]')).toBeNull();
    expect(host.querySelector('[data-interop-test-result]')).toBeNull();
  });

  // Mutation (Rule 19): drop `(cancelled)="onClose()"` from the page's template -> the dialog stays and this goes red.
  it('closes on Cancel, sending nothing and publishing nothing, and opens clean again', async () => {
    const { fixture, host, actions, calls, events } = mount([SENT]);
    await open(fixture, actions);
    send(host);
    await settle(fixture);
    const cancel = [...host.querySelectorAll('.ocu-dialog-actions button')].find((button) => button.textContent?.trim() === STRINGS.actionCancel) as HTMLButtonElement;
    cancel.click();
    await settle(fixture);
    expect(host.querySelector('app-interop-item-test-dialog')).toBeNull();
    expect(calls).toHaveLength(1);
    await open(fixture, actions);
    expect(host.querySelector('[data-interop-test-result]')).toBeNull();
    expect(events.map((event) => event.action)).toEqual(['updated']);
  });
});
