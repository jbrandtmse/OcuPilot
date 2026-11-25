import { Component } from '@angular/core';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type ApiRequestInit, type JsonResult } from '../../core/api';
import { ChangeBus, type ChangeEvent } from '../../core/change-bus';
import { joinCompositeId } from '../../core/entity-id';
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
  INTEROP_WORKFLOW_USER_ADD_ACTION,
  INTEROP_WORKFLOW_USER_EDIT_ACTION,
  INTEROP_WORKFLOW_USER_LIST,
  InteropWorkflowUserListPage,
} from './interop-workflow-user-list.page';
import { INTEROP_WORKFLOW_USER_CHOICES_PATH } from './interop-workflow-user.store';

/**
 * The Workflow users page (Story 24.17 Batch 3a). The shared list page is replaced by an empty stand-in, so only this page's own wiring runs: the two
 * actions it registers after the shell's handler, the New workflow user dialog that offers the users of the instance the list does not hold and posts to
 * the namespace the shell is scoped to, the Edit dialog it opens over the selected row with the name read-only, the request each Edit sends -- only the
 * values the person changed, the flag as `true` or `false`, and never the name -- a refusal kept in the dialog, the change event an applied change
 * publishes, and the Remove the handler's construction registers, which types the workflow user's name and states what removing it does. The handler,
 * the stores and the bus are real; only the server's answers are stubbed.
 */

@Component({ selector: 'app-list-page', template: '' })
class StubListPage {}

const LIST = SCREENS.find((screen) => screen.descriptor === INTEROP_WORKFLOW_USER_LIST)!;

const row = (name: string, extra: Record<string, unknown> = {}): Record<string, unknown> => ({
  Name: name,
  FullName: '',
  IsActive: true,
  Roles: 0,
  ...extra,
});

const ROWS = [row('OcuP2417wA', { FullName: 'Ada Lovelace', Roles: 2 }), row('OcuP2417wB', { IsActive: false })];

const ID = joinCompositeId(['OcuP2417wA']);

const CHOICES: JsonResult<unknown> = {
  kind: 'ok',
  status: 200,
  body: { rows: [{ Name: 'Admin' }, { Name: 'ocup2417wb' }, { Name: 'OcuP2417wC' }, { Name: 'OcuP2417wA' }] },
};

