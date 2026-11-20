import { Component } from '@angular/core';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { provideRouter } from '@angular/router';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type ApiRequestInit, type JsonResult } from '../../core/api';
import { ChangeBus, type ChangeEvent } from '../../core/change-bus';
import { FormDirty } from '../../core/form-dirty';
import { OverlayStack } from '../../core/overlay-stack';
import { ScreenActions, TASK_IMPORT_ACTION_ID } from '../../core/screen-actions';
import { ScreenStores } from '../../core/screen-store';
import { SCREENS } from '../../core/screens.generated';
import { STRINGS } from '../../core/strings';
import { ListPage } from '../../shell/list-page';
import { RESOURCE_LIST } from '../../shell/screen-action-handler';
import { stubAccountPreferences } from '../../testing/account-preferences';
import { RESOURCE_EXPORT, RESOURCE_EXPORT_ALL, ResourceListPage } from './resource-list.page';

/**
 * The Resources list's export and import (Story 21.19, AD-21): the shared list page is replaced by an empty stand-in, so only this page's own
 * wiring runs -- the three actions it registers, the System Explorer dialogs it opens with the resources' wording, and the requests they send
 * through the real `ScreenActionHandler`. Each action request is answered by a stub the test releases; the allowed directories read answers one root.
 */

@Component({ selector: 'app-list-page', template: '' })
class StubListPage {}

const LIST = SCREENS.find((screen) => screen.descriptor === RESOURCE_LIST)!;

const ROOT = '/data/';

const ROWS = [
  { Name: 'ProbeA', Description: 'first', PublicPermission: 'R', ResourceType: 'User', AllowDelete: true },
  { Name: '%DB_IRISSYS', Description: 'system', PublicPermission: '', ResourceType: 'System', AllowDelete: false },
];

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
  readonly path: string;
  readonly body: { readonly action: string; readonly id: string; readonly values?: Record<string, string> };
  answer(result: JsonResult<unknown>): void;
}

function mount() {
  TestBed.resetTestingModule();
  const calls: ActionCall[] = [];
  const api = {
    requestJson: async <T,>(path: string, init: ApiRequestInit = {}): Promise<JsonResult<T>> => {
      if (init.method === 'POST') {
        return new Promise<JsonResult<T>>((resolve) => {
          calls.push({ path, body: JSON.parse(String(init.body)), answer: (result) => resolve(result as JsonResult<T>) });
        });
      }
      if (path.includes('security.alloweddirectories')) {
        return { kind: 'ok', status: 200, body: { fields: [], rows: [{ Directory: ROOT, Restricted: true }], truncated: false, banner: '', criteria: {} } as T };
      }
      return { kind: 'ok', status: 200, body: { fields: [], rows: ROWS, truncated: false, banner: '', criteria: {} } as T };
    },
  };
  const bus = new ChangeBus();
  const events: ChangeEvent[] = [];
  bus.subscribe((event) => events.push(event));
  const stores = new ScreenStores({ account: stubAccountPreferences() });
  TestBed.configureTestingModule({
    providers: [
      provideRouter([{ path: '**', children: [] }]),
      { provide: ApiService, useValue: api as unknown as ApiService },
      { provide: ChangeBus, useValue: bus },
      { provide: FormDirty, useValue: new FormDirty() },
      { provide: ScreenStores, useValue: stores },
      { provide: ScreenActions, useValue: new ScreenActions() },
      { provide: OverlayStack, useValue: new OverlayStack() },
    ],
  });
  TestBed.overrideComponent(ResourceListPage, { remove: { imports: [ListPage] }, add: { imports: [StubListPage] } });
  const store = stores.for(LIST.descriptor, LIST.refreshRates);
  store.applyTick(ROWS, false, '', new Date());
  const fixture = TestBed.createComponent(ResourceListPage);
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  fixture.detectChanges();
  return { fixture, host: fixture.nativeElement as HTMLElement, store, calls, events, actions: TestBed.inject(ScreenActions), page: fixture.componentInstance as unknown as TransferPage };
}

