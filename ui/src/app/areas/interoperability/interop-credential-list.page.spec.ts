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
  INTEROP_CREDENTIAL_ADD_ACTION,
  INTEROP_CREDENTIAL_EDIT_ACTION,
  INTEROP_CREDENTIAL_LIST,
  INTEROP_CREDENTIAL_PASSWORD_ACTION,
  InteropCredentialListPage,
} from './interop-credential-list.page';

/**
 * The Credentials page (Story 24.15). The shared list page is replaced by an empty stand-in, so only this page's own wiring runs: the three actions it
 * registers after the shell's handler, the New credential dialog that posts to the namespace the shell is scoped to, the Edit dialog it opens over the
 * selected row with the name read-only, the request each Edit sends -- only the values the person changed and never the name -- the Set password dialog
 * whose one request carries the password and nothing else, a refusal kept in the dialog, the change event an applied change publishes, and the Remove the
 * handler's construction registers, which types the credential's name. The handler, the stores and the bus are real; only the server's answers are stubbed.
 */

@Component({ selector: 'app-list-page', template: '' })
class StubListPage {}

const LIST = SCREENS.find((screen) => screen.descriptor === INTEROP_CREDENTIAL_LIST)!;

const row = (name: string, extra: Record<string, unknown> = {}): Record<string, unknown> => ({ Name: name, Username: '', BusinessPartner: '', Password: 'not stored', ...extra });

const ROWS = [row('Probe', { Username: 'held', BusinessPartner: 'PartnerA', Password: 'stored' }), row('Other', { Username: 'o' })];

const UPDATED: JsonResult<unknown> = {
  kind: 'ok',
  status: 200,
  body: { action: 'updated', target: { type: 'interop-credential', scope: 'namespace:USER', id: 'Probe' }, readBack: { verdict: 'matches' } },
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
  readonly scope: string | null | undefined;
  readonly body: string;
}

