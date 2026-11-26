import { Component } from '@angular/core';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { Router } from '@angular/router';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type ApiRequestInit, type JsonResult } from '../../core/api';
import { ChangeBus, type ChangeEvent } from '../../core/change-bus';
import { encodeEntityId, joinCompositeId } from '../../core/entity-id';
import { OverlayStack } from '../../core/overlay-stack';
import { ScopeService } from '../../core/scope';
import { ScreenActions } from '../../core/screen-actions';
import { ScreenStores } from '../../core/screen-store';
import { SCREENS } from '../../core/screens.generated';
import { STRINGS } from '../../core/strings';
import { ListPage } from '../../shell/list-page';
import { ScreenActionHandler } from '../../shell/screen-action-handler';
import { stubAccountPreferences } from '../../testing/account-preferences';
import { INTEROP_WORKFLOW_MEMBER_ADD_ACTION, INTEROP_WORKFLOW_MEMBER_LIST, InteropWorkflowMemberListPage } from './interop-workflow-member-list.page';

/**
 * The Role members page (Story 24.17 Batch 3b). The shared list page is replaced by an empty stand-in, so only this page's own wiring runs: the Add member
 * action it registers after the shell's handler, the dialog that reads the workflow users, offers those the role does not hold and posts to the role the
 * route names in the namespace the shell is scoped to, and the Remove the handler's construction registers, which warns first, types no name and sends the
 * row's composite key. The handler, the stores and the bus are real; only the server's answers are stubbed.
 */

@Component({ selector: 'app-list-page', template: '' })
class StubListPage {}

const LIST = SCREENS.find((screen) => screen.descriptor === INTEROP_WORKFLOW_MEMBER_LIST)!;

const ROLE = 'OcuP2417r A';

const READ_PATH = '/api/ocupilot/screens/interop.workflowusers/read?maxRows=1000';

const member = (user: string, extra: Record<string, unknown> = {}): Record<string, unknown> => ({
  Role: ROLE,
  User: user,
  FullName: '',
  Ranking: 3,
  Title: '',
  IsActive: true,
  ...extra,
});

const ROWS = [member('OcuP2417wA', { Ranking: 2, Title: 'Lead' }), member('OcuP2417wB', { IsActive: false })];

const ID = joinCompositeId([ROLE, 'OcuP2417wA']);

const USERS: JsonResult<unknown> = {
  kind: 'ok',
  status: 200,
  body: { rows: [{ Name: 'OcuP2417wA', IsActive: true }, { Name: 'OcuP2417wB', IsActive: false }, { Name: 'OcuP2417wC', IsActive: true }] },
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

/** Configure the testing module at `url`: the workflow users read answers `USERS`, and each other request resolves to the next of `answers`. */
function configure(answers: JsonResult<unknown>[], url: string) {
  TestBed.resetTestingModule();
  const calls: Call[] = [];
  const api = {
    requestJson: async <T,>(path: string, init: ApiRequestInit = {}): Promise<JsonResult<T>> => {
      calls.push({ path, method: init.method ?? 'GET', scope: init.scope, body: init.body ?? '' });
      if (path === READ_PATH) return USERS as JsonResult<T>;
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
      { provide: Router, useValue: { url } as unknown as Router },
      { provide: ScopeService, useValue: { loaded: () => true, namespace: () => 'USER', subscribe: () => () => {} } as unknown as ScopeService },
    ],
  });
  return { calls, events, stores };
}

/** Mount the page over `ROWS`, at the route of `ROLE`'s members unless `url` says otherwise. */
function mount(answers: JsonResult<unknown>[], url = `/${LIST.route}/${encodeEntityId(ROLE)}`) {
  const { calls, events, stores } = configure(answers, url);
  TestBed.overrideComponent(InteropWorkflowMemberListPage, { remove: { imports: [ListPage] }, add: { imports: [StubListPage] } });
  const store = stores.for(LIST.descriptor, LIST.refreshRates);
  store.applyTick(ROWS, false, '', new Date());
  const fixture = TestBed.createComponent(InteropWorkflowMemberListPage);
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  fixture.detectChanges();
  return { fixture, host: fixture.nativeElement as HTMLElement, store, calls, events, actions: TestBed.inject(ScreenActions), handler: TestBed.inject(ScreenActionHandler) };
}

function choose(fixture: ComponentFixture<unknown>, host: HTMLElement, name: string, value: string): void {
  const select = host.querySelector(`[data-interop-workflow-member-field="${name}"]`) as HTMLSelectElement;
  select.value = value;
  select.dispatchEvent(new Event('change'));
  fixture.detectChanges();
}

const dialogs = (host: HTMLElement): number => host.querySelectorAll('app-interop-workflow-member-dialog').length;

afterEach(() => {
  for (const node of planted.splice(0)) node.remove();
  TestBed.resetTestingModule();
});

