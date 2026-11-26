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
  INTEROP_WORKFLOW_ROLE_ADD_ACTION,
  INTEROP_WORKFLOW_ROLE_EDIT_ACTION,
  INTEROP_WORKFLOW_ROLE_LIST,
  InteropWorkflowRoleListPage,
} from './interop-workflow-role-list.page';

/**
 * The Workflow roles page (Story 24.17 Batch 3b). The shared list page is replaced by an empty stand-in, so only this page's own wiring runs: the two
 * actions it registers after the shell's handler, the New workflow role dialog that posts to the namespace the shell is scoped to, the Edit dialog it
 * opens over the selected row with the name read-only, the request each Edit sends -- only the values the person changed, the capacity as text, an
 * emptied description included, and never the name -- a refusal kept in the dialog, the change event an applied change publishes, and the Remove the
 * handler's construction registers, which types the role's name and states what removing it does. The handler, the stores and the bus are real; only
 * the server's answers are stubbed.
 */

@Component({ selector: 'app-list-page', template: '' })
class StubListPage {}

const LIST = SCREENS.find((screen) => screen.descriptor === INTEROP_WORKFLOW_ROLE_LIST)!;

const row = (name: string, extra: Record<string, unknown> = {}): Record<string, unknown> => ({
  Name: name,
  Description: '',
  Capacity: 100,
  Members: 0,
  ...extra,
});

const ROWS = [row('OcuP2417rA', { Description: 'Order approvals', Capacity: 40, Members: 2 }), row('OcuP2417rB')];

const ID = joinCompositeId(['OcuP2417rA']);

const UPDATED: JsonResult<unknown> = {
  kind: 'ok',
  status: 200,
  body: { action: 'updated', target: { type: 'interop-workflow-role', scope: 'namespace:USER', id: ID }, readBack: { verdict: 'matches' } },
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
  TestBed.overrideComponent(InteropWorkflowRoleListPage, { remove: { imports: [ListPage] }, add: { imports: [StubListPage] } });
  const store = stores.for(LIST.descriptor, LIST.refreshRates);
  store.applyTick(ROWS, false, '', new Date());
  const fixture = TestBed.createComponent(InteropWorkflowRoleListPage);
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  fixture.detectChanges();
  return { fixture, host: fixture.nativeElement as HTMLElement, store, calls, events, actions: TestBed.inject(ScreenActions), handler: TestBed.inject(ScreenActionHandler) };
}

async function openEdit(fixture: ComponentFixture<unknown>, store: ReturnType<typeof mount>['store'], actions: ScreenActions, name: string): Promise<void> {
  store.setSelection([joinCompositeId([name])]);
  actions.run(INTEROP_WORKFLOW_ROLE_LIST, INTEROP_WORKFLOW_ROLE_EDIT_ACTION);
  await settle(fixture);
}

function typeInto(fixture: ComponentFixture<unknown>, host: HTMLElement, name: string, value: string): void {
  const control = host.querySelector(`[data-interop-workflow-role-field="${name}"]`) as HTMLInputElement;
  control.value = value;
  control.dispatchEvent(new Event('input'));
  fixture.detectChanges();
}

const confirmDialog = (host: HTMLElement): void => (host.querySelector('[data-interop-workflow-role-confirm]') as HTMLButtonElement).click();

const dialogs = (host: HTMLElement): number => host.querySelectorAll('app-interop-workflow-role-dialog').length;

afterEach(() => {
  for (const node of planted.splice(0)) node.remove();
  TestBed.resetTestingModule();
});

