import { Component } from '@angular/core';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type ApiRequestInit, type JsonResult } from '../../core/api';
import { ChangeBus } from '../../core/change-bus';
import { OverlayStack } from '../../core/overlay-stack';
import { ScopeService } from '../../core/scope';
import { ScreenActions, TASK_IMPORT_ACTION_ID } from '../../core/screen-actions';
import { ScreenStores } from '../../core/screen-store';
import { SCREENS } from '../../core/screens.generated';
import { STRINGS } from '../../core/strings';
import { ListPage } from '../../shell/list-page';
import { stubAccountPreferences } from '../../testing/account-preferences';
import { FOLDER_ITEM_EXPORT_ACTION, FOLDER_ITEM_LIST, FolderItemListPage, exportFileName } from './folder-item-list.page';

/**
 * The Folder items page's transfers (Story 24.10): the shared list page is replaced by an empty stand-in, so only this page's own wiring runs --
 * the actions it registers, the dialogs they open, the requests those send through the real `ScreenActionHandler` and what the page draws of each
 * answer. Each action request is answered by a stub the test releases; the allowed directories read answers one root.
 */

@Component({ selector: 'app-list-page', template: '' })
class StubListPage {}

const LIST = SCREENS.find((screen) => screen.descriptor === FOLDER_ITEM_LIST)!;

const ROOT = '/data/';

const ITEM = 'Sales/Q1 Review.dashboard';

const ROWS = [{ Name: ITEM, Type: 'Dashboard', Owner: '', Modified: '2026-11-17 09:00:00', Favorite: false }];

const planted: HTMLElement[] = [];

async function settle(fixture: ComponentFixture<unknown>): Promise<void> {
  for (let pass = 0; pass < 6; pass += 1) {
    await new Promise((resolve) => setTimeout(resolve, 5));
    fixture.detectChanges();
    await fixture.whenStable();
  }
}

/** One action request the page sent: its parsed body, and what releases its answer. */
interface ActionCall {
  readonly body: { readonly action: string; readonly id: string; readonly values?: Record<string, string> };
  readonly scope: string | null | undefined;
  answer(result: JsonResult<unknown>): void;
}

function mount() {
  TestBed.resetTestingModule();
  const calls: ActionCall[] = [];
  const api = {
    requestJson: async <T,>(path: string, init: ApiRequestInit = {}): Promise<JsonResult<T>> => {
      if (init.method === 'POST') {
        return new Promise<JsonResult<T>>((resolve) => {
          calls.push({ body: JSON.parse(String(init.body)), scope: init.scope, answer: (result) => resolve(result as JsonResult<T>) });
        });
      }
      if (path.includes('security.alloweddirectories')) {
        return { kind: 'ok', status: 200, body: { fields: [], rows: [{ Directory: ROOT, Restricted: true }], truncated: false, banner: '', criteria: {} } as T };
      }
      return { kind: 'ok', status: 200, body: { fields: [], rows: ROWS, truncated: false, banner: '', criteria: {} } as T };
    },
  };
  const stores = new ScreenStores({ account: stubAccountPreferences() });
  const bus = new ChangeBus();
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
  TestBed.overrideComponent(FolderItemListPage, { remove: { imports: [ListPage] }, add: { imports: [StubListPage] } });
  const store = stores.for(LIST.descriptor, LIST.refreshRates);
  store.applyTick(ROWS, false, '', new Date());
  const fixture = TestBed.createComponent(FolderItemListPage);
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  fixture.detectChanges();
  return { fixture, host: fixture.nativeElement as HTMLElement, store, calls, bus, actions: TestBed.inject(ScreenActions) };
}

async function typePath(fixture: ComponentFixture<unknown>, host: HTMLElement, value: string): Promise<void> {
  const input = host.querySelector('.ocu-path-picker input[type="text"]') as HTMLInputElement;
  input.value = value;
  input.dispatchEvent(new Event('input', { bubbles: true }));
  await settle(fixture);
}

const status = (host: HTMLElement): string => host.querySelector('[data-folder-item-transfer-status]')?.textContent?.trim() ?? '';

