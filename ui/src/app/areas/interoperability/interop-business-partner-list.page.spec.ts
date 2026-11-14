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
import {
  INTEROP_BUSINESS_PARTNER_LIST,
  INTEROP_PARTNER_ADD_ACTION,
  INTEROP_PARTNER_EDIT_ACTION,
  InteropBusinessPartnerListPage,
} from './interop-business-partner-list.page';
import { INTEROP_PARTNER_VALUE_FIELDS } from './interop-business-partner.store';

/**
 * The Business partners page (Story 20.26). The shared list page is replaced by an empty stand-in, so only this page's own wiring
 * runs: the two actions it registers after the shell's handler, the New business partner dialog that posts to the namespace the
 * shell is scoped to, the Edit dialog it opens over the selected row with the name read-only, the request each Edit sends -- all
 * thirteen values, an empty one included, and never the name -- a refusal kept in the dialog, the change event an applied change
 * publishes, and the Remove the handler's construction registers, which types the partner's name. The handler, the stores and the
 * bus are real; only the server's answers are stubbed.
 */

@Component({ selector: 'app-list-page', template: '' })
class StubListPage {}

const LIST = SCREENS.find((screen) => screen.descriptor === INTEROP_BUSINESS_PARTNER_LIST)!;

const row = (name: string, extra: Record<string, unknown> = {}): Record<string, unknown> => ({
  Name: name,
  Description: '',
  PrimaryContact: '',
  PrimaryTitle: '',
  PrimaryEmail: '',
  PrimaryPhone: '',
  PrimaryMobile: '',
  PrimaryNotes: '',
  AlternativeContact: '',
  AlternativeTitle: '',
  AlternativeEmail: '',
  AlternativePhone: '',
  AlternativeMobile: '',
  AlternativeNotes: '',
  ...extra,
});

const ROWS = [row('Acme', { Description: 'A supplier', PrimaryContact: 'Pat', PrimaryPhone: '555-0100', AlternativeNotes: 'a\nb' }), row('Bare')];

const UPDATED: JsonResult<unknown> = {
  kind: 'ok',
  status: 200,
  body: { action: 'updated', target: { type: 'business-partner', scope: 'namespace:USER', id: 'Acme' }, readBack: { verdict: 'matches' } },
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
      { provide: ScopeService, useValue: { loaded: () => true, namespace: () => 'USER', subscribe: () => () => {} } as unknown as ScopeService },
    ],
  });
  return { calls, events, stores };
}

/** Mount the page over `ROWS`. */
function mount(answers: JsonResult<unknown>[]) {
  const { calls, events, stores } = configure(answers);
  TestBed.overrideComponent(InteropBusinessPartnerListPage, { remove: { imports: [ListPage] }, add: { imports: [StubListPage] } });
  const store = stores.for(LIST.descriptor, LIST.refreshRates);
  store.applyTick(ROWS, false, '', new Date());
  const fixture = TestBed.createComponent(InteropBusinessPartnerListPage);
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  fixture.detectChanges();
  return { fixture, host: fixture.nativeElement as HTMLElement, store, calls, events, actions: TestBed.inject(ScreenActions), handler: TestBed.inject(ScreenActionHandler) };
}

async function openEdit(fixture: ComponentFixture<unknown>, store: ReturnType<typeof mount>['store'], actions: ScreenActions, name: string): Promise<void> {
  store.setSelection([name]);
  actions.run(INTEROP_BUSINESS_PARTNER_LIST, INTEROP_PARTNER_EDIT_ACTION);
  await settle(fixture);
}

function typeInto(fixture: ComponentFixture<unknown>, host: HTMLElement, name: string, value: string): void {
  const control = host.querySelector(`[data-interop-partner-field="${name}"]`) as HTMLInputElement | HTMLTextAreaElement;
  control.value = value;
  control.dispatchEvent(new Event('input'));
  fixture.detectChanges();
}

const confirmDialog = (host: HTMLElement): void => (host.querySelector('[data-interop-partner-confirm]') as HTMLButtonElement).click();

afterEach(() => {
  for (const node of planted.splice(0)) node.remove();
  TestBed.resetTestingModule();
});

