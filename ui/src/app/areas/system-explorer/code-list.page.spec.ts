import { ComponentFixture, TestBed } from '@angular/core/testing';
import { ActivatedRoute, Router, convertToParamMap, provideRouter } from '@angular/router';
import { BehaviorSubject } from 'rxjs';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type JsonResult } from '../../core/api';
import { ChangeBus } from '../../core/change-bus';
import type { ConnectivityService } from '../../core/connectivity';
import { NavigationService } from '../../core/navigation';
import { OverlayStack } from '../../core/overlay-stack';
import { RefreshService } from '../../core/refresh';
import { ScopeService } from '../../core/scope';
import { ScreenActions, TASK_IMPORT_ACTION_ID } from '../../core/screen-actions';
import { ScreenArrivals } from '../../core/screen-arrival';
import { ScreenStores } from '../../core/screen-store';
import { SCREENS, type ScreenDeclaration } from '../../core/screens.generated';
import { STRINGS } from '../../core/strings';
import { stubAccountPreferences } from '../../testing/account-preferences';
import { COMPILE_ACTION, CodeListPage, DELETE_ACTION, EXPORT_ACTION } from './code-list.page';
import { CodeListSearch, CodeListWrite, isYesNo } from './code-list.store';
import { IMPORT_MAX_CHARACTERS } from './explorer-import-dialog';

/**
 * System Explorer's Classes and Routines lists over the shipped descriptors, with the real
 * `RefreshService`, `ScreenStores`, `createScreenRead` and `DataTable` and a stubbed HTTP answer that
 * echoes the criteria the instance would apply (Story 19.1, AC1), and their compile and delete over
 * the checked rows through the real `ScreenActionHandler`, each action request answered by a stub the
 * test releases (Story 19.2, AC1 and AC2), and their export and import through the two transfer
 * dialogs, the allowed directories read answering one root (Story 19.13).
 */

/** The one allowed root the stubbed Allowed directories read answers. */
const ROOT = '/data/';

const CLASSES = SCREENS.find((screen) => screen.descriptor === 'OcuPilot.Screen.Descriptor.ExplorerClassList') as ScreenDeclaration;
const ROUTINES = SCREENS.find((screen) => screen.descriptor === 'OcuPilot.Screen.Descriptor.ExplorerRoutineList') as ScreenDeclaration;
const SQL_TABLES = SCREENS.find((screen) => screen.descriptor === 'OcuPilot.Screen.Descriptor.ExplorerSqlTables') as ScreenDeclaration;

const row = (name: string) => ({ Name: name, Modified: '2026-10-01 10:00:00.000', Database: 'HSCUSTOM', Generated: false });

async function settle(fixture: ComponentFixture<unknown>): Promise<void> {
  for (let pass = 0; pass < 6; pass += 1) {
    await new Promise((resolve) => setTimeout(resolve, 20));
    fixture.detectChanges();
    await fixture.whenStable();
  }
}

const planted: HTMLElement[] = [];

/** What the instance would echo for `path` under `screen`: each sent value, else the declared default. */
function echoFor(screen: ScreenDeclaration, path: string): Record<string, string> {
  const query = new URLSearchParams(path.split('?')[1] ?? '');
  const applied: Record<string, string> = {};
  for (const field of screen.read?.criteria?.fields ?? []) {
    applied[field.param] = query.get(field.param) ?? field.default ?? '';
  }
  return applied;
}

/** One action request the page sent: its parsed body, and what releases its answer. */
interface ActionCall {
  readonly path: string;
  readonly body: { readonly action: string; readonly id: string; readonly values?: Record<string, string> };
  /** The namespace the request was pinned to, or `undefined` where it follows the shell's. */
  readonly scope: string | null | undefined;
  answer(result: JsonResult<unknown>): void;
}