const dialogRefusal = (host: HTMLElement): string => host.querySelector('[data-explorer-transfer-refusal]')?.textContent?.trim() ?? '';

afterEach(() => {
  for (const node of planted.splice(0)) node.remove();
  TestBed.resetTestingModule();
});

describe('the Folder items page file name', () => {
  it('saves an item as its full name with the folder, the type and a space made safe, then .xml', () => {
    // Mutation (Rule 19): keep `/` in the name -> the first assertion goes red; keep `.` -> the second goes red.
    expect(exportFileName(ITEM)).toBe('Sales-Q1_Review-dashboard.xml');
    expect(exportFileName('a.b.pivot')).toBe('a-b-pivot.xml');
    expect(exportFileName('a:b*c')).toBe('a_b_c.xml');
    expect(exportFileName('')).toBe('folder-item.xml');
  });
});

describe('the Folder items page transfers', () => {
  it('registers Export and the screen-level Import, and opens Export only on a selected item', async () => {
    // Mutation (Rule 19): drop the Export registration from the page's constructor -> the first assertion goes red.
    const { fixture, host, store, actions } = mount();
    expect([FOLDER_ITEM_EXPORT_ACTION, TASK_IMPORT_ACTION_ID].map((id) => actions.has(FOLDER_ITEM_LIST, id))).toEqual([true, true]);
    actions.run(FOLDER_ITEM_LIST, FOLDER_ITEM_EXPORT_ACTION);
    await settle(fixture);
    expect(host.querySelector('app-explorer-export-dialog')).toBeNull();
    store.setSelection([ITEM]);
    actions.run(FOLDER_ITEM_LIST, FOLDER_ITEM_EXPORT_ACTION);
    await settle(fixture);
    expect(host.querySelector('.ocu-dialog-title')?.textContent?.trim()).toBe(`Export folder item ${ITEM}`);
    expect(host.querySelector('[data-explorer-export-replaces]')?.textContent?.trim()).toBe(STRINGS.analyticsFolderItemExportHelp);
  });

  it('draws a refused export\'s rule on the path field and keeps the dialog open with no status line, then closes on an applied one and says so', async () => {
    // Mutation (Rule 19): read the violation of field `root` in place of `path` in `endSend` -> the field assertion goes red.
    const { fixture, host, store, actions, calls } = mount();
    store.setSelection([ITEM]);
    actions.run(FOLDER_ITEM_LIST, FOLDER_ITEM_EXPORT_ACTION);
    await settle(fixture);
    await typePath(fixture, host, '../out.xml');
    (host.querySelector('[data-explorer-export-confirm]') as HTMLButtonElement).click();
    await settle(fixture);
    expect(calls[0].body).toEqual({ action: 'export', id: ITEM, values: { root: ROOT, path: '../out.xml' } });
    expect(calls[0].scope).toBe('USER');
    calls[0].answer({
      kind: 'error',
      status: 400,
      code: 'PATH.ESCAPES',
      reason: 'The path leaves the directory.',
      detail: { violations: [{ field: 'path', code: 'PATH.ESCAPES', reason: 'The path leaves the directory.' }] },
    } as JsonResult<unknown>);
    await settle(fixture);
    expect(host.querySelector('app-explorer-export-dialog')).not.toBeNull();
    expect(host.querySelector('.ocu-path-picker')?.textContent).toContain('The path leaves the directory.');
    expect(dialogRefusal(host)).toBe('');
    expect(status(host)).toBe('');
    await typePath(fixture, host, 'out.xml');
    (host.querySelector('[data-explorer-export-confirm]') as HTMLButtonElement).click();
    await settle(fixture);
    calls[1].answer({ kind: 'ok', status: 200, body: { action: 'updated', target: { type: 'folder-item', scope: 'USER', id: ITEM }, output: { root: ROOT, path: 'out.xml' } } });
    await settle(fixture);
    expect(host.querySelector('app-explorer-export-dialog')).toBeNull();
    expect(status(host)).toBe(`Exported ${ITEM}.`);
  });

  it('keeps the import dialog open with the instance\'s sentence when the file holds more than folder items, and counts the items it created when it does not', async () => {
    // Mutation (Rule 19): drop `refused.reason` from the page's `refusal.set` in `endSend` -> the sentence assertion goes red; read `Name` in place of `Count` -> the status goes red.
    const { fixture, host, actions, calls } = mount();
    actions.run(FOLDER_ITEM_LIST, TASK_IMPORT_ACTION_ID);
    await settle(fixture);
    expect(host.querySelector('input[data-explorer-import-compile]')).toBeNull();
    expect(host.querySelector('.ocu-dialog-title')?.textContent?.trim()).toBe(STRINGS.analyticsFolderItemImportTitle);
    expect(host.querySelector('[data-explorer-import-replaces]')?.textContent?.trim()).toBe(STRINGS.analyticsFolderItemImportHelp);
    await typePath(fixture, host, 'in/mixed.xml');
    (host.querySelector('[data-explorer-import-confirm]') as HTMLButtonElement).click();
    await settle(fixture);
    expect(calls[0].body).toEqual({ action: 'import', id: 'import', values: { root: ROOT, path: 'in/mixed.xml' } });
    calls[0].answer({ kind: 'error', status: 409, code: 'ANALYTICS.FOLDERITEM.IMPORTSHAPE', reason: STRINGS.analyticsRefusalFolderItemImportShape, detail: null });
    await settle(fixture);
    expect(host.querySelector('app-explorer-import-dialog')).not.toBeNull();
    expect(dialogRefusal(host)).toBe(STRINGS.analyticsRefusalFolderItemImportShape);
    expect(status(host)).toBe('');
    (host.querySelector('[data-explorer-import-confirm]') as HTMLButtonElement).click();
    await settle(fixture);
    calls[1].answer({ kind: 'ok', status: 200, body: { action: 'created', target: { type: 'folder-item', scope: 'USER', id: 'import' }, output: { Name: ITEM, Count: 2 } } });
    await settle(fixture);
    expect(host.querySelector('app-explorer-import-dialog')).toBeNull();
    expect(status(host)).toBe('Imported 2 folder items.');
  });

  it('sends a local file as import-local with its name and text, offering .xml and .dfi', async () => {
    // Mutation (Rule 19): send the local file under `import` in place of `import-local` in `onImport` -> the body assertion goes red.
    const { fixture, host, actions, calls } = mount();
    actions.run(FOLDER_ITEM_LIST, TASK_IMPORT_ACTION_ID);
    await settle(fixture);
    const local = host.querySelector('input[data-explorer-import-source="local"]') as HTMLInputElement;
    local.checked = true;
    local.dispatchEvent(new Event('change'));
    await settle(fixture);
    const input = host.querySelector('input[data-explorer-import-file]') as HTMLInputElement;
    expect(input.getAttribute('accept')).toBe('.xml,.dfi');
    Object.defineProperty(input, 'files', { value: [new File(['<dashboard/>'], 'made.xml')], configurable: true });
    input.dispatchEvent(new Event('change'));
    await settle(fixture);
    (host.querySelector('[data-explorer-import-confirm]') as HTMLButtonElement).click();
    await settle(fixture);
    expect(calls[0].body).toEqual({ action: 'import-local', id: 'import', values: { fileName: 'made.xml', content: '<dashboard/>' } });
  });

  it('says which item was deleted when a deletion of a folder item is published, and only then', async () => {
    // Mutation (Rule 19): test `event.action === 'created'` in the page's bus subscription -> the first assertion goes red; drop the type test -> the last goes red.
    const { fixture, host, bus } = mount();
    bus.publish({ kind: 'changed', type: 'folder-item', scope: 'USER', id: ITEM, action: 'created' });
    await settle(fixture);
    expect(status(host)).toBe('');
    bus.publish({ kind: 'changed', type: 'folder-item', scope: 'USER', id: ITEM, action: 'deleted' });
    await settle(fixture);
    expect(status(host)).toBe(`Deleted ${ITEM}.`);
    bus.publish({ kind: 'changed', type: 'term-list', scope: 'USER', id: 'Other.List', action: 'deleted' });
    await settle(fixture);
    expect(status(host)).toBe(`Deleted ${ITEM}.`);
  });
});