describe('the Business partners page', () => {
  it('declares the list this page hosts, with New business partner as its primary action and Edit and Remove as its row actions', () => {
    expect(LIST.primaryAction?.id).toBe(INTEROP_PARTNER_ADD_ACTION);
    expect(LIST.rowActions.map((action) => action.id)).toEqual([INTEROP_PARTNER_EDIT_ACTION, 'remove']);
  });

  // Mutation (Rule 19): drop this page's `actions.register` of `edit` or `add` -> the first assertions go red.
  it('registers New business partner and Edit beside the handler\'s Remove, and opens New business partner for a new partner', async () => {
    const { fixture, host, actions, calls } = mount([]);
    expect(actions.has(INTEROP_BUSINESS_PARTNER_LIST, INTEROP_PARTNER_ADD_ACTION)).toBe(true);
    expect(actions.has(INTEROP_BUSINESS_PARTNER_LIST, INTEROP_PARTNER_EDIT_ACTION)).toBe(true);
    expect(actions.has(INTEROP_BUSINESS_PARTNER_LIST, 'remove')).toBe(true);
    actions.run(INTEROP_BUSINESS_PARTNER_LIST, INTEROP_PARTNER_ADD_ACTION);
    await settle(fixture);
    expect(calls).toHaveLength(0);
    expect(host.querySelector('.ocu-dialog-title')?.textContent?.trim()).toBe(STRINGS.interopPartnerAddAction);
    expect((host.querySelector('[data-interop-partner-field="Name"]') as HTMLInputElement).readOnly).toBe(false);
  });

  it('posts New business partner\'s fields in the namespace the shell is scoped to and closes, publishing the created event', async () => {
    const created: JsonResult<unknown> = { kind: 'ok', status: 201, body: { id: 'Fresh', target: { type: 'business-partner', scope: 'USER', id: 'Fresh' } } };
    const { fixture, host, actions, calls, events } = mount([created]);
    actions.run(INTEROP_BUSINESS_PARTNER_LIST, INTEROP_PARTNER_ADD_ACTION);
    await settle(fixture);
    typeInto(fixture, host, 'Name', 'Fresh');
    confirmDialog(host);
    await settle(fixture);
    expect(calls.map((call) => [call.path, call.scope, (JSON.parse(call.body) as Record<string, string>)['Name']])).toEqual([['/api/ocupilot/interop/business-partners', 'USER', 'Fresh']]);
    expect(host.querySelector('app-interop-business-partner-dialog')).toBeNull();
    expect(events.map((event) => [event.type, event.id, event.action, event.tool])).toEqual([['business-partner', 'Fresh', 'created', 'interop.businesspartners.add']]);
  });

  it('opens Edit over the selected row only, with its name read-only and the values its row reported', async () => {
    const { fixture, host, store, actions, calls } = mount([]);
    actions.run(INTEROP_BUSINESS_PARTNER_LIST, INTEROP_PARTNER_EDIT_ACTION);
    await settle(fixture);
    expect(host.querySelector('app-interop-business-partner-dialog')).toBeNull();
    await openEdit(fixture, store, actions, 'Acme');
    expect(calls).toHaveLength(0);
    expect(host.querySelector('.ocu-dialog-title')?.textContent?.trim()).toBe(STRINGS.interopPartnerEditTitle.replace('<name>', 'Acme'));
    expect(host.querySelector('[data-interop-partner-rename-note]')?.textContent?.trim()).toBe(STRINGS.interopPartnerRenameNote);
    const name = host.querySelector('[data-interop-partner-field="Name"]') as HTMLInputElement;
    expect(name.value).toBe('Acme');
    expect(name.readOnly).toBe(true);
    expect((host.querySelector('[data-interop-partner-field="Description"]') as HTMLTextAreaElement).value).toBe('A supplier');
    expect((host.querySelector('[data-interop-partner-field="PrimaryPhone"]') as HTMLInputElement).value).toBe('555-0100');
    expect((host.querySelector('[data-interop-partner-field="AlternativeNotes"]') as HTMLTextAreaElement).value).toBe('a\nb');
  });

  it('sends all thirteen values and never the name, an emptied one included, closes on an applied change and publishes the updated event', async () => {
    // Mutation (Rule 19): drop `PrimaryPhone` from the values the Edit sends -> the request lacks it and this goes red.
    const { fixture, host, store, actions, calls, events } = mount([UPDATED]);
    await openEdit(fixture, store, actions, 'Acme');
    typeInto(fixture, host, 'PrimaryPhone', '');
    typeInto(fixture, host, 'AlternativeTitle', 'Lead');
    confirmDialog(host);
    await settle(fixture);
    expect(calls).toHaveLength(1);
    expect(calls[0].path).toBe(`/api/ocupilot/screens/${LIST.toolIdentifier}/action`);
    const sent = JSON.parse(calls[0].body) as { action: string; id: string; values: Record<string, string> };
    expect([sent.action, sent.id]).toEqual(['edit', 'Acme']);
    expect(Object.keys(sent.values).sort()).toEqual([...INTEROP_PARTNER_VALUE_FIELDS].sort());
    expect(sent.values['PrimaryPhone']).toBe('');
    expect(sent.values['AlternativeTitle']).toBe('Lead');
    expect(sent.values['Description']).toBe('A supplier');
    expect(host.querySelector('app-interop-business-partner-dialog')).toBeNull();
    expect(events.map((event) => `${event.type}/${event.action}`)).toEqual(['business-partner/updated']);
  });

  // Mutation (Rule 19): drop `(cancelled)="onCloseEdit()"` from the page's template -> the dialog stays and this goes red.
  it('closes on Cancel, sending nothing and publishing nothing', async () => {
    const { fixture, host, store, actions, calls, events } = mount([]);
    await openEdit(fixture, store, actions, 'Acme');
    const cancel = [...host.querySelectorAll('.ocu-dialog-actions button')].find((button) => button.textContent?.trim() === STRINGS.actionCancel) as HTMLButtonElement;
    cancel.click();
    await settle(fixture);
    expect(host.querySelector('app-interop-business-partner-dialog')).toBeNull();
    expect(calls).toHaveLength(0);
    expect(events).toEqual([]);
  });

  it('keeps a refusal on a field in the dialog as the instance\'s sentence, and one that names none above the fields, publishing nothing', async () => {
    const { fixture, host, store, actions, events } = mount([
      {
        kind: 'error',
        status: 422,
        code: 'INTEROP.PARTNER.LENGTH',
        reason: STRINGS.interopPartnerRefusalLength,
        detail: { violations: [{ field: 'PrimaryPhone', code: 'INTEROP.PARTNER.LENGTH', reason: STRINGS.interopPartnerRefusalLength }] },
      } as JsonResult<unknown>,
      { kind: 'error', status: 409, code: 'INTEROP.PARTNER.SOURCECONTROL', reason: STRINGS.interopPartnerRefusalSourceControl } as JsonResult<unknown>,
    ]);
    await openEdit(fixture, store, actions, 'Acme');
    typeInto(fixture, host, 'PrimaryPhone', 'x'.repeat(51));
    confirmDialog(host);
    await settle(fixture);
    expect(host.querySelector('[data-interop-partner-violation="PrimaryPhone"]')?.textContent?.trim()).toBe(STRINGS.interopPartnerRefusalLength);
    expect(host.querySelector('[data-interop-partner-reason]')).toBeNull();
    confirmDialog(host);
    await settle(fixture);
    expect(host.querySelector('[data-interop-partner-violation]')).toBeNull();
    expect(host.querySelector('[data-interop-partner-reason]')?.textContent?.trim()).toBe(STRINGS.interopPartnerRefusalSourceControl);
    expect(events).toEqual([]);
    expect(store.refusal()).toBe('');
  });

  it('types the partner\'s name before Remove, states that it cannot be restored, and sends the row key', async () => {
    // Mutation (Rule 19): drop the list's TYPED_NAME_ROWS entry -> the dialog asks for no name and the name assertion goes red; drop its
    // DESTRUCTIVE_CONSEQUENCES entry -> the consequence assertion goes red.
    const removed: JsonResult<unknown> = { kind: 'ok', status: 200, body: { action: 'deleted', target: { type: 'business-partner', scope: 'USER', id: 'Acme' } } };
    const { fixture, store, actions, handler, calls, events } = mount([removed]);
    store.setSelection(['Acme']);
    actions.run(INTEROP_BUSINESS_PARTNER_LIST, 'remove');
    await settle(fixture);
    expect(handler.pending()?.kind).toBe('typed-name');
    expect(handler.pending()?.name).toBe('Acme');
    expect(handler.pending()?.target).toBe('Acme');
    expect(handler.pending()?.consequence).toBe(STRINGS.interopPartnerRemoveConsequence);
    expect(calls).toHaveLength(0);
    handler.confirmPending();
    await settle(fixture);
    expect(calls).toHaveLength(1);
    expect(JSON.parse(calls[0].body)).toEqual({ action: 'remove', id: 'Acme' });
    expect(events.map((event) => `${event.action} ${event.type} ${event.id}`)).toEqual(['deleted business-partner Acme']);
  });

  // Mutation (Rule 19): drop the list's entry from `UNDRAWN_ACTIONS` -> the handler registers Edit itself and this goes red.
  it('leaves New business partner and Edit to this page: the handler alone registers Remove only', () => {
    configure([]);
    const actions = TestBed.inject(ScreenActions);
    TestBed.inject(ScreenActionHandler);
    expect(actions.has(INTEROP_BUSINESS_PARTNER_LIST, 'remove')).toBe(true);
    expect(actions.has(INTEROP_BUSINESS_PARTNER_LIST, INTEROP_PARTNER_EDIT_ACTION)).toBe(false);
    expect(actions.has(INTEROP_BUSINESS_PARTNER_LIST, INTEROP_PARTNER_ADD_ACTION)).toBe(false);
  });

  it('opens neither dialog over the other', async () => {
    const { fixture, host, store, actions } = mount([]);
    await openEdit(fixture, store, actions, 'Acme');
    actions.run(INTEROP_BUSINESS_PARTNER_LIST, INTEROP_PARTNER_ADD_ACTION);
    await settle(fixture);
    expect(host.querySelectorAll('app-interop-business-partner-dialog')).toHaveLength(1);
    expect(host.querySelector('.ocu-dialog-title')?.textContent?.trim()).toBe(STRINGS.interopPartnerEditTitle.replace('<name>', 'Acme'));
  });
});
