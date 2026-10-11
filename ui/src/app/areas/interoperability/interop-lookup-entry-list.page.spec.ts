import { Component } from '@angular/core';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { Router } from '@angular/router';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type ApiRequestInit, type JsonResult } from '../../core/api';
import { ChangeBus, type ChangeEvent } from '../../core/change-bus';
import { encodeEntityId } from '../../core/entity-id';
import { OverlayStack } from '../../core/overlay-stack';
import { ScopeService } from '../../core/scope';
import { ScreenActions } from '../../core/screen-actions';
import { ScreenStores } from '../../core/screen-store';
import { SCREENS } from '../../core/screens.generated';
import { STRINGS } from '../../core/strings';
import { ListPage } from '../../shell/list-page';
import { ScreenActionHandler } from '../../shell/screen-action-handler';
import { stubAccountPreferences } from '../../testing/account-preferences';
import {
  INTEROP_LOOKUP_ENTRY_ADD_ACTION,
  INTEROP_LOOKUP_ENTRY_LIST,
  INTEROP_LOOKUP_ENTRY_SET_ACTION,
  InteropLookupEntryListPage,
} from './interop-lookup-entry-list.page';

/**
 * A lookup table's entries page (Story 20.5). The shared list page is replaced by an empty stand-in, so only this
 * page's own wiring runs: the two actions it registers after the shell's handler, the Add entry dialog that posts to the
 * table the route names, the Set value dialog it opens over the selected row -- a multi-line field, no default line,
 * no dialog over a credential's key -- the request each Set value sends, an empty value included, a refusal kept in the
 * dialog and the change event an applied change publishes. The handler, the stores and the bus are real; only the
 * server's answers are stubbed.
 */

@Component({ selector: 'app-list-page', template: '' })
class StubListPage {}

const LIST = SCREENS.find((screen) => screen.descriptor === INTEROP_LOOKUP_ENTRY_LIST)!;

const SEP = '\u0001';

const TABLE = 'Probe.Table';

const row = (key: string, extra: Record<string, unknown> = {}): Record<string, unknown> => ({ Table: TABLE, Key: key, Value: '', Secret: false, ...extra });

const ROWS = [row('plain', { Value: 'one\ntwo' }), row('blank'), row('apiPassword', { Secret: true })];

const id = (key: string): string => [TABLE, key].join(SEP);

const UPDATED: JsonResult<unknown> = {
  kind: 'ok',
  status: 200,
  body: { action: 'updated', target: { type: 'lookup-entry', scope: 'namespace:USER', id: id('plain') }, readBack: { verdict: 'matches' } },
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

/** Configure the testing module over stubbed answers: each request resolves to the next of `answers`. */
function configure(answers: JsonResult<unknown>[]) {
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
      { provide: Router, useValue: { url: `/${LIST.route}/${encodeEntityId(TABLE)}` } as unknown as Router },
      { provide: ScopeService, useValue: { loaded: () => true, namespace: () => 'USER', subscribe: () => () => {} } as unknown as ScopeService },
    ],
  });
  return { calls, events, stores };
}

/** Mount the page over `ROWS` on the route that names `TABLE`. */
function mount(answers: JsonResult<unknown>[]) {
  const { calls, events, stores } = configure(answers);
  TestBed.overrideComponent(InteropLookupEntryListPage, { remove: { imports: [ListPage] }, add: { imports: [StubListPage] } });
  const store = stores.for(LIST.descriptor, LIST.refreshRates);
  store.applyTick(ROWS, false, '', new Date());
  const fixture = TestBed.createComponent(InteropLookupEntryListPage);
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  fixture.detectChanges();
  return { fixture, host: fixture.nativeElement as HTMLElement, store, calls, events, actions: TestBed.inject(ScreenActions), handler: TestBed.inject(ScreenActionHandler) };
}

async function openSet(fixture: ComponentFixture<unknown>, store: ReturnType<typeof mount>['store'], actions: ScreenActions, rowId: string): Promise<void> {
  store.setSelection([rowId]);
  actions.run(INTEROP_LOOKUP_ENTRY_LIST, INTEROP_LOOKUP_ENTRY_SET_ACTION);
  await settle(fixture);
}

