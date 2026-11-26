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
import { stubAccountPreferences } from '../../testing/account-preferences';
import { INTEROP_WORKFLOW_TASK_ASSIGN_ACTION, INTEROP_WORKFLOW_TASK_LIST, InteropWorkflowTaskListPage } from './interop-workflow-task-list.page';

/**
 * The Workflow tasks page (Story 24.17 Batch 4). The shared list page is replaced by an empty stand-in, so only this page's own wiring runs: the Assign action it registers, the
 * review it asks for first (which reads the selected task's assignee and priority and writes nothing), the read of the workflow users the dialog offers, the dialog that shows them,
 * the one request an assign sends -- the changed values, the task's ID its target -- a refusal kept in the dialog, and the change event an applied assign publishes. The handler, the
 * stores and the bus are real; only the server's answers are stubbed.
 */

@Component({ selector: 'app-list-page', template: '' })
class StubListPage {}

const LIST = SCREENS.find((screen) => screen.descriptor === INTEROP_WORKFLOW_TASK_LIST)!;

const WORKLIST = SCREENS.find((screen) => screen.descriptor === 'OcuPilot.Screen.Descriptor.InteropWorkflowWorklist')!;

const ROWS = [{ TaskId: '12', RoleName: 'Probe role', IsComplete: false, Status: 'Assigned', Priority: 3, AssignedTo: 'Probe', Namespace: 'USER' }];

const review = (values: Record<string, unknown>): JsonResult<unknown> => ({
  kind: 'ok',
  status: 200,
  body: { rows: [], review: { TaskId: '12', AssignedTo: 'Probe', Priority: 3, IsComplete: false, ...values } },
});

const USERS: JsonResult<unknown> = {
  kind: 'ok',
  status: 200,
  body: { rows: [{ Name: 'Admin', IsActive: true }, { Name: 'Probe', IsActive: true }, { Name: 'Gone', IsActive: false }] },
};

const ASSIGNED: JsonResult<unknown> = {
  kind: 'ok',
  status: 200,
  body: { action: 'updated', target: { type: 'interop-workflow-task', scope: 'USER', id: '12' }, readBack: { verdict: 'matches' } },
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
  readonly body: string;
}