async function mount(
  screen: ScreenDeclaration,
  rows: unknown[] = [row('OcuPilot.Port.AtelierPort.cls')],
  arrivals: ScreenArrivals | null = null,
  echo: (path: string) => Record<string, string> = (path) => echoFor(screen, path)
) {
  TestBed.resetTestingModule();
  const paths: string[] = [];
  const calls: ActionCall[] = [];
  let namespace = 'HSCUSTOM';
  const api = {
    requestJson: async <T,>(path: string, init?: RequestInit & { scope?: string | null }): Promise<JsonResult<T>> => {
      if (init?.method === 'POST') {
        return new Promise<JsonResult<T>>((resolve) => {
          calls.push({ path, body: JSON.parse(String(init.body)), scope: init.scope, answer: (result) => resolve(result as JsonResult<T>) });
        });
      }
      paths.push(path);
      if (path.includes('security.alloweddirectories')) {
        return { kind: 'ok', status: 200, body: { fields: [], rows: [{ Directory: ROOT, Restricted: true }], truncated: false, banner: '', criteria: {} } as T };
      }
      return { kind: 'ok', status: 200, body: { fields: [], rows, truncated: false, banner: '', criteria: echo(path) } as T };
    },
  };
  const stores = new ScreenStores({ account: stubAccountPreferences() });
  const bus = new ChangeBus();
  const refresh = new RefreshService({
    stores,
    connectivity: { retryWhenReachable: () => {} } as unknown as ConnectivityService,
    bus,
    namespace: () => 'HSCUSTOM',
    schedule: () => {},
  });
  TestBed.configureTestingModule({
    providers: [
      provideRouter([{ path: '**', children: [] }]),
      { provide: NavigationService, useValue: { screenForUrl: () => screen } as unknown as NavigationService },
      { provide: ApiService, useValue: api as unknown as ApiService },
      { provide: RefreshService, useValue: refresh },
      { provide: ScreenStores, useValue: stores },
      { provide: ChangeBus, useValue: bus },
      { provide: ScreenActions, useValue: new ScreenActions() },
      { provide: OverlayStack, useValue: new OverlayStack() },
      {
        provide: ScopeService,
        useValue: { loaded: () => true, namespace: () => namespace, subscribe: () => () => {} } as unknown as ScopeService,
      },
      { provide: ActivatedRoute, useValue: { paramMap: new BehaviorSubject(convertToParamMap({})) } as unknown as ActivatedRoute },
      ...(arrivals === null ? [] : [{ provide: ScreenArrivals, useValue: arrivals }]),
    ],
  });
  await TestBed.inject(Router).navigateByUrl(`/${screen.route}?ns=HSCUSTOM`);
  const fixture = TestBed.createComponent(CodeListPage);
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  fixture.detectChanges();
  await settle(fixture);
  const host = fixture.nativeElement as HTMLElement;
  return {
    fixture,
    host,
    paths,
    calls,
    refresh,
    /** Switch the shell's namespace, as the namespace selector does. */
    switchNamespace: (next: string) => {
      namespace = next;
    },
    store: stores.for(screen.descriptor, screen.refreshRates),
    actions: TestBed.inject(ScreenActions),
    field: (param: string) => host.querySelector(`input[data-ocu-criterion="${param}"]`) as HTMLInputElement,
    type: async (param: string, value: string) => {
      const input = host.querySelector(`input[data-ocu-criterion="${param}"]`) as HTMLInputElement;
      input.value = value;
      input.dispatchEvent(new Event('input', { bubbles: true }));
      await settle(fixture);
    },
    check: async (param: string, on: boolean) => {
      const box = host.querySelector(`input[type="checkbox"][data-ocu-criterion="${param}"]`) as HTMLInputElement;
      box.checked = on;
      box.dispatchEvent(new Event('change', { bubbles: true }));
      await settle(fixture);
    },
    search: async () => {
      (host.querySelector('.ocu-criteria-controls button[type="submit"]') as HTMLElement).click();
      await settle(fixture);
    },
  };
}

afterEach(() => {
  for (const node of planted.splice(0)) node.remove();
});

