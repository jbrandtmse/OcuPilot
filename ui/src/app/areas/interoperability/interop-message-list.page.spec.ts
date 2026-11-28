import { Component } from '@angular/core';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

import { ApiService, type ApiRequestInit, type JsonResult } from '../../core/api';
import { ChangeBus, type ChangeEvent } from '../../core/change-bus';
import { OverlayStack } from '../../core/overlay-stack';
import { ScopeService } from '../../core/scope';
import { ScreenActions } from '../../core/screen-actions';
import { ScreenStores } from '../../core/screen-store';
import { SCREENS } from '../../core/screens.generated';
import { STRINGS } from '../../core/strings';
import { AuditPage } from '../logs/audit.page';
import { INTEROP_MESSAGE_LIST, MESSAGE_EXPORT, ScreenActionHandler } from '../../shell/screen-action-handler';
import { stubAccountPreferences } from '../../testing/account-preferences';
import { InteropMessageListPage } from './interop-message-list.page';

/**
 * The Messages page's Export (Story 24.16 Batch 3). The shared search page is replaced by an empty stand-in, so only this page's own wiring runs: the Export action
 * it registers, the review of the checked rows it asks for first, the dialog that lists what each message would do and offers the instance's own separators and
 * character sets, the one request an Export sends -- the two choices and the digest of the review, the checked rows its target -- the file the answer carries saved by
 * this browser, the status line and the failure lines, and a refusal kept in the dialog. The handler, the stores and the bus are real; only the server's answers are stubbed.
 */

@Component({ selector: 'app-audit-page', template: '' })
class StubSearchPage {}

const LIST = SCREENS.find((screen) => screen.descriptor === INTEROP_MESSAGE_LIST)!;

/** A message's review line as the instance words it: its id, source and target joined by a middle dot and an arrow, then its verdict. */
const MIDDLE_DOT = String.fromCharCode(183);
const ARROW = String.fromCharCode(8594);
const OK = `12 ${MIDDLE_DOT} Src ${ARROW} Op: ${STRINGS.interopExportVerdictExport}`;
const NOT_TEXT = `13 ${MIDDLE_DOT} Src ${ARROW} Op: ${STRINGS.interopExportVerdictNotext}`;

const review = (lines: readonly string[] = [OK, NOT_TEXT]): JsonResult<unknown> => ({
  kind: 'ok',
  status: 200,
  body: {
    rows: [{ field: 'Messages', before: '', after: lines.join('\n') }],
    review: { Digest: 'd1', Separator: 'CRLF', Charset: 'UTF8', Separators: ['CRLF', 'CR', 'LF', 'MLLP', 'Tab', 'None'], Charsets: ['UTF8', 'CP1252', 'Latin2'] },
  },
});

/** The bytes `abc` as the instance sends them, base64-encoded. */
const FILE = 'YWJj';

const exported = (lines: readonly string[], file = FILE): JsonResult<unknown> => ({
  kind: 'ok',
  status: 200,
  body: { action: 'updated', target: { type: 'interop-message', scope: 'USER', id: '12' }, readBack: { verdict: 'matches' }, output: { lines, file } },
});

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
  readonly scope: string | null | undefined;
  readonly body: string;
}

/** Mount the page with the rows `12` and `13` checked, each request resolving to the next of `answers`. */
function mount(answers: JsonResult<unknown>[], checked: readonly string[] = ['13', '12']) {
  TestBed.resetTestingModule();
  const calls: Call[] = [];
  const api = {
    requestJson: async <T,>(path: string, init: ApiRequestInit = {}): Promise<JsonResult<T>> => {
      calls.push({ path, method: init.method ?? 'GET', scope: init.scope, body: init.body ?? '' });
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
      { provide: ScopeService, useValue: { loaded: () => true, namespace: () => 'USER', subscribe: () => () => {} } as unknown as ScopeService },
    ],
  });
  TestBed.overrideComponent(InteropMessageListPage, { remove: { imports: [AuditPage] }, add: { imports: [StubSearchPage] } });
  const store = stores.for(LIST.descriptor, LIST.refreshRates);
  store.setChecked([...checked]);
  const fixture = TestBed.createComponent(InteropMessageListPage);
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  fixture.detectChanges();
  // The page's handler is the real one, constructed before the page registers its own action.
  TestBed.inject(ScreenActionHandler);
  return { fixture, host: fixture.nativeElement as HTMLElement, store, calls, events, actions: TestBed.inject(ScreenActions) };
}

