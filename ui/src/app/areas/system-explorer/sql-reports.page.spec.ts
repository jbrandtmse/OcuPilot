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
import {
  EXPLORER_SQL_REPORTS,
  SQL_REPORTS_GENERATE,
  SQL_REPORTS_GENERATE_BROWSER,
  SQL_REPORTS_SAVE,
  SQL_TUNING_ALL_TARGET,
  ScreenActionHandler,
} from '../../shell/screen-action-handler';
import { ARCHETYPE_PAGES, DESCRIPTOR_PAGES, resolveScreenPage } from '../../shell/screen-outlet';
import { stubAccountPreferences } from '../../testing/account-preferences';
import { SqlReportsPage } from './sql-reports.page';

/**
 * SQL troubleshooting reports (Story 21.29). The shared list page is replaced by an empty stand-in, so only this page's own wiring runs: the two actions
 * registered after the shell's handler, the Save query dialog and the request it sends, the Generate report dialog opened on the selected row's support
 * case and its two destinations, the typed-name Delete the handler draws, and the absence of any mail action (AC4). The handler, the stores and the bus
 * are real; only the server's answers are stubbed, each released by the test.
 */

@Component({ selector: 'app-list-page', template: '' })
class StubListPage {}

const LIST = SCREENS.find((screen) => screen.descriptor === EXPLORER_SQL_REPORTS)!;

const ACTION_PATH = `/api/ocupilot/screens/${LIST.toolIdentifier}/action`;

const ROOT = '/data/';

const WRC = 2291;

const ROWS = [
  { ID: '11', WRCNumber: WRC, Saved: '2026-11-26 10:00:00AM', Status: 'Planned', DelimitedIdentifiers: 1, Schema: 'SQLUser', Statement: 'SELECT A FROM OcuProbe229.T' },
  { ID: '12', WRCNumber: 3000, Saved: '2026-11-26 10:05:00AM', Status: 'Planned', DelimitedIdentifiers: 1, Schema: 'SQLUser', Statement: 'SELECT B FROM OcuProbe229.T' },
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
  TestBed.overrideComponent(SqlReportsPage, { remove: { imports: [ListPage] }, add: { imports: [StubListPage] } });
  const store = stores.for(LIST.descriptor, LIST.refreshRates);
  store.applyTick(ROWS, false, '', new Date());
  const fixture = TestBed.createComponent(SqlReportsPage);
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  fixture.detectChanges();
  return { fixture, host: fixture.nativeElement as HTMLElement, store, calls, events, actions: TestBed.inject(ScreenActions), handler: TestBed.inject(ScreenActionHandler) };
}

function slot(host: HTMLElement, name: string): HTMLElement | null {
  return host.querySelector(`[data-slot="${name}"]`);
}

/** Type `value` into the Save dialog's field `name`. */
async function typeInto(fixture: ComponentFixture<unknown>, host: HTMLElement, name: 'wrc' | 'statement', value: string): Promise<void> {
  const field = slot(host, name) as HTMLInputElement | HTMLTextAreaElement;
  field.value = value;
  field.dispatchEvent(new Event('input', { bubbles: true }));
  await settle(fixture);
}

/** Type `value` into the open export dialog's server-path name field. */
async function typePath(fixture: ComponentFixture<unknown>, host: HTMLElement, value: string): Promise<void> {
  const input = host.querySelector('.ocu-path-picker input[type="text"]') as HTMLInputElement;
  input.value = value;
  input.dispatchEvent(new Event('input', { bubbles: true }));
  await settle(fixture);
}

const status = (host: HTMLElement): string => host.querySelector('[data-sql-reports-status]')?.textContent?.trim() ?? '';

const dialogRefusal = (host: HTMLElement): string => host.querySelector('[data-explorer-transfer-refusal]')?.textContent?.trim() ?? '';

const proceed = (host: HTMLElement): HTMLButtonElement => slot(host, 'proceed') as HTMLButtonElement;

const created = (id: string): JsonResult<unknown> => ({
  kind: 'ok',
  status: 200,
  body: { action: 'created', target: { type: 'sql-saved-query', scope: 'namespace:USER', id }, readBack: { verdict: 'nothingSent' } },
});

const refused = (code: string, reason: string): JsonResult<unknown> => ({ kind: 'error', status: 409, code, reason, detail: null });

afterEach(() => {
  for (const node of planted.splice(0)) node.remove();
  document.querySelectorAll('app-screen-action-dialogs, .ocu-dialog').forEach((node) => node.remove());
  TestBed.resetTestingModule();
});