describe('System Explorer lists', () => {
  it('the Classes list opens on one default read, its form showing the declared defaults under their labels', async () => {
    const { host, paths, field } = await mount(CLASSES);
    expect(paths).toEqual(['/api/ocupilot/screens/explorer.classes/read?maxRows=1000']);
    expect(field('pattern').value).toBe('*');
    expect(host.querySelector(`label[for="${field('pattern').id}"]`)?.textContent?.trim()).toBe(STRINGS.explorerClassPatternLabel);
    expect(field('from').value).toBe('');
    expect(host.querySelector(`label[for="${field('from').id}"]`)?.textContent?.trim()).toBe(STRINGS.auditCriteriaBegin);
    expect(host.querySelector('.ocu-criteria-hint')?.textContent?.trim()).toBe(STRINGS.auditCriteriaTimeHint);
    const boxes = Array.from(host.querySelectorAll<HTMLInputElement>('input[type="checkbox"][data-ocu-criterion]'));
    expect(boxes.map((box) => [box.dataset['ocuCriterion'], box.checked])).toEqual([
      ['system', false],
      ['generated', false],
      ['mapped', true],
    ]);
    const markers = Array.from(host.querySelectorAll('.ocu-criteria-marker')).map((label) => label.textContent?.trim());
    expect(markers).toEqual([STRINGS.explorerSystemLabel, STRINGS.explorerGeneratedLabel, STRINGS.explorerMappedLabel]);
    expect(host.querySelector('[role="grid"]')).not.toBeNull();
  });

  it('Story 19.5: the SQL tables list draws its System box unchecked and an empty schema field, and Search sends both', async () => {
    // Mutation (Rule 19): drop the yes/no checkbox branch from `CodeListPage.checkFields` -> no System
    // box is drawn and the first assertion goes red.
    const { host, paths, field, type, check, search } = await mount(SQL_TABLES, [
      { Table: 'OcuProbe195.Visible', Schema: 'OcuProbe195', Name: 'Visible', Class: 'OcuProbe195.Visible', Owner: '_SYSTEM', Sharded: false, Partitioned: false },
    ]);
    expect(paths).toEqual(['/api/ocupilot/screens/explorer.sqltables/read?maxRows=1000']);
    const boxes = Array.from(host.querySelectorAll<HTMLInputElement>('input[type="checkbox"][data-ocu-criterion]'));
    expect(boxes.map((box) => [box.dataset['ocuCriterion'], box.checked])).toEqual([['system', false]]);
    expect(Array.from(host.querySelectorAll('.ocu-criteria-marker')).map((label) => label.textContent?.trim())).toEqual([STRINGS.explorerSystemLabel]);
    expect(field('schema').value).toBe('');
    expect(field('schema').getAttribute('maxlength')).toBe('128');
    expect(host.querySelector(`label[for="${field('schema').id}"]`)?.textContent?.trim()).toBe(STRINGS.explorerSqlColumnSchema);
    await type('schema', 'OcuProbe195');
    await check('system', true);
    await search();
    expect(paths[1]).toBe('/api/ocupilot/screens/explorer.sqltables/read?maxRows=1000&system=yes&schema=OcuProbe195');
  });

  it('the Routines list opens on *.mac with generated items checked', async () => {
    const { field, host } = await mount(ROUTINES, [row('HS.HC.Info.mac')]);
    expect(field('pattern').value).toBe('*.mac');
    expect(host.querySelector(`label[for="${field('pattern').id}"]`)?.textContent?.trim()).toBe(STRINGS.explorerRoutinePatternLabel);
    expect((host.querySelector('input[type="checkbox"][data-ocu-criterion="generated"]') as HTMLInputElement).checked).toBe(true);
  });

  it('Search sends every criterion as the form shows it, a checkbox as yes or no', async () => {
    const { paths, type, check, search } = await mount(CLASSES);
    await type('pattern', 'OcuPilot.*');
    await check('system', true);
    await check('mapped', false);
    await search();
    expect(paths).toHaveLength(2);
    expect(paths[1]).toBe(
      '/api/ocupilot/screens/explorer.classes/read?maxRows=1000&pattern=OcuPilot.*&system=yes&generated=no&mapped=no&from=&to='
    );
  });

  it('an agent arrival runs exactly its criteria, and the form fills the rest from the answer', async () => {
    const arrivals = new ScreenArrivals();
    arrivals.set({ route: CLASSES.route, criterion: '', criteria: { pattern: 'HS.*' } });
    // The instance answers a value the declaration does not default to, so the form can only show
    // it by reading the answer. Mutation (Rule 19): make `CodeListSearch.applyEcho` return at once -> red.
    const { paths, field, host } = await mount(CLASSES, [row('HS.HC.Info.cls')], arrivals, (path) => ({ ...echoFor(CLASSES, path), system: 'yes' }));
    expect(paths).toEqual(['/api/ocupilot/screens/explorer.classes/read?maxRows=1000&pattern=HS.*']);
    expect(field('pattern').value).toBe('HS.*');
    expect((host.querySelector('input[type="checkbox"][data-ocu-criterion="system"]') as HTMLInputElement).checked).toBe(true);
  });

  it('switching the namespace re-reads the search on screen (AC1)', async () => {
    // Mutation (Rule 19): drop the read from `RefreshService.noteScopeChanged` -> red.
    const { fixture, paths, type, search, refresh } = await mount(CLASSES);
    await type('pattern', 'OcuPilot.*');
    await search();
    refresh.noteScopeChanged();
    await settle(fixture);
    expect(paths).toHaveLength(3);
    expect(paths[2]).toBe(paths[1]);
  });

  it('the store opens on the declared defaults and sends nothing until the form is used', () => {
    const search = new CodeListSearch(CLASSES.read?.criteria?.fields ?? []);
    expect(search.criteria()).toEqual({});
    expect(search.value('pattern')).toBe('*');
    expect(search.checked('mapped')).toBe(true);
    search.setChecked('mapped', false);
    search.useForm();
    expect(search.criteria()).toEqual({ pattern: '*', system: 'no', generated: 'no', mapped: 'no', from: '', to: '' });
    expect((CLASSES.read?.criteria?.fields ?? []).filter(isYesNo).map((field) => field.param)).toEqual(['system', 'generated', 'mapped']);
  });
});

/** The console lines a compile answers for `name`, as the screen action route sends them. */
function compiled(name: string, lines: readonly string[], errors = false): JsonResult<unknown> {
  return {
    kind: 'ok',
    status: 200,
    body: { action: 'updated', target: { type: 'class', scope: 'HSCUSTOM', id: name }, output: { lines, errors } },
  };
}

function pane(host: HTMLElement): string {
  return host.querySelector('[data-explorer-write="output"]')?.textContent ?? '';
}

function status(host: HTMLElement): string {
  return host.querySelector('[data-explorer-write="status"]')?.textContent?.trim() ?? '';
}

