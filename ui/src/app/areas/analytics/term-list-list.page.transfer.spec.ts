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
import { TERM_LIST_COPY_ACTION } from './term-list-copy-dialog';
import { TERM_LIST_LIST } from './term-list-dialog';
import { TERM_LIST_EXPORT_ACTION, TermListListPage } from './term-list-list.page';

/**
 * The Term lists page's transfers (Story 24.10): the shared list page is replaced by an empty stand-in, so only this page's own wiring runs --
 * the actions it registers, the dialogs they open, the requests those send through the real `ScreenActionHandler` and what the page draws of
 * each answer. Each action request is answered by a stub the test releases; the allowed directories read answers one root.
 */

@Component({ selector: 'app-list-page', template: '' })
class StubListPage {}

const LIST = SCREENS.find((screen) => screen.descriptor === TERM_LIST_LIST)!;

const ROOT = '/data/';

const ROWS = [{ Name: 'Probe.List', Modified: '2026-11-17 09:00:00' }];

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
  TestBed.configureTestingModule({
    providers: [
      { provide: ApiService, useValue: api as unknown as ApiService },
      { provide: ChangeBus, useValue: new ChangeBus() },
      { provide: ScreenStores, useValue: stores },
      { provide: ScreenActions, useValue: new ScreenActions() },
      { provide: OverlayStack, useValue: new OverlayStack() },
      { provide: ScopeService, useValue: { loaded: () => true, namespace: () => 'USER', subscribe: () => () => {} } as unknown as ScopeService },
    ],
  });
  TestBed.overrideComponent(TermListListPage, { remove: { imports: [ListPage] }, add: { imports: [StubListPage] } });
  const store = stores.for(LIST.descriptor, LIST.refreshRates);
  store.applyTick(ROWS, false, '', new Date());
  const fixture = TestBed.createComponent(TermListListPage);
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  fixture.detectChanges();
  return { fixture, host: fixture.nativeElement as HTMLElement, store, calls, actions: TestBed.inject(ScreenActions) };
}

async function typePath(fixture: ComponentFixture<unknown>, host: HTMLElement, value: string): Promise<void> {
  const input = host.querySelector('.ocu-path-picker input[type="text"]') as HTMLInputElement;
  input.value = value;
  input.dispatchEvent(new Event('input', { bubbles: true }));
  await settle(fixture);
}

const status = (host: HTMLElement): string => host.querySelector('[data-term-list-transfer-status]')?.textContent?.trim() ?? '';

const dialogRefusal = (host: HTMLElement): string => host.querySelector('[data-explorer-transfer-refusal]')?.textContent?.trim() ?? '';

afterEach(() => {
  for (const node of planted.splice(0)) node.remove();
  TestBed.resetTestingModule();
});

