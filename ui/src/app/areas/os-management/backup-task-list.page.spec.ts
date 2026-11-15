import { Component } from '@angular/core';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type ApiRequestInit, type JsonResult } from '../../core/api';
import { ChangeBus, type ChangeEvent } from '../../core/change-bus';
import { OverlayStack } from '../../core/overlay-stack';
import { BACKUP_FREEZE_ACTION_ID, BACKUP_THAW_ACTION_ID, ScreenActions } from '../../core/screen-actions';
import { ScreenStores } from '../../core/screen-store';
import { SCREENS } from '../../core/screens.generated';
import { STRINGS } from '../../core/strings';
import { ListPage } from '../../shell/list-page';
import { BACKUP_TASK_LIST, BACKUP_WRITES_TARGET, ScreenActionHandler } from '../../shell/screen-action-handler';
import { stubAccountPreferences } from '../../testing/account-preferences';
import { BackupTaskListPage } from './backup-task-list.page';

/**
 * Backup tasks (Story 21.2). The shared list page is replaced by an empty stand-in, so only this page's own wiring runs: Freeze writes and Thaw
 * writes registered after the shell's handler, the warning that asks for the suspend limit, the one value each request carries, and the change
 * event an applied write publishes. The handler, the stores and the bus are real; only the server's answers are stubbed.
 */

@Component({ selector: 'app-list-page', template: '' })
class StubListPage {}

const LIST = SCREENS.find((screen) => screen.descriptor === BACKUP_TASK_LIST)!;

const ROWS = [{ Name: 'FullDBList', Type: 'Full', LastRun: '', Status: '', Description: 'Full backup', SystemTask: true, WritesFrozen: false }];

const APPLIED: JsonResult<unknown> = {
  kind: 'ok',
  status: 200,
  body: { action: 'updated', target: { type: 'backup-task', scope: 'instance', id: BACKUP_WRITES_TARGET }, readBack: { verdict: 'nothingSent' } },
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
  TestBed.overrideComponent(BackupTaskListPage, { remove: { imports: [ListPage] }, add: { imports: [StubListPage] } });
  const store = stores.for(LIST.descriptor, LIST.refreshRates);
  store.applyTick(ROWS, false, '', new Date());
  const fixture = TestBed.createComponent(BackupTaskListPage);
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  fixture.detectChanges();
  return { fixture, store, calls, events, actions: TestBed.inject(ScreenActions), handler: TestBed.inject(ScreenActionHandler) };
}

afterEach(() => {
  for (const node of planted.splice(0)) node.remove();
  document.querySelectorAll('app-screen-action-dialogs, .ocu-dialog').forEach((node) => node.remove());
  TestBed.resetTestingModule();
});

describe('the Backup tasks page', () => {
  // Mutation (Rule 19): drop this page's two `actions.register` calls -> both assertions go red, and no surface offers Freeze writes or Thaw writes.
  it('registers Freeze writes and Thaw writes after the handler, which registers Run', () => {
    const { actions } = mount([]);
    expect(actions.has(BACKUP_TASK_LIST, BACKUP_FREEZE_ACTION_ID)).toBe(true);
    expect(actions.has(BACKUP_TASK_LIST, BACKUP_THAW_ACTION_ID)).toBe(true);
    expect(actions.has(BACKUP_TASK_LIST, 'run')).toBe(true);
    // The declared freeze is the page's own id and is never drawn as a row action.
    expect(actions.has(BACKUP_TASK_LIST, 'freeze')).toBe(false);
  });

  it('a thaw is sent at once on the instance\'s writes, with no value, and publishes the updated event', async () => {
    const { fixture, actions, calls, events } = mount([APPLIED]);
    actions.run(BACKUP_TASK_LIST, BACKUP_THAW_ACTION_ID);
    await settle(fixture);
    expect(calls).toEqual([
      {
        path: '/api/ocupilot/screens/osmgmt.backuptasks/action',
        method: 'POST',
        body: JSON.stringify({ action: 'thaw', id: BACKUP_WRITES_TARGET }),
      },
    ]);
    expect(events.map((event) => `${event.type}/${event.scope}/${event.id}/${event.action}`)).toEqual([`backup-task/instance/${BACKUP_WRITES_TARGET}/updated`]);
  });

  // Mutation (Rule 19): drop `freeze` from WARNING_VALUES -> the dialog holds no limit field and the request carries no value.
  it('a freeze opens the warning that asks for the suspend limit and sends it as the one value', async () => {
    const { fixture, actions, calls, handler } = mount([APPLIED]);
    actions.run(BACKUP_TASK_LIST, BACKUP_FREEZE_ACTION_ID);
    await settle(fixture);
    const pending = handler.pending();
    expect(pending?.kind).toBe('warning');
    expect(pending?.consequence).toBe(STRINGS.backupFreezeConsequence);
    expect(pending?.fieldLabel).toBe(STRINGS.backupFreezeLimitLabel);
    expect(pending?.fieldHint).toBe(STRINGS.backupFreezeLimitHelp);
    expect(calls).toHaveLength(0);
    handler.confirmPending(false, '60');
    await settle(fixture);
    expect(calls).toEqual([
      {
        path: '/api/ocupilot/screens/osmgmt.backuptasks/action',
        method: 'POST',
        body: JSON.stringify({ action: 'freeze', id: BACKUP_WRITES_TARGET, values: { limit: '60' } }),
      },
    ]);
  });

  it('a run warns with the run note before it is sent, on the selected task', async () => {
    const { fixture, handler, store, calls } = mount([APPLIED]);
    handler.startFor(BACKUP_TASK_LIST, 'run', 'FullDBList', ROWS[0], store);
    await settle(fixture);
    expect(handler.pending()?.consequence).toBe(STRINGS.backupRunNote);
    expect(calls).toHaveLength(0);
    handler.confirmPending(false);
    await settle(fixture);
    expect(JSON.parse(calls[0].body)).toEqual({ action: 'run', id: 'FullDBList' });
  });
});