describe('the Workflow roles page', () => {
  it('declares the list this page hosts, with New workflow role as its primary action and Edit and Remove as its row actions', () => {
    expect(LIST.primaryAction?.id).toBe(INTEROP_WORKFLOW_ROLE_ADD_ACTION);
    expect(LIST.rowActions.map((action) => action.id)).toEqual([INTEROP_WORKFLOW_ROLE_EDIT_ACTION, 'remove']);
  });

  // Mutation (Rule 19): drop this page's `actions.register` of `edit` or `add` -> the first assertions go red.
  it("registers New workflow role and Edit beside the handler's Remove, and opens New workflow role", async () => {
    const { fixture, host, actions, calls } = mount([]);
    expect(actions.has(INTEROP_WORKFLOW_ROLE_LIST, INTEROP_WORKFLOW_ROLE_ADD_ACTION)).toBe(true);
    expect(actions.has(INTEROP_WORKFLOW_ROLE_LIST, INTEROP_WORKFLOW_ROLE_EDIT_ACTION)).toBe(true);
    expect(actions.has(INTEROP_WORKFLOW_ROLE_LIST, 'remove')).toBe(true);
    actions.run(INTEROP_WORKFLOW_ROLE_LIST, INTEROP_WORKFLOW_ROLE_ADD_ACTION);
    await settle(fixture);
    expect(calls).toEqual([]);
    expect(host.querySelector('.ocu-dialog-title')?.textContent?.trim()).toBe(STRINGS.interopWorkflowRoleAddAction);
  });

  it("posts New workflow role's fields in the namespace the shell is scoped to and closes, publishing the created event", async () => {
    const created: JsonResult<unknown> = { kind: 'ok', status: 201, body: { id: ID, target: { type: 'interop-workflow-role', scope: 'USER', id: ID } } };
    const { fixture, host, actions, calls, events } = mount([created]);
    actions.run(INTEROP_WORKFLOW_ROLE_LIST, INTEROP_WORKFLOW_ROLE_ADD_ACTION);
    await settle(fixture);
    typeInto(fixture, host, 'Name', 'OcuP2417rC');
    typeInto(fixture, host, 'Capacity', '25');
    confirmDialog(host);
    await settle(fixture);
    expect(calls.map((call) => [call.path, call.scope, JSON.parse(call.body)])).toEqual([
      ['/api/ocupilot/interop/workflow-roles', 'USER', { Name: 'OcuP2417rC', Capacity: 25 }],
    ]);
    expect(dialogs(host)).toBe(0);
    expect(events.map((event) => [event.type, event.action, event.tool])).toEqual([['interop-workflow-role', 'created', 'interop.workflowroles.add']]);
  });

  it('opens Edit over the selected row only, with its name read-only and the values its row reported', async () => {
    const { fixture, host, store, actions, calls } = mount([]);
    actions.run(INTEROP_WORKFLOW_ROLE_LIST, INTEROP_WORKFLOW_ROLE_EDIT_ACTION);
    await settle(fixture);
    expect(dialogs(host)).toBe(0);
    await openEdit(fixture, store, actions, 'OcuP2417rA');
    expect(calls).toHaveLength(0);
    expect(host.querySelector('.ocu-dialog-title')?.textContent?.trim()).toBe(STRINGS.interopCredentialEditTitle.replace('<name>', 'OcuP2417rA'));
    const name = host.querySelector('[data-interop-workflow-role-field="Name"]') as HTMLInputElement;
    expect(name.value).toBe('OcuP2417rA');
    expect(name.readOnly).toBe(true);
    expect((host.querySelector('[data-interop-workflow-role-field="Description"]') as HTMLTextAreaElement).value).toBe('Order approvals');
    expect((host.querySelector('[data-interop-workflow-role-field="Capacity"]') as HTMLInputElement).value).toBe('40');
  });

  it('sends only the values the person changed and never the name, an emptied description included, closes on an applied change and publishes the updated event', async () => {
    // Mutation (Rule 19): send every value whether changed or not -> the request carries the capacity and this goes red.
    const { fixture, host, store, actions, calls, events } = mount([UPDATED]);
    await openEdit(fixture, store, actions, 'OcuP2417rA');
    typeInto(fixture, host, 'Description', '');
    confirmDialog(host);
    await settle(fixture);
    expect(calls).toHaveLength(1);
    expect(calls[0].path).toBe(`/api/ocupilot/screens/${LIST.toolIdentifier}/action`);
    const sent = JSON.parse(calls[0].body) as { action: string; id: string; values: Record<string, string> };
    expect([sent.action, sent.id]).toEqual(['edit', ID]);
    expect(sent.values).toEqual({ Description: '' });
    expect(Object.keys(sent.values)).not.toContain('Name');
    expect(dialogs(host)).toBe(0);
    expect(events.map((event) => `${event.type}/${event.action}`)).toEqual(['interop-workflow-role/updated']);
  });

  it('sends the capacity as the number text it holds, beside a changed description', async () => {
    const { fixture, host, store, actions, calls } = mount([UPDATED]);
    await openEdit(fixture, store, actions, 'OcuP2417rA');
    typeInto(fixture, host, 'Description', 'Approvals');
    typeInto(fixture, host, 'Capacity', ' 55 ');
    confirmDialog(host);
    await settle(fixture);
    expect((JSON.parse(calls[0].body) as { values: Record<string, string> }).values).toEqual({ Description: 'Approvals', Capacity: '55' });
  });

  it('closes a dialog that changed nothing without sending or publishing anything', async () => {
    const { fixture, host, store, actions, calls, events } = mount([]);
    await openEdit(fixture, store, actions, 'OcuP2417rA');
    confirmDialog(host);
    await settle(fixture);
    expect(calls).toHaveLength(0);
    expect(events).toEqual([]);
    expect(dialogs(host)).toBe(0);
  });

  it("keeps a refusal on a field in the dialog as the instance's sentence, and one that names none above the fields, publishing nothing", async () => {
    const { fixture, host, store, actions, events } = mount([
      {
        kind: 'error',
        status: 422,
        code: 'INTEROP.WORKFLOW.ROLECAPACITY',
        reason: STRINGS.interopWorkflowRoleRefusalCapacity,
        detail: { violations: [{ field: 'Capacity', code: 'INTEROP.WORKFLOW.ROLECAPACITY', reason: STRINGS.interopWorkflowRoleRefusalCapacity }] },
      } as JsonResult<unknown>,
      { kind: 'error', status: 409, code: 'INTEROP.WORKFLOW.SOURCECONTROL', reason: STRINGS.interopWorkflowUserRefusalSourceControl } as JsonResult<unknown>,
    ]);
    await openEdit(fixture, store, actions, 'OcuP2417rA');
    typeInto(fixture, host, 'Capacity', '101');
    confirmDialog(host);
    await settle(fixture);
    expect(host.querySelector('[data-interop-workflow-role-violation="Capacity"]')?.textContent?.trim()).toBe(STRINGS.interopWorkflowRoleRefusalCapacity);
    expect(host.querySelector('[data-interop-workflow-role-reason]')).toBeNull();
    confirmDialog(host);
    await settle(fixture);
    expect(host.querySelector('[data-interop-workflow-role-violation]')).toBeNull();
    expect(host.querySelector('[data-interop-workflow-role-reason]')?.textContent?.trim()).toBe(STRINGS.interopWorkflowUserRefusalSourceControl);
    expect(events).toEqual([]);
    expect(store.refusal()).toBe('');
  });

  it("types the workflow role's name before Remove, states what removing it does, and sends the row key", async () => {
    // Mutation (Rule 19): drop the list's TYPED_NAME_ROWS entry -> the dialog asks for no name and the name assertion goes red; drop its
    // DESTRUCTIVE_CONSEQUENCES entry, or point it at another sentence -> the consequence assertion goes red.
    const removed: JsonResult<unknown> = { kind: 'ok', status: 200, body: { action: 'deleted', target: { type: 'interop-workflow-role', scope: 'USER', id: ID } } };
    const { fixture, store, actions, handler, calls, events } = mount([removed]);
    store.setSelection([ID]);
    actions.run(INTEROP_WORKFLOW_ROLE_LIST, 'remove');
    await settle(fixture);
    expect(handler.pending()?.kind).toBe('typed-name');
    expect(handler.pending()?.name).toBe('OcuP2417rA');
    expect(handler.pending()?.target).toBe(ID);
    expect(handler.pending()?.consequence).toBe(STRINGS.interopWorkflowRoleRemoveConsequence);
    expect(calls).toHaveLength(0);
    handler.confirmPending();
    await settle(fixture);
    expect(calls).toHaveLength(1);
    expect(JSON.parse(calls[0].body)).toEqual({ action: 'remove', id: ID });
    expect(events.map((event) => `${event.action} ${event.type}`)).toEqual(['deleted interop-workflow-role']);
  });

  // Mutation (Rule 19): drop the list's entry from `UNDRAWN_ACTIONS` -> the handler registers Edit itself and this goes red.
  it('leaves New workflow role and Edit to this page: the handler alone registers Remove only', () => {
    configure([]);
    const actions = TestBed.inject(ScreenActions);
    TestBed.inject(ScreenActionHandler);
    expect(actions.has(INTEROP_WORKFLOW_ROLE_LIST, 'remove')).toBe(true);
    expect(actions.has(INTEROP_WORKFLOW_ROLE_LIST, INTEROP_WORKFLOW_ROLE_EDIT_ACTION)).toBe(false);
    expect(actions.has(INTEROP_WORKFLOW_ROLE_LIST, INTEROP_WORKFLOW_ROLE_ADD_ACTION)).toBe(false);
  });

  it('opens neither dialog over the other', async () => {
    const { fixture, host, store, actions } = mount([]);
    await openEdit(fixture, store, actions, 'OcuP2417rA');
    actions.run(INTEROP_WORKFLOW_ROLE_LIST, INTEROP_WORKFLOW_ROLE_ADD_ACTION);
    await settle(fixture);
    expect(dialogs(host)).toBe(1);
    expect(host.querySelector('.ocu-dialog-title')?.textContent?.trim()).toBe(STRINGS.interopCredentialEditTitle.replace('<name>', 'OcuP2417rA'));
  });
});