const confirm = (host: HTMLElement): HTMLButtonElement => host.querySelector('[data-interop-export-confirm]') as HTMLButtonElement;

async function openDialog(fixture: ComponentFixture<unknown>, actions: ScreenActions): Promise<void> {
  actions.run(INTEROP_MESSAGE_LIST, MESSAGE_EXPORT);
  await settle(fixture);
}

function choose(fixture: ComponentFixture<unknown>, host: HTMLElement, selector: string, value: string): void {
  const select = host.querySelector(selector) as HTMLSelectElement;
  select.value = value;
  select.dispatchEvent(new Event('change'));
  fixture.detectChanges();
}

let saved: { name: string; size: number }[] = [];

beforeEach(() => {
  saved = [];
  let pendingSize = 0;
  vi.stubGlobal(
    'URL',
    Object.assign(URL, {
      createObjectURL: (blob: Blob) => {
        pendingSize = blob.size;
        return 'blob:export';
      },
      revokeObjectURL: () => undefined,
    })
  );
  vi.spyOn(HTMLAnchorElement.prototype, 'click').mockImplementation(function (this: HTMLAnchorElement) {
    saved.push({ name: this.download, size: pendingSize });
  });
});

afterEach(() => {
  for (const node of planted.splice(0)) node.remove();
  TestBed.resetTestingModule();
  vi.restoreAllMocks();
  vi.unstubAllGlobals();
});