describe('the SQL troubleshooting reports page', () => {
  it("is the descriptor's own page", async () => {
    const loader = resolveScreenPage(DESCRIPTOR_PAGES, ARCHETYPE_PAGES, LIST.descriptor, LIST.archetype);
    expect(await loader?.()).toBe(SqlReportsPage);
  });

  // Mutation (Rule 19): drop one of this page's `actions.register` calls, or the handler's UNDRAWN ids for this screen -> the matching assertion goes red.
  it('registers Save query as the primary action and Generate report after the handler, which draws Delete and neither of the others', () => {
    expect(LIST.primaryAction.id).toBe(SQL_REPORTS_SAVE);
    expect(LIST.rowActions.map((action) => action.id)).toEqual([SQL_REPORTS_SAVE, SQL_REPORTS_GENERATE, SQL_REPORTS_GENERATE_BROWSER, 'delete']);
    const { actions } = mount();
    expect(actions.has(EXPLORER_SQL_REPORTS, LIST.primaryAction.id)).toBe(true);
    expect(actions.has(EXPLORER_SQL_REPORTS, SQL_REPORTS_GENERATE)).toBe(true);
    expect(actions.has(EXPLORER_SQL_REPORTS, 'delete')).toBe(true);
    expect(actions.has(EXPLORER_SQL_REPORTS, SQL_REPORTS_GENERATE_BROWSER)).toBe(false);
  });

  // Mutation (Rule 19): declare a `mail` row action on the descriptor, or draw a mailto link or a mail string in the page -> this goes red (AC4).
  it('offers no mail action, no mail link and no string that mails anyone (AC4)', () => {
    const { host, actions } = mount();
    const declared = [LIST.primaryAction.id, ...LIST.rowActions.map((action) => action.id)];
    expect(declared.filter((id) => /mail/i.test(id))).toEqual([]);
    expect(declared.filter((id) => actions.has(EXPLORER_SQL_REPORTS, id)).filter((id) => /mail/i.test(id))).toEqual([]);
    expect(host.innerHTML).not.toMatch(/mailto|@intersystems/i);
    const mine = Object.entries(STRINGS).filter(([key]) => /^(sqlReports|explorerSqlReports|explorerSqlTabReports)/.test(key));
    expect(mine.length).toBeGreaterThan(20);
    expect(mine.filter(([, value]) => /e-?mail|mailto|@/i.test(value.replace('%All', '')))).toEqual([]);
  });

  describe('Save query', () => {
    // Mutation (Rule 19): drop the primary action's registration -> the dialog never opens and the first assertion goes red.
    it('opens its dialog with no row selected, states the consequence, and holds Proceed while the statement is blank', async () => {
      const { fixture, host, actions, calls } = mount();
      actions.run(EXPLORER_SQL_REPORTS, SQL_REPORTS_SAVE);
      await settle(fixture);
      expect(host.ownerDocument.querySelector('.ocu-dialog-title')?.textContent?.trim()).toBe(STRINGS.sqlReportsSaveTitle);
      expect(slot(host, 'consequence')?.textContent?.trim()).toBe(STRINGS.sqlReportsSaveConsequence);
      expect(host.querySelector('label[for^="ocu-sql-report-wrc"]')?.textContent?.trim()).toBe(STRINGS.explorerSqlReportsColumnWrc);
      expect(host.querySelector('.ocu-field-caption')?.textContent?.trim()).toBe(STRINGS.sqlReportsWrcHelp);
      expect(host.querySelector('label[for^="ocu-sql-report-statement"]')?.textContent?.trim()).toBe(STRINGS.explorerSqlColumnStatement);
      expect(proceed(host).getAttribute('aria-disabled')).toBe('true');
      proceed(host).click();
      await settle(fixture);
      expect(calls).toHaveLength(0);
    });

    // Mutation (Rule 19): send the request on any target but `SQL_TUNING_ALL_TARGET`, or drop a value -> the request goes red.
    it('sends the statement and the case on the one target, then closes and says which case was saved', async () => {
      const { fixture, host, actions, calls, events } = mount();
      actions.run(EXPLORER_SQL_REPORTS, SQL_REPORTS_SAVE);
      await settle(fixture);
      await typeInto(fixture, host, 'wrc', ' 2291 ');
      await typeInto(fixture, host, 'statement', 'SELECT A FROM OcuProbe229.T WHERE A > ?');
      expect(proceed(host).getAttribute('aria-disabled')).toBeNull();
      proceed(host).click();
      await settle(fixture);
      expect(calls).toHaveLength(1);
      expect(calls[0].path).toBe(ACTION_PATH);
      expect(calls[0].body).toEqual({
        action: SQL_REPORTS_SAVE,
        id: SQL_TUNING_ALL_TARGET,
        values: { Statement: 'SELECT A FROM OcuProbe229.T WHERE A > ?', WRCNumber: '2291' },
      });
      calls[0].answer(created('13'));
      await settle(fixture);
      expect(slot(host, 'consequence')).toBeNull();
      expect(status(host)).toBe('Saved the query for support case 2291.');
      expect(events.map((event) => `${event.action} ${event.type} ${event.id}`)).toEqual(['created sql-saved-query 13']);
    });

    // Mutation (Rule 19): close the dialog on a refused send -> the dialog assertions go red, and the refusal is lost.
    it("keeps a refused save in the dialog as the instance's own sentence, and sends again on Proceed", async () => {
      const sentence = 'The instance answered this sentence, which no client string holds.';
      expect(Object.values(STRINGS)).not.toContain(sentence);
      const { fixture, host, actions, calls } = mount();
      actions.run(EXPLORER_SQL_REPORTS, SQL_REPORTS_SAVE);
      await settle(fixture);
      await typeInto(fixture, host, 'statement', 'UPDATE OcuProbe229.T SET A = 1');
      proceed(host).click();
      await settle(fixture);
      calls[0].answer(refused('EXPLORER.SQLREPORT.QUERYONLY', sentence));
      await settle(fixture);
      expect(slot(host, 'refusal')?.getAttribute('role')).toBe('alert');
      expect(slot(host, 'refusal')?.textContent?.trim()).toBe(sentence);
      expect(slot(host, 'consequence')).not.toBeNull();
      expect(status(host)).toBe('');
      proceed(host).click();
      await settle(fixture);
      expect(calls).toHaveLength(2);
    });

    it('cancelling sends nothing, and no second dialog opens over one', async () => {
      const { fixture, host, actions, calls, store } = mount();
      actions.run(EXPLORER_SQL_REPORTS, SQL_REPORTS_SAVE);
      await settle(fixture);
      store.setSelection(['11']);
      actions.run(EXPLORER_SQL_REPORTS, SQL_REPORTS_GENERATE);
      await settle(fixture);
      expect(host.ownerDocument.querySelectorAll('.ocu-dialog')).toHaveLength(1);
      expect(host.ownerDocument.querySelector('.ocu-dialog-title')?.textContent?.trim()).toBe(STRINGS.sqlReportsSaveTitle);
      (host.ownerDocument.querySelector('.ocu-dialog-actions button') as HTMLButtonElement).click();
      await settle(fixture);
      expect(slot(host, 'consequence')).toBeNull();
      expect(calls).toHaveLength(0);
    });
  });

  describe('Generate report', () => {
    it('opens no dialog without a selected row, and titles it by the selected row\'s support case', async () => {
      const { fixture, host, store, actions } = mount();
      actions.run(EXPLORER_SQL_REPORTS, SQL_REPORTS_GENERATE);
      await settle(fixture);
      expect(host.querySelector('app-explorer-export-dialog')).toBeNull();
      store.setSelection(['11']);
      actions.run(EXPLORER_SQL_REPORTS, SQL_REPORTS_GENERATE);
      await settle(fixture);
      expect(host.ownerDocument.querySelector('.ocu-dialog-title')?.textContent?.trim()).toBe('Generate report for support case 2291');
      expect(host.querySelector('[data-explorer-export-replaces]')?.textContent?.trim()).toBe(STRINGS.sqlReportsGenerateConsequence);
      expect(STRINGS.sqlReportsGenerateConsequence).toContain('A file already at this name is replaced.');
    });

    // Mutation (Rule 19): send `store.selection()` in `onGenerate` rather than the case the dialog opened on -> a selection cleared under the open dialog sends nothing and this goes red.
    it("generates the selected row's case to a server file and says where it went", async () => {
      const { fixture, host, store, actions, calls, events } = mount();
      store.setSelection(['11']);
      actions.run(EXPLORER_SQL_REPORTS, SQL_REPORTS_GENERATE);
      await settle(fixture);
      await typePath(fixture, host, 'out/WRC2291.xml');
      store.setSelection([]);
      await settle(fixture);
      (host.querySelector('[data-explorer-export-confirm]') as HTMLButtonElement).click();
      await settle(fixture);
      expect(calls).toHaveLength(1);
      expect(calls[0].path).toBe(ACTION_PATH);
      expect(calls[0].body).toEqual({
        action: SQL_REPORTS_GENERATE,
        id: SQL_TUNING_ALL_TARGET,
        values: { WRCNumber: '2291', root: ROOT, path: 'out/WRC2291.xml' },
      });
      calls[0].answer({
        kind: 'ok',
        status: 200,
        body: { action: 'updated', target: { type: 'sql-saved-query', scope: 'namespace:USER', id: SQL_TUNING_ALL_TARGET }, output: { root: ROOT, path: 'out/WRC2291.xml' } },
      });
      await settle(fixture);
      expect(host.querySelector('app-explorer-export-dialog')).toBeNull();
      expect(status(host)).toBe(`Exported the report for support case 2291 to ${ROOT}out/WRC2291.xml.`);
      expect(events.map((event) => `${event.action} ${event.type} ${event.id}`)).toEqual([`updated sql-saved-query ${SQL_TUNING_ALL_TARGET}`]);
    });

    // Mutation (Rule 19): send the report to this browser on the server file's action, or drop `saveText` -> the request or the saved file goes red.
    it('generates to this browser with no file, and saves the answered lines as WRC<case>.xml', async () => {
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
        store.setSelection(['11']);
        actions.run(EXPLORER_SQL_REPORTS, SQL_REPORTS_GENERATE);
        await settle(fixture);
        const browserChoice = host.querySelector('input[data-explorer-export-destination="browser"]') as HTMLInputElement;
        browserChoice.checked = true;
        browserChoice.dispatchEvent(new Event('change'));
        await settle(fixture);
        expect(host.querySelector('app-server-path-picker')).toBeNull();
        (host.querySelector('[data-explorer-export-confirm]') as HTMLButtonElement).click();
        await settle(fixture);
        expect(calls[0].body).toEqual({ action: SQL_REPORTS_GENERATE_BROWSER, id: SQL_TUNING_ALL_TARGET, values: { WRCNumber: '2291' } });
        calls[0].answer({
          kind: 'ok',
          status: 200,
          body: {
            action: 'updated',
            target: { type: 'sql-saved-query', scope: 'namespace:USER', id: SQL_TUNING_ALL_TARGET },
            output: { lines: ['<?xml version="1.0"?>', '<QButtons>', '</QButtons>'] },
          },
        });
        await settle(fixture);
        expect(saved.map((file) => [file.name, file.type])).toEqual([['WRC2291.xml', 'application/xml']]);
        expect(await saved[0].text).toBe('<?xml version="1.0"?>\n<QButtons>\n</QButtons>');
        expect(status(host)).toBe('Saved the report for support case 2291 as WRC2291.xml.');
      } finally {
        URL.createObjectURL = realCreate;
        URL.revokeObjectURL = realRevoke;
        HTMLAnchorElement.prototype.click = realClick;
      }
    });

    it('keeps a refused generate in the dialog with the instance\'s sentence and saves no file', async () => {
      const { fixture, host, store, actions, calls } = mount();
      store.setSelection(['11']);
      actions.run(EXPLORER_SQL_REPORTS, SQL_REPORTS_GENERATE);
      await settle(fixture);
      await typePath(fixture, host, 'out/WRC2291.xml');
      (host.querySelector('[data-explorer-export-confirm]') as HTMLButtonElement).click();
      await settle(fixture);
      calls[0].answer(refused('EXPLORER.SQLREPORT.NOROWS', STRINGS.sqlReportsRefusalNoRows));
      await settle(fixture);
      expect(host.querySelector('app-explorer-export-dialog')).not.toBeNull();
      expect(dialogRefusal(host)).toBe(STRINGS.sqlReportsRefusalNoRows);
      expect(status(host)).toBe('');
    });
  });

  describe('Delete', () => {
    // Mutation (Rule 19): drop `delete` from this screen's DESTRUCTIVE_CONSEQUENCES -> the handler registers no Delete and the first assertion goes red.
    it('types the saved query\'s ID after stating the consequence, sends only once confirmed, and says what was deleted', async () => {
      const { fixture, host, store, actions, handler, calls, events } = mount();
      store.setSelection(['11']);
      actions.run(EXPLORER_SQL_REPORTS, 'delete');
      await settle(fixture);
      const pending = handler.pending();
      expect(pending?.kind).toBe('typed-name');
      expect(pending?.target).toBe('11');
      expect(pending?.name).toBe('11');
      expect(pending?.verb).toBe(STRINGS.actionDelete);
      expect(pending?.consequence).toBe(STRINGS.sqlReportsDeleteConsequence);
      expect(calls).toHaveLength(0);
      handler.cancelPending();
      await settle(fixture);
      expect(calls).toHaveLength(0);
      actions.run(EXPLORER_SQL_REPORTS, 'delete');
      await settle(fixture);
      handler.confirmPending();
      await settle(fixture);
      expect(calls).toHaveLength(1);
      expect(calls[0].body).toEqual({ action: 'delete', id: '11' });
      calls[0].answer({ kind: 'ok', status: 200, body: { action: 'deleted', target: { type: 'sql-saved-query', scope: 'namespace:USER', id: '11' } } });
      await settle(fixture);
      expect(events.map((event) => `${event.action} ${event.type} ${event.id}`)).toEqual(['deleted sql-saved-query 11']);
      expect(status(host)).toBe(STRINGS.sqlReportsDeleteDone);
    });
  });
});
