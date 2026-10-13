import { Component } from '@angular/core';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type ApiRequestInit, type JsonResult } from '../../core/api';
import { ChangeBus, type ChangeEvent } from '../../core/change-bus';
import { OverlayStack } from '../../core/overlay-stack';
import { ScreenActions, actionLabel } from '../../core/screen-actions';
import { ScreenStores } from '../../core/screen-store';
import { SCREENS } from '../../core/screens.generated';
import { STRINGS } from '../../core/strings';
import { ListPage } from '../../shell/list-page';
import { ScreenActionHandler } from '../../shell/screen-action-handler';
import { stubAccountPreferences } from '../../testing/account-preferences';
import { INTEROP_TRANSFORM_LIST, INTEROP_TRANSFORM_TEST_ACTION, InteropTransformListPage } from './interop-transform-list.page';

/**
 * The Data transformations page (Story 20.27). The shared list page is replaced by an empty stand-in, so only this page's own wiring runs: the
 * one action it registers, the dialog it opens over the selected row, the request each Run sends with the row's id and the message as its one
 * value -- an empty one included, which the instance judges -- the answer an applied run leaves in the dialog as text, a refusal kept in the
 * dialog (the message's on the Input, any other above it), a stale answer ignored and the change event an applied run publishes. The handler,
 * the stores and the bus are real; only the server's answers are stubbed.
 */

@Component({ selector: 'app-list-page', template: '' })
class StubListPage {}

const LIST = SCREENS.find((screen) => screen.descriptor === INTEROP_TRANSFORM_LIST)!;

const XML = 'OcuProbeDtl.Xml.cls';

const HL7 = 'OcuProbeDtl.Hl7.cls';

const ROWS = [
  { Name: XML, Modified: '2026-10-13 09:00:00' },
  { Name: HL7, Modified: '2026-10-13 09:01:00' },
];

const ANSWER = {
  status: 'done',
  sourceClass: 'Ens.StringRequest',
  targetClass: 'Ens.StringResponse',
  lines: ['<StringResponse>', '  <StringValue>out:<b>x</b></StringValue>', '</StringResponse>'],
  console: ['probe-device-line'],
  errors: false,
};

const RAN: JsonResult<unknown> = {
  kind: 'ok',
  status: 200,
  body: {
    action: 'updated',
    target: { type: 'class', scope: 'namespace:USER', id: XML },
    readBack: { verdict: 'nothingSent', fields: [], written: [] },
    output: ANSWER,
  },
};

const refusal = (status: number, code: string, reason: string, violations: unknown[] = []): JsonResult<unknown> =>
  ({ kind: 'error', status, code, reason, detail: { violations } }) as unknown as JsonResult<unknown>;

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

/** Mount the page over `ROWS`; each request resolves to the next of `answers`. */
function mount(answers: (JsonResult<unknown> | Promise<JsonResult<unknown>>)[]) {
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
  TestBed.overrideComponent(InteropTransformListPage, { remove: { imports: [ListPage] }, add: { imports: [StubListPage] } });
  const store = stores.for(LIST.descriptor, LIST.refreshRates);
  store.applyTick(ROWS, false, '', new Date());
  const fixture = TestBed.createComponent(InteropTransformListPage);
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  fixture.detectChanges();
  return { fixture, host: fixture.nativeElement as HTMLElement, store, calls, events, actions: TestBed.inject(ScreenActions), handler: TestBed.inject(ScreenActionHandler) };
}

async function open(fixture: ComponentFixture<unknown>, store: ReturnType<typeof mount>['store'], actions: ScreenActions, rowId: string): Promise<void> {
  store.setSelection([rowId]);
  actions.run(INTEROP_TRANSFORM_LIST, INTEROP_TRANSFORM_TEST_ACTION);
  await settle(fixture);
}

function type(fixture: ComponentFixture<unknown>, host: HTMLElement, value: string): void {
  const field = host.querySelector('[data-interop-transform-input]') as HTMLTextAreaElement;
  field.value = value;
  field.dispatchEvent(new Event('input'));
  fixture.detectChanges();
}

const run = (host: HTMLElement): void => (host.querySelector('[data-interop-transform-run]') as HTMLButtonElement).click();

afterEach(() => {
  for (const node of planted.splice(0)) node.remove();
  TestBed.resetTestingModule();
});