/** Configure the testing module over stubbed answers: each request but the partner read resolves to the next of `answers`. */
function configure(answers: JsonResult<unknown>[]) {
  TestBed.resetTestingModule();
  const calls: Call[] = [];
  const api = {
    requestJson: async <T,>(path: string, init: ApiRequestInit = {}): Promise<JsonResult<T>> => {
      if (path.includes('/screens/interop.businesspartners/read')) return { kind: 'ok', status: 200, body: { rows: [{ Name: 'PartnerA' }] } } as JsonResult<T>;
      calls.push({ path, scope: init.scope, body: init.body ?? '' });
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
  TestBed.overrideComponent(InteropCredentialListPage, { remove: { imports: [ListPage] }, add: { imports: [StubListPage] } });
  const store = stores.for(LIST.descriptor, LIST.refreshRates);
  store.applyTick(ROWS, false, '', new Date());
  const fixture = TestBed.createComponent(InteropCredentialListPage);
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  fixture.detectChanges();
  return { fixture, host: fixture.nativeElement as HTMLElement, store, calls, events, actions: TestBed.inject(ScreenActions), handler: TestBed.inject(ScreenActionHandler) };
}

async function openRowAction(fixture: ComponentFixture<unknown>, store: ReturnType<typeof mount>['store'], actions: ScreenActions, action: string, name: string): Promise<void> {
  store.setSelection([name]);
  actions.run(INTEROP_CREDENTIAL_LIST, action);
  await settle(fixture);
}

function typeInto(fixture: ComponentFixture<unknown>, host: HTMLElement, name: string, value: string): void {
  const control = host.querySelector(`[data-interop-credential-field="${name}"]`) as HTMLInputElement | HTMLSelectElement;
  control.value = value;
  control.dispatchEvent(new Event(control.tagName === 'SELECT' ? 'change' : 'input'));
  fixture.detectChanges();
}

const confirmDialog = (host: HTMLElement): void => (host.querySelector('[data-interop-credential-confirm]') as HTMLButtonElement).click();

afterEach(() => {
  for (const node of planted.splice(0)) node.remove();
  TestBed.resetTestingModule();
});

describe('the Credentials page', () => {
  it('declares the list this page hosts, with New credential as its primary action and Edit, Set password and Remove as its row actions', () => {
    expect(LIST.primaryAction?.id).toBe(INTEROP_CREDENTIAL_ADD_ACTION);
    expect(LIST.rowActions.map((action) => action.id)).toEqual([INTEROP_CREDENTIAL_EDIT_ACTION, INTEROP_CREDENTIAL_PASSWORD_ACTION, 'remove']);
    expect(LIST.secretArguments).toEqual(['Password']);
  });

  // Mutation (Rule 19): drop this page's `actions.register` of `edit`, `add` or `password` -> the first assertions go red.
  it('registers New credential, Edit and Set password beside the handler\'s Remove, and opens New credential for a new credential', async () => {
    const { fixture, host, actions, calls } = mount([]);
    for (const action of [INTEROP_CREDENTIAL_ADD_ACTION, INTEROP_CREDENTIAL_EDIT_ACTION, INTEROP_CREDENTIAL_PASSWORD_ACTION, 'remove']) {
      expect(actions.has(INTEROP_CREDENTIAL_LIST, action)).toBe(true);
    }
    actions.run(INTEROP_CREDENTIAL_LIST, INTEROP_CREDENTIAL_ADD_ACTION);
    await settle(fixture);
    expect(calls).toHaveLength(0);
    expect(host.querySelector('.ocu-dialog-title')?.textContent?.trim()).toBe(STRINGS.interopCredentialAddAction);
    expect((host.querySelector('[data-interop-credential-field="Name"]') as HTMLInputElement).readOnly).toBe(false);
  });

  it('posts New credential in the namespace the shell is scoped to, with the typed password, and closes, publishing the created event', async () => {
    const created: JsonResult<unknown> = { kind: 'ok', status: 201, body: { id: 'New', target: { type: 'interop-credential', scope: 'USER', id: 'New' } } };
    const { fixture, host, actions, calls, events } = mount([created]);
    actions.run(INTEROP_CREDENTIAL_LIST, INTEROP_CREDENTIAL_ADD_ACTION);
    await settle(fixture);
    typeInto(fixture, host, 'Name', 'New');
    typeInto(fixture, host, 'Password', 'OcuPw1');
    confirmDialog(host);
    await settle(fixture);
    expect(calls.map((call) => [call.path, call.scope, JSON.parse(call.body) as Record<string, unknown>])).toEqual([['/api/ocupilot/interop/credentials', 'USER', { Name: 'New', Username: '', BusinessPartner: '', Password: 'OcuPw1' }]]);
    expect(host.querySelector('app-interop-credential-dialog')).toBeNull();
    expect(events.map((event) => [event.type, event.action, event.tool])).toEqual([['interop-credential', 'created', 'interop.credentials.add']]);
  });

  it('opens Edit over the selected row only, with its name read-only and the values its row reported', async () => {
    const { fixture, host, store, actions, calls } = mount([]);
    actions.run(INTEROP_CREDENTIAL_LIST, INTEROP_CREDENTIAL_EDIT_ACTION);
    await settle(fixture);
    expect(host.querySelector('app-interop-credential-dialog')).toBeNull();
    await openRowAction(fixture, store, actions, INTEROP_CREDENTIAL_EDIT_ACTION, 'Probe');
    expect(calls).toHaveLength(0);
    expect(host.querySelector('.ocu-dialog-title')?.textContent?.trim()).toBe(STRINGS.interopCredentialEditTitle.replace('<name>', 'Probe'));
    const name = host.querySelector('[data-interop-credential-field="Name"]') as HTMLInputElement;
    expect([name.value, name.readOnly]).toEqual(['Probe', true]);
    expect((host.querySelector('[data-interop-credential-field="Username"]') as HTMLInputElement).value).toBe('held');
    expect((host.querySelector('[data-interop-credential-field="BusinessPartner"]') as HTMLSelectElement).value).toBe('PartnerA');
    expect(host.querySelector('[data-interop-credential-field="Password"]')).toBeNull();
  });

  it('sends only the values the person changed and never the name, an emptied one included, closes on an applied change and publishes the updated event', async () => {
    const { fixture, host, store, actions, calls, events } = mount([UPDATED]);
    await openRowAction(fixture, store, actions, INTEROP_CREDENTIAL_EDIT_ACTION, 'Probe');
    typeInto(fixture, host, 'BusinessPartner', '');
    confirmDialog(host);
    await settle(fixture);
    expect(calls).toHaveLength(1);
    expect(calls[0].path).toBe(`/api/ocupilot/screens/${LIST.toolIdentifier}/action`);
    const sent = JSON.parse(calls[0].body) as { action: string; id: string; values: Record<string, string> };
    expect([sent.action, sent.id]).toEqual(['edit', 'Probe']);
    // Mutation (Rule 19): send the unchanged user name too -> this goes red.
    expect(sent.values).toEqual({ BusinessPartner: '' });
    expect(host.querySelector('app-interop-credential-dialog')).toBeNull();
    expect(events.map((event) => `${event.type}/${event.action}`)).toEqual(['interop-credential/updated']);
  });

  it('closes an Edit that changed nothing without sending or publishing anything, and on Cancel', async () => {
    const { fixture, host, store, actions, calls, events } = mount([]);
    await openRowAction(fixture, store, actions, INTEROP_CREDENTIAL_EDIT_ACTION, 'Probe');
    confirmDialog(host);
    await settle(fixture);
    expect(host.querySelector('app-interop-credential-dialog')).toBeNull();
    await openRowAction(fixture, store, actions, INTEROP_CREDENTIAL_EDIT_ACTION, 'Probe');
    const cancel = [...host.querySelectorAll('.ocu-dialog-actions button')].find((button) => button.textContent?.trim() === STRINGS.actionCancel) as HTMLButtonElement;
    cancel.click();
    await settle(fixture);
    expect(host.querySelector('app-interop-credential-dialog')).toBeNull();
    expect(calls).toHaveLength(0);
    expect(events).toEqual([]);
  });

  it('sends Set password\'s one request with the password and nothing else, never the name or a stored flag, and holds no copy of it', async () => {
    const { fixture, host, store, actions, calls, events } = mount([UPDATED]);
    await openRowAction(fixture, store, actions, INTEROP_CREDENTIAL_PASSWORD_ACTION, 'Probe');
    expect(host.querySelector('.ocu-dialog-title')?.textContent?.trim()).toBe(STRINGS.userActionSetPassword);
    typeInto(fixture, host, 'Password', ' OcuPw2 ');
    confirmDialog(host);
    await settle(fixture);
    expect(calls).toHaveLength(1);
    expect(calls[0].path).toBe(`/api/ocupilot/screens/${LIST.toolIdentifier}/action`);
    // Mutation (Rule 19): send the password trimmed, or beside another value -> this goes red.
    expect(JSON.parse(calls[0].body)).toEqual({ action: 'password', id: 'Probe', values: { Password: ' OcuPw2 ' } });
    expect(host.querySelector('app-interop-credential-dialog')).toBeNull();
    expect(events.map((event) => `${event.type}/${event.action}`)).toEqual(['interop-credential/updated']);
    expect(JSON.stringify(store.data())).not.toContain('OcuPw2');
  });

  it('keeps a refusal on a field in the dialog as the instance\'s sentence, and one that names none above the fields, publishing nothing', async () => {
    const { fixture, host, store, actions, events } = mount([
      {
        kind: 'error',
        status: 422,
        code: 'INTEROP.CREDENTIAL.PARTNER',
        reason: STRINGS.interopCredentialRefusalPartner,
        detail: { violations: [{ field: 'BusinessPartner', code: 'INTEROP.CREDENTIAL.PARTNER', reason: STRINGS.interopCredentialRefusalPartner }] },
      } as JsonResult<unknown>,
      { kind: 'error', status: 403, code: 'PROHIBITED.PROVIDERCREDENTIAL', reason: STRINGS.credentialRefusalProvider } as JsonResult<unknown>,
    ]);
    await openRowAction(fixture, store, actions, INTEROP_CREDENTIAL_EDIT_ACTION, 'Probe');
    typeInto(fixture, host, 'BusinessPartner', '');
    confirmDialog(host);
    await settle(fixture);
    expect(host.querySelector('[data-interop-credential-violation="BusinessPartner"]')?.textContent?.trim()).toBe(STRINGS.interopCredentialRefusalPartner);
    expect(host.querySelector('[data-interop-credential-reason]')).toBeNull();
    confirmDialog(host);
    await settle(fixture);
    expect(host.querySelector('[data-interop-credential-violation]')).toBeNull();
    expect(host.querySelector('[data-interop-credential-reason]')?.textContent?.trim()).toBe(STRINGS.credentialRefusalProvider);
    expect(events).toEqual([]);
  });

  it('types the credential\'s name before Remove, states what removing it does, and sends the row key', async () => {
    // Mutation (Rule 19): drop the list's TYPED_NAME_ROWS entry -> the dialog asks for no name and the name assertion goes red; drop its
    // DESTRUCTIVE_CONSEQUENCES entry -> the consequence assertion goes red.
    const removed: JsonResult<unknown> = { kind: 'ok', status: 200, body: { action: 'deleted', target: { type: 'interop-credential', scope: 'USER', id: 'Probe' } } };
    const { fixture, store, actions, handler, calls, events } = mount([removed]);
    store.setSelection(['Probe']);
    actions.run(INTEROP_CREDENTIAL_LIST, 'remove');
    await settle(fixture);
    expect(handler.pending()?.kind).toBe('typed-name');
    expect(handler.pending()?.name).toBe('Probe');
    expect(handler.pending()?.consequence).toBe(STRINGS.x509DeleteConsequence);
    expect(calls).toHaveLength(0);
    handler.confirmPending();
    await settle(fixture);
    expect(JSON.parse(calls[0].body)).toEqual({ action: 'remove', id: 'Probe' });
    expect(events.map((event) => `${event.action} ${event.type}`)).toEqual(['deleted interop-credential']);
  });

  // Mutation (Rule 19): drop the list's entry from `UNDRAWN_ACTIONS` -> the handler registers Edit and Set password itself and this goes red.
  it('leaves New credential, Edit and Set password to this page: the handler alone registers Remove only', () => {
    configure([]);
    const actions = TestBed.inject(ScreenActions);
    TestBed.inject(ScreenActionHandler);
    expect(actions.has(INTEROP_CREDENTIAL_LIST, 'remove')).toBe(true);
    for (const action of [INTEROP_CREDENTIAL_ADD_ACTION, INTEROP_CREDENTIAL_EDIT_ACTION, INTEROP_CREDENTIAL_PASSWORD_ACTION]) {
      expect(actions.has(INTEROP_CREDENTIAL_LIST, action)).toBe(false);
    }
  });

  it('opens one dialog at a time', async () => {
    const { fixture, host, store, actions } = mount([]);
    await openRowAction(fixture, store, actions, INTEROP_CREDENTIAL_EDIT_ACTION, 'Probe');
    actions.run(INTEROP_CREDENTIAL_LIST, INTEROP_CREDENTIAL_ADD_ACTION);
    actions.run(INTEROP_CREDENTIAL_LIST, INTEROP_CREDENTIAL_PASSWORD_ACTION);
    await settle(fixture);
    expect(host.querySelectorAll('app-interop-credential-dialog')).toHaveLength(1);
    expect(host.querySelector('.ocu-dialog-title')?.textContent?.trim()).toBe(STRINGS.interopCredentialEditTitle.replace('<name>', 'Probe'));
  });
});