describe('the Term lists page transfers', () => {
  it('registers Copy term list, Export and the screen-level Import, and opens Export and Copy only on a selected list', async () => {
    // Mutation (Rule 19): drop the `copy` registration from the page's constructor -> the first assertion goes red.
    const { fixture, host, store, actions } = mount();
    expect([TERM_LIST_COPY_ACTION, TERM_LIST_EXPORT_ACTION, TASK_IMPORT_ACTION_ID].map((id) => actions.has(TERM_LIST_LIST, id))).toEqual([true, true, true]);
    actions.run(TERM_LIST_LIST, TERM_LIST_EXPORT_ACTION);
    actions.run(TERM_LIST_LIST, TERM_LIST_COPY_ACTION);
    await settle(fixture);
    expect([host.querySelector('app-explorer-export-dialog'), host.querySelector('app-term-list-copy-dialog')]).toEqual([null, null]);
    store.setSelection(['Probe.List']);
    actions.run(TERM_LIST_LIST, TERM_LIST_EXPORT_ACTION);
    await settle(fixture);
    expect(host.querySelector('.ocu-dialog-title')?.textContent?.trim()).toBe('Export term list Probe.List');
    expect(host.querySelector('[data-explorer-export-replaces]')?.textContent?.trim()).toBe(STRINGS.analyticsTermListExportHelp);
  });

  it('draws a refused export\'s rule on the path field and keeps the dialog open with no status line, then closes on an applied one and says so', async () => {
    // Mutation (Rule 19): read the violation of field `root` in place of `path` in `endSend` -> the field assertion goes red.
    const { fixture, host, store, actions, calls } = mount();
    store.setSelection(['Probe.List']);
    actions.run(TERM_LIST_LIST, TERM_LIST_EXPORT_ACTION);
    await settle(fixture);
    await typePath(fixture, host, '../out.csv');
    (host.querySelector('[data-explorer-export-confirm]') as HTMLButtonElement).click();
    await settle(fixture);
    expect(calls[0].body).toEqual({ action: 'export', id: 'Probe.List', values: { root: ROOT, path: '../out.csv' } });
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
    await typePath(fixture, host, 'out.csv');
    (host.querySelector('[data-explorer-export-confirm]') as HTMLButtonElement).click();
    await settle(fixture);
    calls[1].answer({ kind: 'ok', status: 200, body: { action: 'updated', target: { type: 'term-list', scope: 'USER', id: 'Probe.List' }, output: { root: ROOT, path: 'out.csv' } } });
    await settle(fixture);
    expect(host.querySelector('app-explorer-export-dialog')).toBeNull();
    expect(status(host)).toBe('Exported Probe.List.');
  });

  it('keeps the import dialog open with the instance\'s sentence when the file is not a term list export, and names the created list when it is', async () => {
    // Mutation (Rule 19): drop `refused.reason` from the page's `refusal.set` in `endSend` -> the sentence assertion goes red.
    const { fixture, host, actions, calls } = mount();
    actions.run(TERM_LIST_LIST, TASK_IMPORT_ACTION_ID);
    await settle(fixture);
    expect(host.querySelector('input[data-explorer-import-compile]')).toBeNull();
    expect(host.querySelector('.ocu-dialog-title')?.textContent?.trim()).toBe(STRINGS.analyticsTermListImportTitle);
    await typePath(fixture, host, 'in/other.csv');
    (host.querySelector('[data-explorer-import-confirm]') as HTMLButtonElement).click();
    await settle(fixture);
    expect(calls[0].body).toEqual({ action: 'import', id: 'import', values: { root: ROOT, path: 'in/other.csv' } });
    calls[0].answer({ kind: 'error', status: 409, code: 'ANALYTICS.TERMLIST.IMPORTSHAPE', reason: STRINGS.analyticsRefusalTermListImportShape, detail: null });
    await settle(fixture);
    expect(host.querySelector('app-explorer-import-dialog')).not.toBeNull();
    expect(dialogRefusal(host)).toBe(STRINGS.analyticsRefusalTermListImportShape);
    expect(status(host)).toBe('');
    (host.querySelector('[data-explorer-import-confirm]') as HTMLButtonElement).click();
    await settle(fixture);
    calls[1].answer({ kind: 'ok', status: 200, body: { action: 'created', target: { type: 'term-list', scope: 'USER', id: 'import' }, output: { Name: 'Probe.Made' } } });
    await settle(fixture);
    expect(host.querySelector('app-explorer-import-dialog')).toBeNull();
    expect(status(host)).toBe('Imported Probe.Made.');
  });

  it('sends a local file as import-local with its name and text, offering .csv and .txt', async () => {
    // Mutation (Rule 19): send the local file under `import` in place of `import-local` in `onImport` -> the body assertion goes red.
    const { fixture, host, actions, calls } = mount();
    actions.run(TERM_LIST_LIST, TASK_IMPORT_ACTION_ID);
    await settle(fixture);
    const local = host.querySelector('input[data-explorer-import-source="local"]') as HTMLInputElement;
    local.checked = true;
    local.dispatchEvent(new Event('change'));
    await settle(fixture);
    const input = host.querySelector('input[data-explorer-import-file]') as HTMLInputElement;
    expect(input.getAttribute('accept')).toBe('.csv,.txt');
    Object.defineProperty(input, 'files', { value: [new File(['%%NAME,Probe.Made\nk,v\n'], 'made.csv')], configurable: true });
    input.dispatchEvent(new Event('change'));
    await settle(fixture);
    (host.querySelector('[data-explorer-import-confirm]') as HTMLButtonElement).click();
    await settle(fixture);
    expect(calls[0].body).toEqual({ action: 'import-local', id: 'import', values: { fileName: 'made.csv', content: '%%NAME,Probe.Made\nk,v\n' } });
  });

  it('closes the copy dialog on an applied copy and says which list became which', async () => {
    // Mutation (Rule 19): drop the `new` placeholder value from `onCopied` -> the status line keeps `<new>` and this goes red.
    const { fixture, host, store, actions, calls } = mount();
    store.setSelection(['Probe.List']);
    actions.run(TERM_LIST_LIST, TERM_LIST_COPY_ACTION);
    await settle(fixture);
    const name = host.querySelector('[data-term-list-copy-name]') as HTMLInputElement;
    name.value = 'Probe.Copy';
    name.dispatchEvent(new Event('input'));
    await settle(fixture);
    (host.querySelector('[data-term-list-copy-confirm]') as HTMLButtonElement).click();
    await settle(fixture);
    expect(calls[0].body).toEqual({ action: 'copy', id: 'Probe.List', values: { NewName: 'Probe.Copy' } });
    calls[0].answer({ kind: 'ok', status: 200, body: { action: 'created', target: { type: 'term-list', scope: 'USER', id: 'Probe.List' } } });
    await settle(fixture);
    expect(host.querySelector('app-term-list-copy-dialog')).toBeNull();
    expect(status(host)).toBe('Copied Probe.List to Probe.Copy.');
  });
});
