import { Component } from '@angular/core';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type ApiRequestInit, type JsonResult } from '../../core/api';
import { ChangeBus, type ChangeEvent } from '../../core/change-bus';
import { OverlayStack } from '../../core/overlay-stack';
import { ScreenActions, TASK_IMPORT_ACTION_ID } from '../../core/screen-actions';
import { ScreenStores } from '../../core/screen-store';
import { SCREENS } from '../../core/screens.generated';
import { STRINGS } from '../../core/strings';
import { ListPage } from '../../shell/list-page';
import { LOCALE_LIST } from '../../shell/screen-action-handler';
import { stubAccountPreferences } from '../../testing/account-preferences';
import { LOCALE_EXPORT, LocaleListPage } from './locale-list.page';

/**
 * Locale definitions' export and import (Story 21.15, AD-21): the shared list page is replaced by an empty stand-in, so only this page's own
 * wiring runs -- the two actions it registers, the two System Explorer dialogs it opens with the locale's wording, and the requests they send
 * through the real `ScreenActionHandler`. Each action request is answered by a stub the test releases; the allowed directories read answers one
 * root.
 */

@Component({ selector: 'app-list-page', template: '' })
class StubListPage {}

const LIST = SCREENS.find((screen) => screen.descriptor === LOCALE_LIST)!;

const ROOT = '/data/';

const ROWS = [
  { Name: 'enuw', Description: 'English (United States) Unicode', Current: true, Custom: false },
  { Name: 'yzzw', Description: 'Custom locale', Current: false, Custom: true },
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
      { provide: ApiService, useValue: api as unknown as ApiService },
      { provide: ChangeBus, useValue: bus },
      { provide: ScreenStores, useValue: stores },
      { provide: ScreenActions, useValue: new ScreenActions() },
      { provide: OverlayStack, useValue: new OverlayStack() },
    ],
  });
  TestBed.overrideComponent(LocaleListPage, { remove: { imports: [ListPage] }, add: { imports: [StubListPage] } });
  const store = stores.for(LIST.descriptor, LIST.refreshRates);
  store.applyTick(ROWS, false, '', new Date());
  const fixture = TestBed.createComponent(LocaleListPage);
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

const status = (host: HTMLElement): string => host.querySelector('[data-locale-transfer-status]')?.textContent?.trim() ?? '';

const dialogRefusal = (host: HTMLElement): string => host.querySelector('[data-explorer-transfer-refusal]')?.textContent?.trim() ?? '';

afterEach(() => {
  for (const node of planted.splice(0)) node.remove();
  TestBed.resetTestingModule();
});

