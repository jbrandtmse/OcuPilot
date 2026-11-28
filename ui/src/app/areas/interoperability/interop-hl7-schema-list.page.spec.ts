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
import { ScreenActionHandler } from '../../shell/screen-action-handler';
import { stubAccountPreferences } from '../../testing/account-preferences';
import { INTEROP_HL7_SCHEMA_ADD_ACTION, INTEROP_HL7_SCHEMA_LIST, InteropHl7SchemaListPage } from './interop-hl7-schema-list.page';
import { fill } from './interop-transfer.flow';

/**
 * The HL7 schemas page (Story 24.18 Batch 1). The shared list page is replaced by an empty stand-in, so only this page's own wiring runs: the three
 * actions it registers beside the handler's Delete, the New HL7 schema dialog it opens over the schemas the list holds, the typed-name Delete the
 * handler draws, and the export and import dialogs it opens with the schema's wording. The handler, the stores and the bus are real; each request
 * the page sends is answered by a stub the test releases, and the allowed directories read answers one root.
 */

@Component({ selector: 'app-list-page', template: '' })
class StubListPage {}

const LIST = SCREENS.find((screen) => screen.descriptor === INTEROP_HL7_SCHEMA_LIST)!;

const ROOT = '/data/';

const ROWS = [
  { Category: '2.5.1', Base: '', Description: '', Standard: true, Modified: '' },
  { Category: 'OcuProbe', Base: '2.5.1', Description: 'Probe', Standard: false, Modified: '2026-11-26 09:00:00' },
];

const planted: HTMLElement[] = [];

async function settle(fixture: ComponentFixture<unknown>): Promise<void> {
  for (let pass = 0; pass < 6; pass += 1) {
    await new Promise((resolve) => setTimeout(resolve, 5));
    fixture.detectChanges();
    await fixture.whenStable();
  }
}

/** One request the page sent: its path, parsed body, the namespace it was pinned to, and what releases its answer. */
interface Call {
  readonly path: string;
  readonly body: Record<string, unknown>;
  readonly scope: string | null | undefined;
  answer(result: JsonResult<unknown>): void;
}

function mount() {
  TestBed.resetTestingModule();
  const calls: Call[] = [];
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
  TestBed.overrideComponent(InteropHl7SchemaListPage, { remove: { imports: [ListPage] }, add: { imports: [StubListPage] } });
  const store = stores.for(LIST.descriptor, LIST.refreshRates);
  store.applyTick(ROWS, false, '', new Date());
  const fixture = TestBed.createComponent(InteropHl7SchemaListPage);
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  fixture.detectChanges();
  return { fixture, host: fixture.nativeElement as HTMLElement, store, calls, events, actions: TestBed.inject(ScreenActions), handler: TestBed.inject(ScreenActionHandler) };
}

/** Type `value` into the open transfer dialog's server-path name field. */
async function typePath(fixture: ComponentFixture<unknown>, host: HTMLElement, value: string): Promise<void> {
  const input = host.querySelector('.ocu-path-picker input[type="text"]') as HTMLInputElement;
  input.value = value;
  input.dispatchEvent(new Event('input', { bubbles: true }));
  await settle(fixture);
}

const status = (host: HTMLElement): string => host.querySelector('[data-interop-hl7-transfer-status]')?.textContent?.trim() ?? '';

afterEach(() => {
  for (const node of planted.splice(0)) node.remove();
  TestBed.resetTestingModule();
});

