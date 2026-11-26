import { Component } from '@angular/core';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type ApiRequestInit, type JsonResult } from '../../core/api';
import { ChangeBus, type ChangeEvent } from '../../core/change-bus';
import { OverlayStack } from '../../core/overlay-stack';
import { SQL_INDEX_ANALYSIS_RUN_ACTION_ID, ScreenActions } from '../../core/screen-actions';
import { ScreenStores } from '../../core/screen-store';
import { SCREENS } from '../../core/screens.generated';
import { STRINGS } from '../../core/strings';
import { ListPage } from '../../shell/list-page';
import {
  EXPLORER_SQL_INDEX_ANALYSIS,
  SQL_INDEX_ANALYSIS_GATHER,
  SQL_INDEX_ANALYSIS_PURGE,
  SQL_TUNING_ALL_TARGET,
  ScreenActionHandler,
} from '../../shell/screen-action-handler';
import { ARCHETYPE_PAGES, DESCRIPTOR_PAGES, resolveScreenPage } from '../../shell/screen-outlet';
import { stubAccountPreferences } from '../../testing/account-preferences';
import { SqlIndexAnalysisPage } from './sql-index-analysis.page';

/**
 * SQL index analyzer (Story 21.27). The shared list page is replaced by an empty stand-in, so only this page's own wiring runs: the three actions
 * registered after the shell's handler, the dialog Gather statements and Run report open with the choices each declares, the one request each sends and
 * the refusal that stays in the dialog, the warning Purge analysis opens, and the change event an applied action publishes. The handler, the stores and
 * the bus are real; only the server's answers are stubbed.
 */

@Component({ selector: 'app-list-page', template: '' })
class StubListPage {}

const LIST = SCREENS.find((screen) => screen.descriptor === EXPLORER_SQL_INDEX_ANALYSIS)!;

const ACTION_PATH = '/api/ocupilot/screens/explorer.sqlindexanalysis/action';

const applied = (id: string): JsonResult<unknown> => ({
  kind: 'ok',
  status: 200,
  body: { action: 'updated', target: { type: 'sql-index-analysis', scope: 'namespace:USER', id }, readBack: { verdict: 'nothingSent' } },
});

const refused = (code: string, reason: string): JsonResult<unknown> => ({ kind: 'error', status: 409, code, reason, detail: null });

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
  TestBed.overrideComponent(SqlIndexAnalysisPage, { remove: { imports: [ListPage] }, add: { imports: [StubListPage] } });
  const fixture = TestBed.createComponent(SqlIndexAnalysisPage);
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  fixture.detectChanges();
  return { fixture, host: fixture.nativeElement as HTMLElement, calls, events, actions: TestBed.inject(ScreenActions), handler: TestBed.inject(ScreenActionHandler) };
}

function slot(host: HTMLElement, name: string): HTMLElement | null {
  return host.querySelector(`[data-slot="${name}"]`);
}

function box(host: HTMLElement, name: string): HTMLInputElement {
  return host.querySelector(`[data-slot="${name}"] input`) as HTMLInputElement;
}

function toggle(input: HTMLInputElement): void {
  input.checked = !input.checked;
  input.dispatchEvent(new Event('change', { bubbles: true }));
}

afterEach(() => {
  for (const node of planted.splice(0)) node.remove();
  document.querySelectorAll('app-screen-action-dialogs, .ocu-dialog').forEach((node) => node.remove());
  TestBed.resetTestingModule();
});