function typeValue(fixture: ComponentFixture<unknown>, host: HTMLElement, value: string): void {
  const field = host.querySelector('[data-interop-setting-value]') as HTMLTextAreaElement;
  field.value = value;
  field.dispatchEvent(new Event('input'));
  fixture.detectChanges();
}

const confirmSet = (host: HTMLElement): void => (host.querySelector('[data-interop-setting-confirm]') as HTMLButtonElement).click();

afterEach(() => {
  for (const node of planted.splice(0)) node.remove();
  TestBed.resetTestingModule();
});

describe('a lookup table\'s entries page', () => {
  it('declares the list this page hosts, with Add entry as its primary action and Set value and Remove as its row actions', () => {
    expect(LIST.primaryAction?.id).toBe(INTEROP_LOOKUP_ENTRY_ADD_ACTION);
    expect(LIST.rowActions.map((action) => action.id)).toEqual([INTEROP_LOOKUP_ENTRY_SET_ACTION, 'remove']);
  });

  // Mutation (Rule 19): drop this page's `actions.register` of `set` or `add` -> the first assertions go red.
  it('registers Add entry and Set value beside the handler\'s Remove, and opens Add entry on the table the route names', async () => {
    const { fixture, host, actions, calls } = mount([]);
    expect(actions.has(INTEROP_LOOKUP_ENTRY_LIST, INTEROP_LOOKUP_ENTRY_ADD_ACTION)).toBe(true);
    expect(actions.has(INTEROP_LOOKUP_ENTRY_LIST, INTEROP_LOOKUP_ENTRY_SET_ACTION)).toBe(true);
    expect(actions.has(INTEROP_LOOKUP_ENTRY_LIST, 'remove')).toBe(true);
    actions.run(INTEROP_LOOKUP_ENTRY_LIST, INTEROP_LOOKUP_ENTRY_ADD_ACTION);
    await settle(fixture);
    expect(calls).toHaveLength(0);
    expect(host.querySelector('.ocu-dialog-title')?.textContent?.trim()).toBe(STRINGS.interopLookupEntryDialogTitle);
    const table = host.querySelector('input[data-interop-lookup-table]') as HTMLInputElement;
    expect(table.value).toBe(TABLE);
    expect(table.readOnly).toBe(true);
  });

  it('posts Add entry\'s key and value to the table the route names, in the namespace the shell is scoped to', async () => {
    const created: JsonResult<unknown> = { kind: 'ok', status: 201, body: { id: id('fresh'), target: { type: 'lookup-entry', scope: 'USER', id: id('fresh') } } };
    const { fixture, host, actions, calls, events } = mount([created]);
    actions.run(INTEROP_LOOKUP_ENTRY_LIST, INTEROP_LOOKUP_ENTRY_ADD_ACTION);
    await settle(fixture);
    const key = host.querySelector('input[data-interop-lookup-key]') as HTMLInputElement;
    key.value = 'fresh';
    key.dispatchEvent(new Event('input'));
    fixture.detectChanges();
    (host.querySelector('[data-interop-lookup-confirm]') as HTMLButtonElement).click();
    await settle(fixture);
    expect(calls.map((call) => [call.path, call.scope, JSON.parse(call.body)])).toEqual([
      ['/api/ocupilot/interop/lookup-entries', 'USER', { Table: TABLE, Key: 'fresh', Value: '' }],
    ]);
    expect(host.querySelector('app-interop-lookup-entry-dialog')).toBeNull();
    expect(events.map((event) => [event.type, event.id, event.action, event.tool])).toEqual([['lookup-entry', id('fresh'), 'created', 'interop.lookupentries.add']]);
  });

  it('opens Set value over the selected row only: a multi-line field with the current value, no default line, and the in-effect-at-once sentence', async () => {
    const { fixture, host, store, actions, calls } = mount([]);
    actions.run(INTEROP_LOOKUP_ENTRY_LIST, INTEROP_LOOKUP_ENTRY_SET_ACTION);
    await settle(fixture);
    expect(host.querySelector('app-interop-item-setting-dialog')).toBeNull();
    await openSet(fixture, store, actions, id('plain'));
    expect(calls).toHaveLength(0);
    expect(host.querySelector('.ocu-dialog-title')?.textContent?.trim()).toBe(STRINGS.interopLookupSetDialogTitle);
    expect(host.querySelector('[data-interop-setting-consequence]')?.textContent?.trim()).toBe(STRINGS.interopLookupEntryHelp);
    expect(host.querySelector('[data-interop-setting-default]')).toBeNull();
    expect(host.querySelector('label')?.textContent?.trim()).toBe(STRINGS.errorLogColumnValue);
    const field = host.querySelector('[data-interop-setting-value]') as HTMLTextAreaElement;
    expect(field.tagName).toBe('TEXTAREA');
    expect(field.value).toBe('one\ntwo');
  });

  // Mutation (Rule 19): drop the secret test from `onOpenSet` -> this goes red.
  it('opens no dialog over a credential\'s key and puts its sentence on the list', async () => {
    const { fixture, host, store, actions } = mount([]);
    await openSet(fixture, store, actions, id('apiPassword'));
    expect(host.querySelector('app-interop-item-setting-dialog')).toBeNull();
    expect(store.refusal()).toBe(STRINGS.interopLookupRefusalSecret);
  });

  it('sends the typed value as the one value, closes on an applied change and publishes the updated event', async () => {
    const { fixture, host, store, actions, calls, events } = mount([UPDATED]);
    await openSet(fixture, store, actions, id('plain'));
    typeValue(fixture, host, 'three\nfour');
    confirmSet(host);
    await settle(fixture);
    expect(calls[0]).toEqual({
      path: '/api/ocupilot/screens/interop.lookupentries/action',
      method: 'POST',
      scope: calls[0].scope,
      body: JSON.stringify({ action: 'set', id: id('plain'), values: { Value: 'three\nfour' } }),
    });
    expect(host.querySelector('app-interop-item-setting-dialog')).toBeNull();
    expect(events.map((event) => `${event.type}/${event.action}`)).toEqual(['lookup-entry/updated']);
    expect(store.refusal()).toBe('');
  });

  it('sends an empty value, which sets the entry to nothing and keeps it', async () => {
    const { fixture, host, store, actions, calls } = mount([UPDATED]);
    await openSet(fixture, store, actions, id('plain'));
    typeValue(fixture, host, '');
    confirmSet(host);
    await settle(fixture);
    expect(JSON.parse(calls[0].body)).toEqual({ action: 'set', id: id('plain'), values: { Value: '' } });
  });

  // Mutation (Rule 19): drop `(cancelled)="onCloseSet()"` from the page's template -> the dialog stays and this goes red.
  it('closes on Cancel, sending nothing and publishing nothing', async () => {
    const { fixture, host, store, actions, calls, events } = mount([]);
    await openSet(fixture, store, actions, id('plain'));
    const cancel = [...host.querySelectorAll('.ocu-dialog-actions button')].find((button) => button.textContent?.trim() === STRINGS.actionCancel) as HTMLButtonElement;
    cancel.click();
    await settle(fixture);
    expect(host.querySelector('app-interop-item-setting-dialog')).toBeNull();
    expect(calls).toHaveLength(0);
    expect(events).toEqual([]);
  });

  it('keeps a refusal on the value in the dialog as the instance\'s sentence, and publishes nothing', async () => {
    const { fixture, host, store, actions, events } = mount([
      {
        kind: 'error',
        status: 422,
        code: 'INTEROP.LOOKUP.VALUE',
        reason: STRINGS.interopLookupRefusalValue,
        detail: { violations: [{ field: 'Value', code: 'INTEROP.LOOKUP.VALUE', reason: STRINGS.interopLookupRefusalValue }] },
      } as JsonResult<unknown>,
    ]);
    await openSet(fixture, store, actions, id('plain'));
    typeValue(fixture, host, 'too long');
    confirmSet(host);
    await settle(fixture);
    expect(host.querySelector('[data-interop-setting-violation]')?.textContent?.trim()).toBe(STRINGS.interopLookupRefusalValue);
    expect(events).toEqual([]);
    expect(store.refusal()).toBe('');
  });

  it('draws a refusal that names no field above the value', async () => {
    const { fixture, host, store, actions } = mount([
      { kind: 'error', status: 409, code: 'INTEROP.LOOKUP.SAME', reason: STRINGS.interopLookupRefusalSame } as JsonResult<unknown>,
    ]);
    await openSet(fixture, store, actions, id('plain'));
    confirmSet(host);
    await settle(fixture);
    expect(host.querySelector('[data-interop-setting-reason]')?.textContent?.trim()).toBe(STRINGS.interopLookupRefusalSame);
  });

  it('types the entry\'s key before Remove, states that the last entry takes the table too, and sends the whole row key', async () => {
    // Mutation (Rule 19): drop the list's TYPED_NAME_ROWS entry -> the dialog asks for the joined row key and the name assertion
    // goes red; drop its DESTRUCTIVE_CONSEQUENCES entry -> Remove registers no handler and the first assertion goes red.
    const removed: JsonResult<unknown> = { kind: 'ok', status: 200, body: { action: 'deleted', target: { type: 'lookup-entry', scope: 'USER', id: id('plain') } } };
    const { fixture, store, actions, handler, calls, events } = mount([removed]);
    expect(actions.has(INTEROP_LOOKUP_ENTRY_LIST, 'remove')).toBe(true);
    store.setSelection([id('plain')]);
    actions.run(INTEROP_LOOKUP_ENTRY_LIST, 'remove');
    await settle(fixture);
    expect(handler.pending()?.kind).toBe('typed-name');
    expect(handler.pending()?.name).toBe('plain');
    expect(handler.pending()?.target).toBe(id('plain'));
    expect(handler.pending()?.consequence).toBe(STRINGS.interopLookupRemoveConsequence);
    expect(calls).toHaveLength(0);
    handler.confirmPending();
    await settle(fixture);
    expect(calls).toHaveLength(1);
    expect(calls[0].path).toBe(`/api/ocupilot/screens/${LIST.toolIdentifier}/action`);
    expect(JSON.parse(calls[0].body)).toEqual({ action: 'remove', id: id('plain') });
    expect(events.map((event) => `${event.action} ${event.type} ${event.id}`)).toEqual([`deleted lookup-entry ${id('plain')}`]);
  });

  // Mutation (Rule 19): drop the list's entry from `UNDRAWN_ACTIONS` -> the handler registers Set value itself and this goes red.
  it('leaves Add entry and Set value to this page: the handler alone registers Remove only', () => {
    configure([]);
    const actions = TestBed.inject(ScreenActions);
    TestBed.inject(ScreenActionHandler);
    expect(actions.has(INTEROP_LOOKUP_ENTRY_LIST, 'remove')).toBe(true);
    expect(actions.has(INTEROP_LOOKUP_ENTRY_LIST, INTEROP_LOOKUP_ENTRY_SET_ACTION)).toBe(false);
    expect(actions.has(INTEROP_LOOKUP_ENTRY_LIST, INTEROP_LOOKUP_ENTRY_ADD_ACTION)).toBe(false);
  });

  it('opens neither dialog over the other', async () => {
    const { fixture, host, store, actions } = mount([]);
    await openSet(fixture, store, actions, id('plain'));
    actions.run(INTEROP_LOOKUP_ENTRY_LIST, INTEROP_LOOKUP_ENTRY_ADD_ACTION);
    await settle(fixture);
    expect(host.querySelector('app-interop-lookup-entry-dialog')).toBeNull();
    expect(host.querySelector('app-interop-item-setting-dialog')).not.toBeNull();
  });
});