describe('System Explorer compile and delete (Story 19.2)', () => {
  it('AC1: Compile opens on the checked rows with the three flags, then sends one compile per document in list order, each answer shown before the next is sent', async () => {
    const { fixture, host, calls, store, actions } = await mount(CLASSES, [row('A.cls'), row('B.cls'), row('C.cls')]);
    expect(actions.has(CLASSES.descriptor, COMPILE_ACTION)).toBe(true);
    expect(actions.has(CLASSES.descriptor, DELETE_ACTION)).toBe(true);
    store.setChecked(['C.cls', 'A.cls']);
    actions.run(CLASSES.descriptor, COMPILE_ACTION);
    await settle(fixture);
    expect(host.querySelector('.ocu-dialog-title')?.textContent?.trim()).toBe('Compile 2 documents');
    const flags = Array.from(host.querySelectorAll<HTMLInputElement>('input[data-explorer-compile-flag]'));
    expect(flags.map((box) => [box.dataset['explorerCompileFlag'], box.checked])).toEqual([
      ['KeepSource', true],
      ['CompileDependents', false],
      ['SkipUpToDate', true],
    ]);
    flags[1].checked = true;
    flags[1].dispatchEvent(new Event('change'));
    // The box is found by its published label, so a label drawn over the wrong flag goes red.
    const keepSource = Array.from(host.querySelectorAll<HTMLLabelElement>('label'))
      .find((label) => label.textContent?.trim() === STRINGS.explorerCompileKeepSource)
      ?.querySelector('input') as HTMLInputElement;
    keepSource.checked = false;
    keepSource.dispatchEvent(new Event('change'));
    (host.querySelector('[data-explorer-compile-confirm]') as HTMLButtonElement).click();
    await settle(fixture);
    expect(host.querySelector('app-explorer-compile-dialog')).toBeNull();
    expect(calls).toHaveLength(1);
    expect(calls[0].path).toBe('/api/ocupilot/screens/explorer.classes/action');
    expect(calls[0].body).toEqual({ action: 'compile', id: 'A.cls', values: { KeepSource: 'false', CompileDependents: 'true', SkipUpToDate: 'true' } });
    expect(status(host)).toBe('Compiling 1 of 2 \u00b7 A.cls');

    // Mutation (Rule 19): answer the screen without `output` -> the pane stays empty and this goes red.
    calls[0].answer(compiled('A.cls', ['Compiling class A', 'Compilation finished successfully.']));
    await settle(fixture);
    expect(pane(host)).toBe('Compiling class A\nCompilation finished successfully.');
    expect(calls).toHaveLength(2);
    expect(calls[1].body.id).toBe('C.cls');
    expect(status(host)).toBe('Compiling 2 of 2 \u00b7 C.cls');
    expect(host.querySelector('[data-explorer-write="output"]')?.getAttribute('tabindex')).toBe('0');
    expect(host.querySelector('[data-explorer-write="output"]')?.getAttribute('aria-label')).toBe(STRINGS.explorerOutputLabel);
    expect(host.querySelector('[data-explorer-write="status"]')?.getAttribute('role')).toBe('status');

    calls[1].answer(compiled('C.cls', ['Compiling class C', 'ERROR: Class OcuProbe.Missing does not exist'], true));
    await settle(fixture);
    expect(pane(host)).toBe('Compiling class A\nCompilation finished successfully.\nCompiling class C\nERROR: Class OcuProbe.Missing does not exist');
    expect(status(host)).toBe('Compiled 2 of 2 documents, 1 with errors.');
    expect(host.querySelector('[data-explorer-write="stop"]')).toBeNull();
  });

  it('AC1: Stop lets the request in flight land and sends no further one', async () => {
    // Mutation (Rule 19): drop the stop check in `CodeListWrite.runCompile` -> a second request is sent.
    const { fixture, host, calls, store, actions } = await mount(ROUTINES, [row('A.mac'), row('B.mac'), row('C.mac')]);
    store.setChecked(['A.mac', 'B.mac', 'C.mac']);
    actions.run(ROUTINES.descriptor, COMPILE_ACTION);
    await settle(fixture);
    (host.querySelector('[data-explorer-compile-confirm]') as HTMLButtonElement).click();
    await settle(fixture);
    expect(calls).toHaveLength(1);
    (host.querySelector('[data-explorer-write="stop"]') as HTMLButtonElement).click();
    await settle(fixture);
    calls[0].answer(compiled('A.mac', ['Compiling routine A.mac']));
    await settle(fixture);
    expect(calls).toHaveLength(1);
    expect(pane(host)).toBe('Compiling routine A.mac');
    expect(status(host)).toBe('Stopped after 1 of 3 documents.');
  });

  it('AC1: a compile sequence sends every request to the namespace it started in when the shell switches namespace mid-run', async () => {
    // Mutation (Rule 19): drop `scope` from the `sendFor` in `onCompile` -> the requests follow the shell and this goes red.
    const { fixture, host, calls, store, actions, switchNamespace } = await mount(CLASSES, [row('A.cls'), row('B.cls')]);
    store.setChecked(['A.cls', 'B.cls']);
    actions.run(CLASSES.descriptor, COMPILE_ACTION);
    await settle(fixture);
    (host.querySelector('[data-explorer-compile-confirm]') as HTMLButtonElement).click();
    await settle(fixture);
    expect(calls).toHaveLength(1);
    switchNamespace('USER');
    calls[0].answer(compiled('A.cls', ['Compiling class A']));
    await settle(fixture);
    expect(calls).toHaveLength(2);
    expect(calls.map((call) => [call.body.id, call.scope])).toEqual([
      ['A.cls', 'HSCUSTOM'],
      ['B.cls', 'HSCUSTOM'],
    ]);
    calls[1].answer(compiled('B.cls', ['Compiling class B']));
    await settle(fixture);
  });

  it("AC1: a refused document is its own line in the pane, in the instance's words, and the sequence goes on", async () => {
    const { fixture, host, calls, store, actions } = await mount(CLASSES, [row('OcuPilot.Port.AtelierPort.cls'), row('B.cls')]);
    store.setChecked(['OcuPilot.Port.AtelierPort.cls', 'B.cls']);
    actions.run(CLASSES.descriptor, COMPILE_ACTION);
    await settle(fixture);
    (host.querySelector('[data-explorer-compile-confirm]') as HTMLButtonElement).click();
    await settle(fixture);
    calls[0].answer({ kind: 'error', status: 403, code: 'PROHIBITED.OCUPILOTCODE', reason: STRINGS.explorerRefusalOcuPilot, detail: null });
    await settle(fixture);
    expect(pane(host)).toBe(`OcuPilot.Port.AtelierPort.cls: ${STRINGS.explorerRefusalOcuPilot}`);
    expect(host.querySelector('.ocu-data-table-refusal')).toBeNull();
    expect(calls).toHaveLength(2);
    calls[1].answer(compiled('B.cls', ['Compiling class B']));
    await settle(fixture);
    expect(status(host)).toBe('Compiled 1 of 2 documents, 0 with errors.');
  });

  it('AC2: Delete over a set is typed by its count, sends the canonical set once, lists each result and clears the checks', async () => {
    // Mutation (Rule 19): ask a set for its first name rather than its count in `deleteTarget` -> red.
    const { fixture, host, calls, store, actions } = await mount(CLASSES, [row('B.cls'), row('A.cls')]);
    store.setChecked(['B.cls', 'A.cls']);
    actions.run(CLASSES.descriptor, DELETE_ACTION);
    await settle(fixture);
    expect(host.querySelector('.ocu-dialog-title')?.textContent?.trim()).toBe('Delete 2');
    expect(host.querySelector('.ocu-typed-name-consequence')?.textContent?.trim()).toBe(
      STRINGS.explorerDeleteSetConsequence.split('<n>').join('2')
    );
    const button = host.querySelector('.ocu-button-destructive') as HTMLButtonElement;
    const field = host.querySelector('.ocu-typed-name-field') as HTMLInputElement;
    field.value = 'B.cls';
    field.dispatchEvent(new Event('input'));
    fixture.detectChanges();
    button.click();
    await settle(fixture);
    expect(calls).toHaveLength(0);
    field.value = '2';
    field.dispatchEvent(new Event('input'));
    fixture.detectChanges();
    button.click();
    await settle(fixture);
    expect(calls).toHaveLength(1);
    expect(calls[0].body).toEqual({ action: 'delete', id: 'A.cls,B.cls' });
    expect(status(host)).toBe('Deleting 2 documents');
    calls[0].answer({
      kind: 'ok',
      status: 200,
      body: {
        action: 'deleted',
        target: { type: 'class', scope: 'HSCUSTOM', id: 'A.cls,B.cls' },
        output: { documents: [{ name: 'A.cls', deleted: true, reason: '' }, { name: 'B.cls', deleted: false, reason: STRINGS.explorerDeleteLocked }] },
      },
    });
    await settle(fixture);
    expect(pane(host)).toBe(`A.cls: deleted\nB.cls: ${STRINGS.explorerDeleteLocked}`);
    expect(status(host)).toBe('Deleted 1 of 2 documents.');
    expect(store.checked().size).toBe(0);
  });

  it('AC2: Delete of one document is typed by its name, and a routine names no stored data (DW-1932)', async () => {
    // Mutation (Rule 19): answer the Classes list's sentence for a routine in `deleteConsequence` -> red.
    const { fixture, host, calls, store, actions } = await mount(ROUTINES, [row('A.mac')]);
    store.setChecked(['A.mac']);
    actions.run(ROUTINES.descriptor, DELETE_ACTION);
    await settle(fixture);
    expect(host.querySelector('.ocu-dialog-title')?.textContent?.trim()).toBe('Delete A.mac');
    expect(host.querySelector('.ocu-typed-name-consequence')?.textContent?.trim()).toBe(STRINGS.explorerRoutineDeleteConsequence);
    const field = host.querySelector('.ocu-typed-name-field') as HTMLInputElement;
    field.value = 'A.mac';
    field.dispatchEvent(new Event('input'));
    fixture.detectChanges();
    (host.querySelector('.ocu-button-destructive') as HTMLButtonElement).click();
    await settle(fixture);
    expect(calls.map((call) => call.body)).toEqual([{ action: 'delete', id: 'A.mac' }]);
  });

  it('no write opens with nothing checked', async () => {
    const { fixture, host, calls, actions } = await mount(CLASSES, [row('A.cls')]);
    actions.run(CLASSES.descriptor, COMPILE_ACTION);
    actions.run(CLASSES.descriptor, DELETE_ACTION);
    await settle(fixture);
    expect(host.querySelector('app-explorer-compile-dialog')).toBeNull();
    expect(host.querySelector('app-typed-name-dialog')).toBeNull();
    expect(calls).toHaveLength(0);
  });

  it('the write store ignores a second run while one is in flight', async () => {
    const write = new CodeListWrite();
    let release: () => void = () => undefined;
    const first = write.runCompile(['A.cls'], () => new Promise((resolve) => (release = () => resolve({ applied: true, lines: ['a'], errors: false, reason: '' }))));
    await write.runCompile(['B.cls'], async () => ({ applied: true, lines: ['b'], errors: false, reason: '' }));
    release();
    await first;
    expect(write.lines()).toEqual(['a']);
  });
});

