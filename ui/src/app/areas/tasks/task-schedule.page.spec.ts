import { Component } from '@angular/core';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type ApiRequestInit, type JsonResult } from '../../core/api';
import { ChangeBus, type ChangeEvent } from '../../core/change-bus';
import { OverlayStack } from '../../core/overlay-stack';
import { ScreenActions, TASK_IMPORT_ACTION_ID, TASK_MANAGER_SUSPEND_ACTION_ID } from '../../core/screen-actions';
import { ScreenStores } from '../../core/screen-store';
import { SCREENS } from '../../core/screens.generated';
import { STRINGS } from '../../core/strings';
import { ListPage } from '../../shell/list-page';
import {
  ScreenActionHandler,
  TASK_EXPORT,
  TASK_MANAGER_RESUME,
  TASK_MANAGER_START,
  TASK_MANAGER_SUSPEND,
  TASK_MANAGER_TARGET,
  TASK_SCHEDULE,
} from '../../shell/screen-action-handler';
import { stubAccountPreferences } from '../../testing/account-preferences';
import { TaskSchedulePage } from './task-schedule.page';

/**
 * The Task schedule page's Export and Import (Story 16.4, AC1, AC2, AC4, AC6, AC9). The shared list
 * page is replaced by an empty stand-in, so only this page's own wiring runs: the two actions it
 * registers after the shell's handler, one dialog at a time, the one request each sends with the
 * file as its two values, a refusal drawn on its field or in the dialog, and the done line. The
 * handler, the stores and the bus are real; only the server's answers are stubbed.
 */

@Component({ selector: 'app-list-page', template: '' })
class StubListPage {}

const SCHEDULE = SCREENS.find((screen) => screen.descriptor === TASK_SCHEDULE)!;

const ROOT = '/durable/iris/mgr/';

const ROWS = [
  { Id: '12', Name: 'OcuP164Nightly', Namespace: '%SYS', Type: 'User' },
  { Id: '13', Name: 'OcuP164Weekly', Namespace: '%SYS', Type: 'User' },
  { Id: '14', Name: 'OcuP164 $& run', Namespace: '%SYS', Type: 'User' },
];

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

/** Mount the page; each action request answers the next of `answers`, and every read the one allowed root. */
function mount(answers: JsonResult<unknown>[]) {
  TestBed.resetTestingModule();
  const calls: Call[] = [];
  const api = {
    requestJson: async <T,>(path: string, init: ApiRequestInit = {}): Promise<JsonResult<T>> => {
      if (!path.endsWith('/action')) {
        return { kind: 'ok', status: 200, body: { fields: ['Directory'], rows: [{ Directory: ROOT }], truncated: false, banner: '' } } as JsonResult<T>;
      }
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
    ],
  });
  TestBed.overrideComponent(TaskSchedulePage, { remove: { imports: [ListPage] }, add: { imports: [StubListPage] } });
  const store = stores.for(SCHEDULE.descriptor, SCHEDULE.refreshRates);
  store.applyTick(ROWS, false, '', new Date());
  const fixture = TestBed.createComponent(TaskSchedulePage);
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  fixture.detectChanges();
  return { fixture, host: fixture.nativeElement as HTMLElement, store, calls, events, actions: TestBed.inject(ScreenActions) };
}

function line(host: HTMLElement): string {
  return host.querySelector('[data-task-transfer-status]')?.textContent?.trim() ?? '';
}

/** Type `name` into the open dialog's file name and press its primary action. */
async function submit(fixture: ComponentFixture<unknown>, host: HTMLElement, name: string, confirm: string): Promise<void> {
  const input = host.querySelector('input.ocu-field-input') as HTMLInputElement;
  input.value = name;
  input.dispatchEvent(new Event('input'));
  await settle(fixture);
  (host.querySelector(confirm) as HTMLButtonElement).click();
  await settle(fixture);
}