describe('the SQL index analyzer page', () => {
  it("is the descriptor's own page", async () => {
    const loader = resolveScreenPage(DESCRIPTOR_PAGES, ARCHETYPE_PAGES, LIST.descriptor, LIST.archetype);
    expect(await loader?.()).toBe(SqlIndexAnalysisPage);
  });

  // Mutation (Rule 19): drop one of this page's `actions.register` calls -> the matching assertion goes red, and no surface offers that action.
  it('registers Gather statements, Run report and Purge analysis after the handler', () => {
    const { actions } = mount([]);
    expect(actions.has(EXPLORER_SQL_INDEX_ANALYSIS, SQL_INDEX_ANALYSIS_GATHER)).toBe(true);
    expect(actions.has(EXPLORER_SQL_INDEX_ANALYSIS, SQL_INDEX_ANALYSIS_RUN_ACTION_ID)).toBe(true);
    expect(actions.has(EXPLORER_SQL_INDEX_ANALYSIS, SQL_INDEX_ANALYSIS_PURGE)).toBe(true);
  });

  // Mutation (Rule 19): declare no primary action on the descriptor, or register Run report under the declared `run` -> the first assertion, or the
  // second and third, go red, and a list holding no row offers neither Gather statements nor Run report.
  it('offers Gather statements as the primary action and Run report at screen level, so neither needs a selected row', () => {
    const { actions } = mount([]);
    expect(LIST.primaryAction.id).toBe(SQL_INDEX_ANALYSIS_GATHER);
    expect(actions.has(EXPLORER_SQL_INDEX_ANALYSIS, LIST.primaryAction.id)).toBe(true);
    expect(SQL_INDEX_ANALYSIS_RUN_ACTION_ID).not.toBe('run');
    expect(LIST.rowActions.map((action) => action.id)).not.toContain(SQL_INDEX_ANALYSIS_RUN_ACTION_ID);
    expect(actions.has(EXPLORER_SQL_INDEX_ANALYSIS, 'run')).toBe(false);
  });

  // Mutation (Rule 19): send the gathering on any target but `SQL_TUNING_ALL_TARGET`, or drop a skip choice from its values -> the request goes red.
  it('a gathering asks for the two skip choices, both on, then sends them on the namespace\'s whole analysis and closes', async () => {
    const { fixture, host, actions, calls, events } = mount([applied(SQL_TUNING_ALL_TARGET)]);
    actions.run(EXPLORER_SQL_INDEX_ANALYSIS, SQL_INDEX_ANALYSIS_GATHER);
    await settle(fixture);
    expect(host.ownerDocument.querySelector('.ocu-dialog-title')?.textContent?.trim()).toBe(STRINGS.sqlIndexAnalysisGatherAction);
    expect(slot(host, 'consequence')?.textContent?.trim()).toBe(STRINGS.sqlIndexAnalysisGatherConsequence);
    expect(slot(host, 'report')).toBeNull();
    expect(slot(host, 'skip-idkeys')).toBeNull();
    expect(slot(host, 'skip-system')?.textContent?.trim()).toBe(STRINGS.sqlIndexAnalysisSkipSystemLabel);
    expect(slot(host, 'skip-inserts')?.textContent?.trim()).toBe(STRINGS.sqlIndexAnalysisSkipInsertsLabel);
    expect(box(host, 'skip-system').checked).toBe(true);
    expect(box(host, 'skip-inserts').checked).toBe(true);
    expect(calls).toHaveLength(0);
    (slot(host, 'proceed') as HTMLButtonElement).click();
    await settle(fixture);
    expect(calls).toEqual([
      {
        path: ACTION_PATH,
        method: 'POST',
        body: JSON.stringify({ action: 'gather', id: SQL_TUNING_ALL_TARGET, values: { SkipSystem: 'true', SkipInserts: 'true' } }),
      },
    ]);
    expect(events.map((event) => `${event.type}/${event.id}/${event.action}`)).toEqual([`sql-index-analysis/${SQL_TUNING_ALL_TARGET}/updated`]);
    expect(slot(host, 'consequence')).toBeNull();
  });

  // Mutation (Rule 19): keep the first sentence whatever the box says -> the second assertion goes red.
  it('a gathering that includes system classes and routines says it outlasts the page\'s wait, and sends the choice', async () => {
    const { fixture, host, actions, calls } = mount([applied(SQL_TUNING_ALL_TARGET)]);
    actions.run(EXPLORER_SQL_INDEX_ANALYSIS, SQL_INDEX_ANALYSIS_GATHER);
    await settle(fixture);
    toggle(box(host, 'skip-system'));
    await settle(fixture);
    expect(slot(host, 'consequence')?.textContent?.trim()).toBe(STRINGS.sqlIndexAnalysisGatherSystemConsequence);
    expect(STRINGS.sqlIndexAnalysisGatherSystemConsequence.startsWith(STRINGS.sqlIndexAnalysisGatherConsequence)).toBe(true);
    toggle(box(host, 'skip-inserts'));
    await settle(fixture);
    (slot(host, 'proceed') as HTMLButtonElement).click();
    await settle(fixture);
    expect(JSON.parse(calls[0].body).values).toEqual({ SkipSystem: 'false', SkipInserts: 'false' });
  });

  // Mutation (Rule 19): send the first report whatever is chosen, or drop the IDKEY choice -> the request goes red.
  it('a report run asks for the report and the three choices, and sends them', async () => {
    const { fixture, host, actions, calls } = mount([applied(SQL_TUNING_ALL_TARGET)]);
    actions.run(EXPLORER_SQL_INDEX_ANALYSIS, SQL_INDEX_ANALYSIS_RUN_ACTION_ID);
    await settle(fixture);
    expect(host.ownerDocument.querySelector('.ocu-dialog-title')?.textContent?.trim()).toBe(STRINGS.sqlIndexAnalysisRunAction);
    expect(slot(host, 'consequence')?.textContent?.trim()).toBe(STRINGS.sqlIndexAnalysisRunConsequence);
    const options = Array.from(host.querySelectorAll('[data-slot="report"] option')) as HTMLOptionElement[];
    expect(options.map((option) => [option.value, option.textContent?.trim()])).toEqual([
      ['IU', STRINGS.sqlIndexAnalysisReportIU],
      ['TS', STRINGS.sqlIndexAnalysisReportTS],
      ['TI', STRINGS.sqlIndexAnalysisReportTI],
      ['JI', STRINGS.sqlIndexAnalysisReportJI],
      ['OI', STRINGS.sqlIndexAnalysisReportOI],
    ]);
    expect(slot(host, 'skip-idkeys')?.textContent?.trim()).toBe(STRINGS.sqlIndexAnalysisSkipIdKeysLabel);
    expect(box(host, 'skip-idkeys').checked).toBe(true);
    const select = host.querySelector('[data-slot="report"] select') as HTMLSelectElement;
    select.value = 'TS';
    select.dispatchEvent(new Event('change', { bubbles: true }));
    toggle(box(host, 'skip-idkeys'));
    await settle(fixture);
    (slot(host, 'proceed') as HTMLButtonElement).click();
    await settle(fixture);
    expect(calls).toEqual([
      {
        path: ACTION_PATH,
        method: 'POST',
        body: JSON.stringify({
          action: 'run',
          id: SQL_TUNING_ALL_TARGET,
          values: { Report: 'TS', SkipSystem: 'true', SkipInserts: 'true', SkipIdKeys: 'false' },
        }),
      },
    ]);
  });

  // Mutation (Rule 19): close the dialog on a refused send -> the dialog assertions go red, and the refusal is lost.
  it('keeps a refused send in the dialog as the instance\'s own sentence, and sends again on Proceed', async () => {
    const { fixture, host, actions, calls } = mount([
      refused('SQL.INDEXANALYSIS.NOSTATEMENTS', STRINGS.sqlIndexAnalysisRefusalNoStatements),
      applied(SQL_TUNING_ALL_TARGET),
    ]);
    actions.run(EXPLORER_SQL_INDEX_ANALYSIS, SQL_INDEX_ANALYSIS_RUN_ACTION_ID);
    await settle(fixture);
    (slot(host, 'proceed') as HTMLButtonElement).click();
    await settle(fixture);
    expect(slot(host, 'refusal')?.getAttribute('role')).toBe('alert');
    expect(slot(host, 'refusal')?.textContent?.trim()).toBe(STRINGS.sqlIndexAnalysisRefusalNoStatements);
    expect(slot(host, 'consequence')).not.toBeNull();
    (slot(host, 'proceed') as HTMLButtonElement).click();
    await settle(fixture);
    expect(calls).toHaveLength(2);
    expect(slot(host, 'consequence')).toBeNull();
  });

  it('cancelling a dialog sends nothing, and no second dialog opens over one', async () => {
    const { fixture, host, actions, calls } = mount([]);
    actions.run(EXPLORER_SQL_INDEX_ANALYSIS, SQL_INDEX_ANALYSIS_GATHER);
    await settle(fixture);
    actions.run(EXPLORER_SQL_INDEX_ANALYSIS, SQL_INDEX_ANALYSIS_RUN_ACTION_ID);
    await settle(fixture);
    expect(host.ownerDocument.querySelectorAll('.ocu-dialog')).toHaveLength(1);
    expect(host.ownerDocument.querySelector('.ocu-dialog-title')?.textContent?.trim()).toBe(STRINGS.sqlIndexAnalysisGatherAction);
    (host.ownerDocument.querySelector('.ocu-dialog-actions button') as HTMLButtonElement).click();
    await settle(fixture);
    expect(slot(host, 'consequence')).toBeNull();
    expect(calls).toHaveLength(0);
  });

  // Mutation (Rule 19): send the purge on any target but `SQL_TUNING_ALL_TARGET` -> the request's id goes red.
  it('a purge warns first, then is sent on the namespace\'s whole analysis and publishes the updated event', async () => {
    const { fixture, actions, calls, events, handler } = mount([applied(SQL_TUNING_ALL_TARGET)]);
    actions.run(EXPLORER_SQL_INDEX_ANALYSIS, SQL_INDEX_ANALYSIS_PURGE);
    await settle(fixture);
    expect(handler.pending()?.kind).toBe('warning');
    expect(handler.pending()?.consequence).toBe(STRINGS.sqlIndexAnalysisPurgeConsequence);
    expect(calls).toHaveLength(0);
    handler.confirmPending(false);
    await settle(fixture);
    expect(calls).toEqual([{ path: ACTION_PATH, method: 'POST', body: JSON.stringify({ action: 'purge', id: SQL_TUNING_ALL_TARGET }) }]);
    expect(events.map((event) => `${event.type}/${event.id}/${event.action}`)).toEqual([`sql-index-analysis/${SQL_TUNING_ALL_TARGET}/updated`]);
  });

  // Mutation (Rule 19): drop `purge` from WARNING_CONSEQUENCES -> no warning opens and the request is sent at once.
  it('a cancelled purge warning sends nothing', async () => {
    const { fixture, actions, calls, handler } = mount([]);
    actions.run(EXPLORER_SQL_INDEX_ANALYSIS, SQL_INDEX_ANALYSIS_PURGE);
    await settle(fixture);
    expect(handler.pending()?.kind).toBe('warning');
    handler.cancelPending();
    await settle(fixture);
    expect(calls).toHaveLength(0);
  });

  it('opens no purge warning while a dialog of the page is open', async () => {
    const { fixture, actions, handler } = mount([]);
    actions.run(EXPLORER_SQL_INDEX_ANALYSIS, SQL_INDEX_ANALYSIS_GATHER);
    await settle(fixture);
    actions.run(EXPLORER_SQL_INDEX_ANALYSIS, SQL_INDEX_ANALYSIS_PURGE);
    await settle(fixture);
    expect(handler.pending()).toBeNull();
  });
});