/** The page's own transfer methods, which the dialogs call. */
interface TransferPage {
  onImport(choice: { readonly source: 'local'; readonly fileName: string; readonly content: string; readonly compile: boolean }): Promise<void>;
}

/** Type `value` into the open dialog's server-path name field. */
async function typePath(fixture: ComponentFixture<unknown>, host: HTMLElement, value: string): Promise<void> {
  const input = host.querySelector('.ocu-path-picker input[type="text"]') as HTMLInputElement;
  input.value = value;
  input.dispatchEvent(new Event('input', { bubbles: true }));
  await settle(fixture);
}

const status = (host: HTMLElement): string => host.querySelector('[data-resource-transfer-status]')?.textContent?.trim() ?? '';

const dialogRefusal = (host: HTMLElement): string => host.querySelector('[data-explorer-transfer-refusal]')?.textContent?.trim() ?? '';

afterEach(() => {
  for (const node of planted.splice(0)) node.remove();
  TestBed.resetTestingModule();
});

describe('the Resources list page export and import', () => {
  // Mutation (Rule 19): drop the list's UNDRAWN_ACTIONS transfer ids in the handler -> it registers `import` too and the last assertion goes red.
  it('declares the four transfer actions, of which the page registers Export, Export all and the screen-level Import and the handler none', () => {
    expect(LIST.rowActions.map((action) => action.id)).toEqual(['delete', 'export', 'export-all', 'import', 'import-local']);
    const { actions } = mount();
    expect(actions.has(RESOURCE_LIST, RESOURCE_EXPORT)).toBe(true);
    expect(actions.has(RESOURCE_LIST, RESOURCE_EXPORT_ALL)).toBe(true);
    expect(actions.has(RESOURCE_LIST, TASK_IMPORT_ACTION_ID)).toBe(true);
    expect(['import', 'import-local'].map((id) => actions.has(RESOURCE_LIST, id))).toEqual([false, false]);
  });

  it('opens no export dialog on a selected resource without one, and offers a server file alone', async () => {
    const { fixture, host, store, actions } = mount();
    actions.run(RESOURCE_LIST, RESOURCE_EXPORT);
    await settle(fixture);
    expect(host.querySelector('app-explorer-export-dialog')).toBeNull();
    store.setSelection(['ProbeA']);
    actions.run(RESOURCE_LIST, RESOURCE_EXPORT);
    await settle(fixture);
    expect(host.querySelector('.ocu-dialog-title')?.textContent?.trim()).toBe(STRINGS.resourceExportTitle);
    expect(host.querySelector('input[data-explorer-export-destination="browser"]')).toBeNull();
    expect(host.querySelector('app-server-path-picker')).not.toBeNull();
  });

  it('exports the selected resource to a server file and says where it went', async () => {
    // Mutation (Rule 19): send `store.selection()[0]` in `onExport` -> the selection cleared under the open dialog sends nothing and this goes red.
    const { fixture, host, store, actions, calls, events } = mount();
    store.setSelection(['ProbeA']);
    actions.run(RESOURCE_LIST, RESOURCE_EXPORT);
    await settle(fixture);
    await typePath(fixture, host, 'out/one.xml');
    store.setSelection([]);
    await settle(fixture);
    (host.querySelector('[data-explorer-export-confirm]') as HTMLButtonElement).click();
    await settle(fixture);
    expect(calls).toHaveLength(1);
    expect(calls[0].path).toBe(`/api/ocupilot/screens/${LIST.toolIdentifier}/action`);
    expect(calls[0].body).toEqual({ action: 'export', id: 'ProbeA', values: { root: ROOT, path: 'out/one.xml' } });
    calls[0].answer({ kind: 'ok', status: 200, body: { action: 'updated', target: { type: 'resource', scope: 'instance', id: 'ProbeA' }, output: { root: ROOT, path: 'out/one.xml', Count: 1 } } });
    await settle(fixture);
    expect(host.querySelector('app-explorer-export-dialog')).toBeNull();
    expect(status(host)).toBe(`Resources exported to ${ROOT}out/one.xml: 1.`);
    expect(events.map((event) => `${event.action} ${event.type} ${event.id}`)).toEqual(['updated resource ProbeA']);
  });

  it('exports every resource on the all target, with no resource selected', async () => {
    // Mutation (Rule 19): send `export` in place of `export-all` for the all target -> the body assertion goes red.
    const { fixture, host, actions, calls } = mount();
    actions.run(RESOURCE_LIST, RESOURCE_EXPORT_ALL);
    await settle(fixture);
    await typePath(fixture, host, 'out/all.xml');
    (host.querySelector('[data-explorer-export-confirm]') as HTMLButtonElement).click();
    await settle(fixture);
    expect(calls[0].body).toEqual({ action: 'export-all', id: '*', values: { root: ROOT, path: 'out/all.xml' } });
    calls[0].answer({ kind: 'ok', status: 200, body: { action: 'updated', target: { type: 'resource', scope: 'instance', id: '*' }, output: { root: ROOT, path: 'out/all.xml', Count: 186 } } });
    await settle(fixture);
    expect(status(host)).toBe(`Resources exported to ${ROOT}out/all.xml: 186.`);
  });

  it('imports from a server file on the one import target, with no compile choice, and says what the instance imported', async () => {
    // Mutation (Rule 19): leave `compileOption` on in the import dialog -> its checkbox is drawn and the first assertion goes red.
    const { fixture, host, actions, calls } = mount();
    actions.run(RESOURCE_LIST, TASK_IMPORT_ACTION_ID);
    await settle(fixture);
    expect(host.querySelector('input[data-explorer-import-compile]')).toBeNull();
    expect(host.querySelector('.ocu-dialog-title')?.textContent?.trim()).toBe(STRINGS.resourceImportTitle);
    expect(host.querySelector('[data-explorer-import-replaces]')?.textContent?.trim()).toBe(STRINGS.resourceImportReplaces);
    await typePath(fixture, host, 'in/resources.xml');
    (host.querySelector('[data-explorer-import-confirm]') as HTMLButtonElement).click();
    await settle(fixture);
    expect(calls).toHaveLength(1);
    expect(calls[0].body).toEqual({ action: 'import', id: 'import', values: { root: ROOT, path: 'in/resources.xml' } });
    calls[0].answer({ kind: 'ok', status: 200, body: { action: 'updated', target: { type: 'resource', scope: 'instance', id: 'import' }, output: { Count: 3 } } });
    await settle(fixture);
    expect(host.querySelector('app-explorer-import-dialog')).toBeNull();
    expect(status(host)).toBe('Resources imported: 3.');
  });

  it('imports the text this browser read on the one import target, and keeps the dialog open with the sentence a refusal gives', async () => {
    // Mutation (Rule 19): send a local file on `import` instead of `import-local` -> the body assertion goes red.
    const { fixture, host, actions, calls, page } = mount();
    actions.run(RESOURCE_LIST, TASK_IMPORT_ACTION_ID);
    await settle(fixture);
    const sent = page.onImport({ source: 'local', fileName: 'resources.xml', content: '<ResourcesExport/>', compile: false });
    await settle(fixture);
    expect(calls[0].body).toEqual({ action: 'import-local', id: 'import', values: { fileName: 'resources.xml', content: '<ResourcesExport/>' } });
    calls[0].answer({ kind: 'error', status: 409, code: 'RESOURCEFILE.CHANGED', reason: STRINGS.resourceFileRefusalChanged, detail: null });
    await sent;
    await settle(fixture);
    expect(host.querySelector('app-explorer-import-dialog')).not.toBeNull();
    expect(dialogRefusal(host)).toBe(STRINGS.resourceFileRefusalChanged);
    expect(status(host)).toBe('');
  });
});