describe('the Role members page', () => {
  it('declares the list this page hosts, with Add member as its primary action and Remove as its one row action', () => {
    expect(LIST.primaryAction?.id).toBe(INTEROP_WORKFLOW_MEMBER_ADD_ACTION);
    expect(LIST.rowActions.map((action) => action.id)).toEqual(['remove']);
    expect(LIST.parentScope).toBe('interoperability/workflow-roles');
  });

  // Mutation (Rule 19): drop this page's `actions.register` of `add` -> the first assertion goes red.
  it("registers Add member beside the handler's Remove, and opens it offering the workflow users the role does not hold", async () => {
    const { fixture, host, actions, calls } = mount([]);
    expect(actions.has(INTEROP_WORKFLOW_MEMBER_LIST, INTEROP_WORKFLOW_MEMBER_ADD_ACTION)).toBe(true);
    expect(actions.has(INTEROP_WORKFLOW_MEMBER_LIST, 'remove')).toBe(true);
    actions.run(INTEROP_WORKFLOW_MEMBER_LIST, INTEROP_WORKFLOW_MEMBER_ADD_ACTION);
    await settle(fixture);
    expect(calls.map((call) => [call.path, call.scope])).toEqual([[READ_PATH, 'USER']]);
    expect(host.querySelector('.ocu-dialog-title')?.textContent?.trim()).toBe(STRINGS.interopWorkflowMemberAddAction);
    const select = host.querySelector('[data-interop-workflow-member-field="User"]') as HTMLSelectElement;
    // Mutation (Rule 19): pass no held names to the dialog -> the two users the list holds are offered and this goes red.
    expect([...select.options].map((option) => option.value).filter((value) => value !== '')).toEqual(['OcuP2417wC']);
  });

  it('posts the member to the role the route names in the namespace the shell is scoped to, closes, and publishes the created event', async () => {
    const created: JsonResult<unknown> = { kind: 'ok', status: 201, body: { id: ID, target: { type: 'interop-workflow-member', scope: 'USER', id: ID } } };
    const { fixture, host, actions, calls, events } = mount([created]);
    actions.run(INTEROP_WORKFLOW_MEMBER_LIST, INTEROP_WORKFLOW_MEMBER_ADD_ACTION);
    await settle(fixture);
    choose(fixture, host, 'User', 'OcuP2417wC');
    choose(fixture, host, 'Ranking', '2');
    (host.querySelector('[data-interop-workflow-member-confirm]') as HTMLButtonElement).click();
    await settle(fixture);
    const posts = calls.filter((call) => call.path !== READ_PATH);
    expect(posts.map((call) => [call.path, call.scope, JSON.parse(call.body)])).toEqual([
      ['/api/ocupilot/interop/workflow-members', 'USER', { Role: ROLE, User: 'OcuP2417wC', Ranking: 2 }],
    ]);
    expect(dialogs(host)).toBe(0);
    expect(events.map((event) => [event.type, event.action, event.tool])).toEqual([['interop-workflow-member', 'created', 'interop.workflowmembers.add']]);
  });

  it('opens nothing for a route that names no role', async () => {
    const { fixture, host, actions, calls } = mount([], `/${LIST.route}`);
    actions.run(INTEROP_WORKFLOW_MEMBER_LIST, INTEROP_WORKFLOW_MEMBER_ADD_ACTION);
    await settle(fixture);
    expect(dialogs(host)).toBe(0);
    expect(calls).toEqual([]);
  });

  it('warns before Remove, types no name, states what removing a member does, and sends the row key', async () => {
    // Mutation (Rule 19): drop the list's WARNING_CONSEQUENCES entry -> the action is sent at once or asks for a typed name and the kind assertion goes
    // red; point it at another sentence -> the consequence assertion goes red.
    const removed: JsonResult<unknown> = { kind: 'ok', status: 200, body: { action: 'deleted', target: { type: 'interop-workflow-member', scope: 'USER', id: ID } } };
    const { fixture, store, actions, handler, calls, events } = mount([removed]);
    store.setSelection([ID]);
    actions.run(INTEROP_WORKFLOW_MEMBER_LIST, 'remove');
    await settle(fixture);
    expect(handler.pending()?.kind).toBe('warning');
    expect(handler.pending()?.consequence).toBe(STRINGS.interopWorkflowMemberRemoveConsequence);
    expect(handler.pending()?.target).toBe(ID);
    expect(calls).toHaveLength(0);
    handler.confirmPending();
    await settle(fixture);
    expect(calls).toHaveLength(1);
    expect(calls[0].path).toBe(`/api/ocupilot/screens/${LIST.toolIdentifier}/action`);
    expect(JSON.parse(calls[0].body)).toEqual({ action: 'remove', id: ID });
    expect(events.map((event) => `${event.action} ${event.type}`)).toEqual(['deleted interop-workflow-member']);
  });

  it('leaves Add member to this page: the handler alone registers Remove', () => {
    configure([], `/${LIST.route}/${encodeEntityId(ROLE)}`);
    const actions = TestBed.inject(ScreenActions);
    TestBed.inject(ScreenActionHandler);
    expect(actions.has(INTEROP_WORKFLOW_MEMBER_LIST, 'remove')).toBe(true);
    expect(actions.has(INTEROP_WORKFLOW_MEMBER_LIST, INTEROP_WORKFLOW_MEMBER_ADD_ACTION)).toBe(false);
  });
});