describe('the Messages page\'s Export', () => {
  it('declares Export as a row action and as a checked-set action of the list', () => {
    expect(LIST.rowActions.map((action) => action.id)).toEqual(['resend', MESSAGE_EXPORT]);
    expect(LIST.multiSelect?.extraActions).toEqual([MESSAGE_EXPORT]);
  });

  // Mutation (Rule 19): drop this page's `actions.register` of `export` -> the first assertion goes red.
  it('registers Export, reviews the checked rows first in id order, and opens the dialog over the review, sending nothing but the review', async () => {
    const { fixture, host, actions, calls } = mount([review()]);
    expect(actions.has(INTEROP_MESSAGE_LIST, MESSAGE_EXPORT)).toBe(true);
    await openDialog(fixture, actions);
    expect(calls).toHaveLength(1);
    expect(calls[0].path).toBe(`/api/ocupilot/screens/${LIST.toolIdentifier}/dryrun`);
    expect(JSON.parse(calls[0].body)).toEqual({ action: MESSAGE_EXPORT, id: '12,13' });
    expect(host.querySelector('.ocu-dialog-title')?.textContent?.trim()).toBe('Export 2 messages');
    expect([...host.querySelectorAll('[data-interop-export-line]')].map((line) => line.textContent?.trim())).toEqual([OK, NOT_TEXT]);
    expect(host.querySelector('[data-interop-export-consequence]')?.textContent?.trim()).toBe(STRINGS.interopMessageExportConsequence);
    const separators = [...host.querySelectorAll('[data-interop-export-separator] option')] as HTMLOptionElement[];
    expect(separators.map((option) => option.value)).toEqual(['CRLF', 'CR', 'LF', 'MLLP', 'Tab', 'None']);
    expect(separators.find((option) => option.selected)?.value).toBe('CRLF');
    const charsets = [...host.querySelectorAll('[data-interop-export-charset] option')] as HTMLOptionElement[];
    expect(charsets.map((option) => option.value)).toEqual(['UTF8', 'CP1252', 'Latin2']);
    expect(charsets.find((option) => option.selected)?.value).toBe('UTF8');
  });

  it('titles the dialog for one message in the singular and opens nothing when no row is checked', async () => {
    const one = mount([review([OK])], ['12']);
    await openDialog(one.fixture, one.actions);
    expect(one.host.querySelector('.ocu-dialog-title')?.textContent?.trim()).toBe('Export 1 message');
    const none = mount([review()], []);
    await openDialog(none.fixture, none.actions);
    expect(none.calls).toHaveLength(0);
    expect(none.host.querySelector('app-interop-message-export-dialog')).toBeNull();
    expect(none.store.refusal()).toBe(STRINGS.tableCheckRowsFirst);
  });

  it('opens nothing and shows the refusal on the list when the review is refused, as for a set none of whose messages can be exported', async () => {
    const { fixture, host, store, actions, calls } = mount([
      { kind: 'error', status: 400, code: 'TOOL.ARGUMENTS', reason: 'The arguments are not valid.', detail: { problem: `${STRINGS.interopExportRefusalNone}\n13: ${STRINGS.interopExportVerdictNotext}` } } as JsonResult<unknown>,
    ]);
    await openDialog(fixture, actions);
    expect(calls).toHaveLength(1);
    expect(host.querySelector('app-interop-message-export-dialog')).toBeNull();
    expect(store.refusal()).toBe(STRINGS.interopExportRefusalNone);
  });

  // Mutation (Rule 19): send the choices without the digest, or the checked rows in the order they were checked -> the request assertion goes red.
  it('sends one export carrying the two choices and the review\'s digest, saves the file the answer carries as the namespace\'s, and reads the status and failure lines', async () => {
    const failure = `13: ${STRINGS.interopExportOutcomeNotExported}: the vendor said no`;
    const { fixture, host, actions, calls, store, events } = mount([review(), exported([`12: ${STRINGS.interopExportOutcomeExported}`, failure])]);
    await openDialog(fixture, actions);
    choose(fixture, host, '[data-interop-export-separator]', 'LF');
    choose(fixture, host, '[data-interop-export-charset]', 'CP1252');
    confirm(host).click();
    await settle(fixture);
    expect(calls).toHaveLength(2);
    expect(calls[1].path).toBe(`/api/ocupilot/screens/${LIST.toolIdentifier}/action`);
    expect(calls[1].scope).toBe('USER');
    expect(JSON.parse(calls[1].body)).toEqual({ action: MESSAGE_EXPORT, id: '12,13', values: { Separator: 'LF', Charset: 'CP1252', Reviewed: 'd1' } });
    expect(saved).toEqual([{ name: 'USER-messages.txt', size: 3 }]);
    expect(host.querySelector('[data-interop-export-status]')?.textContent?.trim()).toBe('Saved 1 message as USER-messages.txt.');
    expect([...host.querySelectorAll('[data-interop-export-failure]')].map((line) => line.textContent?.trim())).toEqual([failure]);
    expect(host.querySelector('app-interop-message-export-dialog')).toBeNull();
    expect([...store.checked()]).toEqual([]);
    expect(events.map((event) => `${event.type}/${event.action}`)).toEqual(['interop-message/updated']);
  });

  it('saves nothing and shows only the failure lines when no message was exported', async () => {
    const failures = [`12: ${STRINGS.interopExportOutcomeNotExported}: refused`, `13: ${STRINGS.interopExportOutcomeNotExported}: refused`];
    const { fixture, host, actions } = mount([review(), { kind: 'ok', status: 200, body: { action: 'updated', output: { lines: failures } } }]);
    await openDialog(fixture, actions);
    confirm(host).click();
    await settle(fixture);
    expect(saved).toEqual([]);
    expect(host.querySelector('[data-interop-export-status]')?.textContent?.trim()).toBe('');
    expect([...host.querySelectorAll('[data-interop-export-failure]')].map((line) => line.textContent?.trim())).toEqual(failures);
  });

  it('keeps the dialog open with the instance\'s sentence when the export is refused, as for a set that changed after it was reviewed', async () => {
    const { fixture, host, actions, events } = mount([
      review(),
      { kind: 'error', status: 409, code: 'INTEROP.EXPORT.CHANGED', reason: STRINGS.interopExportRefusalChanged } as JsonResult<unknown>,
    ]);
    await openDialog(fixture, actions);
    confirm(host).click();
    await settle(fixture);
    expect(host.querySelector('app-interop-message-export-dialog')).not.toBeNull();
    expect(host.querySelector('[data-interop-export-refusal]')?.textContent?.trim()).toBe(STRINGS.interopExportRefusalChanged);
    expect(saved).toEqual([]);
    expect(events).toEqual([]);
  });

  it('closes on Cancel, sending nothing more and saving nothing', async () => {
    const { fixture, host, actions, calls } = mount([review()]);
    await openDialog(fixture, actions);
    const cancel = [...host.querySelectorAll('.ocu-dialog-actions button')].find((button) => button.textContent?.trim() === STRINGS.actionCancel) as HTMLButtonElement;
    cancel.click();
    await settle(fixture);
    expect(host.querySelector('app-interop-message-export-dialog')).toBeNull();
    expect(calls).toHaveLength(1);
    expect(saved).toEqual([]);
  });
});
