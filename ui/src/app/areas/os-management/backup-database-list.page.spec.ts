import { Component } from '@angular/core';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type ApiRequestInit, type JsonResult } from '../../core/api';
import { ChangeBus, type ChangeEvent } from '../../core/change-bus';
import { OverlayStack } from '../../core/overlay-stack';
import { ScreenActions } from '../../core/screen-actions';
import { ScreenStores } from '../../core/screen-store';
import { SCREENS } from '../../core/screens.generated';
import { STRINGS } from '../../core/strings';
import { ListPage } from '../../shell/list-page';
import { BACKUP_ADD_DATABASE, BACKUP_DATABASE_LIST, ScreenActionHandler } from '../../shell/screen-action-handler';
import { stubAccountPreferences } from '../../testing/account-preferences';
import { BackupDatabaseListPage } from './backup-database-list.page';

/**
 * Backup database list (Story 21.2). The shared list page is replaced by an empty stand-in, so only this page's own wiring runs: Add database
 * registered after the shell's handler, its dialog, the request it sends -- the typed name as the action's target and no value -- a refusal kept
 * in the dialog, and the change event an applied add publishes. The handler, the stores and the bus are real; only the server's answers are
 * stubbed.
 */

@Component({ selector: 'app-list-page', template: '' })
class StubListPage {}

const LIST = SCREENS.find((screen) => screen.descriptor === BACKUP_DATABASE_LIST)!;

const APPLIED: JsonResult<unknown> = {
  kind: 'ok',
  status: 200,
  body: { action: 'updated', target: { type: 'backup-database', scope: 'instance', id: 'USER' }, readBack: { verdict: 'nothingSent' } },
};

const CONFLICT: JsonResult<unknown> = {
  kind: 'error',
  status: 409,
  reason: 'The backup list already reflects that change.',
  code: 'BACKUP.LIST.CONFLICT',
  violations: [],
  detail: null,
} as unknown as JsonResult<unknown>;

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
  TestBed.overrideComponent(BackupDatabaseListPage, { remove: { imports: [ListPage] }, add: { imports: [StubListPage] } });
  stores.for(LIST.descriptor, LIST.refreshRates).applyTick([{ Database: 'HSCUSTOM', Directory: '/durable/iris/mgr/hscustom/' }], false, '', new Date());
  const fixture = TestBed.createComponent(BackupDatabaseListPage);
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  fixture.detectChanges();
  return { fixture, host: fixture.nativeElement as HTMLElement, calls, events, actions: TestBed.inject(ScreenActions), handler: TestBed.inject(ScreenActionHandler) };
}

function type(fixture: ComponentFixture<unknown>, host: HTMLElement, text: string): void {
  const field = host.querySelector('.ocu-backup-database-name') as HTMLInputElement;
  field.value = text;
  field.dispatchEvent(new Event('input', { bubbles: true }));
  fixture.detectChanges();
}

function submit(host: HTMLElement): void {
  (host.querySelector('.ocu-backup-database-submit') as HTMLButtonElement).click();
}

afterEach(() => {
  for (const node of planted.splice(0)) node.remove();
  TestBed.resetTestingModule();
});

describe('the Backup database list page', () => {
  // Mutation (Rule 19): drop this page's `actions.register` of `add` -> the first assertion goes red, and no surface offers Add database.
  it('registers Add database, whose dialog opens over the list, beside the handler\'s Remove', async () => {
    const { fixture, host, actions } = mount([]);
    expect(actions.has(BACKUP_DATABASE_LIST, BACKUP_ADD_DATABASE)).toBe(true);
    expect(actions.has(BACKUP_DATABASE_LIST, 'removedatabase')).toBe(true);
    expect(host.querySelector('app-backup-add-database-dialog')).toBeNull();
    actions.run(BACKUP_DATABASE_LIST, BACKUP_ADD_DATABASE);
    await settle(fixture);
    expect(host.querySelector('.ocu-dialog-title')?.textContent?.trim()).toBe(STRINGS.backupAddDatabaseAction);
    expect(host.querySelector('label')?.textContent?.trim()).toBe(STRINGS.systemInfoDatabase);
    expect((host.querySelector('.ocu-backup-database-submit') as HTMLButtonElement).getAttribute('aria-disabled')).toBe('true');
  });

  it('sends the typed name as the target with no value, closes on an applied add and publishes the added database', async () => {
    const { fixture, host, actions, calls, events } = mount([APPLIED]);
    actions.run(BACKUP_DATABASE_LIST, BACKUP_ADD_DATABASE);
    await settle(fixture);
    type(fixture, host, ' USER ');
    expect((host.querySelector('.ocu-backup-database-submit') as HTMLButtonElement).getAttribute('aria-disabled')).toBeNull();
    submit(host);
    await settle(fixture);
    expect(calls).toEqual([
      { path: '/api/ocupilot/screens/osmgmt.backupdatabases/action', method: 'POST', body: JSON.stringify({ action: 'add', id: 'USER' }) },
    ]);
    expect(host.querySelector('app-backup-add-database-dialog')).toBeNull();
    expect(events.map((event) => `${event.type}/${event.scope}/${event.id}/${event.action}`)).toEqual(['backup-database/instance/USER/updated']);
  });

  it("keeps the instance's refusal in the dialog and publishes nothing", async () => {
    const { fixture, host, actions, events } = mount([CONFLICT]);
    actions.run(BACKUP_DATABASE_LIST, BACKUP_ADD_DATABASE);
    await settle(fixture);
    type(fixture, host, 'USER');
    submit(host);
    await settle(fixture);
    expect(host.querySelector('app-backup-add-database-dialog')).not.toBeNull();
    expect(host.querySelector('.ocu-backup-database-refusal')?.textContent?.trim()).toBe(STRINGS.backupRefusalListConflict);
    expect(events).toEqual([]);
  });
});