/** Type `value` into the open dialog's server-path name field. */
async function typePath(fixture: ComponentFixture<unknown>, host: HTMLElement, value: string): Promise<void> {
  const input = host.querySelector('.ocu-path-picker input[type="text"]') as HTMLInputElement;
  input.value = value;
  input.dispatchEvent(new Event('input', { bubbles: true }));
  await settle(fixture);
}

/** The open transfer dialog's own alert, or `''`. */
function dialogRefusal(host: HTMLElement): string {
  return host.querySelector('[data-explorer-transfer-refusal]')?.textContent?.trim() ?? '';
}

/** Pick `file` in the import dialog's local file input, after choosing that source. */
async function pickLocal(fixture: ComponentFixture<unknown>, host: HTMLElement, file: File): Promise<void> {
  const local = host.querySelector('input[data-explorer-import-source="local"]') as HTMLInputElement;
  local.checked = true;
  local.dispatchEvent(new Event('change'));
  await settle(fixture);
  const input = host.querySelector('input[data-explorer-import-file]') as HTMLInputElement;
  expect(input.getAttribute('accept')).toBe('.xml,.cls,.mac,.inc,.int');
  Object.defineProperty(input, 'files', { value: [file], configurable: true });
  input.dispatchEvent(new Event('change'));
  await settle(fixture);
}