const UPDATED: JsonResult<unknown> = {
  kind: 'ok',
  status: 200,
  body: { action: 'updated', target: { type: 'interop-workflow-user', scope: 'namespace:USER', id: ID }, readBack: { verdict: 'matches' } },
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

/** Configure the testing module over stubbed answers: the choices read answers `CHOICES`, and each other request resolves to the next of `answers`. */
function configure(answers: JsonResult<unknown>[]) {
  TestBed.resetTestingModule();
  const calls: Call[] = [];
  const api = {
    requestJson: async <T,>(path: string, init: ApiRequestInit = {}): Promise<JsonResult<T>> => {
      calls.push({ path, method: init.method ?? 'GET', scope: init.scope, body: init.body ?? '' });
      if (path === INTEROP_WORKFLOW_USER_CHOICES_PATH) return CHOICES as JsonResult<T>;
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
  TestBed.overrideComponent(InteropWorkflowUserListPage, { remove: { imports: [ListPage] }, add: { imports: [StubListPage] } });
  const store = stores.for(LIST.descriptor, LIST.refreshRates);
  store.applyTick(ROWS, false, '', new Date());
  const fixture = TestBed.createComponent(InteropWorkflowUserListPage);
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  fixture.detectChanges();
  return { fixture, host: fixture.nativeElement as HTMLElement, store, calls, events, actions: TestBed.inject(ScreenActions), handler: TestBed.inject(ScreenActionHandler) };
}

async function openEdit(fixture: ComponentFixture<unknown>, store: ReturnType<typeof mount>['store'], actions: ScreenActions, name: string): Promise<void> {
  store.setSelection([joinCompositeId([name])]);
  actions.run(INTEROP_WORKFLOW_USER_LIST, INTEROP_WORKFLOW_USER_EDIT_ACTION);
  await settle(fixture);
}

function typeInto(fixture: ComponentFixture<unknown>, host: HTMLElement, name: string, value: string): void {
  const control = host.querySelector(`[data-interop-workflow-user-field="${name}"]`) as HTMLInputElement;
  control.value = value;
  control.dispatchEvent(new Event('input'));
  fixture.detectChanges();
}

function choose(fixture: ComponentFixture<unknown>, host: HTMLElement, value: string): void {
  const select = host.querySelector('[data-interop-workflow-user-field="Name"]') as HTMLSelectElement;
  select.value = value;
  select.dispatchEvent(new Event('change'));
  fixture.detectChanges();
}

const confirmDialog = (host: HTMLElement): void => (host.querySelector('[data-interop-workflow-user-confirm]') as HTMLButtonElement).click();

const dialogs = (host: HTMLElement): number => host.querySelectorAll('app-interop-workflow-user-dialog').length;

afterEach(() => {
  for (const node of planted.splice(0)) node.remove();
  TestBed.resetTestingModule();
});

describe('the Workflow users page', () => {
  it('declares the list this page hosts, with New workflow user as its primary action and Edit and Remove as its row actions', () => {
    expect(LIST.primaryAction?.id).toBe(INTEROP_WORKFLOW_USER_ADD_ACTION);
    expect(LIST.rowActions.map((action) => action.id)).toEqual([INTEROP_WORKFLOW_USER_EDIT_ACTION, 'remove']);
  });

  // Mutation (Rule 19): drop this page's `actions.register` of `edit` or `add` -> the first assertions go red.
  it('registers New workflow user and Edit beside the handler\'s Remove, and opens New workflow user offering the users the list does not hold', async () => {
    const { fixture, host, actions, calls } = mount([]);
    expect(actions.has(INTEROP_WORKFLOW_USER_LIST, INTEROP_WORKFLOW_USER_ADD_ACTION)).toBe(true);
    expect(actions.has(INTEROP_WORKFLOW_USER_LIST, INTEROP_WORKFLOW_USER_EDIT_ACTION)).toBe(true);
    expect(actions.has(INTEROP_WORKFLOW_USER_LIST, 'remove')).toBe(true);
    actions.run(INTEROP_WORKFLOW_USER_LIST, INTEROP_WORKFLOW_USER_ADD_ACTION);
    await settle(fixture);
    expect(calls.map((call) => [call.path, call.scope])).toEqual([[INTEROP_WORKFLOW_USER_CHOICES_PATH, 'USER']]);
    expect(host.querySelector('.ocu-dialog-title')?.textContent?.trim()).toBe(STRINGS.interopWorkflowUserAddAction);
    const select = host.querySelector('[data-interop-workflow-user-field="Name"]') as HTMLSelectElement;
    // Mutation (Rule 19): pass no held names to the dialog -> the two names the list holds are offered and this goes red.
    expect([...select.options].map((option) => option.value).filter((value) => value !== '')).toEqual(['Admin', 'OcuP2417wC']);
  });

  it('posts New workflow user\'s fields in the namespace the shell is scoped to and closes, publishing the created event', async () => {
    const created: JsonResult<unknown> = { kind: 'ok', status: 201, body: { id: ID, target: { type: 'interop-workflow-user', scope: 'USER', id: ID } } };
    const { fixture, host, actions, calls, events } = mount([created]);
    actions.run(INTEROP_WORKFLOW_USER_LIST, INTEROP_WORKFLOW_USER_ADD_ACTION);
    await settle(fixture);
    choose(fixture, host, 'OcuP2417wC');
    typeInto(fixture, host, 'FullName', 'Cy Young');
    confirmDialog(host);
    await settle(fixture);
    const posts = calls.filter((call) => call.path !== INTEROP_WORKFLOW_USER_CHOICES_PATH);
    expect(posts.map((call) => [call.path, call.scope, JSON.parse(call.body)])).toEqual([
      ['/api/ocupilot/interop/workflow-users', 'USER', { Name: 'OcuP2417wC', FullName: 'Cy Young', IsActive: true }],
    ]);
    expect(dialogs(host)).toBe(0);
    expect(events.map((event) => [event.type, event.action, event.tool])).toEqual([['interop-workflow-user', 'created', 'interop.workflowusers.add']]);
  });

  it('opens Edit over the selected row only, with its name read-only and the values its row reported', async () => {
    const { fixture, host, store, actions, calls } = mount([]);
    actions.run(INTEROP_WORKFLOW_USER_LIST, INTEROP_WORKFLOW_USER_EDIT_ACTION);
    await settle(fixture);
    expect(dialogs(host)).toBe(0);
    await openEdit(fixture, store, actions, 'OcuP2417wA');
    expect(calls).toHaveLength(0);
    expect(host.querySelector('.ocu-dialog-title')?.textContent?.trim()).toBe(STRINGS.interopCredentialEditTitle.replace('<name>', 'OcuP2417wA'));
    const name = host.querySelector('[data-interop-workflow-user-field="Name"]') as HTMLInputElement;
    expect(name.value).toBe('OcuP2417wA');
    expect(name.readOnly).toBe(true);
    expect((host.querySelector('[data-interop-workflow-user-field="FullName"]') as HTMLInputElement).value).toBe('Ada Lovelace');
    expect((host.querySelector('[data-interop-workflow-user-field="IsActive"]') as HTMLInputElement).checked).toBe(true);
  });

  it('sends only the values the person changed and never the name, an emptied one included and the flag as text, closes on an applied change and publishes the updated event', async () => {
    const { fixture, host, store, actions, calls, events } = mount([UPDATED]);
    await openEdit(fixture, store, actions, 'OcuP2417wA');
    typeInto(fixture, host, 'FullName', '');
    const flag = host.querySelector('[data-interop-workflow-user-field="IsActive"]') as HTMLInputElement;
    flag.checked = false;
    flag.dispatchEvent(new Event('change'));
    fixture.detectChanges();
    // Taking an active user inactive says what that does, before it is sent.
    expect(host.querySelector('[data-interop-workflow-user-inactive]')?.textContent?.trim()).toBe(STRINGS.interopWorkflowUserInactiveConsequence);
    confirmDialog(host);
    await settle(fixture);
    expect(calls).toHaveLength(1);
    expect(calls[0].path).toBe(`/api/ocupilot/screens/${LIST.toolIdentifier}/action`);
    const sent = JSON.parse(calls[0].body) as { action: string; id: string; values: Record<string, string> };
    expect([sent.action, sent.id]).toEqual(['edit', ID]);
    // Mutation (Rule 19): send the flag as a boolean -> the screen action route refuses it and this goes red.
    expect(sent.values).toEqual({ FullName: '', IsActive: 'false' });
    expect(Object.keys(sent.values)).not.toContain('Name');
    expect(dialogs(host)).toBe(0);
    expect(events.map((event) => `${event.type}/${event.action}`)).toEqual(['interop-workflow-user/updated']);
  });

  it('sends the full name when it is the one value changed, and keeps the flag out of the request', async () => {
    // Mutation (Rule 19): send every value whether changed or not -> the request carries the flag and this goes red.
    const { fixture, host, store, actions, calls } = mount([UPDATED]);
    await openEdit(fixture, store, actions, 'OcuP2417wA');
    typeInto(fixture, host, 'FullName', 'Ada L');
    confirmDialog(host);
    await settle(fixture);
    expect(calls).toHaveLength(1);
    expect((JSON.parse(calls[0].body) as { values: Record<string, string> }).values).toEqual({ FullName: 'Ada L' });
  });

  it('closes a dialog that changed nothing without sending or publishing anything', async () => {
    const { fixture, host, store, actions, calls, events } = mount([]);
    await openEdit(fixture, store, actions, 'OcuP2417wA');
    confirmDialog(host);
    await settle(fixture);
    expect(calls).toHaveLength(0);
    expect(events).toEqual([]);
    expect(dialogs(host)).toBe(0);
  });

  it('closes on Cancel, sending nothing and publishing nothing', async () => {
    const { fixture, host, store, actions, calls, events } = mount([]);
    await openEdit(fixture, store, actions, 'OcuP2417wA');
    const cancel = [...host.querySelectorAll('.ocu-dialog-actions button')].find((button) => button.textContent?.trim() === STRINGS.actionCancel) as HTMLButtonElement;
    cancel.click();
    await settle(fixture);
    expect(dialogs(host)).toBe(0);
    expect(calls).toHaveLength(0);
    expect(events).toEqual([]);
  });

  it('keeps a refusal on a field in the dialog as the instance\'s sentence, and one that names none above the fields, publishing nothing', async () => {
    const { fixture, host, store, actions, events } = mount([
      {
        kind: 'error',
        status: 422,
        code: 'INTEROP.WORKFLOW.FULLNAME',
        reason: STRINGS.interopWorkflowUserRefusalFullName,
        detail: { violations: [{ field: 'FullName', code: 'INTEROP.WORKFLOW.FULLNAME', reason: STRINGS.interopWorkflowUserRefusalFullName }] },
      } as JsonResult<unknown>,
      { kind: 'error', status: 409, code: 'INTEROP.WORKFLOW.SOURCECONTROL', reason: STRINGS.interopWorkflowUserRefusalSourceControl } as JsonResult<unknown>,
    ]);
    await openEdit(fixture, store, actions, 'OcuP2417wA');
    typeInto(fixture, host, 'FullName', 'x'.repeat(129));
    confirmDialog(host);
    await settle(fixture);
    expect(host.querySelector('[data-interop-workflow-user-violation="FullName"]')?.textContent?.trim()).toBe(STRINGS.interopWorkflowUserRefusalFullName);
    expect(host.querySelector('[data-interop-workflow-user-reason]')).toBeNull();
    confirmDialog(host);
    await settle(fixture);
    expect(host.querySelector('[data-interop-workflow-user-violation]')).toBeNull();
    expect(host.querySelector('[data-interop-workflow-user-reason]')?.textContent?.trim()).toBe(STRINGS.interopWorkflowUserRefusalSourceControl);
    expect(events).toEqual([]);
    expect(store.refusal()).toBe('');
  });

  it('types the workflow user\'s name before Remove, states what removing it does, and sends the row key', async () => {
    // Mutation (Rule 19): drop the list's TYPED_NAME_ROWS entry -> the dialog asks for no name and the name assertion goes red; drop its
    // DESTRUCTIVE_CONSEQUENCES entry, or point it at another sentence -> the consequence assertion goes red.
    const removed: JsonResult<unknown> = { kind: 'ok', status: 200, body: { action: 'deleted', target: { type: 'interop-workflow-user', scope: 'USER', id: ID } } };
    const { fixture, store, actions, handler, calls, events } = mount([removed]);
    store.setSelection([ID]);
    actions.run(INTEROP_WORKFLOW_USER_LIST, 'remove');
    await settle(fixture);
    expect(handler.pending()?.kind).toBe('typed-name');
    expect(handler.pending()?.name).toBe('OcuP2417wA');
    expect(handler.pending()?.target).toBe(ID);
    expect(handler.pending()?.consequence).toBe(STRINGS.interopWorkflowUserRemoveConsequence);
    expect(calls).toHaveLength(0);
    handler.confirmPending();
    await settle(fixture);
    expect(calls).toHaveLength(1);
    expect(JSON.parse(calls[0].body)).toEqual({ action: 'remove', id: ID });
    expect(events.map((event) => `${event.action} ${event.type}`)).toEqual(['deleted interop-workflow-user']);
  });

  // Mutation (Rule 19): drop the list's entry from `UNDRAWN_ACTIONS` -> the handler registers Edit itself and this goes red.
  it('leaves New workflow user and Edit to this page: the handler alone registers Remove only', () => {
    configure([]);
    const actions = TestBed.inject(ScreenActions);
    TestBed.inject(ScreenActionHandler);
    expect(actions.has(INTEROP_WORKFLOW_USER_LIST, 'remove')).toBe(true);
    expect(actions.has(INTEROP_WORKFLOW_USER_LIST, INTEROP_WORKFLOW_USER_EDIT_ACTION)).toBe(false);
    expect(actions.has(INTEROP_WORKFLOW_USER_LIST, INTEROP_WORKFLOW_USER_ADD_ACTION)).toBe(false);
  });

  it('opens neither dialog over the other', async () => {
    const { fixture, host, store, actions } = mount([]);
    await openEdit(fixture, store, actions, 'OcuP2417wA');
    actions.run(INTEROP_WORKFLOW_USER_LIST, INTEROP_WORKFLOW_USER_ADD_ACTION);
    await settle(fixture);
    expect(dialogs(host)).toBe(1);
    expect(host.querySelector('.ocu-dialog-title')?.textContent?.trim()).toBe(STRINGS.interopCredentialEditTitle.replace('<name>', 'OcuP2417wA'));
  });
});
