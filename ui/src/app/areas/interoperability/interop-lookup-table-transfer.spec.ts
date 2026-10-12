import { Component } from '@angular/core';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type ApiRequestInit, type JsonResult } from '../../core/api';
import { ChangeBus, type ChangeEvent } from '../../core/change-bus';
import { OverlayStack } from '../../core/overlay-stack';
import { ScopeService } from '../../core/scope';
import { ScreenActions, TASK_IMPORT_ACTION_ID, actionLabel } from '../../core/screen-actions';
import { ScreenStores } from '../../core/screen-store';
import { SCREENS } from '../../core/screens.generated';
import { STRINGS } from '../../core/strings';
import { ListPage } from '../../shell/list-page';
import { stubAccountPreferences } from '../../testing/account-preferences';
import {
  INTEROP_LOOKUP_EXPORT_ACTION,
  INTEROP_LOOKUP_TABLE_LIST,
  InteropLookupTableListPage,
  exportFileName,
  fileTable,
  fill,
} from './interop-lookup-table-list.page';

/**
 * The Lookup tables page's export and import (Story 20.5, AD-21): the shared list page is replaced by an empty stand-in, so only this
 * page's own wiring runs -- the three actions it registers, the two System Explorer dialogs it opens with the table's wording, and the
 * requests they send through the real `ScreenActionHandler`. Each action request is answered by a stub the test releases; the allowed
 * directories read answers one root.
 */

@Component({ selector: 'app-list-page', template: '' })
class StubListPage {}

const LIST = SCREENS.find((screen) => screen.descriptor === INTEROP_LOOKUP_TABLE_LIST)!;

const ROOT = '/data/';

const ROWS = [{ Name: 'Probe.Table', Modified: '2026-10-11 09:00:00' }];

const planted: HTMLElement[] = [];

async function settle(fixture: ComponentFixture<unknown>): Promise<void> {
  for (let pass = 0; pass < 6; pass += 1) {
    await new Promise((resolve) => setTimeout(resolve, 5));
    fixture.detectChanges();
    await fixture.whenStable();
  }
}

/** One action request the page sent: its parsed body, the namespace it was pinned to, and what releases its answer. */
interface ActionCall {
  readonly path: string;
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
          calls.push({ path, body: JSON.parse(String(init.body)), scope: init.scope, answer: (result) => resolve(result as JsonResult<T>) });
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
      { provide: ScopeService, useValue: { loaded: () => true, namespace: () => 'USER', subscribe: () => () => {} } as unknown as ScopeService },
    ],
  });
  TestBed.overrideComponent(InteropLookupTableListPage, { remove: { imports: [ListPage] }, add: { imports: [StubListPage] } });
  const store = stores.for(LIST.descriptor, LIST.refreshRates);
  store.applyTick(ROWS, false, '', new Date());
  const fixture = TestBed.createComponent(InteropLookupTableListPage);
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  fixture.detectChanges();
  return { fixture, host: fixture.nativeElement as HTMLElement, store, calls, events, actions: TestBed.inject(ScreenActions) };
}

/** Type `value` into the open dialog's server-path name field. */
async function typePath(fixture: ComponentFixture<unknown>, host: HTMLElement, value: string): Promise<void> {
  const input = host.querySelector('.ocu-path-picker input[type="text"]') as HTMLInputElement;
  input.value = value;
  input.dispatchEvent(new Event('input', { bubbles: true }));
  await settle(fixture);
}

const status = (host: HTMLElement): string => host.querySelector('[data-interop-lookup-transfer-status]')?.textContent?.trim() ?? '';

const dialogRefusal = (host: HTMLElement): string => host.querySelector('[data-explorer-transfer-refusal]')?.textContent?.trim() ?? '';

afterEach(() => {
  for (const node of planted.splice(0)) node.remove();
  TestBed.resetTestingModule();
});