afterEach(() => {
  for (const node of planted.splice(0)) node.remove();
  TestBed.resetTestingModule();
});

describe('the Task schedule page', () => {
  // Story 16.11: the page registers the Task Manager's three actions -- Suspend at screen level,
  // Resume and Start under the ids the banner names -- each on the literal target, reporting to the
  // list's store; Suspend waits on its warning, the other two are sent at once, and none starts over
  // one of this page's own dialogs.
  //
  // Mutation (Rule 19): drop this page's registration of TASK_MANAGER_SUSPEND_ACTION_ID -> the first
  // assertion goes red, and the command bar draws no Suspend Task Manager.
  it('Story 16.11: registers the Task Manager\u2019s three actions on the literal target', async () => {
    const { fixture, host, actions, calls } = mount([]);
    const handler = TestBed.inject(ScreenActionHandler);
    expect(actions.has(TASK_SCHEDULE, TASK_MANAGER_SUSPEND_ACTION_ID)).toBe(true);
    expect(actions.has(TASK_SCHEDULE, TASK_MANAGER_RESUME)).toBe(true);
    expect(actions.has(TASK_SCHEDULE, TASK_MANAGER_START)).toBe(true);
    expect(actions.has(TASK_SCHEDULE, TASK_MANAGER_SUSPEND)).toBe(false);

    actions.run(TASK_SCHEDULE, TASK_MANAGER_SUSPEND_ACTION_ID);
    await settle(fixture);
    expect(handler.pending()?.kind).toBe('warning');
    expect(handler.pending()?.actionId).toBe(TASK_MANAGER_SUSPEND);
    expect(handler.pending()?.target).toBe(TASK_MANAGER_TARGET);
    expect(calls).toHaveLength(0);
    handler.cancelPending();

    actions.run(TASK_SCHEDULE, TASK_MANAGER_RESUME);
    await settle(fixture);
    actions.run(TASK_SCHEDULE, TASK_MANAGER_START);
    await settle(fixture);
    expect(calls.map((call) => JSON.parse(call.body))).toEqual([
      { action: TASK_MANAGER_RESUME, id: TASK_MANAGER_TARGET },
      { action: TASK_MANAGER_START, id: TASK_MANAGER_TARGET },
    ]);

    // Over the import dialog nothing starts.
    actions.run(TASK_SCHEDULE, TASK_IMPORT_ACTION_ID);
    await settle(fixture);
    expect(host.querySelector('.ocu-dialog-title')?.textContent?.trim()).toBe(STRINGS.taskImportTitle);
    actions.run(TASK_SCHEDULE, TASK_MANAGER_START);
    await settle(fixture);
    expect(calls).toHaveLength(2);
  });

  it('registers Export on the selected task and a screen-level Import, and opens one dialog at a time', async () => {
    // Mutation (Rule 19): drop this page's `actions.register` of TASK_IMPORT_ACTION_ID -> the first
    // assertion goes red, and no surface offers Import.
    const { fixture, host, store, actions, calls } = mount([]);
    expect(actions.has(TASK_SCHEDULE, TASK_IMPORT_ACTION_ID)).toBe(true);
    expect(actions.has(TASK_SCHEDULE, TASK_EXPORT)).toBe(true);
    expect(actions.has(TASK_SCHEDULE, 'import')).toBe(false);
    actions.run(TASK_SCHEDULE, TASK_EXPORT);
    await settle(fixture);
    expect(host.querySelector('app-task-export-dialog')).toBeNull();
    store.setSelection(['12']);
    actions.run(TASK_SCHEDULE, TASK_EXPORT);
    await settle(fixture);
    expect(host.querySelector('.ocu-dialog-title')?.textContent?.trim()).toBe(STRINGS.taskExportTitle.replace('<task>', 'OcuP164Nightly'));
    actions.run(TASK_SCHEDULE, TASK_IMPORT_ACTION_ID);
    await settle(fixture);
    expect(host.querySelectorAll('[role="dialog"]')).toHaveLength(1);
    expect(host.querySelector('app-task-import-dialog')).toBeNull();
    (host.querySelector('.ocu-dialog-actions .ocu-button-secondary') as HTMLButtonElement).click();
    await settle(fixture);
    actions.run(TASK_SCHEDULE, TASK_IMPORT_ACTION_ID);
    await settle(fixture);
    expect(host.querySelector('.ocu-dialog-title')?.textContent?.trim()).toBe(STRINGS.taskImportTitle);
    expect(calls).toHaveLength(0);
  });

  it('AC1, AC9: Export sends the selected task with the root and the name, closes, and reads the done line', async () => {
    // Mutation (Rule 19): the page's `sendFor` omits `path` -> the request body goes red.
    const { fixture, host, store, actions, calls, events } = mount([
      { kind: 'ok', status: 200, body: { action: 'updated', target: { type: 'task', scope: 'instance', id: '12' } } },
    ]);
    store.setSelection(['12']);
    actions.run(TASK_SCHEDULE, TASK_EXPORT);
    await settle(fixture);
    await submit(fixture, host, 'out/nightly.xml', '[data-task-export-confirm]');
    expect(calls).toHaveLength(1);
    expect(calls[0].path).toBe(`/api/ocupilot/screens/${SCHEDULE.toolIdentifier}/action`);
    expect(JSON.parse(calls[0].body)).toEqual({ action: 'export', id: '12', values: { root: ROOT, path: 'out/nightly.xml' } });
    expect(host.querySelector('[role="dialog"]')).toBeNull();
    expect(line(host)).toBe(STRINGS.taskExportDone.replace('<task>', 'OcuP164Nightly').replace('<path>', `${ROOT}out/nightly.xml`));
    expect(events.map(({ type, id, action }) => ({ type, id, action }))).toEqual([{ type: 'task', id: '12', action: 'updated' }]);
  });

  it('AC4: a refusal on the name is drawn on that field, the dialog stays open, and nothing is published', async () => {
    const { fixture, host, store, actions, events } = mount([
      {
        kind: 'error',
        status: 400,
        code: 'PATH.EXISTS',
        reason: 'A directory stands at that name.',
        detail: { violations: [{ field: 'path', code: 'PATH.EXISTS', reason: 'A directory stands at that name.' }] },
      },
    ]);
    store.setSelection(['13']);
    actions.run(TASK_SCHEDULE, TASK_EXPORT);
    await settle(fixture);
    await submit(fixture, host, 'adir', '[data-task-export-confirm]');
    expect(host.querySelector('[role="dialog"]')).not.toBeNull();
    expect(Array.from(host.querySelectorAll('.ocu-form-error')).map((node) => node.textContent?.trim())).toEqual(['A directory stands at that name.']);
    expect(host.querySelector('[data-task-transfer-refusal]')).toBeNull();
    expect(store.refusal()).toBe('');
    expect(line(host)).toBe('');
    expect(events).toEqual([]);
  });

  it('AC2, AC6: Import sends the import target, an import refused over one task names it in the dialog, and an applied one reads the done line', async () => {
    // Mutation (Rule 19, AC9): the handler publishes no change event for Import -> the last assertion
    // goes red, and the list is never told to re-read.
    const { fixture, host, actions, calls, events } = mount([
      {
        kind: 'error',
        status: 422,
        code: 'TASK.RUNASUSER.SECURE',
        reason: 'Running a task as another account needs %Admin_Secure:USE, which you do not hold.',
        detail: { task: 'OcuP164Other' },
      },
      { kind: 'error', status: 409, code: 'TASK.IMPORT.PRESENT', reason: 'Every task in this file is already on this instance.', detail: null },
      { kind: 'ok', status: 200, body: { action: 'created', target: { type: 'task', scope: 'instance', id: 'import' } } },
    ]);
    actions.run(TASK_SCHEDULE, TASK_IMPORT_ACTION_ID);
    await settle(fixture);
    await submit(fixture, host, 'in/tasks.xml', '[data-task-import-confirm]');
    expect(JSON.parse(calls[0].body)).toEqual({ action: 'import', id: 'import', values: { root: ROOT, path: 'in/tasks.xml' } });
    const refused = STRINGS.taskImportRefused
      .replace('<task>', 'OcuP164Other')
      .replace('<reason>', 'Running a task as another account needs %Admin_Secure:USE, which you do not hold.');
    expect(host.querySelector('[data-task-transfer-refusal]')?.textContent?.trim()).toBe(refused);
    (host.querySelector('[data-task-import-confirm]') as HTMLButtonElement).click();
    await settle(fixture);
    expect(host.querySelector('[data-task-transfer-refusal]')?.textContent?.trim()).toBe('Every task in this file is already on this instance.');
    (host.querySelector('[data-task-import-confirm]') as HTMLButtonElement).click();
    await settle(fixture);
    expect(calls).toHaveLength(3);
    expect(host.querySelector('[role="dialog"]')).toBeNull();
    expect(line(host)).toBe(STRINGS.taskImportDone.replace('<path>', `${ROOT}in/tasks.xml`));
    expect(events.map(({ type, id, action }) => ({ type, id, action }))).toEqual([{ type: 'task', id: 'import', action: 'created' }]);
  });

  it('AC4: a refusal on the directory is drawn on that field, the dialog stays open, and nothing else shows it', async () => {
    // Mutation (Rule 19): `showRefusal` sets the root field's reason to '' -> red.
    const reason = 'That directory is not one of the allowed directories.';
    const { fixture, host, actions, events } = mount([
      { kind: 'error', status: 400, code: 'PATH.ROOT', reason, detail: { violations: [{ field: 'root', code: 'PATH.ROOT', reason }] } },
    ]);
    actions.run(TASK_SCHEDULE, TASK_IMPORT_ACTION_ID);
    await settle(fixture);
    await submit(fixture, host, 'in/tasks.xml', '[data-task-import-confirm]');
    expect(host.querySelector('[role="dialog"]')).not.toBeNull();
    expect(Array.from(host.querySelectorAll('.ocu-form-error')).map((node) => node.textContent?.trim())).toEqual([reason]);
    expect(host.querySelector('select')?.getAttribute('aria-invalid')).toBe('true');
    expect(host.querySelector('[data-task-transfer-refusal]')).toBeNull();
    expect(events).toEqual([]);
  });

  it('inserts a task name as it is, whatever placeholder or replacement pattern it holds', async () => {
    // Mutation (Rule 19): the dialog's title substitutes with a string replacement, or the page's
    // `fill` substitutes one placeholder after another -> red.
    const name = 'OcuP164 <reason> $& run';
    const { fixture, host, store, actions } = mount([
      { kind: 'error', status: 422, code: 'TASK.NAMESPACE.UNKNOWN', reason: 'Refused.', detail: { task: name } },
    ]);
    store.setSelection(['14']);
    actions.run(TASK_SCHEDULE, TASK_EXPORT);
    await settle(fixture);
    expect(host.querySelector('.ocu-dialog-title')?.textContent?.trim()).toBe(STRINGS.taskExportTitle.split('<task>').join('OcuP164 $& run'));
    (host.querySelector('.ocu-dialog-actions .ocu-button-secondary') as HTMLButtonElement).click();
    await settle(fixture);
    actions.run(TASK_SCHEDULE, TASK_IMPORT_ACTION_ID);
    await settle(fixture);
    await submit(fixture, host, 'in/tasks.xml', '[data-task-import-confirm]');
    expect(host.querySelector('[data-task-transfer-refusal]')?.textContent?.trim()).toBe(
      STRINGS.taskImportRefused.split('<reason>').join('Refused.').split('<task>').join(name)
    );
  });
});