describe('the Data transformations page', () => {
  it('declares Test as its one row action, labelled Test, and draws it nowhere itself', () => {
    expect(LIST.rowActions.map((action) => action.id)).toEqual([INTEROP_TRANSFORM_TEST_ACTION]);
    expect(LIST.primaryAction?.id ?? '').toBe('');
    expect(actionLabel(INTEROP_TRANSFORM_LIST, INTEROP_TRANSFORM_TEST_ACTION)).toBe(STRINGS.serverFlagTest);
    expect(LIST.table?.emptyNextKey).toBe('');
    expect(LIST.table?.emptyAgentKey).toBe('interopTransformsEmptyAgent');
  });

  // Mutation (Rule 19): drop this page's `actions.register` of `test` -> the first assertion goes red.
  it('registers Test beside the handler\'s construction, and opens its dialog over the selected row only', async () => {
    const { fixture, host, store, actions, calls } = mount([]);
    expect(actions.has(INTEROP_TRANSFORM_LIST, INTEROP_TRANSFORM_TEST_ACTION)).toBe(true);
    actions.run(INTEROP_TRANSFORM_LIST, INTEROP_TRANSFORM_TEST_ACTION);
    await settle(fixture);
    expect(host.querySelector('app-interop-transform-test-dialog'), 'with no selection nothing opens').toBeNull();
    await open(fixture, store, actions, 'Not.A.Row.cls');
    expect(host.querySelector('app-interop-transform-test-dialog'), 'a key that names no row opens nothing').toBeNull();
    await open(fixture, store, actions, HL7);
    expect(calls).toHaveLength(0);
    expect(host.querySelector('.ocu-dialog-title')?.textContent?.trim()).toBe(`Test ${HL7}`);
    expect(host.querySelector('[data-interop-transform-result]')).toBeNull();
  });

  it('posts the row\'s id with the message as its one value, leaves the dialog open on the answer as text, and publishes the updated event', async () => {
    const { fixture, host, store, actions, calls, events } = mount([RAN]);
    await open(fixture, store, actions, XML);
    type(fixture, host, '<StringRequest><StringValue>x</StringValue></StringRequest>');
    run(host);
    await settle(fixture);
    expect(calls[0]).toEqual({
      path: '/api/ocupilot/screens/interop.transforms/action',
      method: 'POST',
      body: JSON.stringify({ action: 'test', id: XML, values: { content: '<StringRequest><StringValue>x</StringValue></StringRequest>' } }),
    });
    expect(host.querySelector('app-interop-transform-test-dialog')).not.toBeNull();
    expect(host.querySelector('[data-interop-transform-status]')?.textContent?.trim()).toBe(STRINGS.interopTransformDone);
    expect(host.querySelector('[data-interop-transform-source]')?.textContent?.trim()).toBe(`${STRINGS.interopTransformSourceClass}Ens.StringRequest`);
    expect(host.querySelector('[data-interop-transform-lines] pre')?.textContent).toBe(ANSWER.lines.join('\n'));
    expect(host.querySelector('[data-interop-transform-console] pre')?.textContent).toBe('probe-device-line');
    expect(host.querySelector('[data-interop-transform-result] b')).toBeNull();
    expect(events.map((event) => `${event.type}/${event.action}`)).toEqual(['class/updated']);
    expect(store.refusal()).toBe('');
  });

  it('sends an empty message too, which the instance refuses on the Input', async () => {
    const reason = STRINGS.interopTransformRefusalContent;
    const { fixture, host, store, actions, calls, events } = mount([refusal(422, 'AGENT.VALIDATION', reason, [{ field: 'content', code: 'INTEROP.TRANSFORM.CONTENT', reason }])]);
    await open(fixture, store, actions, XML);
    run(host);
    await settle(fixture);
    expect(JSON.parse(calls[0].body)).toEqual({ action: 'test', id: XML, values: { content: '' } });
    expect(host.querySelector('[data-interop-transform-violation]')?.textContent?.trim()).toBe(reason);
    expect(host.querySelector('[data-interop-transform-reason]')).toBeNull();
    expect(host.querySelector('[data-interop-transform-result]')).toBeNull();
    expect(events).toEqual([]);
    expect(store.refusal(), 'the list\'s banner stays clear').toBe('');
  });

  // Mutation (Rule 19): put every refusal on the Input -> the second leg goes red.
  it('draws any other refusal above the Input, and clears a refusal on the next run', async () => {
    const { fixture, host, store, actions, calls } = mount([refusal(409, 'INTEROP.TRANSFORM.SOURCEFORMAT', STRINGS.interopTransformRefusalSourceFormat), RAN]);
    await open(fixture, store, actions, XML);
    type(fixture, host, 'x');
    run(host);
    await settle(fixture);
    expect(host.querySelector('[data-interop-transform-reason]')?.textContent?.trim()).toBe(STRINGS.interopTransformRefusalSourceFormat);
    expect(host.querySelector('[data-interop-transform-violation]')).toBeNull();
    expect(host.querySelector('[data-interop-transform-result]')).toBeNull();
    run(host);
    await settle(fixture);
    expect(calls).toHaveLength(2);
    expect(host.querySelector('[data-interop-transform-reason]')).toBeNull();
    expect(host.querySelector('[data-interop-transform-result]')).not.toBeNull();
  });

  it('clears the result of a run whose next run is refused', async () => {
    const { fixture, host, store, actions } = mount([RAN, refusal(409, 'INTEROP.TRANSFORM.TARGETFORMAT', STRINGS.interopTransformRefusalTargetFormat)]);
    await open(fixture, store, actions, XML);
    type(fixture, host, 'x');
    run(host);
    await settle(fixture);
    expect(host.querySelector('[data-interop-transform-result]')).not.toBeNull();
    run(host);
    await settle(fixture);
    expect(host.querySelector('[data-interop-transform-result]')).toBeNull();
    expect(host.querySelector('[data-interop-transform-reason]')?.textContent?.trim()).toBe(STRINGS.interopTransformRefusalTargetFormat);
  });

  // Mutation (Rule 19): drop the `this.target() !== target` guard from `onRun` -> the answer lands in the next dialog and this goes red.
  it('ignores an answer that arrives after its dialog was canceled, or reopened on another row', async () => {
    let finish: (value: JsonResult<unknown>) => void = () => undefined;
    const pending = new Promise<JsonResult<unknown>>((resolve) => {
      finish = resolve;
    });
    const { fixture, host, store, actions, events } = mount([pending]);
    await open(fixture, store, actions, XML);
    type(fixture, host, 'x');
    run(host);
    await settle(fixture);
    const cancel = [...host.querySelectorAll('.ocu-dialog-actions button')].find((button) => button.textContent?.trim() === STRINGS.actionCancel) as HTMLButtonElement;
    cancel.click();
    await settle(fixture);
    expect(host.querySelector('app-interop-transform-test-dialog')).toBeNull();
    await open(fixture, store, actions, HL7);
    expect(host.querySelector('.ocu-dialog-title')?.textContent?.trim()).toBe(`Test ${HL7}`);
    finish(RAN);
    await settle(fixture);
    expect(host.querySelector('[data-interop-transform-result]'), 'the first dialog\'s answer is not the second\'s').toBeNull();
    expect(host.querySelector('[data-interop-transform-run]')?.getAttribute('aria-disabled')).toBeNull();
    expect(events.map((event) => event.action), 'the run itself was applied and is published').toEqual(['updated']);
  });

  it('reads an answer that is no transformation answer as no result', async () => {
    const odd: JsonResult<unknown> = { kind: 'ok', status: 200, body: { action: 'updated', target: { type: 'class', scope: 'namespace:USER', id: XML }, output: { status: 'done', lines: ['x'] } } };
    const { fixture, host, store, actions } = mount([odd]);
    await open(fixture, store, actions, XML);
    type(fixture, host, 'x');
    run(host);
    await settle(fixture);
    expect(host.querySelector('app-interop-transform-test-dialog')).not.toBeNull();
    expect(host.querySelector('[data-interop-transform-result]')).toBeNull();
  });

  // Mutation (Rule 19): drop `(cancelled)="onClose()"` from the page's template -> the dialog stays and this goes red.
  it('closes on Cancel, sending nothing more and opening clean again', async () => {
    const { fixture, host, store, actions, calls } = mount([RAN]);
    await open(fixture, store, actions, XML);
    type(fixture, host, 'x');
    run(host);
    await settle(fixture);
    const cancel = [...host.querySelectorAll('.ocu-dialog-actions button')].find((button) => button.textContent?.trim() === STRINGS.actionCancel) as HTMLButtonElement;
    cancel.click();
    await settle(fixture);
    expect(host.querySelector('app-interop-transform-test-dialog')).toBeNull();
    expect(calls).toHaveLength(1);
    await open(fixture, store, actions, XML);
    expect(host.querySelector('[data-interop-transform-result]')).toBeNull();
    expect((host.querySelector('[data-interop-transform-input]') as HTMLTextAreaElement).value).toBe('');
  });
});