describe('the Locale definitions page export and import', () => {
  // Mutation (Rule 19): drop the list's UNDRAWN_ACTIONS transfer ids in the handler -> it registers `import` too and the last assertion goes red.
  it('declares the four transfer actions, of which the page registers Export and the screen-level Import and the handler none', () => {
    expect(LIST.rowActions.map((action) => action.id)).toEqual(['validate', 'install', 'delete', 'copy', 'export', 'export-browser', 'import', 'import-local']);
    const { actions } = mount();
    expect(actions.has(LOCALE_LIST, LOCALE_EXPORT)).toBe(true);
    expect(actions.has(LOCALE_LIST, TASK_IMPORT_ACTION_ID)).toBe(true);
    expect(['export-browser', 'import', 'import-local'].map((id) => actions.has(LOCALE_LIST, id))).toEqual([false, false, false]);
  });

  it('opens no export dialog without a selected locale, and titles it by the selected locale', async () => {
    const { fixture, host, store, actions } = mount();
    actions.run(LOCALE_LIST, LOCALE_EXPORT);
    await settle(fixture);
    expect(host.querySelector('app-explorer-export-dialog')).toBeNull();
    store.setSelection(['enuw']);
    actions.run(LOCALE_LIST, LOCALE_EXPORT);
    await settle(fixture);
    expect(host.querySelector('.ocu-dialog-title')?.textContent?.trim()).toBe('Export locale enuw');
    expect(host.querySelector('[data-explorer-export-replaces]')?.textContent?.trim()).toBe(STRINGS.taskExportReplaces);
  });

  it('exports the selected locale to a server file and says where it went', async () => {
    // Mutation (Rule 19): send `store.selection()[0]` in `onExport` -> the selection cleared under the open dialog sends nothing and this goes red.
    const { fixture, host, store, actions, calls, events } = mount();
    store.setSelection(['enuw']);
    actions.run(LOCALE_LIST, LOCALE_EXPORT);
    await settle(fixture);
    await typePath(fixture, host, 'out/enuw.xml');
    store.setSelection([]);
    await settle(fixture);
    (host.querySelector('[data-explorer-export-confirm]') as HTMLButtonElement).click();
    await settle(fixture);
    expect(calls).toHaveLength(1);
    expect(calls[0].path).toBe(`/api/ocupilot/screens/${LIST.toolIdentifier}/action`);
    expect(calls[0].body).toEqual({ action: 'export', id: 'enuw', values: { root: ROOT, path: 'out/enuw.xml' } });
    calls[0].answer({ kind: 'ok', status: 200, body: { action: 'updated', target: { type: 'locale', scope: 'instance', id: 'enuw' }, output: { root: ROOT, path: 'out/enuw.xml' } } });
    await settle(fixture);
    expect(host.querySelector('app-explorer-export-dialog')).toBeNull();
    expect(status(host)).toBe(`Exported locale enuw to ${ROOT}out/enuw.xml.`);
    expect(events.map((event) => `${event.action} ${event.type} ${event.id}`)).toEqual(['updated locale enuw']);
  });

  it('exports to this browser with no file, and saves the answered lines as <locale>.xml', async () => {
    const saved: { name: string; type: string; text: Promise<string> }[] = [];
    const realCreate = URL.createObjectURL;
    const realRevoke = URL.revokeObjectURL;
    const realClick = HTMLAnchorElement.prototype.click;
    URL.createObjectURL = (blob: Blob) => {
      saved.push({ name: '', type: blob.type, text: blob.text() });
      return 'blob:probe';
    };
    URL.revokeObjectURL = () => undefined;
    HTMLAnchorElement.prototype.click = function (this: HTMLAnchorElement) {
      saved[saved.length - 1].name = this.download;
    };
    try {
      const { fixture, host, store, actions, calls } = mount();
      store.setSelection(['enuw']);
      actions.run(LOCALE_LIST, LOCALE_EXPORT);
      await settle(fixture);
      const browserChoice = host.querySelector('input[data-explorer-export-destination="browser"]') as HTMLInputElement;
      browserChoice.checked = true;
      browserChoice.dispatchEvent(new Event('change'));
      await settle(fixture);
      expect(host.querySelector('app-server-path-picker')).toBeNull();
      (host.querySelector('[data-explorer-export-confirm]') as HTMLButtonElement).click();
      await settle(fixture);
      expect(calls[0].body).toEqual({ action: 'export-browser', id: 'enuw' });
      calls[0].answer({
        kind: 'ok',
        status: 200,
        body: { action: 'updated', target: { type: 'locale', scope: 'instance', id: 'enuw' }, output: { lines: ['<?xml version="1.0"?>', '<LocalesDeepExport>', '</LocalesDeepExport>'] } },
      });
      await settle(fixture);
      expect(saved.map((file) => [file.name, file.type])).toEqual([['enuw.xml', 'application/xml']]);
      expect(await saved[0].text).toBe('<?xml version="1.0"?>\n<LocalesDeepExport>\n</LocalesDeepExport>');
      expect(status(host)).toBe('Saved locale enuw as enuw.xml.');
    } finally {
      URL.createObjectURL = realCreate;
      URL.revokeObjectURL = realRevoke;
      HTMLAnchorElement.prototype.click = realClick;
    }
  });

  it('imports from a server file on the one import target, with no compile choice, and says what the instance imported', async () => {
    // Mutation (Rule 19): leave `compileOption` on in the import dialog -> its checkbox is drawn and the first assertion goes red.
    const { fixture, host, actions, calls } = mount();
    actions.run(LOCALE_LIST, TASK_IMPORT_ACTION_ID);
    await settle(fixture);
    expect(host.querySelector('input[data-explorer-import-compile]')).toBeNull();
    expect(host.querySelector('.ocu-dialog-title')?.textContent?.trim()).toBe(STRINGS.localeImportTitle);
    expect(host.querySelector('[data-explorer-import-replaces]')?.textContent?.trim()).toBe(STRINGS.localeImportReplaces);
    await typePath(fixture, host, 'in/locales.xml');
    (host.querySelector('[data-explorer-import-confirm]') as HTMLButtonElement).click();
    await settle(fixture);
    expect(calls).toHaveLength(1);
    expect(calls[0].body).toEqual({ action: 'import', id: 'import', values: { root: ROOT, path: 'in/locales.xml' } });
    calls[0].answer({
      kind: 'ok',
      status: 200,
      body: { action: 'updated', target: { type: 'locale', scope: 'instance', id: 'import' }, output: { Locales: 1, Tables: 2, SubTables: 3 } },
    });
    await settle(fixture);
    expect(host.querySelector('app-explorer-import-dialog')).toBeNull();
    expect(status(host)).toBe('Imported 1 locales, 2 tables and 3 subtables.');
  });

  it('imports the text this browser read on the one import target, and keeps the dialog open with the sentence a refusal gives', async () => {
    // Mutation (Rule 19): send a local file on `import` instead of `import-local` -> the body assertion goes red.
    const { fixture, host, actions, calls, page } = mount();
    actions.run(LOCALE_LIST, TASK_IMPORT_ACTION_ID);
    await settle(fixture);
    const sent = page.onImport({ source: 'local', fileName: 'yzzw.xml', content: '<LocalesDeepExport/>', compile: false });
    await settle(fixture);
    expect(calls[0].body).toEqual({ action: 'import-local', id: 'import', values: { fileName: 'yzzw.xml', content: '<LocalesDeepExport/>' } });
    calls[0].answer({ kind: 'error', status: 409, code: 'LOCALE.IMPORT.CHANGED', reason: STRINGS.localeRefusalImportChanged, detail: null });
    await sent;
    await settle(fixture);
    expect(host.querySelector('app-explorer-import-dialog')).not.toBeNull();
    expect(dialogRefusal(host)).toBe(STRINGS.localeRefusalImportChanged);
    expect(status(host)).toBe('');
  });
});