describe('the HL7 schemas page', () => {
  it('declares New HL7 schema as its primary action and Delete and the four transfer actions as its row actions, and registers all but the transfers\' four with the handler', () => {
    // Mutation (Rule 19): drop the list's UNDRAWN_ACTIONS entry in the handler -> it registers `import` too and the last assertion goes red.
    expect(LIST.primaryAction?.id).toBe(INTEROP_HL7_SCHEMA_ADD_ACTION);
    expect(LIST.rowActions.map((action) => action.id)).toEqual(['delete', 'export', 'export-browser', 'import', 'import-local']);
    const { actions } = mount();
    expect([INTEROP_HL7_SCHEMA_ADD_ACTION, 'delete', 'export', TASK_IMPORT_ACTION_ID].map((id) => actions.has(INTEROP_HL7_SCHEMA_LIST, id))).toEqual([true, true, true, true]);
    expect(['export-browser', 'import', 'import-local'].map((id) => actions.has(INTEROP_HL7_SCHEMA_LIST, id))).toEqual([false, false, false]);
    expect([actionLabel(INTEROP_HL7_SCHEMA_LIST, 'add'), actionLabel(INTEROP_HL7_SCHEMA_LIST, 'export'), actionLabel(INTEROP_HL7_SCHEMA_LIST, TASK_IMPORT_ACTION_ID)]).toEqual([
      STRINGS.interopHl7SchemaAddAction,
      STRINGS.taskExportAction,
      STRINGS.actionImport,
    ]);
  });

  it('opens the New HL7 schema dialog over the schemas the list holds, and posts the new schema to the namespace the shell is scoped to', async () => {
    // Mutation (Rule 19): drop `baseChoices.set` from `onOpen` -> the base offers only none and the option assertion goes red.
    const { fixture, host, actions, calls, events } = mount();
    actions.run(INTEROP_HL7_SCHEMA_LIST, INTEROP_HL7_SCHEMA_ADD_ACTION);
    await settle(fixture);
    expect(host.querySelector('.ocu-dialog-title')?.textContent?.trim()).toBe(STRINGS.interopHl7SchemaAddAction);
    expect([...host.querySelectorAll('[data-interop-hl7-schema-field="Base"] option')].map((option) => (option as HTMLOptionElement).value)).toEqual(['', '2.5.1', 'OcuProbe']);
    const type = (name: string, value: string, event = 'input'): void => {
      const input = host.querySelector(`[data-interop-hl7-schema-field="${name}"]`) as HTMLInputElement;
      input.value = value;
      input.dispatchEvent(new Event(event));
      fixture.detectChanges();
    };
    type('Name', 'OcuProbe2');
    type('Base', '2.5.1', 'change');
    (host.querySelector('[data-interop-hl7-schema-confirm]') as HTMLButtonElement).click();
    await settle(fixture);
    expect(calls.map((call) => [call.path, call.scope, call.body])).toEqual([['/api/ocupilot/interop/hl7-schemas', 'USER', { Name: 'OcuProbe2', Base: '2.5.1' }]]);
    calls[0].answer({ kind: 'ok', status: 201, body: { id: 'OcuProbe2', target: { type: 'interop-hl7-schema', scope: 'USER', id: 'OcuProbe2' } } });
    await settle(fixture);
    expect(host.querySelector('app-interop-hl7-schema-dialog')).toBeNull();
    expect(events.map((event) => [event.type, event.id, event.action, event.tool])).toEqual([['interop-hl7-schema', 'OcuProbe2', 'created', 'interop.hl7schemas.add']]);
  });

  it('types the schema\'s name before Delete, titles the dialog with the published words, states what goes, and sends the name as the id', async () => {
    // Mutation (Rule 19): drop the list's DESTRUCTIVE_CONSEQUENCES entry -> Delete registers no handler and the first assertion goes red.
    const { fixture, store, actions, handler, calls, events } = mount();
    expect(actions.has(INTEROP_HL7_SCHEMA_LIST, 'delete')).toBe(true);
    store.setSelection(['OcuProbe']);
    actions.run(INTEROP_HL7_SCHEMA_LIST, 'delete');
    await settle(fixture);
    expect(handler.pending()?.kind).toBe('typed-name');
    expect(handler.pending()?.name).toBe('OcuProbe');
    expect(`${handler.pending()?.verb} ${handler.pending()?.name}`).toBe(fill(STRINGS.interopHl7DeleteTitle, { schema: 'OcuProbe' }));
    expect(handler.pending()?.consequence).toBe(STRINGS.interopHl7DeleteConsequence);
    expect(calls).toHaveLength(0);
    handler.confirmPending();
    await settle(fixture);
    expect(calls).toHaveLength(1);
    expect(calls[0].path).toBe(`/api/ocupilot/screens/${LIST.toolIdentifier}/action`);
    expect(calls[0].body).toEqual({ action: 'delete', id: 'OcuProbe' });
    calls[0].answer({ kind: 'ok', status: 200, body: { action: 'deleted', target: { type: 'interop-hl7-schema', scope: 'USER', id: 'OcuProbe' } } });
    await settle(fixture);
    expect(events.map((event) => `${event.action} ${event.type} ${event.id}`)).toEqual(['deleted interop-hl7-schema OcuProbe']);
  });

  it('opens no export dialog without a selected schema, titles it by the selected schema, and exports to a server file pinned to the namespace it opened in', async () => {
    const { fixture, host, store, actions, calls, events } = mount();
    actions.run(INTEROP_HL7_SCHEMA_LIST, 'export');
    await settle(fixture);
    expect(host.querySelector('app-explorer-export-dialog')).toBeNull();
    store.setSelection(['OcuProbe']);
    actions.run(INTEROP_HL7_SCHEMA_LIST, 'export');
    await settle(fixture);
    expect(host.querySelector('.ocu-dialog-title')?.textContent?.trim()).toBe('Export HL7 schema OcuProbe');
    await typePath(fixture, host, 'out/OcuProbe.xml');
    store.setSelection([]);
    await settle(fixture);
    (host.querySelector('[data-explorer-export-confirm]') as HTMLButtonElement).click();
    await settle(fixture);
    expect(calls[0].body).toEqual({ action: 'export', id: 'OcuProbe', values: { root: ROOT, path: 'out/OcuProbe.xml' } });
    expect(calls[0].scope).toBe('USER');
    calls[0].answer({ kind: 'ok', status: 200, body: { action: 'updated', target: { type: 'interop-hl7-schema', scope: 'USER', id: 'OcuProbe' }, output: { root: ROOT, path: 'out/OcuProbe.xml' } } });
    await settle(fixture);
    expect(host.querySelector('app-explorer-export-dialog')).toBeNull();
    expect(status(host)).toBe(`Exported HL7 schema OcuProbe to ${ROOT}out/OcuProbe.xml.`);
    expect(events.map((event) => `${event.action} ${event.type} ${event.id}`)).toEqual(['updated interop-hl7-schema OcuProbe']);
  });

  it('exports to this browser with no file, and saves the answered lines as <schema>.xml', async () => {
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
      store.setSelection(['OcuProbe']);
      actions.run(INTEROP_HL7_SCHEMA_LIST, 'export');
      await settle(fixture);
      const browserChoice = host.querySelector('input[data-explorer-export-destination="browser"]') as HTMLInputElement;
      browserChoice.checked = true;
      browserChoice.dispatchEvent(new Event('change'));
      await settle(fixture);
      (host.querySelector('[data-explorer-export-confirm]') as HTMLButtonElement).click();
      await settle(fixture);
      expect(calls[0].body).toEqual({ action: 'export-browser', id: 'OcuProbe' });
      calls[0].answer({ kind: 'ok', status: 200, body: { action: 'updated', target: { type: 'interop-hl7-schema', scope: 'USER', id: 'OcuProbe' }, output: { lines: ['<?xml version="1.0"?>', '<Export>', '</Export>'] } } });
      await settle(fixture);
      expect(saved.map((file) => [file.name, file.type])).toEqual([['OcuProbe.xml', 'application/xml']]);
      expect(await saved[0].text).toBe('<?xml version="1.0"?>\n<Export>\n</Export>');
      expect(status(host)).toBe('Saved HL7 schema OcuProbe as OcuProbe.xml.');
    } finally {
      URL.createObjectURL = realCreate;
      URL.revokeObjectURL = realRevoke;
      HTMLAnchorElement.prototype.click = realClick;
    }
  });

  it('imports from a server file on the one import target, titled and worded as published, and says which file', async () => {
    const { fixture, host, actions, calls } = mount();
    actions.run(INTEROP_HL7_SCHEMA_LIST, TASK_IMPORT_ACTION_ID);
    await settle(fixture);
    expect(host.querySelector('input[data-explorer-import-compile]')).toBeNull();
    expect(host.querySelector('.ocu-dialog-title')?.textContent?.trim()).toBe(STRINGS.interopHl7ImportTitle);
    expect(host.querySelector('[data-explorer-import-replaces]')?.textContent?.trim()).toBe(STRINGS.interopHl7ImportConsequence);
    await typePath(fixture, host, 'in/OcuProbe.xml');
    (host.querySelector('[data-explorer-import-confirm]') as HTMLButtonElement).click();
    await settle(fixture);
    expect(calls[0].body).toEqual({ action: 'import', id: 'import', values: { root: ROOT, path: 'in/OcuProbe.xml' } });
    expect(calls[0].scope).toBe('USER');
    calls[0].answer({ kind: 'ok', status: 200, body: { action: 'updated', target: { type: 'interop-hl7-schema', scope: 'USER', id: 'import' } } });
    await settle(fixture);
    expect(host.querySelector('app-explorer-import-dialog')).toBeNull();
    expect(status(host)).toBe(`Imported the HL7 schema in ${ROOT}in/OcuProbe.xml.`);
  });

  it('sends a local file on the schema it holds, the document name less .HL7, and the unnamed import target otherwise', async () => {
    // Mutation (Rule 19): pass `.LUT` as the HL7 page's extension -> the file's id reads `import` and the first assertion goes red.
    const text = '<?xml version="1.0"?>\n<Export><Document name="OcuProbe.HL7"><Category name="OcuProbe"/></Document></Export>\n';
    for (const [content, id] of [
      [text, 'OcuProbe'],
      ['<Export><Document name="OcuProbe.LUT"/></Export>', 'import'],
    ] as const) {
      const { fixture, host, actions, calls } = mount();
      actions.run(INTEROP_HL7_SCHEMA_LIST, TASK_IMPORT_ACTION_ID);
      await settle(fixture);
      const local = host.querySelector('input[data-explorer-import-source="local"]') as HTMLInputElement;
      local.checked = true;
      local.dispatchEvent(new Event('change'));
      await settle(fixture);
      const input = host.querySelector('input[data-explorer-import-file]') as HTMLInputElement;
      expect(input.getAttribute('accept')).toBe('.xml');
      Object.defineProperty(input, 'files', { value: [new File([content], 'probe.xml')], configurable: true });
      input.dispatchEvent(new Event('change'));
      await settle(fixture);
      (host.querySelector('[data-explorer-import-confirm]') as HTMLButtonElement).click();
      await settle(fixture);
      expect(calls[0].body).toEqual({ action: 'import-local', id, values: { fileName: 'probe.xml', content } });
      calls[0].answer({ kind: 'ok', status: 200, body: { action: 'updated', target: { type: 'interop-hl7-schema', scope: 'USER', id } } });
      await settle(fixture);
      expect(status(host)).toBe('Imported the HL7 schema in probe.xml.');
    }
  });

  it('keeps the import dialog open with the instance\'s sentence when the refusal names no field', async () => {
    const { fixture, host, actions, calls } = mount();
    actions.run(INTEROP_HL7_SCHEMA_LIST, TASK_IMPORT_ACTION_ID);
    await settle(fixture);
    await typePath(fixture, host, 'in/two.xml');
    (host.querySelector('[data-explorer-import-confirm]') as HTMLButtonElement).click();
    await settle(fixture);
    const reason = 'An import file must hold exactly one HL7 schema and nothing else, in the form the Export action writes.';
    calls[0].answer({ kind: 'error', status: 409, code: 'INTEROP.HL7.IMPORTSHAPE', reason, detail: null });
    await settle(fixture);
    expect(host.querySelector('app-explorer-import-dialog')).not.toBeNull();
    expect(host.querySelector('[data-explorer-transfer-refusal]')?.textContent?.trim()).toBe(reason);
    expect(status(host)).toBe('');
  });
});