/** Mount the page over `ROWS`, each request resolving to the next of `answers`. */
function mount(answers: JsonResult<unknown>[]) {
  TestBed.resetTestingModule();
  const calls: Call[] = [];
  const api = {
    requestJson: async <T,>(path: string, init: ApiRequestInit = {}): Promise<JsonResult<T>> => {
      calls.push({ path, body: init.body ?? '' });
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
  TestBed.overrideComponent(InteropWorkflowTaskListPage, { remove: { imports: [ListPage] }, add: { imports: [StubListPage] } });
  const store = stores.for(LIST.descriptor, LIST.refreshRates);
  store.applyTick(ROWS, false, '', new Date());
  const fixture = TestBed.createComponent(InteropWorkflowTaskListPage);
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  fixture.detectChanges();
  return { fixture, host: fixture.nativeElement as HTMLElement, store, calls, events, actions: TestBed.inject(ScreenActions) };
}

function choose(fixture: ComponentFixture<unknown>, host: HTMLElement, name: string, value: string): void {
  const control = host.querySelector(`[data-interop-workflow-task-field="${name}"]`) as HTMLSelectElement;
  control.value = value;
  control.dispatchEvent(new Event('change'));
  fixture.detectChanges();
}

const confirm = (host: HTMLElement): HTMLButtonElement => host.querySelector('[data-interop-workflow-task-confirm]') as HTMLButtonElement;

async function openDialog(fixture: ComponentFixture<unknown>, store: ReturnType<typeof mount>['store'], actions: ScreenActions, id = '12'): Promise<void> {
  store.setSelection(id === '' ? [] : [id]);
  actions.run(INTEROP_WORKFLOW_TASK_LIST, INTEROP_WORKFLOW_TASK_ASSIGN_ACTION);
  await settle(fixture);
}

afterEach(() => {
  for (const node of planted.splice(0)) node.remove();
  TestBed.resetTestingModule();
});

describe('the Workflow tasks page', () => {
  it('declares Assign and Cancel task as its row actions and no primary action, and the worklist none', () => {
    expect(LIST.primaryAction?.id).toBe('');
    expect(LIST.rowActions.map((action) => action.id)).toEqual(['assign', 'cancel']);
    expect(WORKLIST.rowActions).toEqual([]);
    expect(WORKLIST.primaryAction?.id).toBe('');
  });

  // Mutation (Rule 19): drop this page's `actions.register` of `assign` -> the first assertion goes red.
  it('registers Assign, reviews the selected task first, reads the workflow users and opens the dialog over what they answered', async () => {
    const { fixture, host, store, actions, calls } = mount([review({}), USERS]);
    expect(actions.has(INTEROP_WORKFLOW_TASK_LIST, INTEROP_WORKFLOW_TASK_ASSIGN_ACTION)).toBe(true);
    await openDialog(fixture, store, actions);
    expect(calls).toHaveLength(2);
    expect(calls[0].path).toBe(`/api/ocupilot/screens/${LIST.toolIdentifier}/dryrun`);
    expect(JSON.parse(calls[0].body)).toEqual({ action: INTEROP_WORKFLOW_TASK_ASSIGN_ACTION, id: '12' });
    expect(calls[1].path).toContain('interop.workflowusers');
    expect(host.querySelector('.ocu-dialog-title')?.textContent?.trim()).toBe(STRINGS.interopWorkflowTaskAssignTitle);
    const users = [...host.querySelectorAll('[data-interop-workflow-task-field="User"] option')].map((option) => (option as HTMLOptionElement).value);
    expect(users).toEqual(['', 'Probe', 'Admin']);
    expect((host.querySelector('[data-interop-workflow-task-field="User"]') as HTMLSelectElement).value).toBe('Probe');
    expect((host.querySelector('[data-interop-workflow-task-field="Priority"]') as HTMLSelectElement).value).toBe('3');
  });

  it('asks for nothing with no task selected', async () => {
    const { fixture, host, store, actions, calls } = mount([review({}), USERS]);
    await openDialog(fixture, store, actions, '');
    expect(calls).toHaveLength(0);
    expect(host.querySelector('app-interop-workflow-task-dialog')).toBeNull();
  });

  it('opens nothing and shows the refusal on the list when the review is refused, as for a task that is complete', async () => {
    const { fixture, host, store, actions, calls } = mount([
      { kind: 'error', status: 409, code: 'INTEROP.WORKFLOW.TASKCOMPLETE', reason: STRINGS.interopWorkflowTaskRefusalComplete } as JsonResult<unknown>,
    ]);
    await openDialog(fixture, store, actions);
    expect(calls).toHaveLength(1);
    expect(host.querySelector('app-interop-workflow-task-dialog')).toBeNull();
    expect(store.refusal()).toBe(STRINGS.interopWorkflowTaskRefusalComplete);
  });

  // Mutation (Rule 19): send the unchanged user with the priority -> the body assertion goes red.
  it('sends one Assign with only the changed values, the task\'s ID its target, closes on an applied assign and publishes the updated event', async () => {
    const { fixture, host, store, actions, calls, events } = mount([review({}), USERS, ASSIGNED]);
    await openDialog(fixture, store, actions);
    choose(fixture, host, 'Priority', '2');
    confirm(host).click();
    await settle(fixture);
    expect(calls).toHaveLength(3);
    expect(calls[2].path).toBe(`/api/ocupilot/screens/${LIST.toolIdentifier}/action`);
    expect(JSON.parse(calls[2].body)).toEqual({ action: INTEROP_WORKFLOW_TASK_ASSIGN_ACTION, id: '12', values: { Priority: '2' } });
    expect(host.querySelector('app-interop-workflow-task-dialog')).toBeNull();
    expect(events.map((event) => `${event.type}/${event.action}`)).toEqual(['interop-workflow-task/updated']);
  });

  it('sends an empty User for Unassigned', async () => {
    const { fixture, host, store, actions, calls } = mount([review({}), USERS, ASSIGNED]);
    await openDialog(fixture, store, actions);
    choose(fixture, host, 'User', '');
    confirm(host).click();
    await settle(fixture);
    expect(JSON.parse(calls[2].body)).toEqual({ action: INTEROP_WORKFLOW_TASK_ASSIGN_ACTION, id: '12', values: { User: '' } });
  });

  // Mutation (Rule 19): close the dialog on any answer -> the dialog assertion goes red.
  it('keeps the dialog open with the answer\'s sentence when the assign was refused, and publishes nothing', async () => {
    const { fixture, host, store, actions, events } = mount([
      review({}),
      USERS,
      { kind: 'error', status: 409, code: 'INTEROP.WORKFLOW.TASKUNCHANGED', reason: STRINGS.interopWorkflowTaskRefusalUnchanged } as JsonResult<unknown>,
    ]);
    await openDialog(fixture, store, actions);
    confirm(host).click();
    await settle(fixture);
    expect(host.querySelector('app-interop-workflow-task-dialog')).not.toBeNull();
    expect(host.querySelector('[data-interop-workflow-task-refusal]')?.textContent?.trim()).toBe(STRINGS.interopWorkflowTaskRefusalUnchanged);
    expect(events).toEqual([]);
  });

  it('closes on Cancel without sending, and opens no second dialog over the first', async () => {
    const { fixture, host, store, actions, calls } = mount([review({}), USERS, review({}), USERS]);
    await openDialog(fixture, store, actions);
    await openDialog(fixture, store, actions);
    expect(calls).toHaveLength(2);
    const cancel = [...host.querySelectorAll('.ocu-dialog-actions button')].find((button) => button.textContent?.trim() === STRINGS.actionCancel) as HTMLButtonElement;
    cancel.click();
    await settle(fixture);
    expect(host.querySelector('app-interop-workflow-task-dialog')).toBeNull();
    expect(calls).toHaveLength(2);
  });
});