describe('the Lookup tables page export and import', () => {
  it('declares the four transfer actions, of which the page registers Export and the screen-level Import and the handler none', () => {
    // Mutation (Rule 19): drop the list's UNDRAWN_ACTIONS entry in the handler -> it registers `import` too and the last assertion goes red.
    expect(LIST.rowActions.map((action) => action.id)).toEqual(['delete', 'export', 'export-browser', 'import', 'import-local']);
    const { actions } = mount();
    expect(actions.has(INTEROP_LOOKUP_TABLE_LIST, INTEROP_LOOKUP_EXPORT_ACTION)).toBe(true);
    expect(actions.has(INTEROP_LOOKUP_TABLE_LIST, TASK_IMPORT_ACTION_ID)).toBe(true);
    expect(['export-browser', 'import', 'import-local'].map((id) => actions.has(INTEROP_LOOKUP_TABLE_LIST, id))).toEqual([false, false, false]);
    // Mutation (Rule 19): drop `export` from the list's DESCRIPTOR_ACTION_LABELS entry -> its menu entry reads "export" and this goes red.
    expect([actionLabel(INTEROP_LOOKUP_TABLE_LIST, 'export'), actionLabel(INTEROP_LOOKUP_TABLE_LIST, TASK_IMPORT_ACTION_ID)]).toEqual([STRINGS.taskExportAction, STRINGS.actionImport]);
  });

  it('opens no export dialog without a selected table, and titles it by the selected table with the table\'s words', async () => {
    const { fixture, host, store, actions } = mount();
    actions.run(INTEROP_LOOKUP_TABLE_LIST, INTEROP_LOOKUP_EXPORT_ACTION);
    await settle(fixture);
    expect(host.querySelector('app-explorer-export-dialog')).toBeNull();
    store.setSelection(['Probe.Table']);
    actions.run(INTEROP_LOOKUP_TABLE_LIST, INTEROP_LOOKUP_EXPORT_ACTION);
    await settle(fixture);
    expect(host.querySelector('.ocu-dialog-title')?.textContent?.trim()).toBe('Export lookup table Probe.Table');
    expect(host.querySelector('[data-explorer-export-replaces]')?.textContent?.trim()).toBe(STRINGS.interopLookupExportReplaces);
  });

  it('exports the table the dialog opened on to a server file, pinned to the namespace the dialog opened in, and says where it went', async () => {
    // Mutation (Rule 19): drop `scope` from the export's `sendFor` in `onExport` -> the request follows the shell and the scope assertion goes red.
    const { fixture, host, store, actions, calls, events } = mount();
    store.setSelection(['Probe.Table']);
    actions.run(INTEROP_LOOKUP_TABLE_LIST, INTEROP_LOOKUP_EXPORT_ACTION);
    await settle(fixture);
    await typePath(fixture, host, 'out/Probe.Table.xml');
    // Mutation (Rule 19): send `store.selection()[0]` in `onExport` -> the selection cleared under the open dialog sends nothing and this goes red.
    store.setSelection([]);
    await settle(fixture);
    (host.querySelector('[data-explorer-export-confirm]') as HTMLButtonElement).click();
    await settle(fixture);
    expect(calls).toHaveLength(1);
    expect(calls[0].path).toBe(`/api/ocupilot/screens/${LIST.toolIdentifier}/action`);
    expect(calls[0].body).toEqual({ action: 'export', id: 'Probe.Table', values: { root: ROOT, path: 'out/Probe.Table.xml' } });
    expect(calls[0].scope).toBe('USER');
    calls[0].answer({
      kind: 'ok',
      status: 200,
      body: { action: 'updated', target: { type: 'lookup-table', scope: 'USER', id: 'Probe.Table' }, output: { root: ROOT, path: 'out/Probe.Table.xml' } },
    });
    await settle(fixture);
    expect(host.querySelector('app-explorer-export-dialog')).toBeNull();
    expect(status(host)).toBe(`Exported lookup table Probe.Table to ${ROOT}out/Probe.Table.xml.`);
    expect(events.map((event) => `${event.action} ${event.type} ${event.id}`)).toEqual(['updated lookup-table Probe.Table']);
  });

  it('exports to this browser with no file, and saves the answered lines as <table>.xml', async () => {
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
      store.setSelection(['Probe.Table']);
      actions.run(INTEROP_LOOKUP_TABLE_LIST, INTEROP_LOOKUP_EXPORT_ACTION);
      await settle(fixture);
      const browserChoice = host.querySelector('input[data-explorer-export-destination="browser"]') as HTMLInputElement;
      browserChoice.checked = true;
      browserChoice.dispatchEvent(new Event('change'));
      await settle(fixture);
      expect(host.querySelector('app-server-path-picker')).toBeNull();
      (host.querySelector('[data-explorer-export-confirm]') as HTMLButtonElement).click();
      await settle(fixture);
      expect(calls[0].body).toEqual({ action: 'export-browser', id: 'Probe.Table' });
      calls[0].answer({
        kind: 'ok',
        status: 200,
        body: { action: 'updated', target: { type: 'lookup-table', scope: 'USER', id: 'Probe.Table' }, output: { lines: ['<?xml version="1.0"?>', '<Export>', '</Export>'] } },
      });
      await settle(fixture);
      expect(saved.map((file) => [file.name, file.type])).toEqual([['Probe.Table.xml', 'application/xml']]);
      expect(await saved[0].text).toBe('<?xml version="1.0"?>\n<Export>\n</Export>');
      expect(status(host)).toBe('Saved lookup table Probe.Table as Probe.Table.xml.');
    } finally {
      URL.createObjectURL = realCreate;
      URL.revokeObjectURL = realRevoke;
      HTMLAnchorElement.prototype.click = realClick;
    }
  });

  it('imports from a server file on the one import target, with no compile choice, and says which file', async () => {
    // Mutation (Rule 19): leave `compileOption` on in the import dialog -> its checkbox is drawn and the first assertion goes red.
    const { fixture, host, actions, calls } = mount();
    expect(actions.has(INTEROP_LOOKUP_TABLE_LIST, TASK_IMPORT_ACTION_ID)).toBe(true);
    actions.run(INTEROP_LOOKUP_TABLE_LIST, TASK_IMPORT_ACTION_ID);
    await settle(fixture);
    expect(host.querySelector('input[data-explorer-import-compile]')).toBeNull();
    expect(host.querySelector('.ocu-dialog-title')?.textContent?.trim()).toBe(STRINGS.interopLookupImportTitle);
    expect(host.querySelector('[data-explorer-import-replaces]')?.textContent?.trim()).toBe(STRINGS.interopLookupImportConsequence);
    await typePath(fixture, host, 'in/Probe.Table.xml');
    (host.querySelector('[data-explorer-import-confirm]') as HTMLButtonElement).click();
    await settle(fixture);
    expect(calls[0].body).toEqual({ action: 'import', id: 'import', values: { root: ROOT, path: 'in/Probe.Table.xml' } });
    expect(calls[0].scope).toBe('USER');
    calls[0].answer({ kind: 'ok', status: 200, body: { action: 'updated', target: { type: 'lookup-table', scope: 'USER', id: 'import' } } });
    await settle(fixture);
    expect(host.querySelector('app-explorer-import-dialog')).toBeNull();
    expect(status(host)).toBe(`Imported the lookup table in ${ROOT}in/Probe.Table.xml.`);
  });

  it('reads a local file as text, offers only .xml, and sends it as import-local with its name and text', async () => {
    // Mutation (Rule 19): drop `content` from the local import's values in `onImport` -> the body assertion goes red.
    const { fixture, host, actions, calls } = mount();
    actions.run(INTEROP_LOOKUP_TABLE_LIST, TASK_IMPORT_ACTION_ID);
    await settle(fixture);
    const local = host.querySelector('input[data-explorer-import-source="local"]') as HTMLInputElement;
    local.checked = true;
    local.dispatchEvent(new Event('change'));
    await settle(fixture);
    const input = host.querySelector('input[data-explorer-import-file]') as HTMLInputElement;
    expect(input.getAttribute('accept')).toBe('.xml');
    Object.defineProperty(input, 'files', { value: [new File(['<Export>\n</Export>\n'], 't.xml')], configurable: true });
    input.dispatchEvent(new Event('change'));
    await settle(fixture);
    (host.querySelector('[data-explorer-import-confirm]') as HTMLButtonElement).click();
    await settle(fixture);
    expect(calls[0].body).toEqual({ action: 'import-local', id: 'import', values: { fileName: 't.xml', content: '<Export>\n</Export>\n' } });
    calls[0].answer({ kind: 'ok', status: 200, body: { action: 'updated', target: { type: 'lookup-table', scope: 'USER', id: 'import' } } });
    await settle(fixture);
    expect(status(host)).toBe('Imported the lookup table in t.xml.');
  });

  it('fills the status line in one pass, so a table name holding a placeholder or a $ pattern is shown as it is', () => {
    // Mutation (Rule 19): chain `.replace('<table>', ...).replace('<path>', ...)` in `fill` -> the path lands inside the name and this goes red.
    expect(fill(STRINGS.interopLookupExportDone, { table: 'a<path>b$&', path: '/data/x.xml' })).toBe('Exported lookup table a<path>b$& to /data/x.xml.');
  });

  it('sends a local file on the table it names, so the write holds that table, and the unnamed import target otherwise', async () => {
    // Mutation (Rule 19): send INTEROP_LOOKUP_IMPORT_TARGET for every import in `onImport` -> the first id assertion goes red.
    const text = '<?xml version="1.0"?>\n<Export><Document name="Probe.Other &amp; Co.LUT"><lookupTable><entry table="Probe.Other &amp; Co" key="k">v</entry></lookupTable></Document></Export>\n';
    const { fixture, host, actions, calls } = mount();
    actions.run(INTEROP_LOOKUP_TABLE_LIST, TASK_IMPORT_ACTION_ID);
    await settle(fixture);
    const local = host.querySelector('input[data-explorer-import-source="local"]') as HTMLInputElement;
    local.checked = true;
    local.dispatchEvent(new Event('change'));
    await settle(fixture);
    const input = host.querySelector('input[data-explorer-import-file]') as HTMLInputElement;
    Object.defineProperty(input, 'files', { value: [new File([text], 'other.xml')], configurable: true });
    input.dispatchEvent(new Event('change'));
    await settle(fixture);
    (host.querySelector('[data-explorer-import-confirm]') as HTMLButtonElement).click();
    await settle(fixture);
    expect(calls[0].body.id).toBe('Probe.Other & Co');
    expect([fileTable('<Export></Export>'), fileTable('not xml <'), fileTable('<Export><Document name="a.cls"/></Export>'), fileTable('<Export><Document name="A.LUT"/><Document name="B.LUT"/></Export>')]).toEqual(['', '', '', '']);
  });

  it('keeps the import dialog open with the instance\'s sentence when the file is not exactly one lookup table', async () => {
    // Mutation (Rule 19): drop the refusal render from `ExplorerImportDialog` -> the sentence assertion goes red.
    const { fixture, host, actions, calls } = mount();
    actions.run(INTEROP_LOOKUP_TABLE_LIST, TASK_IMPORT_ACTION_ID);
    await settle(fixture);
    await typePath(fixture, host, 'in/two-tables.xml');
    (host.querySelector('[data-explorer-import-confirm]') as HTMLButtonElement).click();
    await settle(fixture);
    calls[0].answer({ kind: 'error', status: 409, code: 'INTEROP.LOOKUP.IMPORTSHAPE', reason: STRINGS.interopLookupRefusalImportShape, detail: null });
    await settle(fixture);
    expect(host.querySelector('app-explorer-import-dialog')).not.toBeNull();
    expect(dialogRefusal(host)).toBe(STRINGS.interopLookupRefusalImportShape);
    expect(status(host)).toBe('');
  });

  it('names a downloaded table\'s file by the table, with each character a file name cannot hold made an underscore', () => {
    expect(exportFileName('Probe.Table')).toBe('Probe.Table.xml');
    expect(exportFileName('a/b\\c:d*e')).toBe('a_b_c_d_e.xml');
    expect(exportFileName('x\ny')).toBe('x_y.xml');
    expect(exportFileName('')).toBe('lookup-table.xml');
  });
});