describe('System Explorer export and import (Story 19.13)', () => {
  it('AC1: Export over the checked rows to a server file sends one export over the canonical set with the file, pinned to its namespace', async () => {
    // Mutation (Rule 19): drop `scope` from the export's `sendFor` in `onExport` -> the request follows the shell and this goes red.
    const { fixture, host, calls, store, actions, switchNamespace } = await mount(CLASSES, [row('B.cls'), row('A.cls')]);
    expect(actions.has(CLASSES.descriptor, EXPORT_ACTION)).toBe(true);
    store.setChecked(['B.cls', 'A.cls']);
    actions.run(CLASSES.descriptor, EXPORT_ACTION);
    await settle(fixture);
    expect(host.querySelector('.ocu-dialog-title')?.textContent?.trim()).toBe('Export 2 documents');
    expect(host.querySelector('[data-explorer-export-replaces]')?.textContent?.trim()).toBe(STRINGS.taskExportReplaces);
    const confirm = host.querySelector('[data-explorer-export-confirm]') as HTMLButtonElement;
    expect(confirm.getAttribute('aria-disabled')).toBe('true');
    await typePath(fixture, host, 'out/classes.xml');
    expect(confirm.getAttribute('aria-disabled')).toBeNull();
    switchNamespace('USER');
    confirm.click();
    await settle(fixture);
    expect(calls).toHaveLength(1);
    expect(calls[0].body).toEqual({ action: 'export', id: 'A.cls,B.cls', values: { root: ROOT, path: 'out/classes.xml' } });
    expect(calls[0].scope).toBe('HSCUSTOM');
    calls[0].answer({ kind: 'ok', status: 200, body: { action: 'updated', target: { type: 'class', scope: 'HSCUSTOM', id: 'A.cls,B.cls' }, output: { root: ROOT, path: 'out/classes.xml' } } });
    await settle(fixture);
    expect(host.querySelector('app-explorer-export-dialog')).toBeNull();
    expect(status(host)).toBe(`Exported 2 documents to ${ROOT}out/classes.xml.`);
  });

  it('Export to this browser sends export-browser and saves the answered lines as <NAMESPACE>-export.xml', async () => {
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
      const { fixture, host, calls, store, actions } = await mount(CLASSES, [row('A.cls')]);
      store.setChecked(['A.cls']);
      actions.run(CLASSES.descriptor, EXPORT_ACTION);
      await settle(fixture);
      expect(host.querySelector('.ocu-dialog-title')?.textContent?.trim()).toBe('Export 1 document');
      const browserChoice = host.querySelector('input[data-explorer-export-destination="browser"]') as HTMLInputElement;
      browserChoice.checked = true;
      browserChoice.dispatchEvent(new Event('change'));
      await settle(fixture);
      expect(host.querySelector('app-server-path-picker')).toBeNull();
      (host.querySelector('[data-explorer-export-confirm]') as HTMLButtonElement).click();
      await settle(fixture);
      expect(calls[0].body).toEqual({ action: 'export-browser', id: 'A.cls' });
      calls[0].answer({ kind: 'ok', status: 200, body: { action: 'updated', target: { type: 'class', scope: 'HSCUSTOM', id: 'A.cls' }, output: { lines: ['<?xml version="1.0"?>', '<Export>', '</Export>'] } } });
      await settle(fixture);
      expect(saved.map((file) => [file.name, file.type])).toEqual([['HSCUSTOM-export.xml', 'application/xml']]);
      expect(await saved[0].text).toBe('<?xml version="1.0"?>\n<Export>\n</Export>');
      expect(status(host)).toBe('Saved 1 documents as HSCUSTOM-export.xml.');
    } finally {
      URL.createObjectURL = realCreate;
      URL.revokeObjectURL = realRevoke;
      HTMLAnchorElement.prototype.click = realClick;
    }
  });

  it("AC2: a refused export shows the instance's sentence in the dialog, which stays open, and a refusal on the name lands on the picker's field", async () => {
    // Mutation (Rule 19): drop the refusal render from `ExplorerExportDialog` -> red.
    const { fixture, host, calls, store, actions } = await mount(CLASSES, [row('A.cls')]);
    store.setChecked(['A.cls']);
    actions.run(CLASSES.descriptor, EXPORT_ACTION);
    await settle(fixture);
    await typePath(fixture, host, 'a.xml');
    (host.querySelector('[data-explorer-export-confirm]') as HTMLButtonElement).click();
    await settle(fixture);
    const version = "This instance's source code API answers version 6, and this operation needs version 7 or later.";
    calls[0].answer({ kind: 'error', status: 501, code: 'PORT.NOTIMPLEMENTED', reason: version, detail: null });
    await settle(fixture);
    expect(host.querySelector('app-explorer-export-dialog')).not.toBeNull();
    expect(dialogRefusal(host)).toBe(version);
    expect(status(host)).toBe('');
    (host.querySelector('[data-explorer-export-confirm]') as HTMLButtonElement).click();
    await settle(fixture);
    calls[1].answer({
      kind: 'error',
      status: 400,
      code: 'EXPLORER.EXPORT.DIRECTORY',
      reason: STRINGS.explorerExportDirectory,
      detail: { violations: [{ field: 'path', code: 'EXPLORER.EXPORT.DIRECTORY', reason: STRINGS.explorerExportDirectory }] },
    });
    await settle(fixture);
    expect(host.querySelector('.ocu-path-picker .ocu-form-error')?.textContent?.trim()).toBe(STRINGS.explorerExportDirectory);
    expect(dialogRefusal(host)).toBe('');
  });

  it('Import from a server file sends import on the one target with the file and the compile choice, and lists what it loaded', async () => {
    const { fixture, host, calls, actions } = await mount(ROUTINES, [row('A.mac')]);
    expect(actions.has(ROUTINES.descriptor, TASK_IMPORT_ACTION_ID)).toBe(true);
    actions.run(ROUTINES.descriptor, TASK_IMPORT_ACTION_ID);
    await settle(fixture);
    expect(host.querySelector('.ocu-dialog-title')?.textContent?.trim()).toBe(STRINGS.actionImport);
    expect(host.querySelector('[data-explorer-import-replaces]')?.textContent?.trim()).toBe(STRINGS.explorerImportReplaces);
    const compile = host.querySelector('input[data-explorer-import-compile]') as HTMLInputElement;
    expect(compile.checked).toBe(true);
    compile.checked = false;
    compile.dispatchEvent(new Event('change'));
    await typePath(fixture, host, 'in/all.xml');
    (host.querySelector('[data-explorer-import-confirm]') as HTMLButtonElement).click();
    await settle(fixture);
    expect(calls[0].body).toEqual({ action: 'import', id: 'import', values: { root: ROOT, path: 'in/all.xml', Compile: 'false' } });
    expect(calls[0].scope).toBe('HSCUSTOM');
    expect(status(host)).toBe(`Importing ${ROOT}in/all.xml`);
    calls[0].answer({ kind: 'ok', status: 200, body: { action: 'created', target: { type: 'routine', scope: 'HSCUSTOM', id: 'import' }, output: { imported: ['A.MAC', 'B.MAC'], lines: ['Load started', 'Load finished successfully.'], errors: false } } });
    await settle(fixture);
    expect(host.querySelector('app-explorer-import-dialog')).toBeNull();
    expect(pane(host)).toBe('A.MAC\nB.MAC\nLoad started\nLoad finished successfully.');
    expect(status(host)).toBe('Imported 2 documents.');
  });

  it('Import from a local file reads it as text and sends import-local with its name, text and compile choice', async () => {
    // Mutation (Rule 19): drop `content` from the local import's values in `onImport` -> red.
    const { fixture, host, calls, actions } = await mount(CLASSES, [row('A.cls')]);
    actions.run(CLASSES.descriptor, TASK_IMPORT_ACTION_ID);
    await settle(fixture);
    const confirm = host.querySelector('[data-explorer-import-confirm]') as HTMLButtonElement;
    await pickLocal(fixture, host, new File(['Class A.B\n{\n}\n'], 'B.cls'));
    expect(confirm.getAttribute('aria-disabled')).toBeNull();
    confirm.click();
    await settle(fixture);
    expect(calls[0].body).toEqual({ action: 'import-local', id: 'import', values: { fileName: 'B.cls', content: 'Class A.B\n{\n}\n', Compile: 'true' } });
    calls[0].answer({ kind: 'ok', status: 200, body: { action: 'created', target: { type: 'class', scope: 'HSCUSTOM', id: 'import' }, output: { imported: ['A.B.cls'], lines: ['ERROR: probe compile error'], errors: true } } });
    await settle(fixture);
    expect(status(host)).toBe('Imported 1 documents, with compile errors.');
  });

  it('a local file read before the source was switched away and back is not sent: Import waits for a file again', async () => {
    // Mutation (Rule 19): keep `local` in `ExplorerImportDialog.onSource` -> Import stays available and this goes red.
    const { fixture, host, calls, actions } = await mount(CLASSES, [row('A.cls')]);
    actions.run(CLASSES.descriptor, TASK_IMPORT_ACTION_ID);
    await settle(fixture);
    await pickLocal(fixture, host, new File(['Class A.B\n{\n}\n'], 'B.cls'));
    const server = host.querySelector('input[data-explorer-import-source="server"]') as HTMLInputElement;
    server.checked = true;
    server.dispatchEvent(new Event('change'));
    await settle(fixture);
    const local = host.querySelector('input[data-explorer-import-source="local"]') as HTMLInputElement;
    local.checked = true;
    local.dispatchEvent(new Event('change'));
    await settle(fixture);
    const confirm = host.querySelector('[data-explorer-import-confirm]') as HTMLButtonElement;
    expect(confirm.getAttribute('aria-disabled')).toBe('true');
    confirm.click();
    await settle(fixture);
    expect(calls).toHaveLength(0);
  });

  it('a local file above three million characters is refused in the dialog before anything is sent', async () => {
    // Mutation (Rule 19): drop the length check in `ExplorerImportDialog.onFile` -> the file is sent and this goes red.
    const { fixture, host, calls, actions } = await mount(CLASSES, [row('A.cls')]);
    actions.run(CLASSES.descriptor, TASK_IMPORT_ACTION_ID);
    await settle(fixture);
    await pickLocal(fixture, host, new File(['a'.repeat(IMPORT_MAX_CHARACTERS + 1)], 'big.xml'));
    expect(dialogRefusal(host)).toBe(STRINGS.explorerImportTooLarge);
    const confirm = host.querySelector('[data-explorer-import-confirm]') as HTMLButtonElement;
    expect(confirm.getAttribute('aria-disabled')).toBe('true');
    confirm.click();
    await settle(fixture);
    expect(calls).toHaveLength(0);
  });

  it("AC2: a refused import shows the instance's sentence in the import dialog, which stays open, and a refusal on the name lands on the picker's field", async () => {
    // Mutation (Rule 19): answer `localRefusal()` alone from `ExplorerImportDialog.shownRefusal` -> red.
    const { fixture, host, calls, actions } = await mount(CLASSES, [row('A.cls')]);
    actions.run(CLASSES.descriptor, TASK_IMPORT_ACTION_ID);
    await settle(fixture);
    await typePath(fixture, host, 'in/a.xml');
    (host.querySelector('[data-explorer-import-confirm]') as HTMLButtonElement).click();
    await settle(fixture);
    const version = "This instance's source code API answers version 6, and this operation needs version 7 or later.";
    calls[0].answer({ kind: 'error', status: 501, code: 'PORT.NOTIMPLEMENTED', reason: version, detail: null });
    await settle(fixture);
    expect(host.querySelector('app-explorer-import-dialog')).not.toBeNull();
    expect(dialogRefusal(host)).toBe(version);
    expect(status(host)).toBe('');
    (host.querySelector('[data-explorer-import-confirm]') as HTMLButtonElement).click();
    await settle(fixture);
    calls[1].answer({ kind: 'error', status: 400, code: 'PATH.NOFILE', reason: 'No such file.', detail: { violations: [{ field: 'path', code: 'PATH.NOFILE', reason: 'No such file.' }] } });
    await settle(fixture);
    expect(host.querySelector('.ocu-path-picker .ocu-form-error')?.textContent?.trim()).toBe('No such file.');
    expect(dialogRefusal(host)).toBe('');
  });

  it('DW-1932: Delete of several routines names no stored data', async () => {
    // Mutation (Rule 19): answer the Classes list's set sentence for routines in `deleteConsequence` -> red.
    const { fixture, host, store, actions } = await mount(ROUTINES, [row('A.mac'), row('B.mac')]);
    store.setChecked(['A.mac', 'B.mac']);
    actions.run(ROUTINES.descriptor, DELETE_ACTION);
    await settle(fixture);
    expect(host.querySelector('.ocu-typed-name-consequence')?.textContent?.trim()).toBe(STRINGS.explorerRoutineDeleteSetConsequence.replace('<n>', '2'));
  });

  it('no transfer dialog opens over another, and Export opens on the checked rows only', async () => {
    const { fixture, host, calls, store, actions } = await mount(CLASSES, [row('A.cls')]);
    actions.run(CLASSES.descriptor, EXPORT_ACTION);
    await settle(fixture);
    expect(host.querySelector('app-explorer-export-dialog')).toBeNull();
    actions.run(CLASSES.descriptor, TASK_IMPORT_ACTION_ID);
    await settle(fixture);
    store.setChecked(['A.cls']);
    actions.run(CLASSES.descriptor, EXPORT_ACTION);
    actions.run(CLASSES.descriptor, COMPILE_ACTION);
    await settle(fixture);
    expect(host.querySelector('app-explorer-import-dialog')).not.toBeNull();
    expect(host.querySelector('app-explorer-export-dialog')).toBeNull();
    expect(host.querySelector('app-explorer-compile-dialog')).toBeNull();
    expect(calls).toHaveLength(0);
  });
});
